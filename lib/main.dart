import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow all orientations to support auto-rotation out of the box
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const CouchMouseApp());
}

class CouchMouseApp extends StatelessWidget {
  const CouchMouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CouchMouse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F13),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF0DF5E3),
          surface: Color(0xFF16161F),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _channel = MethodChannel('com.example.couchmouse/hid');

  // Device capabilities and permissions
  bool _isSupported = true;
  bool _permissionsGranted = false;
  bool _isConnected = false;
  bool _isRegistered = false;
  String? _connectedDeviceName;

  // Settings configurations
  double _sensitivity = 1.5;
  bool _accelerationEnabled = true;

  // Key state logic
  final List<int> _activeKeys = []; // 6-key rollover buffer
  int _modifierByte = 0x00;        // Sticky modifier byte bitmask
  bool _fnActive = false;           // Fn key translation layer active
  bool _holdLockActive = false;     // Tapping normal keys locks them down

  // Orientation toggle (Forces full screen keyboard in landscape)
  bool _forcedLandscapeKeyboard = false;

  // Fractional delta movement accumulators (sub-pixel precision)
  double _fractionalDx = 0.0;
  double _fractionalDy = 0.0;
  double _fractionalWheel = 0.0;
  int _lastButtonsState = 0;

  // Trackpad finger indicator coordinates
  Offset? _touchPos;

  // Click buttons touch animations
  bool _leftActive = false;
  bool _rightActive = false;

  // USB HID Scancodes Definition
  static const Map<String, int> _scancodes = {
    'A': 0x04, 'B': 0x05, 'C': 0x06, 'D': 0x07, 'E': 0x08, 'F': 0x09, 'G': 0x0A,
    'H': 0x0B, 'I': 0x0C, 'J': 0x0D, 'K': 0x0E, 'L': 0x0F, 'M': 0x10, 'N': 0x11,
    'O': 0x12, 'P': 0x13, 'Q': 0x14, 'R': 0x15, 'S': 0x16, 'T': 0x17, 'U': 0x18,
    'V': 0x19, 'W': 0x1A, 'X': 0x1B, 'Y': 0x1C, 'Z': 0x1D,
    '1': 0x1E, '2': 0x1F, '3': 0x20, '4': 0x21, '5': 0x22, '6': 0x23, '7': 0x24,
    '8': 0x25, '9': 0x26, '0': 0x27,
    'ENTER': 0x28, 'ESC': 0x29, 'BACKSPACE': 0x2A, 'TAB': 0x2B, 'SPACE': 0x2C,
    '-': 0x2D, '=': 0x2E, '[': 0x2F, ']': 0x30, '\\': 0x31,
    ';': 0x33, '\'': 0x34, '`': 0x35, ',': 0x36, '.': 0x37, '/': 0x38,
    'CAPS': 0x39,
    'F1': 0x3A, 'F2': 0x3B, 'F3': 0x3C, 'F4': 0x3D, 'F5': 0x3E, 'F6': 0x3F,
    'F7': 0x40, 'F8': 0x41, 'F9': 0x42, 'F10': 0x43, 'F11': 0x44, 'F12': 0x45,
    'PRINTSCREEN': 0x46, 'SCROLL': 0x47, 'PAUSE': 0x48,
    'INSERT': 0x49, 'HOME': 0x4A, 'PAGEUP': 0x4B, 'DELETE': 0x4C, 'END': 0x4D,
    'PAGEDOWN': 0x4E,
    'RIGHT': 0x4F, 'LEFT': 0x50, 'DOWN': 0x51, 'UP': 0x52,
  };

  @override
  void initState() {
    super.initState();
    _checkSupportAndPermissions();
    _setupPlatformChannel();
  }

  void _setupPlatformChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onConnectionStateChanged':
          final connected = call.arguments['connected'] as bool;
          final deviceName = call.arguments['deviceName'] as String?;
          setState(() {
            _isConnected = connected;
            _connectedDeviceName = deviceName;
          });
          break;
        case 'onRegistrationChanged':
          final registered = call.arguments['registered'] as bool;
          setState(() {
            _isRegistered = registered;
          });
          break;
      }
    });
  }

  Future<void> _checkSupportAndPermissions() async {
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
      setState(() {
        _isSupported = supported;
      });

      if (supported) {
        _checkPermissions();
      }
    } catch (e) {
      debugPrint("Error checking support: $e");
    }
  }

  Future<void> _checkPermissions() async {
    PermissionStatus connectStatus = await Permission.bluetoothConnect.status;
    PermissionStatus advertiseStatus = await Permission.bluetoothAdvertise.status;
    PermissionStatus scanStatus = await Permission.bluetoothScan.status;

    bool granted = connectStatus.isGranted && 
                   advertiseStatus.isGranted && 
                   scanStatus.isGranted;

    if (!granted) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.bluetoothScan,
        Permission.location,
      ].request();

      granted = (statuses[Permission.bluetoothConnect]?.isGranted ?? false) &&
                (statuses[Permission.bluetoothAdvertise]?.isGranted ?? false) &&
                (statuses[Permission.bluetoothScan]?.isGranted ?? false);

      if (!granted && (statuses[Permission.location]?.isGranted ?? false)) {
        granted = true; 
      }
    }

    setState(() {
      _permissionsGranted = granted;
    });

    if (granted) {
      _initializeBluetooth();
    }
  }

  Future<void> _initializeBluetooth() async {
    try {
      await _channel.invokeMethod('registerAppProfile');
      await _loadConnectionState();
    } catch (e) {
      debugPrint("Error initializing Bluetooth HID: $e");
    }
  }

  Future<void> _loadConnectionState() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getConnectionState');
      if (result != null) {
        setState(() {
          _isConnected = result['connected'] as bool? ?? false;
          _connectedDeviceName = result['deviceName'] as String?;
          _isRegistered = result['registered'] as bool? ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error loading connection state: $e");
    }
  }

  Future<void> _openBluetoothSettings() async {
    try {
      await _channel.invokeMethod('openBluetoothSettings');
    } catch (e) {
      debugPrint("Error opening bluetooth settings: $e");
    }
  }

  // Keyboard HID report sender
  Future<void> _sendKeyboardReport() async {
    final List<int> reportKeys = List<int>.filled(6, 0);
    for (int i = 0; i < _activeKeys.length && i < 6; i++) {
      reportKeys[i] = _activeKeys[i];
    }

    final List<int> report = [
      _modifierByte,
      0x00, // Reserved
      ...reportKeys,
    ];

    try {
      await _channel.invokeMethod('sendKeyboardReport', {'report': report});
    } catch (e) {
      debugPrint("Error dispatching Keyboard HID event: $e");
    }
  }

  // Keyboard helper to clear stuck buttons
  Future<void> _clearAllKeys() async {
    setState(() {
      _activeKeys.clear();
      _modifierByte = 0x00;
      _fnActive = false;
      _holdLockActive = false;
    });
    await _sendKeyboardReport();
  }

  // Mouse HID report sender (applies Sensitivity and Acceleration)
  Future<void> _sendReport({
    required int buttons,
    required double dx,
    required double dy,
    double wheel = 0,
  }) async {
    // 1. Apply Sensitivity
    double scaledDx = dx * _sensitivity;
    double scaledDy = dy * _sensitivity;
    double scaledWheel = wheel;

    // 2. Apply Mouse Acceleration if enabled (velocity quadratic scaling)
    if (_accelerationEnabled && (dx != 0 || dy != 0)) {
      double velocityX = scaledDx.abs();
      double velocityY = scaledDy.abs();
      scaledDx = scaledDx * (1.0 + velocityX * 0.05);
      scaledDy = scaledDy * (1.0 + velocityY * 0.05);
    }

    // 3. Accumulate sub-pixel values
    double totalDx = scaledDx + _fractionalDx;
    double totalDy = scaledDy + _fractionalDy;
    double totalWheel = scaledWheel + _fractionalWheel;

    int intDx = totalDx.truncate();
    int intDy = totalDy.truncate();
    int intWheel = totalWheel.truncate();

    _fractionalDx = totalDx - intDx;
    _fractionalDy = totalDy - intDy;
    _fractionalWheel = totalWheel - intWheel;

    if (intDx != 0 || intDy != 0 || intWheel != 0 || buttons != _lastButtonsState) {
      _lastButtonsState = buttons;
      try {
        await _channel.invokeMethod('sendMouseReport', {
          'buttons': buttons,
          'dx': intDx.toDouble(),
          'dy': intDy.toDouble(),
          'wheel': intWheel,
        });
      } on PlatformException catch (e) {
        debugPrint("Error dispatching Mouse HID event: ${e.message}");
      }
    }
  }

  Future<void> _tapClick() async {
    await _sendReport(buttons: 0x01, dx: 0, dy: 0, wheel: 0);
    await Future.delayed(const Duration(milliseconds: 15));
    await _sendReport(buttons: 0x00, dx: 0, dy: 0, wheel: 0);
  }

  // Keyboard modifier and key tap parser
  void _onKeyTap(String label) async {
    if (label == 'CTRL' || label == 'SHIFT' || label == 'ALT' || label == 'WIN') {
      int bit = 0;
      switch (label) {
        case 'CTRL': bit = 0x01; break;
        case 'SHIFT': bit = 0x02; break;
        case 'ALT': bit = 0x04; break;
        case 'WIN': bit = 0x08; break;
      }
      setState(() {
        _modifierByte ^= bit;
      });
      await _sendKeyboardReport();
      return;
    }

    if (label == 'FN') {
      setState(() {
        _fnActive = !_fnActive;
      });
      return;
    }

    if (label == 'HOLDLOCK') {
      setState(() {
        _holdLockActive = !_holdLockActive;
      });
      return;
    }

    int? scancode = _getScancode(label);
    if (scancode == null) return;

    if (_holdLockActive) {
      setState(() {
        if (_activeKeys.contains(scancode)) {
          _activeKeys.remove(scancode);
        } else {
          if (_activeKeys.length < 6) {
            _activeKeys.add(scancode);
          }
        }
      });
      await _sendKeyboardReport();
    } else {
      setState(() {
        if (!_activeKeys.contains(scancode) && _activeKeys.length < 6) {
          _activeKeys.add(scancode);
        }
      });
      await _sendKeyboardReport();

      await Future.delayed(const Duration(milliseconds: 15));

      setState(() {
        _activeKeys.remove(scancode);
      });
      await _sendKeyboardReport();
    }
  }

  int? _getScancode(String label) {
    if (_fnActive) {
      switch (label) {
        case '1': return _scancodes['F1'];
        case '2': return _scancodes['F2'];
        case '3': return _scancodes['F3'];
        case '4': return _scancodes['F4'];
        case '5': return _scancodes['F5'];
        case '6': return _scancodes['F6'];
        case '7': return _scancodes['F7'];
        case '8': return _scancodes['F8'];
        case '9': return _scancodes['F9'];
        case '0': return _scancodes['F10'];
        case '-': return _scancodes['F11'];
        case '=': return _scancodes['F12'];
        case 'ESC': return _scancodes['`'];
        case 'UP': return _scancodes['PAGEUP'];
        case 'DOWN': return _scancodes['PAGEDOWN'];
        case 'LEFT': return _scancodes['HOME'];
        case 'RIGHT': return _scancodes['END'];
        case 'BACKSPACE': return _scancodes['DELETE'];
      }
    }
    return _scancodes[label];
  }

  String _getDisplayLabel(String label) {
    if (_fnActive) {
      switch (label) {
        case '1': return 'F1';
        case '2': return 'F2';
        case '3': return 'F3';
        case '4': return 'F4';
        case '5': return 'F5';
        case '6': return 'F6';
        case '7': return 'F7';
        case '8': return 'F8';
        case '9': return 'F9';
        case '0': return 'F10';
        case '-': return 'F11';
        case '=': return 'F12';
        case 'ESC': return '`';
        case 'UP': return 'PgUp';
        case 'DOWN': return 'PgDn';
        case 'LEFT': return 'Home';
        case 'RIGHT': return 'End';
        case 'BACKSPACE': return 'Del';
      }
    }
    return label;
  }

  // Toggles locked orientation state
  void _enableForcedKeyboard(bool enable) {
    setState(() {
      _forcedLandscapeKeyboard = enable;
    });
    if (enable) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Widget _buildUnsupportedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
            const SizedBox(height: 24),
            const Text(
              "Unsupported Device",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              "CouchMouse requires Android 9 (API Level 28) or higher for native Bluetooth HID Device Emulation.\n\nYour device's Android version does not support this profile.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_searching, size: 80, color: Color(0xFF00E5FF)),
            const SizedBox(height: 24),
            const Text(
              "Bluetooth Access Required",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              "CouchMouse emulates a standard Bluetooth mouse and keyboard combo. We need Bluetooth permissions to advertise and register the controller profile.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _checkPermissions,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Grant Permissions"),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: const Color(0xFF00E5FF),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _openBluetoothSettings,
              child: const Text(
                "Open System Settings",
                style: TextStyle(color: Color(0xFF0DF5E3), fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot() {
    Color dotColor = Colors.red;
    if (_isConnected) {
      dotColor = const Color(0xFF0DF5E3);
    } else if (_isRegistered) {
      dotColor = Colors.amber;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: dotColor.withValues(alpha: 0.6),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF16161F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isConnected ? const Color(0x330DF5E3) : const Color(0x22FFFFFF),
            width: 1.5,
          ),
          boxShadow: [
            if (_isConnected)
              const BoxShadow(
                color: Color(0x1A0DF5E3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Row(
          children: [
            _buildStatusDot(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isConnected ? "Connected" : "Not Connected",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isConnected ? const Color(0xFF0DF5E3) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isConnected
                        ? "Connected to ${_connectedDeviceName ?? 'Host Laptop'}"
                        : "Pair via phone's Bluetooth settings to 'CouchMouse'",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _openBluetoothSettings,
              icon: const Icon(Icons.settings_bluetooth),
              color: const Color(0xFF00E5FF),
              tooltip: "Bluetooth Settings",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackpadArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (details) {
              setState(() {
                _touchPos = details.localFocalPoint;
              });
            },
            onScaleUpdate: (details) {
              setState(() {
                _touchPos = details.localFocalPoint;
              });
              if (details.pointerCount == 1) {
                _sendReport(
                  buttons: 0,
                  dx: details.focalPointDelta.dx,
                  dy: details.focalPointDelta.dy,
                  wheel: 0,
                );
              } else if (details.pointerCount == 2) {
                double dy = details.focalPointDelta.dy;
                double wheel = dy * 0.4;
                if (wheel != 0) {
                  _sendReport(buttons: 0, dx: 0, dy: 0, wheel: wheel);
                }
              }
            },
            onScaleEnd: (details) {
              setState(() {
                _touchPos = null;
              });
            },
            onTap: _tapClick,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111116),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _touchPos != null ? const Color(0x3300E5FF) : const Color(0x11FFFFFF),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 40,
                    color: _touchPos != null ? const Color(0xFF00E5FF) : Colors.white12,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Trackpad Surface",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _touchPos != null ? Colors.white : Colors.white30,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Slide to Move • Tap to Click • 2 Fingers to Scroll",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: _touchPos != null ? Colors.white60 : Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_touchPos != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: TrackpadPainter(_touchPos),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhysicalClickButtons({required double height}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF16161F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x11FFFFFF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) {
                  setState(() => _leftActive = true);
                  _sendReport(buttons: 0x01, dx: 0, dy: 0);
                },
                onTapUp: (_) {
                  setState(() => _leftActive = false);
                  _sendReport(buttons: 0x00, dx: 0, dy: 0);
                },
                onTapCancel: () {
                  setState(() => _leftActive = false);
                  _sendReport(buttons: 0x00, dx: 0, dy: 0);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  decoration: BoxDecoration(
                    color: _leftActive ? const Color(0x1000E5FF) : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                    border: _leftActive
                        ? Border.all(color: const Color(0x3300E5FF), width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mouse,
                          color: _leftActive ? const Color(0xFF00E5FF) : Colors.white38,
                          size: height > 70 ? 28 : 22,
                        ),
                        if (height > 70) const SizedBox(height: 8),
                        Text(
                          "LEFT CLICK",
                          style: TextStyle(
                            color: _leftActive ? const Color(0xFF00E5FF) : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: height > 70 ? 14 : 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 1.5,
              color: const Color(0x11FFFFFF),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) {
                  setState(() => _rightActive = true);
                  _sendReport(buttons: 0x02, dx: 0, dy: 0);
                },
                onTapUp: (_) {
                  setState(() => _rightActive = false);
                  _sendReport(buttons: 0x00, dx: 0, dy: 0);
                },
                onTapCancel: () {
                  setState(() => _rightActive = false);
                  _sendReport(buttons: 0x00, dx: 0, dy: 0);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  decoration: BoxDecoration(
                    color: _rightActive ? const Color(0x100DF5E3) : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: _rightActive
                        ? Border.all(color: const Color(0x330DF5E3), width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mouse_outlined,
                          color: _rightActive ? const Color(0xFF0DF5E3) : Colors.white38,
                          size: height > 70 ? 28 : 22,
                        ),
                        if (height > 70) const SizedBox(height: 8),
                        Text(
                          "RIGHT CLICK",
                          style: TextStyle(
                            color: _rightActive ? const Color(0xFF0DF5E3) : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: height > 70 ? 14 : 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String label, {int flex = 2}) {
    bool isActive = false;
    Color activeColor = const Color(0xFF00E5FF);

    if (label == 'CTRL') {
      isActive = (_modifierByte & 0x01) != 0;
    } else if (label == 'SHIFT') {
      isActive = (_modifierByte & 0x02) != 0;
    } else if (label == 'ALT') {
      isActive = (_modifierByte & 0x04) != 0;
    } else if (label == 'WIN') {
      isActive = (_modifierByte & 0x08) != 0;
    } else if (label == 'FN') {
      isActive = _fnActive;
      activeColor = const Color(0xFF0DF5E3);
    } else if (label == 'HOLDLOCK') {
      isActive = _holdLockActive;
      activeColor = Colors.amber;
    } else {
      int? scancode = _getScancode(label);
      isActive = scancode != null && _activeKeys.contains(scancode);
    }

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Material(
          color: isActive ? activeColor.withValues(alpha: 0.15) : const Color(0xFF22222E),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: () => _onKeyTap(label),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isActive ? activeColor : const Color(0x33FFFFFF),
                  width: isActive ? 1.5 : 0.8,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _getDisplayLabel(label),
                style: TextStyle(
                  color: isActive ? activeColor : Colors.white70,
                  fontSize: label.length > 3 ? 10 : 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildKey('ESC', flex: 3),
                _buildKey('1'), _buildKey('2'), _buildKey('3'), _buildKey('4'), _buildKey('5'),
                _buildKey('6'), _buildKey('7'), _buildKey('8'), _buildKey('9'), _buildKey('0'),
                _buildKey('-'), _buildKey('='),
                _buildKey('BACKSPACE', flex: 4),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildKey('TAB', flex: 3),
                _buildKey('Q'), _buildKey('W'), _buildKey('E'), _buildKey('R'), _buildKey('T'),
                _buildKey('Y'), _buildKey('U'), _buildKey('I'), _buildKey('O'), _buildKey('P'),
                _buildKey('['), _buildKey(']'), _buildKey('\\', flex: 3),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildKey('CAPS', flex: 4),
                _buildKey('A'), _buildKey('S'), _buildKey('D'), _buildKey('F'), _buildKey('G'),
                _buildKey('H'), _buildKey('J'), _buildKey('K'), _buildKey('L'), _buildKey(';'),
                _buildKey('\''),
                _buildKey('ENTER', flex: 5),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildKey('SHIFT', flex: 5),
                _buildKey('Z'), _buildKey('X'), _buildKey('C'), _buildKey('V'), _buildKey('B'),
                _buildKey('N'), _buildKey('M'), _buildKey(','), _buildKey('.'), _buildKey('/'),
                _buildKey('UP'),
                _buildKey('FN', flex: 3),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildKey('CTRL', flex: 3),
                _buildKey('WIN', flex: 3),
                _buildKey('ALT', flex: 3),
                _buildKey('SPACE', flex: 12),
                _buildKey('LEFT'),
                _buildKey('DOWN'),
                _buildKey('RIGHT'),
                _buildKey('HOLDLOCK', flex: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF16161F),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            Row(
              children: const [
                Icon(Icons.settings, color: Color(0xFF00E5FF), size: 28),
                SizedBox(width: 12),
                Text(
                  "CouchMouse Settings",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 32),
            
            const Text(
              "Pointer Sensitivity",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white70),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _sensitivity,
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    activeColor: const Color(0xFF00E5FF),
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      setState(() {
                        _sensitivity = val;
                      });
                    },
                  ),
                ),
                Text(
                  "${_sensitivity.toStringAsFixed(1)}x",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text(
                "Mouse Acceleration",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white70),
              ),
              subtitle: const Text(
                "Accelerates pointer speed on faster swipes",
                style: TextStyle(fontSize: 12, color: Colors.white30),
              ),
              value: _accelerationEnabled,
              activeThumbColor: const Color(0xFF0DF5E3),
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  _accelerationEnabled = val;
                });
              },
            ),
            const Divider(color: Colors.white24, height: 32),

            const Text(
              "Keyboard Operations",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                _clearAllKeys();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("All keyboard states reset."),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Reset Active Keys"),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 32),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openBluetoothSettings();
              },
              icon: const Icon(Icons.bluetooth),
              label: const Text("Bluetooth Settings"),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: const Color(0xFF00E5FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView(bool isLandscape) {
    if (isLandscape) {
      // Split Landscape Layout (Left: Mouse Control, Right: Keyboard Control)
      return Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _buildConnectionCard(),
                Expanded(child: _buildTrackpadArea()),
                const SizedBox(height: 8),
                _buildPhysicalClickButtons(height: 65),
              ],
            ),
          ),
          Container(width: 1.5, color: const Color(0x22FFFFFF)),
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Split Keyboard Control",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      TextButton.icon(
                        onPressed: _clearAllKeys,
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text("Reset", style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: _buildKeyboard()),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Default Portrait Layout
    return Column(
      children: [
        _buildConnectionCard(),
        Expanded(child: _buildTrackpadArea()),
        const SizedBox(height: 16),
        _buildPhysicalClickButtons(height: 100),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) return Scaffold(body: SafeArea(child: _buildUnsupportedView()));
    if (!_permissionsGranted) return Scaffold(body: SafeArea(child: _buildPermissionsView()));

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;

        if (_forcedLandscapeKeyboard) {
          // Forced Full-Screen Keyboard screen (locked in Landscape)
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.keyboard_alt_outlined, color: Color(0xFF00E5FF)),
                        const SizedBox(width: 12),
                        const Text(
                          "CouchMouse Full Keyboard Mode",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _clearAllKeys,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text("Clear Keys"),
                          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _enableForcedKeyboard(false),
                          icon: const Icon(Icons.videogame_asset_off_outlined),
                          label: const Text("Exit Keyboard"),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.black,
                            backgroundColor: const Color(0xFF00E5FF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: _buildKeyboard()),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          drawer: _buildSettingsDrawer(),
          appBar: AppBar(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.mouse, color: Color(0xFF00E5FF)),
                SizedBox(width: 12),
                Text(
                  "CouchMouse",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.keyboard),
                color: const Color(0xFF00E5FF),
                onPressed: () => _enableForcedKeyboard(true),
                tooltip: "Open Keyboard",
              ),
            ],
          ),
          body: SafeArea(
            child: _buildMainView(isLandscape),
          ),
        );
      },
    );
  }
}

class TrackpadPainter extends CustomPainter {
  final Offset? touchPosition;

  TrackpadPainter(this.touchPosition);

  @override
  void paint(Canvas canvas, Size size) {
    if (touchPosition == null) return;

    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0x3D00E5FF),
          Color(0x0F00E5FF),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: touchPosition!, radius: 48.0));
    canvas.drawCircle(touchPosition!, 48.0, glowPaint);

    final Paint ringPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(touchPosition!, 20.0, ringPaint);

    final Paint dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(touchPosition!, 4.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant TrackpadPainter oldDelegate) {
    return oldDelegate.touchPosition != touchPosition;
  }
}
