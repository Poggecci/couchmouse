import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Start the application allowing all orientations (fluid auto-rotation support)
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
        scaffoldBackgroundColor: const Color(0xFF07070B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF0DF5E3),
          surface: Color(0xFF13131B),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class KeyInfo {
  final String label;
  final String? fnLabel;
  final int scancode;
  final int? fnScancode;
  final double flex;
  final bool isModifier;
  final int modifierMask;

  const KeyInfo({
    required this.label,
    this.fnLabel,
    required this.scancode,
    this.fnScancode,
    this.flex = 1.0,
    this.isModifier = false,
    this.modifierMask = 0,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _channel = MethodChannel('com.example.couchmouse/hid');

  // Key mappings for the 60% keyboard layout
  static const List<List<KeyInfo>> _keyboardLayout = [
    // Row 1
    [
      KeyInfo(label: "Esc", fnLabel: "`", scancode: 0x29, fnScancode: 0x35, flex: 1.2),
      KeyInfo(label: "1", fnLabel: "F1", scancode: 0x1E, fnScancode: 0x3A),
      KeyInfo(label: "2", fnLabel: "F2", scancode: 0x1F, fnScancode: 0x3B),
      KeyInfo(label: "3", fnLabel: "F3", scancode: 0x20, fnScancode: 0x3C),
      KeyInfo(label: "4", fnLabel: "F4", scancode: 0x21, fnScancode: 0x3D),
      KeyInfo(label: "5", fnLabel: "F5", scancode: 0x22, fnScancode: 0x3E),
      KeyInfo(label: "6", fnLabel: "F6", scancode: 0x23, fnScancode: 0x3F),
      KeyInfo(label: "7", fnLabel: "F7", scancode: 0x24, fnScancode: 0x40),
      KeyInfo(label: "8", fnLabel: "F8", scancode: 0x25, fnScancode: 0x41),
      KeyInfo(label: "9", fnLabel: "F9", scancode: 0x26, fnScancode: 0x42),
      KeyInfo(label: "0", fnLabel: "F10", scancode: 0x27, fnScancode: 0x43),
      KeyInfo(label: "-", fnLabel: "F11", scancode: 0x2D, fnScancode: 0x44),
      KeyInfo(label: "=", fnLabel: "F12", scancode: 0x2E, fnScancode: 0x45),
      KeyInfo(label: "Back", fnLabel: "Del", scancode: 0x2A, fnScancode: 0x4C, flex: 1.8),
    ],
    // Row 2
    [
      KeyInfo(label: "Tab", scancode: 0x2B, flex: 1.5),
      KeyInfo(label: "Q", scancode: 0x14),
      KeyInfo(label: "W", scancode: 0x1A),
      KeyInfo(label: "E", scancode: 0x08),
      KeyInfo(label: "R", scancode: 0x15),
      KeyInfo(label: "T", scancode: 0x17),
      KeyInfo(label: "Y", scancode: 0x1C),
      KeyInfo(label: "U", scancode: 0x18),
      KeyInfo(label: "I", scancode: 0x0C),
      KeyInfo(label: "O", scancode: 0x12),
      KeyInfo(label: "P", scancode: 0x13),
      KeyInfo(label: "[", scancode: 0x2F),
      KeyInfo(label: "]", scancode: 0x30),
      KeyInfo(label: "\\", scancode: 0x31, flex: 1.5),
    ],
    // Row 3
    [
      KeyInfo(label: "Caps", scancode: 0x39, flex: 1.8),
      KeyInfo(label: "A", scancode: 0x04),
      KeyInfo(label: "S", scancode: 0x16),
      KeyInfo(label: "D", scancode: 0x07),
      KeyInfo(label: "F", scancode: 0x09),
      KeyInfo(label: "G", scancode: 0x0A),
      KeyInfo(label: "H", scancode: 0x0B),
      KeyInfo(label: "J", scancode: 0x0D),
      KeyInfo(label: "K", scancode: 0x0E),
      KeyInfo(label: "L", scancode: 0x0F),
      KeyInfo(label: ";", scancode: 0x33),
      KeyInfo(label: "'", scancode: 0x34),
      KeyInfo(label: "Enter", scancode: 0x28, flex: 2.2),
    ],
    // Row 4
    [
      KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x02, flex: 2.2),
      KeyInfo(label: "Z", scancode: 0x1D),
      KeyInfo(label: "X", scancode: 0x1B),
      KeyInfo(label: "C", scancode: 0x06),
      KeyInfo(label: "V", scancode: 0x19),
      KeyInfo(label: "B", scancode: 0x05),
      KeyInfo(label: "N", scancode: 0x11),
      KeyInfo(label: "M", scancode: 0x10),
      KeyInfo(label: ",", scancode: 0x36),
      KeyInfo(label: ".", scancode: 0x37),
      KeyInfo(label: "/", scancode: 0x38),
      KeyInfo(label: "▲", fnLabel: "PgUp", scancode: 0x52, fnScancode: 0x4B, flex: 1.2),
      KeyInfo(label: "Shift", scancode: 0, isModifier: true, modifierMask: 0x20, flex: 1.3),
    ],
    // Row 5
    [
      KeyInfo(label: "Ctrl", scancode: 0, isModifier: true, modifierMask: 0x01, flex: 1.4),
      KeyInfo(label: "Win", scancode: 0, isModifier: true, modifierMask: 0x08, flex: 1.3),
      KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x04, flex: 1.3),
      KeyInfo(label: "Space", scancode: 0x2C, flex: 4.8),
      KeyInfo(label: "Alt", scancode: 0, isModifier: true, modifierMask: 0x40, flex: 1.2),
      KeyInfo(label: "Fn", scancode: -1, flex: 1.2),
      KeyInfo(label: "◀", fnLabel: "Home", scancode: 0x50, fnScancode: 0x4A, flex: 1.0),
      KeyInfo(label: "▼", fnLabel: "PgDn", scancode: 0x51, fnScancode: 0x4E, flex: 1.0),
      KeyInfo(label: "▶", fnLabel: "End", scancode: 0x4F, fnScancode: 0x4D, flex: 1.0),
    ],
  ];

  bool _isSupported = true;
  bool _permissionsGranted = false;
  bool _isConnected = false;
  bool _isRegistered = false;
  String? _connectedDeviceName;

  // Trackpad Settings
  double _sensitivity = 3.0;
  bool _mouseAcceleration = true;

  // Fraction accumulators for precision control
  double _fractionalDx = 0.0;
  double _fractionalDy = 0.0;
  double _fractionalWheel = 0.0;
  int _lastButtonsState = 0;

  // Trackpad Touch positions for visual trails
  Offset? _touchPos;
  List<Offset> _trailPoints = [];

  // Bottom click zones visual active trigger state
  bool _leftActive = false;
  bool _rightActive = false;

  // Virtual Keyboard State Buffers
  final Set<int> _activeScancodes = {};
  int _modifiersBitmask = 0;
  bool _fnActive = false;
  bool _holdLockActive = false;

  // Layout Management: Forced Landscape Full-Screen Keyboard state
  bool _forcedLandscapeKeyboard = false;

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
    try {
      final sdkVersion = await _channel.invokeMethod<int>('getSdkVersion') ?? 0;
      bool granted = false;

      if (sdkVersion >= 31) {
        PermissionStatus connectStatus = await Permission.bluetoothConnect.status;
        PermissionStatus advertiseStatus = await Permission.bluetoothAdvertise.status;
        PermissionStatus scanStatus = await Permission.bluetoothScan.status;

        granted = connectStatus.isGranted && 
                  advertiseStatus.isGranted && 
                  scanStatus.isGranted;

        if (!granted) {
          Map<Permission, PermissionStatus> statuses = await [
            Permission.bluetoothConnect,
            Permission.bluetoothAdvertise,
            Permission.bluetoothScan,
          ].request();

          granted = (statuses[Permission.bluetoothConnect]?.isGranted ?? false) &&
                    (statuses[Permission.bluetoothAdvertise]?.isGranted ?? false) &&
                    (statuses[Permission.bluetoothScan]?.isGranted ?? false);
        }
      } else {
        // Under Android 12 (API level 30 and lower), Location runtime is needed for BT scanning/discovery
        PermissionStatus locationStatus = await Permission.location.status;
        granted = locationStatus.isGranted;

        if (!granted) {
          PermissionStatus reqStatus = await Permission.location.request();
          granted = reqStatus.isGranted;
        }
      }

      setState(() {
        _permissionsGranted = granted;
      });

      if (granted) {
        _initializeBluetooth();
      }
    } catch (e) {
      debugPrint("Error running permission checks: $e");
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

  // Send Mouse HID Report ID 2
  Future<void> _sendReport({
    required int buttons,
    required double dx,
    required double dy,
    double wheel = 0,
  }) async {
    double totalDx = dx + _fractionalDx;
    double totalDy = dy + _fractionalDy;
    double totalWheel = wheel + _fractionalWheel;

    int intDx = totalDx.truncate();
    int intDy = totalDy.truncate();
    int intWheel = totalWheel.truncate();

    _fractionalDx = totalDx - intDx;
    _fractionalDy = totalDy - intDy;
    _fractionalWheel = totalWheel - intWheel;

    // Clamp coordinates to prevent overflow of relative signed bytes (-127 to 127)
    intDx = intDx.clamp(-127, 127);
    intDy = intDy.clamp(-127, 127);
    intWheel = intWheel.clamp(-127, 127);

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
        debugPrint("Error dispatching HID mouse event: ${e.message}");
      }
    }
  }

  // Send Keyboard HID Report ID 1
  Future<void> _sendKeyboardReport() async {
    List<int> bytes = List.filled(8, 0);
    bytes[0] = _modifiersBitmask;
    bytes[1] = 0; // Reserved byte (constant padding)
    
    int idx = 2;
    for (int scancode in _activeScancodes) {
      if (idx < 8) {
        bytes[idx] = scancode;
        idx++;
      }
    }
    
    try {
      await _channel.invokeMethod('sendKeyboardReport', {'bytes': bytes});
    } on PlatformException catch (e) {
      debugPrint("Error sending HID keyboard report: ${e.message}");
    }
  }

  // Reset all modifier states and active buttons
  void _resetHidState() {
    setState(() {
      _activeScancodes.clear();
      _modifiersBitmask = 0;
      _lastButtonsState = 0;
      _leftActive = false;
      _rightActive = false;
      _fnActive = false;
    });
    // Send zero reports for both keyboard and mouse
    _sendKeyboardReport();
    _sendReport(buttons: 0, dx: 0, dy: 0);
  }

  // Tap-to-click trigger sequence
  Future<void> _tapClick() async {
    await _sendReport(buttons: 0x01, dx: 0, dy: 0, wheel: 0);
    await Future.delayed(const Duration(milliseconds: 15));
    await _sendReport(buttons: 0x00, dx: 0, dy: 0, wheel: 0);
  }

  // Key operations for Virtual Keyboard
  Future<void> _handleKeyTap(KeyInfo key) async {
    if (key.scancode == -1) {
      // Toggle Fn translation layer
      setState(() {
        _fnActive = !_fnActive;
      });
      return;
    }

    if (key.isModifier) {
      // Tapping sticky modifiers
      setState(() {
        _modifiersBitmask ^= key.modifierMask;
      });
      await _sendKeyboardReport();
      return;
    }

    // Resolve translated scancode depending on Fn active state
    int scancode = (_fnActive && key.fnScancode != null) ? key.fnScancode! : key.scancode;

    if (_holdLockActive) {
      // HoldLock active: Toggle state
      setState(() {
        if (_activeScancodes.contains(scancode)) {
          _activeScancodes.remove(scancode);
        } else {
          if (_activeScancodes.length < 6) {
            _activeScancodes.add(scancode);
          }
        }
      });
      await _sendKeyboardReport();
    } else {
      // Normal: Send press down, delay 15ms, then release
      setState(() {
        _activeScancodes.add(scancode);
      });
      await _sendKeyboardReport();
      await Future.delayed(const Duration(milliseconds: 15));
      setState(() {
        _activeScancodes.remove(scancode);
      });
      await _sendKeyboardReport();
    }
  }

  Future<void> _toggleForcedLandscapeKeyboard() async {
    if (_forcedLandscapeKeyboard) {
      setState(() {
        _forcedLandscapeKeyboard = false;
      });
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      setState(() {
        _forcedLandscapeKeyboard = true;
      });
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  // --- UI Layout Generators ---

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
              "CouchMouse emulates a standard Bluetooth mouse and keyboard. To register this hardware profile, the app requires Bluetooth permission to advertise to hosts.",
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
            color: dotColor.withOpacity(0.6),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionDashboard({bool compact = false}) {
    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 6, 12, 6)
          : const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF13131B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isConnected ? const Color(0x330DF5E3) : const Color(0x1AFFFFFF),
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isConnected ? "Connected" : "Not Connected",
                    style: TextStyle(
                      fontSize: compact ? 15 : 18,
                      fontWeight: FontWeight.bold,
                      color: _isConnected ? const Color(0xFF0DF5E3) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isConnected
                        ? "Connected to ${_connectedDeviceName ?? 'Host Laptop'}"
                        : "Pair via phone's Bluetooth settings as 'CouchMouse'",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11 : 13,
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
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: compact ? 22 : 26,
              tooltip: "Bluetooth Settings",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackpad({required double height, double borderOpacity = 0.08}) {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            setState(() {
              _touchPos = details.localFocalPoint;
              _trailPoints = [details.localFocalPoint];
            });
          },
          onScaleUpdate: (details) {
            if (details.pointerCount == 1) {
              setState(() {
                _touchPos = details.localFocalPoint;
                _trailPoints.add(details.localFocalPoint);
                if (_trailPoints.length > 15) {
                  _trailPoints.removeAt(0);
                }
              });

              // Apply sensitivity and mouse acceleration formulas
              double rawDx = details.focalPointDelta.dx;
              double rawDy = details.focalPointDelta.dy;

              double scaledDx = rawDx * _sensitivity;
              double scaledDy = rawDy * _sensitivity;

              if (_mouseAcceleration) {
                scaledDx = scaledDx * (1.0 + scaledDx.abs() * 0.05);
                scaledDy = scaledDy * (1.0 + scaledDy.abs() * 0.05);
              }

              _sendReport(
                buttons: _lastButtonsState,
                dx: scaledDx,
                dy: scaledDy,
                wheel: 0,
              );
            } else if (details.pointerCount == 2) {
              setState(() {
                _touchPos = details.localFocalPoint;
                _trailPoints.clear();
              });

              // Scroll input direction is natural (-dy)
              double dy = details.focalPointDelta.dy;
              double wheelDelta = -dy * 0.25;
              if (wheelDelta != 0) {
                _sendReport(buttons: _lastButtonsState, dx: 0, dy: 0, wheel: wheelDelta);
              }
            }
          },
          onScaleEnd: (details) {
            setState(() {
              _touchPos = null;
              _trailPoints.clear();
            });
          },
          onTap: _tapClick,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F0F16), Color(0xFF08080C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _touchPos != null
                    ? const Color(0x3D00E5FF)
                    : Colors.white.withOpacity(borderOpacity),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: height < 200 ? 32 : 48,
                  color: _touchPos != null ? const Color(0xFF00E5FF) : Colors.white12,
                ),
                const SizedBox(height: 12),
                Text(
                  "Trackpad Surface",
                  style: TextStyle(
                    fontSize: height < 200 ? 15 : 18,
                    fontWeight: FontWeight.bold,
                    color: _touchPos != null ? Colors.white : Colors.white30,
                  ),
                ),
                if (height >= 180) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Slide to Move • Tap to Click • 2 Fingers to Scroll",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: height < 200 ? 11 : 12,
                      color: _touchPos != null ? Colors.white60 : Colors.white24,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
        if (_touchPos != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: TrackpadPainter(_trailPoints, _touchPos),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildClickButtons({required double height, double fontSize = 14}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF13131B),
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
                  gradient: _leftActive
                      ? const RadialGradient(
                          colors: [Color(0x3300E5FF), Colors.transparent],
                          radius: 1.0,
                        )
                      : null,
                  color: _leftActive ? const Color(0x0A00E5FF) : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  border: _leftActive
                      ? Border.all(color: const Color(0xFF00E5FF), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mouse,
                        color: _leftActive ? const Color(0xFF00E5FF) : Colors.white38,
                        size: height < 70 ? 20 : 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "LEFT CLICK",
                        style: TextStyle(
                          color: _leftActive ? const Color(0xFF00E5FF) : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
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
                  gradient: _rightActive
                      ? const RadialGradient(
                          colors: [Color(0x330DF5E3), Colors.transparent],
                          radius: 1.0,
                        )
                      : null,
                  color: _rightActive ? const Color(0x0A0DF5E3) : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: _rightActive
                      ? Border.all(color: const Color(0xFF0DF5E3), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mouse_outlined,
                        color: _rightActive ? const Color(0xFF0DF5E3) : Colors.white38,
                        size: height < 70 ? 20 : 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "RIGHT CLICK",
                        style: TextStyle(
                          color: _rightActive ? const Color(0xFF0DF5E3) : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
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
    );
  }

  Widget _buildKeyboardToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E15),
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // HoldLock Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _holdLockActive = !_holdLockActive;
                    if (!_holdLockActive) {
                      _activeScancodes.clear();
                      _sendKeyboardReport();
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _holdLockActive ? const Color(0x20FFCA28) : const Color(0xFF1B1B27),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _holdLockActive ? const Color(0xFFFFCA28) : const Color(0x18FFFFFF),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _holdLockActive ? Icons.lock : Icons.lock_open,
                        size: 13,
                        color: _holdLockActive ? const Color(0xFFFFCA28) : Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "HoldLock",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _holdLockActive ? const Color(0xFFFFCA28) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Quick Reset Button
              GestureDetector(
                onTap: _resetHidState,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B27),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x18FFFFFF), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh, size: 13, color: Colors.white54),
                      SizedBox(width: 6),
                      Text(
                        "Reset",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Text(
            _fnActive ? "FN LAYER: ACTIVE" : "STANDARD LAYER",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: _fnActive ? const Color(0xFF00E5FF) : Colors.white30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboard({bool compact = false}) {
    double rowHeight = compact ? 38.0 : 48.0;
    double keyFontSize = compact ? 10.0 : 13.0;

    return Container(
      color: const Color(0xFF07070B),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _keyboardLayout.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: row.map((key) {
                // Determine layout active state (glow highlight)
                bool isActive = false;
                Color glowColor = const Color(0xFF00E5FF);

                if (key.isModifier) {
                  isActive = (_modifiersBitmask & key.modifierMask) != 0;
                  glowColor = const Color(0xFFE040FB); // Magenta glow for sticky modifiers
                } else if (key.scancode == -1) {
                  isActive = _fnActive;
                  glowColor = const Color(0xFF00E5FF);
                } else {
                  int scancode = (_fnActive && key.fnScancode != null) ? key.fnScancode! : key.scancode;
                  isActive = _activeScancodes.contains(scancode);
                  glowColor = _holdLockActive ? const Color(0xFFFFCA28) : const Color(0xFF0DF5E3);
                }

                // Determine display label
                String label = (_fnActive && key.fnLabel != null) ? key.fnLabel! : key.label;

                return Expanded(
                  flex: (key.flex * 10).toInt(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _handleKeyTap(key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        height: rowHeight,
                        decoration: BoxDecoration(
                          color: isActive ? glowColor.withOpacity(0.12) : const Color(0xFF14141E),
                          borderRadius: BorderRadius.circular(compact ? 6 : 8),
                          border: Border.all(
                            color: isActive
                                ? glowColor
                                : Colors.white.withOpacity(compact ? 0.05 : 0.08),
                            width: isActive ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            if (isActive)
                              BoxShadow(
                                color: glowColor.withOpacity(0.2),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: keyFontSize,
                            fontWeight: FontWeight.bold,
                            color: isActive ? glowColor : Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Main Structural Layout Builders ---

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildConnectionDashboard(compact: false),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildTrackpad(height: constraints.maxHeight, borderOpacity: 0.1);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _buildClickButtons(height: 95, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSplitLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Trackpad and mouse click buttons
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Column(
              children: [
                _buildConnectionDashboard(compact: true),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return _buildTrackpad(height: constraints.maxHeight, borderOpacity: 0.08);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                _buildClickButtons(height: 60, fontSize: 11),
              ],
            ),
          ),
        ),
        // Divider line
        Container(
          width: 1.5,
          color: const Color(0x18FFFFFF),
          margin: const EdgeInsets.symmetric(vertical: 12),
        ),
        // Right Column: Virtual 60% Keyboard Layout
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildKeyboardToolbar(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: _buildKeyboard(compact: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForcedLandscapeKeyboardLayout() {
    return Column(
      children: [
        // Full screen keyboard header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF13131B),
            border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.keyboard, color: Color(0xFF00E5FF)),
                  const SizedBox(width: 12),
                  const Text(
                    "CouchMouse Full Keyboard",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  _buildStatusDot(),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _toggleForcedLandscapeKeyboard,
                icon: const Icon(Icons.exit_to_app, size: 16),
                label: const Text("Exit Keyboard"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildKeyboardToolbar(),
        Expanded(
          child: Container(
            color: const Color(0xFF07070B),
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildKeyboard(compact: false),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) {
      return Scaffold(
        body: SafeArea(child: _buildUnsupportedView()),
      );
    }

    if (!_permissionsGranted) {
      return Scaffold(
        body: SafeArea(child: _buildPermissionsView()),
      );
    }

    return OrientationBuilder(
      builder: (context, orientation) {
        // If Forced Landscape Keyboard is enabled, override everything with the full keyboard layout
        bool showFullKeyboard = _forcedLandscapeKeyboard && orientation == Orientation.landscape;

        return Scaffold(
          appBar: showFullKeyboard
              ? null // No appBar when in full screen keyboard
              : AppBar(
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        orientation == Orientation.portrait ? Icons.mouse : Icons.keyboard,
                        color: const Color(0xFF00E5FF),
                      ),
                      const SizedBox(width: 12),
                      const Text(
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
                    // Only show forced landscape lock button if currently in portrait
                    if (orientation == Orientation.portrait)
                      IconButton(
                        icon: const Icon(Icons.keyboard, color: Color(0xFF0DF5E3)),
                        onPressed: _toggleForcedLandscapeKeyboard,
                        tooltip: "Full Keyboard Mode",
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
          drawer: showFullKeyboard ? null : _buildDrawer(),
          body: SafeArea(
            child: showFullKeyboard
                ? _buildForcedLandscapeKeyboardLayout()
                : (orientation == Orientation.portrait
                    ? _buildPortraitLayout()
                    : _buildSplitLandscapeLayout()),
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF13131B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF07070B), Color(0xFF13131B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(bottom: BorderSide(color: Color(0x18FFFFFF))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x1A00E5FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.mouse, color: Color(0xFF00E5FF), size: 30),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "CouchMouse",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "Premium Bluetooth Controller",
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    "MOUSE CONTROLS",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.0),
                  ),
                ),
                // Sensitivity control
                Card(
                  color: const Color(0xFF1B1B26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Sensitivity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("${_sensitivity.toStringAsFixed(1)}x", style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF00E5FF),
                            inactiveTrackColor: const Color(0x22FFFFFF),
                            thumbColor: const Color(0xFF0DF5E3),
                            overlayColor: const Color(0x2200E5FF),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: _sensitivity,
                            min: 0.5,
                            max: 6.0,
                            onChanged: (val) {
                              setState(() {
                                _sensitivity = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Mouse Acceleration Toggle
                Card(
                  color: const Color(0xFF1B1B26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: SwitchListTile(
                    activeColor: const Color(0xFF0DF5E3),
                    title: const Text("Mouse Acceleration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text("Increases cursor speed with rapid swipes", style: TextStyle(fontSize: 12, color: Colors.white54)),
                    value: _mouseAcceleration,
                    onChanged: (val) {
                      setState(() {
                        _mouseAcceleration = val;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    "UTILITIES",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.0),
                  ),
                ),
                // HoldLock Toggle (Drawer duplicate)
                ListTile(
                  leading: Icon(
                    _holdLockActive ? Icons.lock : Icons.lock_open,
                    color: _holdLockActive ? const Color(0xFFFFCA28) : Colors.white60,
                  ),
                  title: const Text("HoldLock Mode", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  trailing: Switch(
                    activeColor: const Color(0xFFFFCA28),
                    value: _holdLockActive,
                    onChanged: (val) {
                      setState(() {
                        _holdLockActive = val;
                        if (!_holdLockActive) {
                          _activeScancodes.clear();
                          _sendKeyboardReport();
                        }
                      });
                    },
                  ),
                ),
                // Reset State Utility
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.redAccent),
                  title: const Text("Reset HID Profile State", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  onTap: () {
                    _resetHidState();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Bluetooth Keyboard/Mouse State Reset"),
                        backgroundColor: Color(0xFF13131B),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const Divider(color: Color(0x18FFFFFF), height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    "CONNECTION INSTRUCTIONS",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.0),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    "1. Open your host device's (PC, Mac, Linux) standard Bluetooth settings.\n"
                    "2. Tap the Bluetooth settings icon in the top header card to view your phone's system Bluetooth menu.\n"
                    "3. Ensure Bluetooth is ON and pair with 'CouchMouse' from the list.\n"
                    "4. Once paired, CouchMouse acts as a physical peripheral device.",
                    style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrackpadPainter extends CustomPainter {
  final List<Offset> points;
  final Offset? currentPoint;

  TrackpadPainter(this.points, this.currentPoint);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty && currentPoint == null) return;

    // Draw the neon cyan trail connecting past points
    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        double progress = i / points.length; // 0.0 to 1.0
        final Paint trailPaint = Paint()
          ..color = const Color(0xFF00E5FF).withOpacity(progress * 0.4)
          ..strokeWidth = progress * 6.0 + 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(points[i], points[i + 1], trailPaint);
      }
    }

    if (currentPoint != null) {
      // Subtle outer halo glow
      final Paint glowPaint = Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0x4000E5FF),
            Color(0x1000E5FF),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: currentPoint!, radius: 44.0));
      canvas.drawCircle(currentPoint!, 44.0, glowPaint);

      // Inner glowing ring outline
      final Paint ringPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(currentPoint!, 18.0, ringPaint);

      // Focal point center dot
      final Paint dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentPoint!, 4.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TrackpadPainter oldDelegate) {
    return true;
  }
}
