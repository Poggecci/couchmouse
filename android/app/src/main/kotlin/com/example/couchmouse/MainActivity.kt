package com.example.couchmouse

import android.annotation.SuppressLint
import android.bluetooth.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.hardware.input.InputManager
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val GAMEPAD_UI_INTERVAL_MS = 33L // ~30 Hz is plenty for a status display
        // Max silence on the HID link before a keep-alive report (see updateLinkKeepAlive).
        const val LINK_KEEPALIVE_MS = 50L
    }

    private val CHANNEL = "com.example.couchmouse/hid"
    private val TAG = "RemoteMouseHID"

    private var bluetoothAdapter: BluetoothAdapter? = null
    // Volatile: also read by the gamepad sender thread (see sendReport).
    @Volatile private var bluetoothHidDevice: BluetoothHidDevice? = null
    @Volatile private var hostDevice: BluetoothDevice? = null
    private var keyboardReportHost: BluetoothDevice? = null
    private var keyboardInputResumed = false

    // Gamepad forwarding (Report ID 3). Input events, method-channel calls and
    // HID callbacks (mainExecutor) run on the main thread; reports are sent at a
    // fixed rate from a dedicated sender thread via [gamepadPump].
    private var gamepadModeEnabled = false
    private var windowFocused = false
    private val gamepadMapper = GamepadInputMapper()

    // Report sender (see GamepadReportPump for the policy). Its own thread
    // keeps main-thread work (UI, input dispatch) from delaying reports.
    private val gamepadSenderThread =
        HandlerThread("GamepadReportPump", Process.THREAD_PRIORITY_DISPLAY).apply { start() }
    private val gamepadSender = Handler(gamepadSenderThread.looper)
    private val gamepadPump = GamepadReportPump(send = { report -> sendReport(GamepadReport.REPORT_ID, report) })
    private val gamepadTick = Runnable { runGamepadPump() }
    // Axis layout per InputDevice id. Android assigns a new id when a
    // controller reconnects, and the cache is cleared whenever the mode toggles.
    private val gamepadLayouts = HashMap<Int, GamepadAxisLayout>()

    // Live gamepad state for the Flutter UI, throttled so the UI bridge is
    // never in the input -> HID hot path.
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingUiGamepadState: GamepadState? = null
    private val flushGamepadUi = Runnable {
        val state = pendingUiGamepadState ?: return@Runnable
        pendingUiGamepadState = null
        notifyFlutter("onGamepadState", gamepadStateToMap(state))
    }

    private val inputDeviceListener = object : InputManager.InputDeviceListener {
        override fun onInputDeviceAdded(deviceId: Int) = onControllersChanged()
        override fun onInputDeviceRemoved(deviceId: Int) {
            gamepadLayouts.remove(deviceId)
            onControllersChanged()
        }
        override fun onInputDeviceChanged(deviceId: Int) {
            gamepadLayouts.remove(deviceId)
            onControllersChanged()
        }
    }

    // Link keep-alive state (see updateLinkKeepAlive). The keep-alive itself runs on
    // the main thread; lastReportSentAt is also written by the gamepad sender thread.
    @Volatile private var lastReportSentAt = 0L       // SystemClock.uptimeMillis()
    private var lastKeyboardReport = ByteArray(8)     // last keyboard state sent
    private val linkKeepAliveTick = Runnable { runLinkKeepAlive() }

    private var isRegistered = false
    private var cachedFlutterEngine: FlutterEngine? = null

    private val bluetoothReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action
            if (BluetoothAdapter.ACTION_SCAN_MODE_CHANGED == action) {
                val scanMode = intent.getIntExtra(BluetoothAdapter.EXTRA_SCAN_MODE, BluetoothAdapter.ERROR)
                val isDiscoverable = (scanMode == BluetoothAdapter.SCAN_MODE_CONNECTABLE_DISCOVERABLE)
                runOnUiThread {
                    cachedFlutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, CHANNEL).invokeMethod(
                            "onScanModeChanged", 
                            mapOf("isDiscoverable" to isDiscoverable)
                        )
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter(BluetoothAdapter.ACTION_SCAN_MODE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(bluetoothReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(bluetoothReceiver, filter)
        }
        (getSystemService(Context.INPUT_SERVICE) as? InputManager)
            ?.registerInputDeviceListener(inputDeviceListener, mainHandler)
    }

    private fun initBluetoothHID() {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
        if (bluetoothAdapter == null) {
            Log.e(TAG, "Bluetooth not supported on this hardware configuration.")
            return
        }

        try {
            // Fetch proxy reference to standard system HID service
            bluetoothAdapter?.getProfileProxy(this, object : BluetoothProfile.ServiceListener {
                @SuppressLint("MissingPermission")
                override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
                    if (profile == BluetoothProfile.HID_DEVICE) {
                        bluetoothHidDevice = proxy as? BluetoothHidDevice
                        try {
                            registerAppProfile()
                        } catch (e: SecurityException) {
                            Log.e(TAG, "SecurityException during profile registration: ${e.message}")
                        } catch (e: Exception) {
                            Log.e(TAG, "Exception during profile registration: ${e.message}")
                        }
                    }
                }

                override fun onServiceDisconnected(profile: Int) {
                    if (profile == BluetoothProfile.HID_DEVICE) {
                        bluetoothHidDevice = null
                        hostDevice = null
                        isRegistered = false
                        keyboardReportHost = null
                        updateGamepadStreaming()
                        notifyFlutter("onRegistrationChanged", mapOf("registered" to false))
                        notifyFlutter("onConnectionStateChanged", mapOf("connected" to false))
                    }
                }
            }, BluetoothProfile.HID_DEVICE)
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException during getProfileProxy: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Exception during getProfileProxy: ${e.message}")
        }
    }

    @SuppressLint("MissingPermission")
    private fun registerAppProfile() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return

        val sdpSettings = BluetoothHidDeviceAppSdpSettings(
            "CouchMouse",
            "CouchMouse Controller",
            "CouchMouseDev",
            // HIDDeviceSubclass: 0xC0 (combo keyboard/pointing) | 0x08 (gamepad).
            // Most hosts rely on the report descriptor rather than this value.
            0xC8.toByte(),
            HidDescriptors.COMPOSITE_DESCRIPTOR
        )

        try {
            bluetoothHidDevice?.registerApp(
                sdpSettings,
                // Without QoS the controller services the HID link only every ~25-35 ms,
                // so reports leave in bursts (cursor stutter). Ask for guaranteed
                // service with low latency, like a real mouse does.
                hidQos(),
                hidQos(),
                mainExecutor,
                object : BluetoothHidDevice.Callback() {
                    override fun onAppStatusChanged(pluggedDevice: BluetoothDevice?, registered: Boolean) {
                        Log.d(TAG, "Application HID Profile registration state: $registered")
                        isRegistered = registered
                        if (!registered) keyboardReportHost = null
                        updateGamepadStreaming()
                        notifyFlutter("onRegistrationChanged", mapOf("registered" to registered))
                    }

                    override fun onConnectionStateChanged(device: BluetoothDevice?, state: Int) {
                        val isConnected = (state == BluetoothProfile.STATE_CONNECTED)
                        val deviceName = if (isConnected) {
                            try {
                                device?.name ?: "Host Laptop"
                            } catch (e: SecurityException) {
                                Log.e(TAG, "SecurityException querying device name: ${e.message}")
                                "Host Laptop"
                            }
                        } else null
                        
                        when (state) {
                            BluetoothProfile.STATE_CONNECTED -> {
                                Log.i(TAG, "Connected to host: $deviceName")
                                hostDevice = device
                                updateGamepadStreaming()
                            }
                            BluetoothProfile.STATE_DISCONNECTED -> {
                                Log.i(TAG, "Disconnected from host")
                                hostDevice = null
                                keyboardReportHost = null
                                updateGamepadStreaming()
                            }
                        }
                        updateLinkKeepAlive()

                        notifyFlutter(
                            "onConnectionStateChanged",
                            mapOf(
                                "connected" to isConnected,
                                "deviceName" to deviceName,
                                "deviceAddress" to device?.address
                            )
                        )
                    }

                    override fun onGetReport(device: BluetoothDevice?, type: Byte, id: Byte, bufferSize: Int) {
                        Log.d(TAG, "onGetReport: type=$type, id=$id, bufferSize=$bufferSize")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            val data = when (id.toInt()) {
                                1 -> ByteArray(8) // Keyboard
                                2 -> ByteArray(4) // Mouse
                                GamepadReport.REPORT_ID -> gamepadPump.currentReport() // Gamepad
                                else -> ByteArray(bufferSize.coerceAtLeast(1))
                            }
                            try {
                                bluetoothHidDevice?.replyReport(device, type, id, data)
                            } catch (e: SecurityException) {
                                Log.e(TAG, "SecurityException in replyReport: ${e.message}")
                            } catch (e: Exception) {
                                Log.e(TAG, "Exception in replyReport: ${e.message}")
                            }
                        }
                    }

                    override fun onSetReport(device: BluetoothDevice?, type: Byte, id: Byte, data: ByteArray?) {
                        Log.d(TAG, "onSetReport: type=$type, id=$id")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            try {
                                bluetoothHidDevice?.reportError(device, BluetoothHidDevice.ERROR_RSP_SUCCESS)
                            } catch (e: SecurityException) {
                                Log.e(TAG, "SecurityException in reportError: ${e.message}")
                            } catch (e: Exception) {
                                Log.e(TAG, "Exception in reportError: ${e.message}")
                            }
                        }
                    }

                    override fun onSetProtocol(device: BluetoothDevice?, protocol: Byte) {
                        Log.d(TAG, "onSetProtocol: protocol=$protocol")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            try {
                                bluetoothHidDevice?.reportError(device, BluetoothHidDevice.ERROR_RSP_SUCCESS)
                            } catch (e: SecurityException) {
                                Log.e(TAG, "SecurityException in reportError: ${e.message}")
                            } catch (e: Exception) {
                                Log.e(TAG, "Exception in reportError: ${e.message}")
                            }
                        }
                    }
                }
            )
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException inside registerApp: ${e.message}")
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Exception inside registerApp: ${e.message}")
            throw e
        }
    }

    @SuppressLint("MissingPermission")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cachedFlutterEngine = flutterEngine

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
                }
                "requestDiscoverable" -> {
                    val duration = call.argument<Int>("duration") ?: 120
                    val adapter = bluetoothAdapter
                    if (adapter == null) {
                        result.error("UNAVAILABLE", "Bluetooth adapter not available", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).apply {
                            putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, duration)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: SecurityException) {
                        result.error("SECURITY_EXCEPTION", "Permission denied: ${e.message}", null)
                    } catch (e: Exception) {
                        result.error("ERROR", "Could not request Bluetooth discoverability: ${e.message}", null)
                    }
                }
                "isDiscoverable" -> {
                    val adapter = bluetoothAdapter
                    if (adapter == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val isDisc = adapter.scanMode == BluetoothAdapter.SCAN_MODE_CONNECTABLE_DISCOVERABLE
                        result.success(isDisc)
                    } catch (e: SecurityException) {
                        result.error("SECURITY_EXCEPTION", "Permission denied: ${e.message}", null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getSdkVersion" -> {
                    result.success(Build.VERSION.SDK_INT)
                }
                "registerAppProfile" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                        result.error("UNSUPPORTED", "Bluetooth HID requires Android 9+", null)
                        return@setMethodCallHandler
                    }
                    try {
                        if (bluetoothHidDevice == null) {
                            initBluetoothHID()
                        } else if (!isRegistered) {
                            registerAppProfile()
                        }
                        result.success(true)
                    } catch (e: SecurityException) {
                        result.error("SECURITY_EXCEPTION", "Permission denied: ${e.message}", null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getConnectionState" -> {
                    val device = hostDevice
                    val deviceName = if (device != null) {
                        try {
                            device.name ?: "Host Laptop"
                        } catch (e: SecurityException) {
                            "Host Laptop"
                        }
                    } else null
                    val deviceAddress = device?.address

                    if (device != null) {
                        result.success(mapOf(
                            "connected" to true, 
                            "deviceName" to deviceName,
                            "deviceAddress" to deviceAddress,
                            "registered" to isRegistered
                        ))
                    } else {
                        result.success(mapOf(
                            "connected" to false, 
                            "deviceName" to null,
                            "deviceAddress" to null,
                            "registered" to isRegistered
                        ))
                    }
                }
                "openBluetoothSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Could not open Bluetooth settings", e.message)
                    }
                }
                "getPairedDevices" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                        result.error("UNSUPPORTED", "Bluetooth HID requires Android 9+", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val pairedDevices = bluetoothAdapter?.bondedDevices ?: emptySet()
                        val devicesList = pairedDevices.map { device ->
                            val name = try {
                                device.name ?: "Unknown Device"
                            } catch (e: SecurityException) {
                                "Unknown Device"
                            }
                            mapOf(
                                "name" to name,
                                "address" to device.address
                            )
                        }
                        result.success(devicesList)
                    } catch (e: SecurityException) {
                        result.error("SECURITY_EXCEPTION", "Permission denied: ${e.message}", null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "connectDevice" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                        result.error("UNSUPPORTED", "Bluetooth HID requires Android 9+", null)
                        return@setMethodCallHandler
                    }
                    val address = call.argument<String>("address")
                    if (address == null) {
                        result.error("INVALID_ARGUMENT", "Address cannot be null", null)
                        return@setMethodCallHandler
                    }
                    val hid = bluetoothHidDevice
                    val adapter = bluetoothAdapter
                    if (hid == null || adapter == null) {
                        result.error("UNAVAILABLE", "Bluetooth HID device proxy not initialized", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val device = adapter.getRemoteDevice(address)
                        val success = hid.connect(device)
                        result.success(success)
                    } catch (e: SecurityException) {
                        result.error("SECURITY_EXCEPTION", "Permission denied: ${e.message}", null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "disconnectDevice" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                        result.error("UNSUPPORTED", "Bluetooth HID requires Android 9+", null)
                        return@setMethodCallHandler
                    }
                    val address = call.argument<String>("address")
                    val hid = bluetoothHidDevice
                    val adapter = bluetoothAdapter
                    if (hid == null || adapter == null) {
                        result.error("UNAVAILABLE", "Bluetooth HID device proxy not initialized", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val device = if (address != null) {
                            adapter.getRemoteDevice(address)
                        } else {
                            hostDevice
                        }
                        if (device != null) {
                            if (device == hostDevice) {
                                releaseKeyboard()
                                sendNeutralGamepadNow()
                            }
                            val success = hid.disconnect(device)
                            result.success(success)
                        } else {
                            result.success(false)
                        }
                    } catch (e: SecurityException) {
                        result.error("SECURITY_EXCEPTION", "Permission denied: ${e.message}", null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "sendMouseReport" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                        result.error("UNSUPPORTED", "Bluetooth HID requires Android 9+", null)
                        return@setMethodCallHandler
                    }
                    val buttons = call.argument<Int>("buttons") ?: 0
                    val dx = call.argument<Double>("dx")?.toInt() ?: 0
                    val dy = call.argument<Double>("dy")?.toInt() ?: 0
                    val wheel = call.argument<Int>("wheel") ?: 0

                    val report = byteArrayOf(
                        buttons.toByte(),
                        dx.coerceIn(-127, 127).toByte(),
                        dy.coerceIn(-127, 127).toByte(),
                        wheel.coerceIn(-127, 127).toByte()
                    )
                    val success = sendReport(2, report)
                    if (success) {
                        result.success(null)
                    } else {
                        result.error("UNAVAILABLE", "No Bluetooth device currently connected.", null)
                    }
                }
                "sendKeyboardReport" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                        result.error("UNSUPPORTED", "Bluetooth HID requires Android 9+", null)
                        return@setMethodCallHandler
                    }
                    val bytesList = call.argument<List<Int>>("bytes")
                    if (bytesList == null || bytesList.size != 8) {
                        result.error("INVALID_ARGUMENT", "Keyboard report requires exactly 8 bytes", null)
                        return@setMethodCallHandler
                    }
                    val report = ByteArray(8)
                    for (i in 0 until 8) {
                        report[i] = bytesList[i].toByte()
                    }
                    val holdsKeys = report.any { it != 0.toByte() }
                    if (holdsKeys && (!keyboardInputResumed || !hasWindowFocus())) {
                        result.error("UNAVAILABLE", "Couch Mouse has lost window focus.", null)
                        return@setMethodCallHandler
                    }
                    val success = sendReport(1, report)
                    if (success) {
                        lastKeyboardReport = report
                        keyboardReportHost = if (holdsKeys) hostDevice else null
                        result.success(null)
                    } else {
                        result.error("UNAVAILABLE", "No Bluetooth device currently connected.", null)
                    }
                }
                "setGamepadMode" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled == null) {
                        result.error("INVALID_ARGUMENT", "enabled must be a boolean", null)
                        return@setMethodCallHandler
                    }
                    gamepadModeEnabled = enabled
                    gamepadLayouts.clear()
                    // Deliver stick events as they arrive instead of once per display
                    // frame (saves up to a frame of latency). API 30+.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        window.decorView.requestUnbufferedDispatch(
                            if (enabled) InputDevice.SOURCE_CLASS_JOYSTICK else InputDevice.SOURCE_CLASS_NONE
                        )
                    }
                    updateGamepadStreaming()
                    // The handheld sits idle as a controller: don't let the screen sleep.
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(gamepadModeEnabled)
                }
                "getGamepadMode" -> {
                    result.success(gamepadModeEnabled)
                }
                "setGamepadReportRate" -> {
                    val hz = call.argument<Int>("hz")
                    if (hz == null || hz <= 0) {
                        result.error("INVALID_ARGUMENT", "hz must be a positive integer", null)
                        return@setMethodCallHandler
                    }
                    gamepadSender.post { gamepadPump.setMaxRateHz(hz) }
                    result.success(true)
                }
                "getGamepadControllers" -> {
                    result.success(physicalControllerNames())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * L2CAP/HCI QoS for the HID channels. Latency is in microseconds and becomes the
     * link's poll interval (Tpoll). 2.5 ms measured smooth on a Linux host (vs ~25-35 ms
     * bursts with no QoS). Token rate/bucket cover small reports at up to ~250 Hz.
     */
    private fun hidQos() = BluetoothHidDeviceAppQosSettings(
        BluetoothHidDeviceAppQosSettings.SERVICE_GUARANTEED,
        4000,  // token rate, bytes/s
        16,    // token bucket size, bytes
        0,     // peak bandwidth (0 = unspecified)
        2500,  // latency, us
        BluetoothHidDeviceAppQosSettings.MAX, // delay variation (don't care)
    )

    @SuppressLint("MissingPermission")
    private fun sendReport(id: Int, report: ByteArray): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false

        val device = hostDevice
        val hid = bluetoothHidDevice
        if (device == null || hid == null) {
            return false
        }

        return try {
            lastReportSentAt = SystemClock.uptimeMillis()
            hid.sendReport(device, id, report)
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException inside sendReport: ${e.message}")
            false
        } catch (e: Exception) {
            Log.e(TAG, "Exception inside sendReport: ${e.message}")
            false
        }
    }

    private fun releaseKeyboard() {
        val device = hostDevice ?: return
        if (keyboardReportHost == device && sendReport(1, ByteArray(8))) {
            keyboardReportHost = null
            lastKeyboardReport = ByteArray(8)
        }
    }

    /**
     * Starts the fixed-rate gamepad stream when it should run (gamepad mode on,
     * host connected, app resumed and focused) and stops it otherwise.
     * Stopping releases everything: locally (key-up events for held buttons
     * will go elsewhere now) and on the host (the pump flushes neutral reports).
     */
    private fun updateGamepadStreaming() {
        val stream = gamepadModeEnabled && isRegistered && hostDevice != null &&
            keyboardInputResumed && windowFocused
        if (!stream) {
            gamepadMapper.reset()
            gamepadPump.update(GamepadState.NEUTRAL)
            if (gamepadModeEnabled) publishGamepadStateToUi(GamepadState.NEUTRAL)
        }
        gamepadSender.post {
            if (gamepadPump.setStreaming(stream)) runGamepadPump()
        }
        // Called on every registration/connection/lifecycle/focus change, so it also
        // (re)evaluates the link keep-alive.
        updateLinkKeepAlive()
    }

    /** Sender thread only: sends whatever is due and schedules the next wake-up. */
    private fun runGamepadPump() {
        gamepadSender.removeCallbacks(gamepadTick)
        val next = gamepadPump.tick(SystemClock.uptimeMillis()) ?: return
        gamepadSender.postAtTime(gamepadTick, next)
    }

    /** One synchronous neutral report, for when the host link is about to go away. */
    private fun sendNeutralGamepadNow() {
        if (gamepadModeEnabled) sendReport(GamepadReport.REPORT_ID, GamepadState.NEUTRAL.toReport())
    }

    // ---- Physical controller capture (gamepad mode) ----

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (gamepadModeEnabled && gamepadMapper.handles(event.keyCode) && isPhysicalController(event.device)) {
            val layout = layoutFor(event.device)
            when (event.action) {
                KeyEvent.ACTION_DOWN -> if (event.repeatCount == 0) {
                    gamepadMapper.onKey(event.keyCode, true, layout)
                    onGamepadInput()
                }
                KeyEvent.ACTION_UP -> {
                    gamepadMapper.onKey(event.keyCode, false, layout)
                    onGamepadInput()
                }
            }
            // Consume so Flutter UI navigation and the B -> Back fallback don't fire.
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (gamepadModeEnabled &&
            event.isFromSource(InputDevice.SOURCE_JOYSTICK) &&
            event.actionMasked == MotionEvent.ACTION_MOVE &&
            isPhysicalController(event.device)
        ) {
            // Batched samples are skipped on purpose: only the latest position matters.
            gamepadMapper.onMotion(layoutFor(event.device)) { axis -> event.getAxisValue(axis) }
            onGamepadInput()
            return true
        }
        return super.dispatchGenericMotionEvent(event)
    }

    private fun onGamepadInput() {
        val state = gamepadMapper.state
        // A change wakes the sender at once instead of waiting for the next keepalive.
        if (gamepadPump.update(state)) gamepadSender.post(gamepadTick)
        publishGamepadStateToUi(state)
    }

    private fun publishGamepadStateToUi(state: GamepadState) {
        if (pendingUiGamepadState == null) mainHandler.postDelayed(flushGamepadUi, GAMEPAD_UI_INTERVAL_MS)
        pendingUiGamepadState = state
    }

    private fun gamepadStateToMap(state: GamepadState): Map<String, Any> = mapOf(
        "buttons" to state.buttons,
        "hat" to state.hat,
        "leftX" to state.leftX.toDouble(),
        "leftY" to state.leftY.toDouble(),
        "rightX" to state.rightX.toDouble(),
        "rightY" to state.rightY.toDouble(),
        "leftTrigger" to state.leftTrigger.toDouble(),
        "rightTrigger" to state.rightTrigger.toDouble(),
    )

    private fun physicalControllerNames(): List<String> =
        InputDevice.getDeviceIds().toList()
            .mapNotNull { InputDevice.getDevice(it) }
            .filter { isPhysicalController(it) }
            .map { it.name }
            .distinct()

    private fun onControllersChanged() {
        notifyFlutter("onGamepadControllersChanged", mapOf("controllers" to physicalControllerNames()))
    }

    private fun isPhysicalController(device: InputDevice?): Boolean {
        if (device == null || device.isVirtual) return false
        val sources = device.sources
        return (sources and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD ||
            (sources and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
    }

    private fun layoutFor(device: InputDevice?): GamepadAxisLayout {
        if (device == null) return GamepadAxisLayout.DEFAULT
        return gamepadLayouts.getOrPut(device.id) {
            GamepadAxisLayout.from(
                hasAxis = { axis -> device.getMotionRange(axis, InputDevice.SOURCE_JOYSTICK) != null },
                flat = { axis -> device.getMotionRange(axis, InputDevice.SOURCE_JOYSTICK)?.flat ?: 0f },
            )
        }
    }

    // ---- Link keep-alive ----
    //
    // Android's HID-device power manager drops an idle link into sniff with
    // subrating (max receive latency 225 ms). The first report after a pause then
    // waits up to ~225 ms for the next anchor: the start of every swipe or key
    // press lags. Keeping a little traffic on the link holds it in the busy
    // 11.25 ms sniff state. The keep-alive re-sends the current keyboard state:
    // an unchanged keyboard report produces no key events on the host, and it
    // never touches the mouse (a zero-motion mouse report can count as activity).
    // Runs on the main thread, like every other keyboard send, so it can never
    // re-send a stale key state after a newer one.

    // In gamepad mode the report pump already sends at least every 50 ms, so the
    // link keep-alive stands down.
    private fun linkKeepAliveWanted(): Boolean =
        isRegistered && hostDevice != null && keyboardInputResumed && hasWindowFocus() &&
            !gamepadModeEnabled

    private fun updateLinkKeepAlive() {
        mainHandler.removeCallbacks(linkKeepAliveTick)
        if (linkKeepAliveWanted()) runLinkKeepAlive()
    }

    private fun runLinkKeepAlive() {
        if (!linkKeepAliveWanted()) return
        val now = SystemClock.uptimeMillis()
        if (now - lastReportSentAt >= LINK_KEEPALIVE_MS) {
            sendReport(1, lastKeyboardReport)
        }
        // max(): if the send didn't go out (link dropping), don't spin on a past deadline.
        mainHandler.postAtTime(linkKeepAliveTick, maxOf(lastReportSentAt, now) + LINK_KEEPALIVE_MS)
    }

    private fun notifyFlutter(method: String, arguments: Map<String, Any?>) {
        cachedFlutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod(method, arguments)
        }
    }

    override fun onResume() {
        super.onResume()
        keyboardInputResumed = true
        updateGamepadStreaming()
    }

    override fun onPause() {
        keyboardInputResumed = false
        releaseKeyboard()
        updateGamepadStreaming()
        super.onPause()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        windowFocused = hasFocus
        if (!hasFocus) releaseKeyboard()
        updateGamepadStreaming()
        super.onWindowFocusChanged(hasFocus)
        updateLinkKeepAlive()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(linkKeepAliveTick)
        releaseKeyboard()
        gamepadSender.removeCallbacksAndMessages(null)
        gamepadSenderThread.quitSafely()
        if (gamepadPump.isStreaming) sendNeutralGamepadNow()
        mainHandler.removeCallbacks(flushGamepadUi)
        (getSystemService(Context.INPUT_SERVICE) as? InputManager)
            ?.unregisterInputDeviceListener(inputDeviceListener)
        cachedFlutterEngine = null
        try {
            unregisterReceiver(bluetoothReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Exception unregistering bluetooth receiver: ${e.message}")
        }
        super.onDestroy()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && bluetoothAdapter != null) {
            try {
                if (isRegistered) {
                    bluetoothHidDevice?.unregisterApp()
                    isRegistered = false
                }
                bluetoothAdapter?.closeProfileProxy(BluetoothProfile.HID_DEVICE, bluetoothHidDevice)
            } catch (e: SecurityException) {
                Log.e(TAG, "SecurityException during unregisterApp/closeProfileProxy: ${e.message}")
            } catch (e: Exception) {
                Log.e(TAG, "Exception during unregisterApp/closeProfileProxy: ${e.message}")
            }
        }
    }
}
