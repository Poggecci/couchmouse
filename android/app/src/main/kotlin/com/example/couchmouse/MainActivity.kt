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
import io.flutter.plugin.common.StandardMethodCodec

class MainActivity : FlutterActivity() {
    private companion object {
        const val GAMEPAD_UI_INTERVAL_MS = 33L
        // Max silence on the HID link before a keep-alive report (see updateLinkKeepAlive).
        const val LINK_KEEPALIVE_MS = 50L

        const val HID_QOS_LATENCY_US = 2_500
        const val MOUSE_REPORT_ID = 2
    }

    private val CHANNEL = "com.example.couchmouse/hid"
    private val MOUSE_CHANNEL = "com.example.couchmouse/mouse"
    private val TAG = "RemoteMouseHID"
    private val settingsDocuments = SettingsDocuments(this)

    private var bluetoothAdapter: BluetoothAdapter? = null
    // Volatile: also read by the gamepad sender thread (see sendReport).
    @Volatile private var bluetoothHidDevice: BluetoothHidDevice? = null
    @Volatile private var hostDevice: BluetoothDevice? = null
    private var a2dpProxy: BluetoothProfile? = null
    private var headsetProxy: BluetoothProfile? = null
    private var audioProxiesRequested = false
    private var keyboardReportHost: BluetoothDevice? = null
    private var keyboardInputResumed = false

    // Gamepad forwarding (Report ID 3). Input events, method-channel calls and
    // HID callbacks (mainExecutor) run on the main thread. The pump sends
    // reports on a dedicated sender thread.
    private var gamepadModeEnabled = false
    private var windowFocused = false
    private val gamepadMappers = LinkedHashMap<Int, GamepadInputMapper>()
    private var gamepadMotionDeviceId: Int? = null

    // Report sender (see GamepadReportPump for the policy). Its own thread
    // keeps main-thread work (UI, input dispatch) from delaying reports.
    private val gamepadSenderThread =
        HandlerThread("GamepadReportPump", Process.THREAD_PRIORITY_DISPLAY).apply { start() }
    private val gamepadSender = Handler(gamepadSenderThread.looper)
    private val gamepadPump = GamepadReportPump(send = { report -> sendReport(GamepadReport.REPORT_ID, report) })
    private val gamepadTick = Runnable { runGamepadPump() }

    // Mouse reports (Report ID 2), paced on their own sender thread (see
    // MouseReportPump). Motion arrives on a background channel task queue, so
    // neither receiving nor sending waits for the main thread, which also
    // renders the UI.
    private val mouseSenderThread =
        HandlerThread("MouseReportPump", Process.THREAD_PRIORITY_DISPLAY).apply { start() }
    private val mouseSender = Handler(mouseSenderThread.looper)
    private val mousePump = MouseReportPump(send = { report -> sendReport(MOUSE_REPORT_ID, report) })
    private val mouseTick = Runnable { runMousePump() }
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
            if (gamepadMappers.remove(deviceId) != null) {
                if (gamepadMotionDeviceId == deviceId) gamepadMotionDeviceId = null
                publishGamepadInput(discardPending = true)
            }
            onControllersChanged()
        }
        override fun onInputDeviceChanged(deviceId: Int) {
            gamepadLayouts.remove(deviceId)
            onControllersChanged()
        }
    }

    // Link keep-alive state (main thread only; see updateLinkKeepAlive).
    // Also written by the mouse sender thread (see sendReport).
    @Volatile private var lastReportSentAt = 0L // SystemClock.uptimeMillis()
    private val neutralKeyboardReport = ByteArray(8)
    private var heldKeyboardReport: ByteArray? = null
    private val linkKeepAliveTick = Runnable { runLinkKeepAlive() }

    @Volatile private var isRegistered = false // also read by the mouse channel queue
    private var cachedFlutterEngine: FlutterEngine? = null

    private val bluetoothReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action
            if (action == BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED ||
                action == BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED
            ) {
                runOnUiThread { notifyHostAudio() }
            } else if (BluetoothAdapter.ACTION_SCAN_MODE_CHANGED == action) {
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
            } else if (BluetoothDevice.ACTION_BOND_STATE_CHANGED == action) {
                notifyFlutter("onBondStateChanged", emptyMap())
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter(BluetoothAdapter.ACTION_SCAN_MODE_CHANGED).apply {
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            addAction(BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED)
        }
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
                        resetHidSession()
                        HidConnectionService.stop(this@MainActivity)
                        updateGamepadStreaming()
                        notifyFlutter("onRegistrationChanged", mapOf("registered" to false))
                        notifyFlutter("onConnectionStateChanged", mapOf("connected" to false))
                    }
                }
            }, BluetoothProfile.HID_DEVICE)
            if (!audioProxiesRequested) {
                audioProxiesRequested = true
                bluetoothAdapter?.getProfileProxy(this, audioProfileListener, BluetoothProfile.A2DP)
                bluetoothAdapter?.getProfileProxy(this, audioProfileListener, BluetoothProfile.HEADSET)
            }
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
                        if (!registered) {
                            resetHidSession()
                            HidConnectionService.stop(this@MainActivity)
                        }
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
                                if (hostDevice != device) resetHidSession()
                                hostDevice = device
                                HidConnectionService.start(this@MainActivity, deviceName ?: "host")
                            }
                            BluetoothProfile.STATE_DISCONNECTED -> {
                                Log.i(TAG, "Disconnected from host")
                                hostDevice = null
                                resetHidSession()
                                HidConnectionService.stop(this@MainActivity)
                            }
                            else -> return
                        }
                        updateGamepadStreaming()

                        notifyFlutter(
                            "onConnectionStateChanged",
                            mapOf(
                                "connected" to isConnected,
                                "deviceName" to deviceName,
                                "deviceAddress" to device?.address?.takeIf { isConnected }
                            )
                        )
                        if (isConnected) notifyHostAudio()
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.couchmouse/settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "exportSettings" -> {
                        val contents = call.argument<String>("contents")
                        if (contents == null) {
                            result.error("INVALID_BACKUP", "No settings backup to save.", null)
                        } else {
                            settingsDocuments.open(result, contents)
                        }
                    }
                    "importSettings" -> settingsDocuments.open(result)
                    else -> result.notImplemented()
                }
            }
        cachedFlutterEngine = flutterEngine

        // Mouse input: handled on a background task queue, not the main thread.
        // Fire-and-forget: Flutter doesn't wait for a reply per touch event.
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, MOUSE_CHANNEL, StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())
            .setMethodCallHandler { call, result ->
                val args = call.arguments as? List<*>
                val connected = isRegistered && hostDevice != null
                val wake = when (call.method) {
                    "move" -> connected && args != null && mousePump.move(
                        (args[0] as Number).toInt(),
                        (args[1] as Number).toInt(),
                        (args[2] as Number).toInt(),
                    )
                    "buttons" -> connected && args != null &&
                        mousePump.setButtons((args[0] as Number).toInt(), force = args[1] == true)
                    "setRate" -> {
                        val hz = (args?.get(0) as? Number)?.toInt()
                        if (hz != null) mouseSender.post { mousePump.setMaxRateHz(hz) }
                        false
                    }
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                if (wake) mouseSender.post(mouseTick)
                result.success(null)
            }

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
                        if (device.bondState != BluetoothDevice.BOND_BONDED) {
                            result.error("NOT_BONDED", "Pair this device again in Bluetooth settings.", null)
                            return@setMethodCallHandler
                        }
                        val success = hid.getConnectionState(device) == BluetoothProfile.STATE_CONNECTING ||
                            hid.connect(device)
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
                    if (sendKeyboardReport(if (holdsKeys) report else null)) {
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
     * Request 2.5 ms access latency for the HID interrupt channel.
     * Bluetooth Core Vol 3, Part A, §5.3 reserves zero bandwidth fields for
     * Best Effort. Use the token-rate wildcard and the largest peak value.
     */
    private fun hidQos() = BluetoothHidDeviceAppQosSettings(
        BluetoothHidDeviceAppQosSettings.SERVICE_GUARANTEED,
        BluetoothHidDeviceAppQosSettings.MAX, // token rate (maximum available)
        16, // token bucket size, bytes
        BluetoothHidDeviceAppQosSettings.MAX, // peak bandwidth (largest unsigned value)
        HID_QOS_LATENCY_US,
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
            val sent = hid.sendReport(device, id, report)
            if (sent && id != GamepadReport.REPORT_ID) lastReportSentAt = SystemClock.uptimeMillis()
            sent
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException inside sendReport: ${e.message}")
            false
        } catch (e: Exception) {
            Log.e(TAG, "Exception inside sendReport: ${e.message}")
            false
        }
    }

    private fun sendKeyboardReport(heldReport: ByteArray?): Boolean {
        // A failed release leaves the host needing a key-up. Keep subsequent
        // reports neutral so a keep-alive can retry the release.
        if (heldReport == null) heldKeyboardReport = null
        if (!sendReport(1, heldReport ?: neutralKeyboardReport)) return false
        heldKeyboardReport = heldReport
        keyboardReportHost = if (heldReport == null) null else hostDevice
        return true
    }

    private fun releaseKeyboard() {
        val device = hostDevice ?: return
        if (keyboardReportHost == device) sendKeyboardReport(null)
    }

    private fun resetHidSession() {
        heldKeyboardReport = null
        keyboardReportHost = null
        lastReportSentAt = 0L
        mousePump.reset()
    }

    /**
     * Starts the gamepad stream when it should run (gamepad mode on,
     * host connected, app resumed and focused) and stops it otherwise.
     * Stopping releases everything: locally (key-up events for held buttons
     * will go elsewhere now) and on the host (the pump flushes neutral reports).
     */
    private fun updateGamepadStreaming() {
        val stream = gamepadModeEnabled && isRegistered && hostDevice != null &&
            keyboardInputResumed && windowFocused
        if (!stream) {
            gamepadMappers.clear()
            gamepadMotionDeviceId = null
            gamepadPump.resetInput()
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

    /** Mouse sender thread only: sends whatever is due and schedules the next wake-up. */
    private fun runMousePump() {
        mouseSender.removeCallbacks(mouseTick)
        val next = mousePump.tick(SystemClock.uptimeMillis()) ?: return
        mouseSender.postAtTime(mouseTick, next)
    }

    /** One synchronous neutral report, for when the host link is about to go away. */
    private fun sendNeutralGamepadNow() {
        if (gamepadModeEnabled) sendReport(GamepadReport.REPORT_ID, GamepadState.NEUTRAL.toReport())
    }

    // ---- Physical controller capture (gamepad mode) ----

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val device = event.device
        if (gamepadModeEnabled && device != null && isPhysicalController(device)) {
            val mapper = gamepadMappers.getOrPut(device.id) { GamepadInputMapper() }
            if (!mapper.handles(event.keyCode)) return super.dispatchKeyEvent(event)
            val layout = layoutFor(device)
            when (event.action) {
                KeyEvent.ACTION_DOWN -> if (event.repeatCount == 0) {
                    mapper.onKey(event.keyCode, true, layout)
                    publishGamepadInput()
                }
                KeyEvent.ACTION_UP -> {
                    mapper.onKey(event.keyCode, false, layout)
                    publishGamepadInput()
                }
            }
            // Consume so Flutter UI navigation and the B -> Back fallback don't fire.
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        val device = event.device
        if (gamepadModeEnabled &&
            event.isFromSource(InputDevice.SOURCE_JOYSTICK) &&
            event.actionMasked == MotionEvent.ACTION_MOVE &&
            device != null && isPhysicalController(device)
        ) {
            val mapper = gamepadMappers.getOrPut(device.id) { GamepadInputMapper() }
            val layout = layoutFor(device)
            gamepadMotionDeviceId = device.id
            // D-pad axes can carry several transitions in a batched event.
            // Use the newest analog positions for all of those transitions.
            for (sample in 0 until event.historySize) {
                mapper.onMotion(layout) { axis ->
                    if (axis == MotionEvent.AXIS_HAT_X || axis == MotionEvent.AXIS_HAT_Y) {
                        event.getHistoricalAxisValue(axis, sample)
                    } else {
                        event.getAxisValue(axis)
                    }
                }
                publishGamepadInput()
            }
            mapper.onMotion(layout) { axis -> event.getAxisValue(axis) }
            publishGamepadInput()
            return true
        }
        return super.dispatchGenericMotionEvent(event)
    }

    private fun publishGamepadInput(discardPending: Boolean = false) {
        val motion = gamepadMotionDeviceId?.let { gamepadMappers[it]?.state } ?: GamepadState.NEUTRAL
        var buttons = 0
        var hat = motion.hat
        var leftTrigger = 0f
        var rightTrigger = 0f
        for (mapper in gamepadMappers.values) {
            val input = mapper.state
            buttons = buttons or input.buttons
            if (hat == Hat.CENTERED) hat = input.hat
            leftTrigger = maxOf(leftTrigger, input.leftTrigger)
            rightTrigger = maxOf(rightTrigger, input.rightTrigger)
        }
        val state = motion.copy(
            buttons = buttons,
            hat = hat,
            leftTrigger = leftTrigger,
            rightTrigger = rightTrigger,
        )
        // A change wakes the sender at once instead of waiting for the next keepalive.
        val wake = if (discardPending) gamepadPump.resetInput(state) else gamepadPump.update(state)
        if (wake) gamepadSender.post(gamepadTick)
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
        var nextSendAt = lastReportSentAt + LINK_KEEPALIVE_MS
        if (now >= nextSendAt) {
            sendKeyboardReport(heldKeyboardReport)
            // Retry after a full interval if the stack rejected the report.
            nextSendAt = maxOf(lastReportSentAt, now) + LINK_KEEPALIVE_MS
        }
        mainHandler.postAtTime(linkKeepAliveTick, nextSendAt)
    }

    // ---- Host audio ----
    //
    // A host that also connects media or call audio shares the Bluetooth link
    // with HID. Reports queue behind any sound streamed to the host. On some
    // phones (Galaxy S25 on One UI 9), an audio event while the HID app is not
    // registered also leaves the link in sniff subrating sized for audio: the
    // host polls the mouse only every ~750 ms until the link is rebuilt.
    // Flutter warns the user.

    private val audioProfileListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
            when (profile) {
                BluetoothProfile.A2DP -> a2dpProxy = proxy
                BluetoothProfile.HEADSET -> headsetProxy = proxy
            }
            notifyHostAudio()
        }

        // The proxy rebinds by itself when Bluetooth comes back on.
        override fun onServiceDisconnected(profile: Int) {}
    }

    @SuppressLint("MissingPermission")
    private fun notifyHostAudio() {
        val device = hostDevice ?: return
        val connected = listOf(a2dpProxy, headsetProxy).any { proxy ->
            try {
                proxy?.getConnectionState(device) == BluetoothProfile.STATE_CONNECTED
            } catch (e: SecurityException) {
                false
            }
        }
        notifyFlutter("onHostAudioChanged", mapOf("connected" to connected))
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
        super.onWindowFocusChanged(hasFocus)
        updateGamepadStreaming()
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        settingsDocuments.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(linkKeepAliveTick)
        releaseKeyboard()
        gamepadSender.removeCallbacksAndMessages(null)
        gamepadSenderThread.quitSafely()
        mouseSender.removeCallbacksAndMessages(null)
        mouseSenderThread.quitSafely()
        if (gamepadPump.isStreaming) sendNeutralGamepadNow()
        mainHandler.removeCallbacks(flushGamepadUi)
        (getSystemService(Context.INPUT_SERVICE) as? InputManager)
            ?.unregisterInputDeviceListener(inputDeviceListener)
        HidConnectionService.stop(this)
        settingsDocuments.close()
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
                a2dpProxy?.let { bluetoothAdapter?.closeProfileProxy(BluetoothProfile.A2DP, it) }
                headsetProxy?.let { bluetoothAdapter?.closeProfileProxy(BluetoothProfile.HEADSET, it) }
            } catch (e: SecurityException) {
                Log.e(TAG, "SecurityException during unregisterApp/closeProfileProxy: ${e.message}")
            } catch (e: Exception) {
                Log.e(TAG, "Exception during unregisterApp/closeProfileProxy: ${e.message}")
            }
        }
    }
}
