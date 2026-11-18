package com.example.couchmouse

import android.annotation.SuppressLint
import android.bluetooth.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        // Max silence on the HID link before a keep-alive report (see updateLinkKeepAlive).
        const val LINK_KEEPALIVE_MS = 50L

        const val HID_QOS_LATENCY_US = 2_500
        // An 8-byte keyboard report, report ID, and HIDP header every 2.5 ms.
        const val HID_QOS_BYTES_PER_SECOND = 10 * 1_000_000 / HID_QOS_LATENCY_US
    }

    private val CHANNEL = "com.example.couchmouse/hid"
    private val TAG = "RemoteMouseHID"
    private val settingsDocuments = SettingsDocuments(this)

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothHidDevice: BluetoothHidDevice? = null
    private var hostDevice: BluetoothDevice? = null
    private var keyboardReportHost: BluetoothDevice? = null
    private var keyboardInputResumed = false

    // Link keep-alive state (main thread only; see updateLinkKeepAlive).
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastReportSentAt = 0L // SystemClock.uptimeMillis()
    private val neutralKeyboardReport = ByteArray(8)
    private var heldKeyboardReport: ByteArray? = null
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
                        updateLinkKeepAlive()
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
            0xC0.toByte(), // Subclass descriptor code representing Combo Keyboard/Mouse
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
                        if (!registered) resetHidSession()
                        updateLinkKeepAlive()
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
                            }
                            BluetoothProfile.STATE_DISCONNECTED -> {
                                Log.i(TAG, "Disconnected from host")
                                hostDevice = null
                                resetHidSession()
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
                            if (device == hostDevice) releaseKeyboard()
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
                    if (sendKeyboardReport(if (holdsKeys) report else null)) {
                        result.success(null)
                    } else {
                        result.error("UNAVAILABLE", "No Bluetooth device currently connected.", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * L2CAP QoS for the HID interrupt channel. The 2.5 ms access latency requests
     * a shorter poll interval. The HID Profile Appendix D examples use the same
     * nonzero peak bandwidth and token rate for Guaranteed service.
     */
    private fun hidQos() = BluetoothHidDeviceAppQosSettings(
        BluetoothHidDeviceAppQosSettings.SERVICE_GUARANTEED,
        HID_QOS_BYTES_PER_SECOND, // token rate
        16, // token bucket size, bytes
        HID_QOS_BYTES_PER_SECOND, // peak bandwidth
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
            if (sent) lastReportSentAt = SystemClock.uptimeMillis()
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

    private fun linkKeepAliveWanted(): Boolean =
        isRegistered && hostDevice != null && keyboardInputResumed && hasWindowFocus()

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

    private fun notifyFlutter(method: String, arguments: Map<String, Any?>) {
        cachedFlutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod(method, arguments)
        }
    }

    override fun onResume() {
        super.onResume()
        keyboardInputResumed = true
        updateLinkKeepAlive()
    }

    override fun onPause() {
        keyboardInputResumed = false
        releaseKeyboard()
        updateLinkKeepAlive()
        super.onPause()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        if (!hasFocus) releaseKeyboard()
        super.onWindowFocusChanged(hasFocus)
        updateLinkKeepAlive()
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        settingsDocuments.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(linkKeepAliveTick)
        releaseKeyboard()
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
            } catch (e: SecurityException) {
                Log.e(TAG, "SecurityException during unregisterApp/closeProfileProxy: ${e.message}")
            } catch (e: Exception) {
                Log.e(TAG, "Exception during unregisterApp/closeProfileProxy: ${e.message}")
            }
        }
    }
}
