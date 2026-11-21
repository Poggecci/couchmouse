import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'settings_providers.dart';
import 'gamepad_state.dart';
import 'keyboard_layouts.dart';
import 'widgets/trackpad.dart';
import 'widgets/scroll_wheel.dart';
import 'widgets/click_buttons.dart';
import 'widgets/virtual_keyboard.dart';
import 'widgets/connection_dashboard.dart';
import 'widgets/control_drawer.dart';
import 'widgets/bluetooth_devices_sheet.dart';
import 'widgets/walkthrough_dialog.dart';
import 'widgets/gamepad_view.dart';
import 'widgets/typing_box.dart';

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

enum _TextSource {
  clipboard('Paste', 'Pasting'),
  typingBox('Send', 'Sending');

  const _TextSource(this.noun, this.progress);
  final String noun;
  final String progress;
}

class CouchMouseApp extends ConsumerWidget {
  const CouchMouseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(settingsProvider.select((s) => s.darkMode));
    return MaterialApp(
      title: 'CouchMouse',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: darkMode ? ThemeMode.system : ThemeMode.light,
      // Screens without an app bar get the same status bar icons.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).appBarTheme.systemOverlayStyle!,
        child: child!,
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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.example.couchmouse/hid');
  static const _mouseChannel = MethodChannel('com.example.couchmouse/mouse');
  static const _settingsChannel = MethodChannel(
    'com.example.couchmouse/settings',
  );

  bool _isSupported = true;
  bool _permissionsGranted = false;
  bool _isRegistered = false;
  bool _hostAudioWarned = false;
  bool _walkthroughChecked = false;
  bool _transferringSettings = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  double _sensitivity = 5.0;
  bool _mouseAcceleration = false;
  bool _trackpadOnLeft = false;
  KeyboardKind _keyboardKind = KeyboardKind.seventyFive;
  bool _invertTwoFingerScroll = false;
  double _scrollSensitivity = 1.0;
  double _scrollMomentum = 0.0;

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
  bool _typingText = false;
  bool _cancelTypingRequested = false;

  bool _keyboardMode = false;
  bool _keyboardDidOpen = false;
  late final FocusNode _builtInKeyboardFocusNode;
  late final TextEditingController _builtInKeyboardController;
  bool _builtInKeyboardActive = false;
  bool _typingBox = false;
  final TextEditingController _typingBoxController = TextEditingController();
  double _swipeDragDistance = 0.0;
  double _horizontalSwipeDragDistance = 0.0;
  Future<void> _keystrokeQueue = Future.value();
  int _keyboardQueueGeneration = 0;
  bool _keyboardInputFocused = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _builtInKeyboardFocusNode = FocusNode(onKeyEvent: _handleTypingBoxKey);
    _builtInKeyboardFocusNode.addListener(() {
      if (!mounted) return;
      setState(() {
        _builtInKeyboardActive = _builtInKeyboardFocusNode.hasFocus;
        if (!_builtInKeyboardFocusNode.hasFocus) {
          final orientation =
              MediaQuery.maybeOrientationOf(context) ?? Orientation.portrait;
          if (orientation == Orientation.portrait) {
            _keyboardMode = false;
          }
        }
      });
    });
    _builtInKeyboardController = TextEditingController(text: " ");
    _checkSupportAndPermissions();
    _setupPlatformChannel();
    _syncGamepadReportRateToNative(ref.read(gamepadReportRateProvider));
    _syncGamepadModeToNative(ref.read(gamepadModeProvider));
  }

  @override
  void dispose() {
    _interruptKeyboardInput();
    WidgetsBinding.instance.removeObserver(this);
    _builtInKeyboardFocusNode.dispose();
    _builtInKeyboardController.dispose();
    _typingBoxController.dispose();
    super.dispose();
  }

  void _setupPlatformChannel() {
    _channel.setMethodCallHandler((call) async {
      if (!mounted) return;
      switch (call.method) {
        case 'onConnectionStateChanged':
          final connected = call.arguments['connected'] as bool;
          final deviceName = call.arguments['deviceName'] as String?;
          final deviceAddress = call.arguments['deviceAddress'] as String?;
          if (!connected) {
            _discardKeyboardInput();
            _hostAudioWarned = false;
          }
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
          if (!registered) _discardKeyboardInput();
          setState(() {
            _isRegistered = registered;
          });
          if (registered) {
            _retryLastConnection();
          }
          break;
        case 'onBondStateChanged':
          ref.invalidate(pairedDevicesProvider);
          break;
        case 'onHostAudioChanged':
          if (call.arguments['connected'] as bool && !_hostAudioWarned) {
            _hostAudioWarned = true;
            _warnHostAudio();
          }
          break;
        case 'onScanModeChanged':
          final isDiscoverable = call.arguments['isDiscoverable'] as bool;
          ref
              .read(discoverableProvider.notifier)
              .setDiscoverable(isDiscoverable);
          break;
        case 'onGamepadState':
          ref
              .read(gamepadLiveStateProvider.notifier)
              .update(GamepadSnapshot.fromMap(call.arguments as Map));
          break;
        case 'onGamepadControllersChanged':
          final names = (call.arguments['controllers'] as List?) ?? const [];
          ref
              .read(gamepadControllersProvider.notifier)
              .update(names.cast<String>());
          break;
      }
    });
  }

  Future<void> _checkSupportAndPermissions({bool request = true}) async {
    try {
      final supported =
          await _channel.invokeMethod<bool>('isSupported') ?? false;
      setState(() {
        _isSupported = supported;
      });

      if (supported) {
        _checkPermissions(request: request);
        _checkDiscoverability();
      }
    } catch (e) {
      debugPrint("Error checking support: $e");
    }
  }

  Future<void> _checkPermissions({bool request = true}) async {
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

        if (!granted && request) {
          if (connectStatus.isPermanentlyDenied ||
              advertiseStatus.isPermanentlyDenied ||
              scanStatus.isPermanentlyDenied) {
            await openAppSettings();
            return;
          }

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

        if (!granted && request) {
          if (locationStatus.isPermanentlyDenied) {
            await openAppSettings();
            return;
          }

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
      if (mounted && result != null) {
        final connected = result['connected'] as bool? ?? false;
        final registered = result['registered'] as bool? ?? false;
        if (connected ||
            !registered ||
            !ref.read(connectionStateProvider).isConnecting) {
          await ref
              .read(connectionStateProvider.notifier)
              .updateConnectionState(
                isConnected: connected,
                connectedDeviceName: result['deviceName'] as String?,
                connectedDeviceAddress: result['deviceAddress'] as String?,
              );
        }
        if (!mounted) return;
        setState(() {
          _isRegistered = registered;
        });
        if (_isRegistered) {
          _retryLastConnection();
        }
      }
    } catch (e) {
      debugPrint("Error loading connection state: $e");
    }
  }

  Future<void> _transferSettings({required bool export}) async {
    if (_transferringSettings) return;
    _transferringSettings = true;
    _scaffoldKey.currentState?.closeDrawer();
    final messenger = ScaffoldMessenger.of(context);

    String message;
    try {
      if (export) {
        final backup = await ref
            .read(settingsProvider.notifier)
            .exportSettings();
        if (!mounted) return;
        final saved = await _settingsChannel.invokeMethod<bool>(
          'exportSettings',
          {'contents': backup},
        );
        if (saved != true) return;
        message = 'Settings backup saved.';
      } else {
        final backup = await _settingsChannel.invokeMethod<String>(
          'importSettings',
        );
        if (!mounted || backup == null) return;
        await ref.read(settingsProvider.notifier).importSettings(backup);
        message = 'Settings restored.';
      }
    } on FormatException {
      message = 'Choose a valid Couch Mouse settings backup.';
    } on PlatformException catch (error) {
      message = error.message ?? 'Could not open the settings backup.';
    } catch (error) {
      debugPrint('Settings backup failed: ${error.runtimeType}');
      message = export
          ? 'Could not save settings.'
          : 'Could not restore settings.';
    } finally {
      _transferringSettings = false;
    }
    if (mounted) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  // Host audio on the same Bluetooth link can stall HID reports (see the
  // "Host audio" notes in MainActivity.kt).
  void _warnHostAudio() {
    final name =
        ref.read(connectionStateProvider).connectedDeviceName ?? 'The host';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$name is also using this phone for audio. If the cursor lags, '
          'turn off its call and media audio in Bluetooth settings, '
          'then reconnect.',
        ),
        action: SnackBarAction(
          label: 'SETTINGS',
          textColor: const Color(0xFF00E5FF),
          onPressed: _openBluetoothSettings,
        ),
        behavior: SnackBarBehavior.floating,
        persist: false,
        duration: const Duration(seconds: 10),
      ),
    );
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
      final isDisc =
          await _channel.invokeMethod<bool>('isDiscoverable') ?? false;
      ref.read(discoverableProvider.notifier).setDiscoverable(isDisc);
    } catch (e) {
      debugPrint("Error checking discoverability: $e");
    }
  }

  Future<void> _requestDiscoverable() async {
    if (!_permissionsGranted) {
      await _checkPermissions(request: true);
      if (!_permissionsGranted) return;
    }
    try {
      await _channel.invokeMethod('requestDiscoverable', {'duration': 120});
    } catch (e) {
      debugPrint("Error requesting bluetooth discoverability: $e");
    }
  }

  Future<void> _connectToDevice(String address, String name) async {
    ref
        .read(connectionStateProvider.notifier)
        .updateConnectingState(isConnecting: true, connectingAddress: address);

    try {
      final success =
          await _channel.invokeMethod<bool>('connectDevice', {
            'address': address,
          }) ??
          false;
      if (!success) {
        ref
            .read(connectionStateProvider.notifier)
            .updateConnectingState(
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
              ref
                  .read(connectionStateProvider.notifier)
                  .updateConnectingState(
                    isConnecting: false,
                    connectingAddress: null,
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Connection to $name timed out",
                    style: const TextStyle(color: Colors.black),
                  ),
                  backgroundColor: Colors.amber,
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ref
          .read(connectionStateProvider.notifier)
          .updateConnectingState(isConnecting: false, connectingAddress: null);
      final needsPairing = e is PlatformException && e.code == 'NOT_BONDED';
      if (needsPairing) {
        ref.invalidate(pairedDevicesProvider);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            needsPairing
                ? 'Pair $name again in Bluetooth settings.'
                : 'Error connecting to $name: $e',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _disconnectDevice() async {
    _discardKeyboardInput();
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
    if (state == AppLifecycleState.resumed) {
      if (!_keyboardInputFocused) {
        setState(() => _keyboardInputFocused = true);
      }
      _checkSupportAndPermissions(request: false);
      _retryLastConnection();
    } else if (_keyboardInputFocused) {
      _keyboardInputFocused = false;
      _interruptKeyboardInput();
      setState(() {
        _keyboardMode = false;
        _keyboardDidOpen = false;
      });
      _builtInKeyboardFocusNode.unfocus();
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
      try {
        final pairedDevices = await ref.read(pairedDevicesProvider.future);
        final isStillPaired = pairedDevices.any(
          (device) => device['address'] == lastAddress,
        );
        if (!isStillPaired) {
          debugPrint(
            "Auto-reconnect skipped: $lastName ($lastAddress) is no longer in paired devices.",
          );
          return;
        }
      } catch (e) {
        debugPrint("Error checking paired devices for auto-reconnect: $e");
        return;
      }

      if (!mounted || !_isRegistered) return;
      final currentConnection = ref.read(connectionStateProvider);
      if (currentConnection.isConnected || currentConnection.isConnecting) {
        return;
      }
      debugPrint(
        "Auto-reconnecting to last known device: $lastName ($lastAddress)",
      );
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
    bool force = false,
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

    // No ±127 clamp here: the native pump carries larger motion into the
    // following reports.
    if (intDx != 0 || intDy != 0 || intWheel != 0) {
      _sendMouse('move', [intDx, intDy, intWheel]);
    }
    if (force || buttons != _lastButtonsState) {
      _lastButtonsState = buttons;
      _sendMouse('buttons', [buttons, force]);
    }
  }

  /// Fire-and-forget: the native side paces mouse reports on its own thread,
  /// so a touch event never waits for a reply.
  void _sendMouse(String method, List<Object> args) {
    _mouseChannel.invokeMethod<void>(method, args).catchError((Object e) {
      if (e is! MissingPluginException) {
        debugPrint("Error dispatching HID mouse event: $e");
      }
    });
  }

  Future<bool> _sendKeyboardReport() {
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

    return _sendKeyboardBytes(bytes);
  }

  Future<bool> _sendKeyboardBytes(List<int> bytes) async {
    try {
      await _channel.invokeMethod('sendKeyboardReport', {'bytes': bytes});
      return true;
    } on PlatformException catch (e) {
      debugPrint("Error sending HID keyboard report: ${e.message}");
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _enqueueKeyboardOperation(Future<void> Function() operation) {
    if (!_keyboardInputFocused) return Future.value();
    final generation = _keyboardQueueGeneration;
    _keystrokeQueue = _keystrokeQueue.then((_) async {
      if (!mounted || generation != _keyboardQueueGeneration) return;
      try {
        await operation();
      } catch (e) {
        debugPrint("Error processing keyboard input: $e");
      }
    });
    return _keystrokeQueue;
  }

  void _discardKeyboardInput() {
    _keyboardQueueGeneration++;
    _activeScancodes.clear();
    _modifiersBitmask = 0;
  }

  void _interruptKeyboardInput() {
    final shouldRelease =
        _typingText || _activeScancodes.isNotEmpty || _modifiersBitmask != 0;
    _discardKeyboardInput();
    if (shouldRelease) unawaited(_sendKeyboardReport());
  }

  /// Tells the native side whether to capture controller input, and refreshes
  /// the list of physical controllers when turning it on.
  Future<void> _syncGamepadModeToNative(bool enabled) async {
    try {
      await _channel.invokeMethod('setGamepadMode', {'enabled': enabled});
      if (!enabled) {
        ref
            .read(gamepadLiveStateProvider.notifier)
            .update(GamepadSnapshot.neutral);
        return;
      }
      final names =
          await _channel.invokeListMethod<String>('getGamepadControllers') ??
          const <String>[];
      if (!mounted) return;
      ref.read(gamepadControllersProvider.notifier).update(names);
    } catch (e) {
      debugPrint("Error updating gamepad mode: $e");
    }
  }

  Future<void> _syncGamepadReportRateToNative(int hz) async {
    try {
      await _channel.invokeMethod('setGamepadReportRate', {'hz': hz});
    } catch (e) {
      debugPrint("Error setting gamepad report rate: $e");
    }
  }

  void _onGamepadModeChanged(bool enabled) {
    if (enabled) {
      // The gamepad screen replaces the trackpad and keyboard: release
      // anything they might still be holding on the host.
      _resetHidState();
      setState(() {
        _keyboardMode = false;
        _keyboardDidOpen = false;
      });
      _builtInKeyboardFocusNode.unfocus();
    }
    _syncGamepadModeToNative(enabled);
  }

  void _resetHidState() {
    _discardKeyboardInput();
    setState(() {
      _lastButtonsState = 0;
      _leftActive = false;
      _rightActive = false;
      _fnActive = false;
    });
    _enqueueKeyboardOperation(() async {
      await _sendKeyboardReport();
    });
    // Forced: _lastButtonsState was just zeroed above, so an unforced send
    // would be skipped and a held mouse button would stay stuck on the host.
    _sendReport(buttons: 0, dx: 0, dy: 0, force: true);
  }

  Future<void> _tapClick() async {
    await _sendReport(buttons: 0x01, dx: 0, dy: 0, wheel: 0);
    await Future.delayed(const Duration(milliseconds: 15));
    await _sendReport(buttons: 0x00, dx: 0, dy: 0, wheel: 0);
  }

  Future<void> _handleKeyTap(KeyInfo key) =>
      _enqueueKeyboardOperation(() async {
        if (key.scancode == -1) {
          setState(() {
            _fnActive = !_fnActive;
          });
          return;
        }

        if (key.isModifier) {
          await _toggleModifier(key.modifierMask);
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
          await _typeKeyStroke(scancode);
        }
      });

  Future<void> _toggleModifier(int mask) async {
    setState(() => _modifiersBitmask ^= mask);
    await _sendKeyboardReport();
  }

  Future<void> _setHoldLock(bool enabled) async {
    setState(() {
      _holdLockActive = enabled;
      if (!enabled) _activeScancodes.clear();
    });
    if (!enabled) await _sendKeyboardReport();
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

  Future<void> _queueKeyStroke(int scancode, {bool shift = false}) =>
      _enqueueKeyboardOperation(() => _typeKeyStroke(scancode, shift: shift));

  Future<void> _typeKeyStroke(int scancode, {bool shift = false}) async {
    final generation = _keyboardQueueGeneration;
    final originalModifiers = _modifiersBitmask;
    final alreadyHeld = _activeScancodes.contains(scancode);
    setState(() {
      if (shift) _modifiersBitmask |= 0x02;
      _activeScancodes.add(scancode);
    });
    await _sendKeyboardReport();
    await Future.delayed(const Duration(milliseconds: 15));

    if (!mounted || generation != _keyboardQueueGeneration) return;
    setState(() {
      if (!alreadyHeld) _activeScancodes.remove(scancode);
      _modifiersBitmask = originalModifiers;
    });
    await _sendKeyboardReport();
    await Future.delayed(const Duration(milliseconds: 10));
  }

  // The keyboard has nothing to delete in an empty box, so pass backspace on.
  KeyEventResult _handleTypingBoxKey(FocusNode node, KeyEvent event) {
    if (!_typingBox ||
        _typingBoxController.text.isNotEmpty ||
        event is KeyUpEvent ||
        event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    _queueKeyStroke(0x2A);
    return KeyEventResult.handled;
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
          onChanged: (val) {
            if (val.length > 1) {
              String typed = val.substring(1);
              for (int i = 0; i < typed.length; i++) {
                String char = typed[i];
                if (KeyboardLayouts.charToScancode.containsKey(char)) {
                  _queueKeyStroke(
                    KeyboardLayouts.charToScancode[char]!,
                    shift: false,
                  );
                } else if (KeyboardLayouts.shiftCharToScancode.containsKey(
                  char,
                )) {
                  _queueKeyStroke(
                    KeyboardLayouts.shiftCharToScancode[char]!,
                    shift: true,
                  );
                }
              }
            } else if (val.isEmpty) {
              _queueKeyStroke(0x2A);
            }
            _builtInKeyboardController.text = " ";
            _builtInKeyboardController.selection =
                const TextSelection.collapsed(offset: 1);
          },
          onSubmitted: (_) {
            _queueKeyStroke(0x28);
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
            Text(
              "Unsupported Device",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: context.palette.ink,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "CouchMouse requires Android 9 (API Level 28) or higher for native Bluetooth HID Device Emulation.\n\nYour device's Android version does not support this profile.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: context.palette.ink.withValues(alpha: 0.54),
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
            Text(
              "Bluetooth Access Required",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: context.palette.ink,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "CouchMouse emulates a standard Bluetooth mouse and keyboard. To register this hardware profile, the app requires Bluetooth permission to advertise to hosts.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: context.palette.ink.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _checkPermissions(request: true),
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
              child: Text(
                "Open System Settings",
                style: TextStyle(
                  color: context.palette.ink.withValues(alpha: 0.6),
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot() {
    final connection = ref.watch(connectionStateProvider);
    Color dotColor = const Color(0xFF8E8E93);
    if (connection.isConnected) {
      dotColor = const Color(0xFF34C759);
    } else if (_isRegistered) {
      dotColor = const Color(0xFFFF9500);
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
    );
  }

  Widget _buildHoldLockButton({bool compact = false}) {
    return GestureDetector(
      onTap: () =>
          _enqueueKeyboardOperation(() => _setHoldLock(!_holdLockActive)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: _holdLockActive
              ? context.palette.ink
              : context.palette.surface,
          borderRadius: BorderRadius.circular(compact ? 6 : 8),
          border: Border.all(
            color: _holdLockActive
                ? context.palette.ink
                : context.palette.ink.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _holdLockActive ? Icons.lock : Icons.lock_open,
              size: compact ? 11 : 13,
              color: _holdLockActive
                  ? context.palette.paper
                  : context.palette.ink.withValues(alpha: 0.4),
            ),
            SizedBox(width: compact ? 4 : 6),
            Text(
              "HoldLock",
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: _holdLockActive
                    ? context.palette.paper
                    : context.palette.ink.withValues(alpha: 0.6),
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
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(compact ? 6 : 8),
          border: Border.all(
            color: context.palette.ink.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.refresh,
              size: compact ? 11 : 13,
              color: context.palette.ink.withValues(alpha: 0.4),
            ),
            SizedBox(width: compact ? 4 : 6),
            Text(
              "Reset",
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: context.palette.ink.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelTyping() {
    if (_typingText) {
      _cancelTypingRequested = true;
    }
  }

  Future<void> _pasteClipboard() async {
    if (_typingText || !_keyboardInputFocused) return;

    final generation = _keyboardQueueGeneration;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || _typingText || generation != _keyboardQueueGeneration) {
      return;
    }

    final rawText = data?.text;
    if (rawText == null || rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Clipboard is empty"),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await _typeText(
      KeyboardLayouts.typableText(rawText),
      _TextSource.clipboard,
    );
  }

  Future<void> _sendTypingBox() async {
    if (_typingText || !_keyboardInputFocused) return;
    final text = KeyboardLayouts.typableText(_typingBoxController.text);
    if (text.isEmpty) return;
    _setTypingBoxText(text);

    final typed = await _typeText(text, _TextSource.typingBox);
    if (typed == null || !mounted) return;
    final current = _typingBoxController.text;
    if (current.startsWith(text.substring(0, typed))) {
      _setTypingBoxText(current.substring(typed));
    }
  }

  void _setTypingBoxText(String text) {
    _typingBoxController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Types [text] as key presses and returns how many characters reached the
  /// host, or null if nothing was attempted.
  Future<int?> _typeText(String text, _TextSource source) async {
    final messenger = ScaffoldMessenger.of(context);

    final connection = ref.read(connectionStateProvider);
    if (!connection.isConnected) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("No Bluetooth host connected"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return null;
    }

    final chars = text.runes.map(String.fromCharCode).toList();
    final unsupported = <String>{};
    for (final char in chars) {
      if (!KeyboardLayouts.charToScancode.containsKey(char) &&
          !KeyboardLayouts.shiftCharToScancode.containsKey(char)) {
        unsupported.add(char);
      }
    }

    if (unsupported.isNotEmpty) {
      final sample = unsupported.map((c) => "'$c'").take(5).join(', ');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "Cannot ${source.noun.toLowerCase()}: contains characters that cannot be typed ($sample)",
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return null;
    }

    final generation = _keyboardQueueGeneration;
    setState(() {
      _typingText = true;
      _cancelTypingRequested = false;
    });

    final statusNotifier = ValueNotifier<String>(
      "${source.progress} 0/${chars.length}...",
    );

    messenger.clearSnackBars();
    final snackBarController = messenger.showSnackBar(
      SnackBar(
        content: ValueListenableBuilder<String>(
          valueListenable: statusNotifier,
          builder: (context, status, _) {
            return Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00E5FF),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            );
          },
        ),
        action: SnackBarAction(
          label: 'CANCEL',
          textColor: const Color(0xFF00E5FF),
          onPressed: _cancelTyping,
        ),
        behavior: SnackBarBehavior.floating,
        persist: true,
        dismissDirection: DismissDirection.none,
      ),
    );

    int typedCount = 0;
    bool reportFailed = false;
    await _enqueueKeyboardOperation(() async {
      bool sessionIsCurrent() =>
          mounted && generation == _keyboardQueueGeneration;
      if (_cancelTypingRequested) return;

      final releaseReport = List<int>.filled(8, 0);
      final restoreKeyboard =
          _modifiersBitmask != 0 || _activeScancodes.isNotEmpty;
      reportFailed =
          restoreKeyboard && !await _sendKeyboardBytes(releaseReport);

      for (final char in chars) {
        if (reportFailed || _cancelTypingRequested || !sessionIsCurrent()) {
          break;
        }

        final unshiftedScancode = KeyboardLayouts.charToScancode[char];
        final pressReport = List<int>.filled(8, 0)
          ..[0] = unshiftedScancode == null ? 0x02 : 0
          ..[2] =
              unshiftedScancode ?? KeyboardLayouts.shiftCharToScancode[char]!;
        if (!await _sendKeyboardBytes(pressReport)) {
          reportFailed = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 15));
        if (!sessionIsCurrent()) return;

        if (!await _sendKeyboardBytes(releaseReport)) {
          reportFailed = true;
          break;
        }
        typedCount++;
        statusNotifier.value =
            "${source.progress} $typedCount/${chars.length}...";
        await Future.delayed(const Duration(milliseconds: 10));
      }

      if (!sessionIsCurrent()) return;
      if (!reportFailed && restoreKeyboard) {
        reportFailed = !await _sendKeyboardReport();
      }
      if (reportFailed && sessionIsCurrent()) {
        _discardKeyboardInput();
        await _sendKeyboardBytes(releaseReport);
      }
    });

    unawaited(snackBarController.closed.then((_) => statusNotifier.dispose()));
    if (!messenger.mounted) return typedCount;
    messenger.clearSnackBars();
    if (!mounted) return typedCount;
    setState(() => _typingText = false);

    final String message;
    if (reportFailed) {
      message =
          "${source.noun} stopped after $typedCount/${chars.length} characters";
    } else if (typedCount < chars.length) {
      message =
          "${source.noun} cancelled ($typedCount/${chars.length} characters typed)";
    } else if (source == _TextSource.clipboard) {
      message = "Pasted $typedCount characters";
    } else {
      return typedCount;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    return typedCount;
  }

  Widget _buildPasteButton({bool compact = false}) {
    return GestureDetector(
      onTap: _typingText ? _cancelTyping : _pasteClipboard,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: _typingText
              ? const Color(0xFFD32F2F)
              : context.palette.surface,
          borderRadius: BorderRadius.circular(compact ? 6 : 8),
          border: Border.all(
            color: _typingText
                ? const Color(0xFFD32F2F)
                : context.palette.ink.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _typingText ? Icons.close : Icons.paste_rounded,
              size: compact ? 11 : 13,
              color: _typingText
                  ? Colors.white
                  : context.palette.ink.withValues(alpha: 0.4),
            ),
            SizedBox(width: compact ? 4 : 6),
            Text(
              _typingText ? "Cancel" : "Paste",
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: _typingText
                    ? Colors.white
                    : context.palette.ink.withValues(alpha: 0.6),
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
      decoration: BoxDecoration(
        color: context.palette.paper,
        border: Border(
          bottom: BorderSide(
            color: context.palette.ink.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildHoldLockButton(compact: false),
              const SizedBox(width: 8),
              _buildResetButton(compact: false),
              const SizedBox(width: 8),
              _buildPasteButton(compact: false),
            ],
          ),
          Text(
            _fnActive ? "FN LAYER: ACTIVE" : "STANDARD LAYER",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: _fnActive
                  ? context.palette.ink
                  : context.palette.ink.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardAccessoryBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: context.palette.paper,
        border: Border(
          top: BorderSide(color: context.palette.ink.withValues(alpha: 0.08)),
          bottom: BorderSide(
            color: context.palette.ink.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          _buildAccessoryButton(
            icon: Icons.keyboard_hide,
            onTap: _toggleKeyboardMode,
            color: Colors.white,
            backgroundColor: Colors.redAccent.withValues(alpha: 0.7),
            borderColor: Colors.transparent,
          ),
          _buildAccessoryDivider(),
          _buildAccessoryButton(
            icon: _typingText ? Icons.close : Icons.paste_rounded,
            onTap: _typingText ? _cancelTyping : _pasteClipboard,
            color: _typingText ? Colors.white : context.palette.ink,
            backgroundColor: _typingText
                ? const Color(0xFFD32F2F)
                : context.palette.surface,
            borderColor: context.palette.ink.withValues(alpha: 0.08),
          ),
          _buildAccessoryDivider(),
          _buildAccessoryKey("Esc", 0x29),
          _buildAccessoryKey("Tab", 0x2B),
          _buildAccessoryDivider(),
          _buildAccessoryModifier("Ctrl", 0x01, context.palette.ink),
          _buildAccessoryModifier("Shift", 0x02, context.palette.ink),
          _buildAccessoryModifier("Alt", 0x04, context.palette.ink),
          _buildAccessoryModifier("Win", 0x08, context.palette.ink),
          _buildAccessoryDivider(),
          _buildAccessoryKey("◀", 0x50),
          _buildAccessoryKey("▲", 0x52),
          _buildAccessoryKey("▼", 0x51),
          _buildAccessoryKey("▶", 0x4F),
          _buildAccessoryDivider(),
          if (_typingBox) _buildAccessoryKey("⌫", 0x2A),
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
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.palette.ink.withValues(alpha: 0.08),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: context.palette.ink,
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
        onTap: () => _enqueueKeyboardOperation(() => _toggleModifier(mask)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? context.palette.ink : context.palette.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? context.palette.ink
                  : context.palette.ink.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? context.palette.paper : context.palette.ink,
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
    Color? color,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: backgroundColor ?? context.palette.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor ?? context.palette.ink.withValues(alpha: 0.08),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color ?? context.palette.ink, size: 16),
        ),
      ),
    );
  }

  Widget _buildAccessoryDivider() {
    return Container(
      width: 1.5,
      height: 24,
      color: context.palette.ink.withValues(alpha: 0.08),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    );
  }

  Widget _buildTrackpad({
    required double height,
    required double borderOpacity,
    required CouchMouseSettings settings,
    required String? hostAddress,
  }) {
    return Trackpad(
      key: ValueKey(hostAddress),
      height: height,
      borderOpacity: borderOpacity,
      sensitivity: _sensitivity,
      mouseAcceleration: _mouseAcceleration,
      invertTwoFingerScroll: _invertTwoFingerScroll,
      scrollSensitivity: _scrollSensitivity,
      trackball:
          settings.trackball &&
          _keyboardInputFocused &&
          _isRegistered &&
          hostAddress != null,
      trackballFriction: settings.trackballFriction,
      onReport: ({required dx, required dy, required wheel}) {
        _sendReport(buttons: _lastButtonsState, dx: dx, dy: dy, wheel: wheel);
      },
      onTap: _tapClick,
    );
  }

  Widget _buildPortraitLayout(
    CouchMouseSettings settings,
    String? hostAddress,
  ) {
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
                          child: _buildTrackpad(
                            height: constraints.maxHeight,
                            borderOpacity: 0.1,
                            settings: settings,
                            hostAddress: hostAddress,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ScrollWheel(
                          height: constraints.maxHeight,
                          scrollSensitivity: _scrollSensitivity,
                          invertScroll: _invertTwoFingerScroll,
                          scrollMomentum: _scrollMomentum,
                          onScroll: (wheel) {
                            _sendReport(
                              buttons: _lastButtonsState,
                              dx: 0,
                              dy: 0,
                              wheel: wheel,
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (_builtInKeyboardActive || (_typingBox && _keyboardMode)) ...[
              const SizedBox(height: 16),
              _buildKeyboardAccessoryBar(),
              if (_typingBox)
                TypingBox(
                  controller: _typingBoxController,
                  focusNode: _builtInKeyboardFocusNode,
                  onSend: _sendTypingBox,
                ),
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
                onHorizontalDragStart: (details) {
                  _horizontalSwipeDragDistance = 0.0;
                },
                onHorizontalDragUpdate: (details) {
                  if (details.primaryDelta != null) {
                    _horizontalSwipeDragDistance += details.primaryDelta!;
                    if (_horizontalSwipeDragDistance > 30.0) {
                      _scaffoldKey.currentState?.openDrawer();
                      _horizontalSwipeDragDistance = 0.0;
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
        if (!_typingBox)
          Positioned(left: 0, top: 0, child: _buildHiddenTextField()),
      ],
    );
  }

  Widget _buildSplitLandscapeLayout(
    CouchMouseSettings settings,
    String? hostAddress,
  ) {
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
                        child: _buildTrackpad(
                          height: constraints.maxHeight,
                          borderOpacity: 0.08,
                          settings: settings,
                          hostAddress: hostAddress,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ScrollWheel(
                        height: constraints.maxHeight,
                        scrollSensitivity: _scrollSensitivity,
                        invertScroll: _invertTwoFingerScroll,
                        scrollMomentum: _scrollMomentum,
                        onScroll: (wheel) {
                          _sendReport(
                            buttons: _lastButtonsState,
                            dx: 0,
                            dy: 0,
                            wheel: wheel,
                          );
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
      color: context.palette.ink.withValues(alpha: 0.08),
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
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(
          bottom: BorderSide(
            color: context.palette.ink.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildStatusDot(),
              const SizedBox(width: 8),
              Text(
                "CouchMouse",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: context.palette.ink,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 12),
              _buildHoldLockButton(compact: true),
              const SizedBox(width: 6),
              _buildResetButton(compact: true),
              const SizedBox(width: 6),
              _buildPasteButton(compact: true),
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
                  color: _fnActive
                      ? context.palette.ink
                      : context.palette.ink.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _toggleKeyboardMode,
                icon: Icon(CupertinoIcons.keyboard, color: context.palette.ink),
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
            color: context.palette.paper,
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

  double _getEffectiveScrollSensitivity(double sliderValue) {
    final double t = (sliderValue - 1.0) / 4.0;
    return 0.05 + t * (3.0 - 0.05);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final hostAddress = ref.watch(
      connectionStateProvider.select(
        (state) => state.isConnected ? state.connectedDeviceAddress : null,
      ),
    );
    final gamepadMode = ref.watch(gamepadModeProvider);
    ref.listen<bool>(gamepadModeProvider, (previous, next) {
      if (previous != next) _onGamepadModeChanged(next);
    });
    ref.listen<int>(gamepadReportRateProvider, (previous, next) {
      if (previous != next) _syncGamepadReportRateToNative(next);
    });

    _sensitivity = settings.sensitivity;
    _mouseAcceleration = settings.mouseAcceleration;
    _trackpadOnLeft = settings.trackpadOnLeft;
    _keyboardKind = settings.keyboardKind;
    _invertTwoFingerScroll = settings.invertTwoFingerScroll;
    _scrollSensitivity = _getEffectiveScrollSensitivity(
      settings.scrollSensitivity,
    );
    _scrollMomentum = settings.scrollMomentum;
    _typingBox = settings.typingBox;

    if (!_isSupported) {
      return Scaffold(body: SafeArea(child: _buildUnsupportedView()));
    }

    if (!_permissionsGranted) {
      return Scaffold(body: SafeArea(child: _buildPermissionsView()));
    }

    if (!_walkthroughChecked && settings.tutorialStatus == 'none') {
      _walkthroughChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WalkthroughDialog.show(context, isFirstStart: true, ref: ref);
      });
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
        !gamepadMode && _keyboardMode && orientation == Orientation.landscape;

    return Scaffold(
      key: _scaffoldKey,
      appBar: showFullKeyboard
          ? null
          : AppBar(
              leading: Builder(
                builder: (context) => IconButton(
                  icon: Icon(CupertinoIcons.bars, color: context.palette.ink),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    gamepadMode
                        ? CupertinoIcons.game_controller
                        : orientation == Orientation.portrait
                        ? Icons.mouse_outlined
                        : CupertinoIcons.keyboard,
                    color: context.palette.ink,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "CouchMouse",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: context.palette.ink,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                if (gamepadMode)
                  const SizedBox.shrink()
                else if (orientation == Orientation.portrait)
                  IconButton(
                    icon: Icon(
                      _builtInKeyboardActive
                          ? CupertinoIcons.keyboard_chevron_compact_down
                          : CupertinoIcons.keyboard,
                      color: context.palette.ink,
                    ),
                    onPressed: _toggleKeyboardMode,
                    tooltip: "Built-in Keyboard",
                  )
                else if (orientation == Orientation.landscape)
                  IconButton(
                    icon: Icon(
                      CupertinoIcons.keyboard,
                      color: context.palette.ink.withValues(alpha: 0.54),
                    ),
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
              onExportSettings: () => _transferSettings(export: true),
              onImportSettings: () => _transferSettings(export: false),
              onHoldLockChanged: (val) =>
                  _enqueueKeyboardOperation(() => _setHoldLock(val)),
              onResetHidState: _resetHidState,
              onKeyboardKindChanged: (kind) {
                ref.read(settingsProvider.notifier).updateKeyboardKind(kind);
                _enqueueKeyboardOperation(() async {
                  setState(_activeScancodes.clear);
                  await _sendKeyboardReport();
                });
              },
            ),
      body: SafeArea(
        child: gamepadMode
            ? GamepadModeView(
                isRegistered: _isRegistered,
                onConnectionTap: _showBluetoothDevicesBottomSheet,
                onExit: () =>
                    ref.read(gamepadModeProvider.notifier).setEnabled(false),
              )
            : IgnorePointer(
                ignoring: _typingText,
                child: AnimatedOpacity(
                  opacity: _typingText ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: showFullKeyboard
                      ? _buildForcedLandscapeKeyboardLayout()
                      : (orientation == Orientation.portrait
                            ? _buildPortraitLayout(settings, hostAddress)
                            : _buildSplitLandscapeLayout(
                                settings,
                                hostAddress,
                              )),
                ),
              ),
      ),
    );
  }
}
