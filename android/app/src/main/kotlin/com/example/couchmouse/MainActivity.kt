package com.example.couchmouse

import android.annotation.SuppressLint
import android.bluetooth.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.couchmouse/hid"
    private val TAG = "RemoteMouseHID"

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothHidDevice: BluetoothHidDevice? = null
    private var hostDevice: BluetoothDevice? = null

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
                        isRegistered = false
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

        val executor = Executors.newSingleThreadExecutor()

        try {
            bluetoothHidDevice?.registerApp(
                sdpSettings,
                null, // QoS Incoming settings (Optional)
                null, // QoS Outgoing settings (Optional)
                executor,
                object : BluetoothHidDevice.Callback() {
                    override fun onAppStatusChanged(pluggedDevice: BluetoothDevice?, registered: Boolean) {
                        Log.d(TAG, "Application HID Profile registration state: $registered")
                        isRegistered = registered
                        runOnUiThread {
                            cachedFlutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                                MethodChannel(messenger, CHANNEL).invokeMethod(
                                    "onRegistrationChanged", 
                                    mapOf("registered" to registered)
                                )
                            }
                        }
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
                            }
                            BluetoothProfile.STATE_DISCONNECTED -> {
                                Log.i(TAG, "Disconnected from host")
                                hostDevice = null
                            }
                        }

                        runOnUiThread {
                            cachedFlutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                                MethodChannel(messenger, CHANNEL).invokeMethod(
                                    "onConnectionStateChanged", 
                                    mapOf(
                                        "connected" to isConnected, 
                                        "deviceName" to deviceName,
                                        "deviceAddress" to device?.address
                                    )
                                )
                            }
                        }
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
                    val success = sendReport(1, report)
                    if (success) {
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

    @SuppressLint("MissingPermission")
    private fun sendReport(id: Int, report: ByteArray): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false

        val device = hostDevice
        val hid = bluetoothHidDevice
        if (device == null || hid == null) {
            return false
        }

        return try {
            hid.sendReport(device, id, report)
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException inside sendReport: ${e.message}")
            false
        } catch (e: Exception) {
            Log.e(TAG, "Exception inside sendReport: ${e.message}")
            false
        }
    }

    override fun onDestroy() {
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
