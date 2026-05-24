package com.example.couchmouse

import android.annotation.SuppressLint
import android.bluetooth.*
import android.content.Context
import android.content.Intent
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

    // Register standard Report IDs
    private val REPORT_ID_KEYBOARD = 1
    private val REPORT_ID_MOUSE = 2

    private var isRegistered = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
        }
    }

    @SuppressLint("MissingPermission")
    private fun registerAppProfile() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return

        val sdpSettings = BluetoothHidDeviceAppSdpSettings(
            "CouchMouse",
            "Virtual Combo Controller",
            "CouchMouseDev",
            0xC0.toByte(), // Subclass descriptor code representing a Combo Keyboard/Mouse
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
                            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                                MethodChannel(messenger, CHANNEL).invokeMethod(
                                    "onRegistrationChanged", 
                                    mapOf("registered" to registered)
                                )
                            }
                        }
                    }

                    override fun onConnectionStateChanged(device: BluetoothDevice?, state: Int) {
                        val isConnected = (state == BluetoothProfile.STATE_CONNECTED)
                        val deviceName = if (isConnected) device?.name ?: "Unknown Device" else null
                        
                        when (state) {
                            BluetoothProfile.STATE_CONNECTED -> {
                                Log.i(TAG, "Connected to host: ${device?.name}")
                                hostDevice = device
                            }
                            BluetoothProfile.STATE_DISCONNECTED -> {
                                Log.i(TAG, "Disconnected from host")
                                hostDevice = null
                            }
                        }

                        runOnUiThread {
                            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                                MethodChannel(messenger, CHANNEL).invokeMethod(
                                    "onConnectionStateChanged", 
                                    mapOf("connected" to isConnected, "deviceName" to deviceName)
                                )
                            }
                        }
                    }
                }
            )
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException inside registerApp: ${e.message}")
            throw e
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
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
                    if (device != null) {
                        result.success(mapOf(
                            "connected" to true, 
                            "deviceName" to (device.name ?: "Unknown Device"),
                            "registered" to isRegistered
                        ))
                    } else {
                        result.success(mapOf(
                            "connected" to false, 
                            "deviceName" to null,
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
                "sendMouseReport" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                        result.error("UNSUPPORTED", "Bluetooth HID requires Android 9+", null)
                        return@setMethodCallHandler
                    }
                    val buttons = call.argument<Int>("buttons") ?: 0
                    val dx = call.argument<Double>("dx")?.toInt() ?: 0
                    val dy = call.argument<Double>("dy")?.toInt() ?: 0
                    val wheel = call.argument<Int>("wheel") ?: 0

                    val success = sendMouseReport(buttons, dx, dy, wheel)
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
                    val reportList = call.argument<List<Int>>("report")
                    if (reportList == null || reportList.size != 8) {
                        result.error("INVALID_ARGUMENT", "Keyboard report must be 8 bytes", null)
                        return@setMethodCallHandler
                    }

                    val reportBytes = ByteArray(8)
                    for (i in 0 until 8) {
                        reportBytes[i] = reportList[i].toByte()
                    }

                    val success = sendKeyboardReport(reportBytes)
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
    private fun sendMouseReport(buttons: Int, dx: Int, dy: Int, wheel: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false

        val device = hostDevice
        val hid = bluetoothHidDevice
        if (device == null || hid == null) {
            return false
        }

        // Map inputs into the defined standard 4-byte Mouse report (ID 2)
        val report = byteArrayOf(
            buttons.toByte(),                  // Byte 0: Button States
            dx.coerceIn(-127, 127).toByte(),   // Byte 1: Signed relative X coordinate
            dy.coerceIn(-127, 127).toByte(),   // Byte 2: Signed relative Y coordinate
            wheel.coerceIn(-127, 127).toByte() // Byte 3: Relative scroll wheel
        )

        return hid.sendReport(device, REPORT_ID_MOUSE, report)
    }

    @SuppressLint("MissingPermission")
    private fun sendKeyboardReport(report: ByteArray): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false

        val device = hostDevice
        val hid = bluetoothHidDevice
        if (device == null || hid == null) {
            return false
        }

        return hid.sendReport(device, REPORT_ID_KEYBOARD, report)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && bluetoothAdapter != null) {
            bluetoothAdapter?.closeProfileProxy(BluetoothProfile.HID_DEVICE, bluetoothHidDevice)
        }
    }
}
