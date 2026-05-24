import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock orientation to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
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

  bool _isSupported = true;
  bool _permissionsGranted = false;
  bool _isConnected = false;
  bool _isRegistered = false;
  String? _connectedDeviceName;

  // Fraction accumulations for sub-pixel precision control
  double _fractionalDx = 0.0;
  double _fractionalDy = 0.0;
  double _fractionalWheel = 0.0;
  int _lastButtonsState = 0;

  // Trackpad visual cursor dot position
  Offset? _touchPos;

  // Visual state triggers for bottom buttons
  bool _leftActive = false;
  bool _rightActive = false;

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
        Permission.location, // Location is legacy backup for older devices
      ].request();

      // On Android 12+, we must have BluetoothConnect
      granted = (statuses[Permission.bluetoothConnect]?.isGranted ?? false) &&
                (statuses[Permission.bluetoothAdvertise]?.isGranted ?? false) &&
                (statuses[Permission.bluetoothScan]?.isGranted ?? false);

      // On Android 11 and lower, check location permission status instead
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
        debugPrint("Error dispatching HID event: ${e.message}");
      }
    }
  }

  Future<void> _tapClick() async {
    await _sendReport(buttons: 0x01, dx: 0, dy: 0, wheel: 0);
    await Future.delayed(const Duration(milliseconds: 15));
    await _sendReport(buttons: 0x00, dx: 0, dy: 0, wheel: 0);
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
              "CouchMouse emulates a standard Bluetooth mouse. To do this, we need Bluetooth permissions to register the profile and advertise to your computer.",
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

  Widget _buildMainView() {
    return Column(
      children: [
        // Connection dashboard card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? const Color(0xFF0DF5E3) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isConnected
                            ? "Connected to ${_connectedDeviceName ?? 'Host Laptop'}"
                            : "Pair via phone's Bluetooth settings to 'CouchMouse'",
                        style: const TextStyle(
                          fontSize: 13,
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
        ),

        // Trackpad Surface Area
        Expanded(
          child: Padding(
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
                      // Scroll delta scale
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
                          size: 48,
                          color: _touchPos != null ? const Color(0xFF00E5FF) : Colors.white12,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Trackpad Surface",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _touchPos != null ? Colors.white : Colors.white30,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Slide to Move • Tap to Click • 2 Fingers to Scroll",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
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
          ),
        ),

        const SizedBox(height: 16),

        // Bottom Physical-like Click Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            height: 100,
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
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "LEFT CLICK",
                              style: TextStyle(
                                color: _leftActive ? const Color(0xFF00E5FF) : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "RIGHT CLICK",
                              style: TextStyle(
                                color: _rightActive ? const Color(0xFF0DF5E3) : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mouse, color: Color(0xFF00E5FF)),
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
      ),
      body: SafeArea(
        child: !_isSupported
            ? _buildUnsupportedView()
            : (!_permissionsGranted ? _buildPermissionsView() : _buildMainView()),
      ),
    );
  }
}

class TrackpadPainter extends CustomPainter {
  final Offset? touchPosition;

  TrackpadPainter(this.touchPosition);

  @override
  void paint(Canvas canvas, Size size) {
    if (touchPosition == null) return;

    // Subtle outer halo glow
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0x3D00E5FF),
          Color(0x0F00E5FF),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: touchPosition!, radius: 48.0));
    canvas.drawCircle(touchPosition!, 48.0, glowPaint);

    // Inner glowing ring outline
    final Paint ringPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(touchPosition!, 20.0, ringPaint);

    // Focal point center dot
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
