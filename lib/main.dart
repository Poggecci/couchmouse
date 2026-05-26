import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_providers.dart';
import 'keyboard_layouts.dart';
import 'widgets/trackpad.dart';
import 'widgets/scroll_wheel.dart';
import 'widgets/click_buttons.dart';
import 'widgets/virtual_keyboard.dart';
import 'widgets/connection_dashboard.dart';
import 'widgets/control_drawer.dart';
import 'widgets/bluetooth_devices_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const CouchMouseApp(),
    ),
  );
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.example.couchmouse/hid');

  bool _isSupported = true;
  bool _permissionsGranted = false;
  bool _isRegistered = false;

  double _sensitivity = 10.0;
  bool _mouseAcceleration = false;
  bool _trackpadOnLeft = false;
  KeyboardKind _keyboardKind = KeyboardKind.seventyFive;
  bool _invertTwoFingerScroll = false;
  double _scrollSensitivity = 1.0;

  double _fractionalDx = 0.0;
  double _fractionalDy = 0.0;
  double _fractionalWheel = 0.0;
  int _lastButtonsState = 0;

  bool _leftActive = false;
  bool _rightActive = false;

  final Set<int> _activeScancodes = {};
  int _modifiersBitmask = 0;
  bool _fnActive = false;
  bool _holdLockActive = false;

  bool _keyboardMode = false;
  bool _keyboardDidOpen = false;
  late final FocusNode _builtInKeyboardFocusNode;
  late final TextEditingController _builtInKeyboardController;
  bool _builtInKeyboardActive = false;
  double _swipeDragDistance = 0.0;
  Future<void> _keystrokeQueue = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _builtInKeyboardFocusNode = FocusNode();
    _builtInKeyboardFocusNode.addListener(() {
      if (!mounted) return;
      setState(() {
        _builtInKeyboardActive = _builtInKeyboardFocusNode.hasFocus;
        if (!_builtInKeyboardFocusNode.hasFocus) {
          final orientation = MediaQuery.maybeOrientationOf(context) ?? Orientation.portrait;
          if (orientation == Orientation.portrait) {
            _keyboardMode = false;
          }
        }
      });
    });
    _builtInKeyboardController = TextEditingController(text: " ");
    _checkSupportAndPermissions();
    _setupPlatformChannel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _builtInKeyboardFocusNode.dispose();
    _builtInKeyboardController.dispose();
    super.dispose();
  }

  void _setupPlatformChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onConnectionStateChanged':
          final connected = call.arguments['connected'] as bool;
          final deviceName = call.arguments['deviceName'] as String?;
          final deviceAddress = call.arguments['deviceAddress'] as String?;
          await ref
              .read(connectionStateProvider.notifier)
              .updateConnectionState(
                isConnected: connected,
                connectedDeviceName: deviceName,
                connectedDeviceAddress: deviceAddress,
              );
          break;
        case 'onRegistrationChanged':
          final registered = call.arguments['registered'] as bool;
          setState(() {
            _isRegistered = registered;
          });
          if (registered) {
            _retryLastConnection();
          }
          break;
        case 'onScanModeChanged':
          final isDiscoverable = call.arguments['isDiscoverable'] as bool;
          ref.read(discoverableProvider.notifier).setDiscoverable(isDiscoverable);
          break;
      }
    });
  }

  Future<void> _checkSupportAndPermissions() async {
    try {
      final supported =
          await _channel.invokeMethod<bool>('isSupported') ?? false;
      setState(() {
        _isSupported = supported;
      });

      if (supported) {
        _checkPermissions();
        _checkDiscoverability();
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
        PermissionStatus connectStatus =
            await Permission.bluetoothConnect.status;
        PermissionStatus advertiseStatus =
            await Permission.bluetoothAdvertise.status;
        PermissionStatus scanStatus = await Permission.bluetoothScan.status;

        granted =
            connectStatus.isGranted &&
            advertiseStatus.isGranted &&
            scanStatus.isGranted;

        if (!granted) {
          Map<Permission, PermissionStatus> statuses = await [
            Permission.bluetoothConnect,
            Permission.bluetoothAdvertise,
            Permission.bluetoothScan,
          ].request();

          granted =
              (statuses[Permission.bluetoothConnect]?.isGranted ?? false) &&
              (statuses[Permission.bluetoothAdvertise]?.isGranted ?? false) &&
              (statuses[Permission.bluetoothScan]?.isGranted ?? false);
        }
      } else {
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
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getConnectionState',
      );
      if (result != null) {
        await ref
            .read(connectionStateProvider.notifier)
            .updateConnectionState(
              isConnected: result['connected'] as bool? ?? false,
              connectedDeviceName: result['deviceName'] as String?,
              connectedDeviceAddress: result['deviceAddress'] as String?,
            );
        setState(() {
          _isRegistered = result['registered'] as bool? ?? false;
        });
        if (_isRegistered) {
          _retryLastConnection();
        }
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

  Future<void> _checkDiscoverability() async {
    try {
      final isDisc = await _channel.invokeMethod<bool>('isDiscoverable') ?? false;
      ref.read(discoverableProvider.notifier).setDiscoverable(isDisc);
    } catch (e) {
      debugPrint("Error checking discoverability: $e");
    }
  }

  Future<void> _requestDiscoverable() async {
    if (!_permissionsGranted) {
      await _checkPermissions();
      if (!_permissionsGranted) return;
    }
    try {
      await _channel.invokeMethod('requestDiscoverable', {
        'duration': 120,
      });
    } catch (e) {
      debugPrint("Error requesting bluetooth discoverability: $e");
    }
  }

  Future<void> _connectToDevice(String address, String name) async {
    ref.read(connectionStateProvider.notifier).updateConnectingState(
          isConnecting: true,
          connectingAddress: address,
        );

    try {
      final success =
          await _channel.invokeMethod<bool>('connectDevice', {
            'address': address,
          }) ??
          false;
      if (!success) {
        ref.read(connectionStateProvider.notifier).updateConnectingState(
              isConnecting: false,
              connectingAddress: null,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to initiate connection to $name"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            final connection = ref.read(connectionStateProvider);
            if (connection.isConnecting &&
                connection.connectingAddress == address) {
              ref.read(connectionStateProvider.notifier).updateConnectingState(
                    isConnecting: false,
                    connectingAddress: null,
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Connection to $name timed out"),
                  backgroundColor: Colors.amber,
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      ref.read(connectionStateProvider.notifier).updateConnectingState(
            isConnecting: false,
            connectingAddress: null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error connecting to $name: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _disconnectDevice() async {
    try {
      final success =
          await _channel.invokeMethod<bool>('disconnectDevice') ?? false;
      if (success) {
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.remove('last_connected_device_address');
        await prefs.remove('last_connected_device_name');
        await ref
            .read(connectionStateProvider.notifier)
            .updateConnectionState(
              isConnected: false,
              connectedDeviceName: null,
              connectedDeviceAddress: null,
            );
      }
    } catch (e) {
      debugPrint("Error disconnecting device: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_keyboardMode) {
        setState(() {
          _keyboardMode = false;
          _keyboardDidOpen = false;
          _builtInKeyboardFocusNode.unfocus();
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      _checkSupportAndPermissions();
      _retryLastConnection();
    }
  }

  Future<void> _retryLastConnection() async {
    final connection = ref.read(connectionStateProvider);
    if (connection.isConnected || connection.isConnecting) return;
    if (!_isRegistered) return;

    final prefs = ref.read(sharedPreferencesProvider);
    final lastAddress = prefs.getString('last_connected_device_address');
    final lastName = prefs.getString('last_connected_device_name');

    if (lastAddress != null && lastName != null) {
      debugPrint("Auto-reconnecting to last known device: $lastName ($lastAddress)");
      await _connectToDevice(lastAddress, lastName);
    }
  }

  void _showBluetoothDevicesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF13131B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return BluetoothDevicesSheet(
          isRegistered: _isRegistered,
          onConnect: _connectToDevice,
          onDisconnect: _disconnectDevice,
          onRequestDiscoverable: _requestDiscoverable,
        );
      },
    );
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

    intDx = intDx.clamp(-127, 127);
    intDy = intDy.clamp(-127, 127);
    intWheel = intWheel.clamp(-127, 127);

    if (intDx != 0 ||
        intDy != 0 ||
        intWheel != 0 ||
        buttons != _lastButtonsState) {
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

  Future<void> _sendKeyboardReport() async {
    List<int> bytes = List.filled(8, 0);
    bytes[0] = _modifiersBitmask;
    bytes[1] = 0;

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

  void _resetHidState() {
    setState(() {
      _activeScancodes.clear();
      _modifiersBitmask = 0;
      _lastButtonsState = 0;
      _leftActive = false;
      _rightActive = false;
      _fnActive = false;
    });
    _sendKeyboardReport();
    _sendReport(buttons: 0, dx: 0, dy: 0);
  }

  Future<void> _tapClick() async {
    await _sendReport(buttons: 0x01, dx: 0, dy: 0, wheel: 0);
    await Future.delayed(const Duration(milliseconds: 15));
    await _sendReport(buttons: 0x00, dx: 0, dy: 0, wheel: 0);
  }

  Future<void> _handleKeyTap(KeyInfo key) async {
    if (key.scancode == -1) {
      setState(() {
        _fnActive = !_fnActive;
      });
      return;
    }

    if (key.isModifier) {
      setState(() {
        _modifiersBitmask ^= key.modifierMask;
      });
      await _sendKeyboardReport();
      return;
    }

    int scancode = (_fnActive && key.fnScancode != null)
        ? key.fnScancode!
        : key.scancode;

    if (_holdLockActive) {
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

  void _toggleKeyboardMode() {
    setState(() {
      _keyboardMode = !_keyboardMode;
      _keyboardDidOpen = false;
      if (!_keyboardMode) {
        _builtInKeyboardFocusNode.unfocus();
      }
    });
  }

  Future<void> _queueKeyStroke(int scancode, {bool shift = false}) {
    _keystrokeQueue = _keystrokeQueue.then((_) async {
      int originalModifiers = _modifiersBitmask;

      if (shift) {
        _modifiersBitmask |= 0x02;
      }

      setState(() {
        _activeScancodes.add(scancode);
      });
      await _sendKeyboardReport();

      await Future.delayed(const Duration(milliseconds: 15));

      setState(() {
        _activeScancodes.remove(scancode);
        _modifiersBitmask = originalModifiers;
      });
      await _sendKeyboardReport();

      await Future.delayed(const Duration(milliseconds: 10));
    });
    return _keystrokeQueue;
  }

  Widget _buildHiddenTextField() {
    return SizedBox(
      width: 1,
      height: 1,
      child: Opacity(
        opacity: 0.0,
        child: TextField(
          controller: _builtInKeyboardController,
          focusNode: _builtInKeyboardFocusNode,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.send,
          onChanged: (val) async {
            if (val.length > 1) {
              String typed = val.substring(1);
              for (int i = 0; i < typed.length; i++) {
                String char = typed[i];
                if (KeyboardLayouts.charToScancode.containsKey(char)) {
                  await _queueKeyStroke(KeyboardLayouts.charToScancode[char]!, shift: false);
                } else if (KeyboardLayouts.shiftCharToScancode.containsKey(char)) {
                  await _queueKeyStroke(
                    KeyboardLayouts.shiftCharToScancode[char]!,
                    shift: true,
                  );
                }
              }
            } else if (val.isEmpty) {
              await _queueKeyStroke(0x2A);
            }
            _builtInKeyboardController.text = " ";
            _builtInKeyboardController.selection =
                const TextSelection.collapsed(offset: 1);
          },
          onSubmitted: (_) async {
            await _queueKeyStroke(0x28);
            _builtInKeyboardFocusNode.requestFocus();
          },
        ),
      ),
    );
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "CouchMouse requires Android 9 (API Level 28) or higher for native Bluetooth HID Device Emulation.\n\nYour device's Android version does not support this profile.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white54,
                height: 1.5,
              ),
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
            const Icon(
              Icons.bluetooth_searching,
              size: 80,
              color: Color(0xFF00E5FF),
            ),
            const SizedBox(height: 24),
            const Text(
              "Bluetooth Access Required",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "CouchMouse emulates a standard Bluetooth mouse and keyboard. To register this hardware profile, the app requires Bluetooth permission to advertise to hosts.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _checkPermissions,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Grant Permissions"),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: const Color(0xFF00E5FF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
    final connection = ref.watch(connectionStateProvider);
    Color dotColor = Colors.red;
    if (connection.isConnected) {
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

  Widget _buildHoldLockButton({bool compact = false}) {
    return GestureDetector(
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
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: _holdLockActive
              ? const Color(0x20FFCA28)
              : const Color(0xFF1B1B26),
          borderRadius: BorderRadius.circular(compact ? 6 : 8),
          border: Border.all(
            color: _holdLockActive
                ? const Color(0xFFFFCA28)
                : const Color(0x18FFFFFF),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _holdLockActive ? Icons.lock : Icons.lock_open,
              size: compact ? 11 : 13,
              color: _holdLockActive
                  ? const Color(0xFFFFCA28)
                  : Colors.white54,
            ),
            SizedBox(width: compact ? 4 : 6),
            Text(
              "HoldLock",
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: _holdLockActive
                    ? const Color(0xFFFFCA28)
                    : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton({bool compact = false}) {
    return GestureDetector(
      onTap: _resetHidState,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B26),
          borderRadius: BorderRadius.circular(compact ? 6 : 8),
          border: Border.all(
            color: const Color(0x18FFFFFF),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.refresh,
              size: compact ? 11 : 13,
              color: Colors.white54,
            ),
            SizedBox(width: compact ? 4 : 6),
            Text(
              "Reset",
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ],
        ),
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
              _buildHoldLockButton(compact: false),
              const SizedBox(width: 8),
              _buildResetButton(compact: false),
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

  Widget _buildKeyboardAccessoryBar() {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Color(0xFF13131B),
        border: Border(
          top: BorderSide(color: Color(0x18FFFFFF)),
          bottom: BorderSide(color: Color(0x18FFFFFF)),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          _buildAccessoryButton(
            icon: Icons.keyboard_hide,
            onTap: _toggleKeyboardMode,
            color: Colors.redAccent,
          ),
          _buildAccessoryDivider(),
          _buildAccessoryKey("Esc", 0x29),
          _buildAccessoryKey("Tab", 0x2B),
          _buildAccessoryDivider(),
          _buildAccessoryModifier("Ctrl", 0x01, const Color(0xFFE040FB)),
          _buildAccessoryModifier("Shift", 0x02, const Color(0xFFE040FB)),
          _buildAccessoryModifier("Alt", 0x04, const Color(0xFFE040FB)),
          _buildAccessoryModifier("Win", 0x08, const Color(0xFFE040FB)),
          _buildAccessoryDivider(),
          _buildAccessoryKey("◀", 0x50),
          _buildAccessoryKey("▲", 0x52),
          _buildAccessoryKey("▼", 0x51),
          _buildAccessoryKey("▶", 0x4F),
          _buildAccessoryDivider(),
          _buildAccessoryKey("Del", 0x4C),
          _buildAccessoryKey("Enter", 0x28),
        ],
      ),
    );
  }

  Widget _buildAccessoryKey(String label, int scancode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTap: () async {
          await _queueKeyStroke(scancode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B26),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x18FFFFFF)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessoryModifier(String label, int mask, Color glowColor) {
    bool isActive = (_modifiersBitmask & mask) != 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTap: () async {
          setState(() {
            _modifiersBitmask ^= mask;
          });
          await _sendKeyboardReport();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isActive
                ? glowColor.withValues(alpha: 0.15)
                : const Color(0xFF1B1B26),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? glowColor : const Color(0x18FFFFFF),
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? glowColor : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessoryButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = const Color(0xFF00E5FF),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B26),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x18FFFFFF)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }

  Widget _buildAccessoryDivider() {
    return Container(
      width: 1.5,
      height: 24,
      color: const Color(0x18FFFFFF),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    );
  }

  Widget _buildPortraitLayout() {
    return Stack(
      children: [
        Column(
          children: [
            ConnectionDashboard(
              compact: false,
              isRegistered: _isRegistered,
              onTap: _showBluetoothDevicesBottomSheet,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      children: [
                        Expanded(
                          child: Trackpad(
                            height: constraints.maxHeight,
                            borderOpacity: 0.1,
                            sensitivity: _sensitivity,
                            mouseAcceleration: _mouseAcceleration,
                            invertTwoFingerScroll: _invertTwoFingerScroll,
                            scrollSensitivity: _scrollSensitivity,
                            onReport: ({required double dx, required double dy, required double wheel}) {
                              _sendReport(buttons: _lastButtonsState, dx: dx, dy: dy, wheel: wheel);
                            },
                            onTap: _tapClick,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ScrollWheel(
                          height: constraints.maxHeight,
                          scrollSensitivity: _scrollSensitivity,
                          invertScroll: _invertTwoFingerScroll,
                          onScroll: (wheel) {
                            _sendReport(buttons: _lastButtonsState, dx: 0, dy: 0, wheel: wheel);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (_builtInKeyboardActive) ...[
              const SizedBox(height: 16),
              _buildKeyboardAccessoryBar(),
            ] else
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: (details) {
                  _swipeDragDistance = 0.0;
                },
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta != null) {
                    _swipeDragDistance += details.primaryDelta!;
                    if (_swipeDragDistance < -30.0) {
                      if (!_keyboardMode) {
                        _toggleKeyboardMode();
                      } else {
                        _builtInKeyboardFocusNode.requestFocus();
                      }
                      _swipeDragDistance = 0.0;
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: ClickButtons(
                    height: 95,
                    fontSize: 13,
                    compact: false,
                    leftActive: _leftActive,
                    rightActive: _rightActive,
                    onLeftTapDown: (_) {
                      setState(() => _leftActive = true);
                      _sendReport(buttons: 0x01, dx: 0, dy: 0);
                    },
                    onLeftTapUp: (_) {
                      setState(() => _leftActive = false);
                      _sendReport(buttons: 0x00, dx: 0, dy: 0);
                    },
                    onLeftTapCancel: () {
                      setState(() => _leftActive = false);
                      _sendReport(buttons: 0x00, dx: 0, dy: 0);
                    },
                    onRightTapDown: (_) {
                      setState(() => _rightActive = true);
                      _sendReport(buttons: 0x02, dx: 0, dy: 0);
                    },
                    onRightTapUp: (_) {
                      setState(() => _rightActive = false);
                      _sendReport(buttons: 0x00, dx: 0, dy: 0);
                    },
                    onRightTapCancel: () {
                      setState(() => _rightActive = false);
                      _sendReport(buttons: 0x00, dx: 0, dy: 0);
                    },
                  ),
                ),
              ),
          ],
        ),
        Positioned(left: 0, top: 0, child: _buildHiddenTextField()),
      ],
    );
  }

  Widget _buildSplitLandscapeLayout() {
    final trackpadColumn = Expanded(
      flex: 1,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _trackpadOnLeft ? 12 : 8,
          8,
          _trackpadOnLeft ? 8 : 12,
          8,
        ),
        child: Column(
          children: [
            ConnectionDashboard(
              compact: true,
              isRegistered: _isRegistered,
              onTap: _showBluetoothDevicesBottomSheet,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      Expanded(
                        child: Trackpad(
                          height: constraints.maxHeight,
                          borderOpacity: 0.08,
                          sensitivity: _sensitivity,
                          mouseAcceleration: _mouseAcceleration,
                          invertTwoFingerScroll: _invertTwoFingerScroll,
                          scrollSensitivity: _scrollSensitivity,
                          onReport: ({required double dx, required double dy, required double wheel}) {
                            _sendReport(buttons: _lastButtonsState, dx: dx, dy: dy, wheel: wheel);
                          },
                          onTap: _tapClick,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ScrollWheel(
                        height: constraints.maxHeight,
                        scrollSensitivity: _scrollSensitivity,
                        invertScroll: _invertTwoFingerScroll,
                        onScroll: (wheel) {
                          _sendReport(buttons: _lastButtonsState, dx: 0, dy: 0, wheel: wheel);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            ClickButtons(
              height: 50,
              fontSize: 11,
              compact: true,
              leftActive: _leftActive,
              rightActive: _rightActive,
              onLeftTapDown: (_) {
                setState(() => _leftActive = true);
                _sendReport(buttons: 0x01, dx: 0, dy: 0);
              },
              onLeftTapUp: (_) {
                setState(() => _leftActive = false);
                _sendReport(buttons: 0x00, dx: 0, dy: 0);
              },
              onLeftTapCancel: () {
                setState(() => _leftActive = false);
                _sendReport(buttons: 0x00, dx: 0, dy: 0);
              },
              onRightTapDown: (_) {
                setState(() => _rightActive = true);
                _sendReport(buttons: 0x02, dx: 0, dy: 0);
              },
              onRightTapUp: (_) {
                setState(() => _rightActive = false);
                _sendReport(buttons: 0x00, dx: 0, dy: 0);
              },
              onRightTapCancel: () {
                setState(() => _rightActive = false);
                _sendReport(buttons: 0x00, dx: 0, dy: 0);
              },
            ),
          ],
        ),
      ),
    );

    final divider = Container(
      width: 1.5,
      color: const Color(0x18FFFFFF),
      margin: const EdgeInsets.symmetric(vertical: 12),
    );

    final keyboardColumn = Expanded(
      flex: 3,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _trackpadOnLeft ? 8 : 12,
          8,
          _trackpadOnLeft ? 12 : 8,
          8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeyboardToolbar(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: VirtualKeyboard(
                    compact: true,
                    keyboardKind: _keyboardKind,
                    fnActive: _fnActive,
                    holdLockActive: _holdLockActive,
                    modifiersBitmask: _modifiersBitmask,
                    activeScancodes: _activeScancodes,
                    onKeyTap: _handleKeyTap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _trackpadOnLeft
          ? [trackpadColumn, divider, keyboardColumn]
          : [keyboardColumn, divider, trackpadColumn],
    );
  }

  Widget _buildForcedLandscapeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF13131B),
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildStatusDot(),
              const SizedBox(width: 8),
              const Text(
                "CouchMouse",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 12),
              _buildHoldLockButton(compact: true),
              const SizedBox(width: 6),
              _buildResetButton(compact: true),
            ],
          ),
          Row(
            children: [
              Text(
                _fnActive ? "FN ACTIVE" : "STANDARD",
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: _fnActive ? const Color(0xFF00E5FF) : Colors.white30,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _toggleKeyboardMode,
                icon: const Icon(Icons.keyboard, color: Color(0xFF0DF5E3)),
                tooltip: "Split Keyboard Layout",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForcedLandscapeKeyboardLayout() {
    return Column(
      children: [
        _buildForcedLandscapeHeader(),
        Expanded(
          child: Container(
            color: const Color(0xFF07070B),
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: VirtualKeyboard(
                compact: true,
                keyboardKind: _keyboardKind,
                fnActive: _fnActive,
                holdLockActive: _holdLockActive,
                modifiersBitmask: _modifiersBitmask,
                activeScancodes: _activeScancodes,
                onKeyTap: _handleKeyTap,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    _sensitivity = settings.sensitivity;
    _mouseAcceleration = settings.mouseAcceleration;
    _trackpadOnLeft = settings.trackpadOnLeft;
    _keyboardKind = settings.keyboardKind;
    _invertTwoFingerScroll = settings.invertTwoFingerScroll;
    _scrollSensitivity = settings.scrollSensitivity;

    if (!_isSupported) {
      return Scaffold(body: SafeArea(child: _buildUnsupportedView()));
    }

    if (!_permissionsGranted) {
      return Scaffold(body: SafeArea(child: _buildPermissionsView()));
    }

    final orientation = MediaQuery.of(context).orientation;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    if (orientation == Orientation.portrait) {
      if (_keyboardMode) {
        if (viewInsetsBottom > 0) {
          _keyboardDidOpen = true;
        } else if (_keyboardDidOpen && viewInsetsBottom == 0) {
          _keyboardMode = false;
          _keyboardDidOpen = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _builtInKeyboardFocusNode.unfocus();
          });
        }
      }
    } else {
      _keyboardDidOpen = false;
    }

    if (orientation == Orientation.landscape &&
        _builtInKeyboardFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _builtInKeyboardFocusNode.unfocus();
      });
    } else if (orientation == Orientation.portrait &&
        _keyboardMode &&
        !_builtInKeyboardFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _builtInKeyboardFocusNode.requestFocus();
      });
    } else if (orientation == Orientation.portrait &&
        !_keyboardMode &&
        _builtInKeyboardFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _builtInKeyboardFocusNode.unfocus();
      });
    }

    bool showFullKeyboard =
        _keyboardMode && orientation == Orientation.landscape;

    return Scaffold(
      appBar: showFullKeyboard
          ? null
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
                    orientation == Orientation.portrait
                        ? Icons.mouse
                        : Icons.keyboard,
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
                if (orientation == Orientation.portrait)
                  IconButton(
                    icon: Icon(
                      _builtInKeyboardActive
                          ? Icons.keyboard_hide
                          : Icons.keyboard,
                      color: const Color(0xFF0DF5E3),
                    ),
                    onPressed: _toggleKeyboardMode,
                    tooltip: "Built-in Keyboard",
                  )
                else if (orientation == Orientation.landscape)
                  IconButton(
                    icon: const Icon(Icons.keyboard, color: Color(0xFF0DF5E3)),
                    onPressed: _toggleKeyboardMode,
                    tooltip: "Full Keyboard Mode",
                  ),
                const SizedBox(width: 8),
              ],
            ),
      drawer: showFullKeyboard
          ? null
          : ControlDrawer(
              holdLockActive: _holdLockActive,
              onHoldLockChanged: (val) {
                setState(() {
                  _holdLockActive = val;
                  if (!_holdLockActive) {
                    _activeScancodes.clear();
                    _sendKeyboardReport();
                  }
                });
              },
              onResetHidState: _resetHidState,
              onKeyboardKindChanged: (kind) {
                ref.read(settingsProvider.notifier).updateKeyboardKind(kind);
                _activeScancodes.clear();
                _sendKeyboardReport();
              },
            ),
      body: SafeArea(
        child: showFullKeyboard
            ? _buildForcedLandscapeKeyboardLayout()
            : (orientation == Orientation.portrait
                  ? _buildPortraitLayout()
                  : _buildSplitLandscapeLayout()),
      ),
    );
  }
}
