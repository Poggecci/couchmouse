import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'keyboard_layouts.dart' show KeyboardKind;

class CouchMouseSettings {
  final double sensitivity;
  final bool mouseAcceleration;
  final bool trackpadOnLeft;
  final KeyboardKind keyboardKind;
  final bool invertTwoFingerScroll;
  final double scrollSensitivity;
  final double scrollMomentum;

  CouchMouseSettings({
    required this.sensitivity,
    required this.mouseAcceleration,
    required this.trackpadOnLeft,
    required this.keyboardKind,
    required this.invertTwoFingerScroll,
    required this.scrollSensitivity,
    required this.scrollMomentum,
  });

  CouchMouseSettings copyWith({
    double? sensitivity,
    bool? mouseAcceleration,
    bool? trackpadOnLeft,
    KeyboardKind? keyboardKind,
    bool? invertTwoFingerScroll,
    double? scrollSensitivity,
    double? scrollMomentum,
  }) {
    return CouchMouseSettings(
      sensitivity: sensitivity ?? this.sensitivity,
      mouseAcceleration: mouseAcceleration ?? this.mouseAcceleration,
      trackpadOnLeft: trackpadOnLeft ?? this.trackpadOnLeft,
      keyboardKind: keyboardKind ?? this.keyboardKind,
      invertTwoFingerScroll:
          invertTwoFingerScroll ?? this.invertTwoFingerScroll,
      scrollSensitivity: scrollSensitivity ?? this.scrollSensitivity,
      scrollMomentum: scrollMomentum ?? this.scrollMomentum,
    );
  }
}

class DeviceConnectionState {
  final bool isConnected;
  final String? connectedDeviceName;
  final String? connectedDeviceAddress;
  final bool isConnecting;
  final String? connectingAddress;

  DeviceConnectionState({
    required this.isConnected,
    this.connectedDeviceName,
    this.connectedDeviceAddress,
    this.isConnecting = false,
    this.connectingAddress,
  });

  DeviceConnectionState copyWith({
    bool? isConnected,
    String? connectedDeviceName,
    String? connectedDeviceAddress,
    bool? isConnecting,
    String? connectingAddress,
  }) {
    return DeviceConnectionState(
      isConnected: isConnected ?? this.isConnected,
      connectedDeviceName: connectedDeviceName ?? this.connectedDeviceName,
      connectedDeviceAddress:
          connectedDeviceAddress ?? this.connectedDeviceAddress,
      isConnecting: isConnecting ?? this.isConnecting,
      connectingAddress: connectingAddress ?? this.connectingAddress,
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    "sharedPreferencesProvider must be overridden in ProviderScope",
  );
});

class ConnectionStateNotifier extends Notifier<DeviceConnectionState> {
  @override
  DeviceConnectionState build() {
    return DeviceConnectionState(isConnected: false);
  }

  Future<void> updateConnectionState({
    required bool isConnected,
    String? connectedDeviceName,
    String? connectedDeviceAddress,
  }) async {
    state = state.copyWith(
      isConnected: isConnected,
      connectedDeviceName: connectedDeviceName,
      connectedDeviceAddress: connectedDeviceAddress,
      isConnecting: false,
      connectingAddress: null,
    );
    if (isConnected &&
        connectedDeviceAddress != null &&
        connectedDeviceName != null) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(
        'last_connected_device_address',
        connectedDeviceAddress,
      );
      await prefs.setString('last_connected_device_name', connectedDeviceName);

      final history = List<String>.from(
        prefs.getStringList('connected_device_addresses_history') ?? [],
      );
      history.remove(connectedDeviceAddress);
      history.insert(0, connectedDeviceAddress);
      await prefs.setStringList('connected_device_addresses_history', history);
    }
  }

  void updateConnectingState({
    required bool isConnecting,
    String? connectingAddress,
  }) {
    state = state.copyWith(
      isConnecting: isConnecting,
      connectingAddress: connectingAddress,
    );
  }
}

final connectionStateProvider =
    NotifierProvider<ConnectionStateNotifier, DeviceConnectionState>(
      ConnectionStateNotifier.new,
    );

class SettingsNotifier extends Notifier<CouchMouseSettings> {
  static const String _keyGlobalSensitivity = 'global_sensitivity';
  static const String _keyGlobalMouseAcceleration = 'global_mouse_acceleration';
  static const String _keyGlobalTrackpadOnLeft = 'global_trackpad_on_left';
  static const String _keyGlobalKeyboardKind = 'global_keyboard_kind';
  static const String _keyGlobalInvertTwoFingerScroll =
      'global_invert_two_finger_scroll';
  static const String _keyGlobalScrollSensitivity = 'global_scroll_sensitivity';
  static const String _keyGlobalScrollMomentum = 'global_scroll_momentum';

  String _deviceKey(String address, String key) => 'device_${address}_$key';

  @override
  CouchMouseSettings build() {
    final connection = ref.watch(connectionStateProvider);
    final prefs = ref.watch(sharedPreferencesProvider);

    if (connection.isConnected && connection.connectedDeviceAddress != null) {
      final address = connection.connectedDeviceAddress!;
      final hasDeviceSettings = prefs.containsKey(
        _deviceKey(address, 'sensitivity'),
      );
      if (hasDeviceSettings) {
        return CouchMouseSettings(
          sensitivity:
              prefs.getDouble(_deviceKey(address, 'sensitivity')) ?? 5.0,
          mouseAcceleration:
              prefs.getBool(_deviceKey(address, 'mouse_acceleration')) ?? false,
          trackpadOnLeft:
              prefs.getBool(_deviceKey(address, 'trackpad_on_left')) ?? false,
          keyboardKind:
              KeyboardKind.values[prefs.getInt(
                    _deviceKey(address, 'keyboard_kind'),
                  ) ??
                  KeyboardKind.seventyFive.index],
          invertTwoFingerScroll:
              prefs.getBool(_deviceKey(address, 'invert_two_finger_scroll')) ??
              false,
          scrollSensitivity:
              prefs.getDouble(_deviceKey(address, 'scroll_sensitivity')) ?? 2.0,
          scrollMomentum:
              prefs.getDouble(_deviceKey(address, 'scroll_momentum')) ?? 0.05,
        );
      }
    }

    return CouchMouseSettings(
      sensitivity: prefs.getDouble(_keyGlobalSensitivity) ?? 5.0,
      mouseAcceleration: prefs.getBool(_keyGlobalMouseAcceleration) ?? false,
      trackpadOnLeft: prefs.getBool(_keyGlobalTrackpadOnLeft) ?? false,
      keyboardKind:
          KeyboardKind.values[prefs.getInt(_keyGlobalKeyboardKind) ??
              KeyboardKind.seventyFive.index],
      invertTwoFingerScroll:
          prefs.getBool(_keyGlobalInvertTwoFingerScroll) ?? false,
      scrollSensitivity: prefs.getDouble(_keyGlobalScrollSensitivity) ?? 2.0,
      scrollMomentum: prefs.getDouble(_keyGlobalScrollMomentum) ?? 0.05,
    );
  }

  Future<void> updateSensitivity(double value) async {
    state = state.copyWith(sensitivity: value);
    await _saveCurrentState();
  }

  Future<void> updateMouseAcceleration(bool value) async {
    state = state.copyWith(mouseAcceleration: value);
    await _saveCurrentState();
  }

  Future<void> updateTrackpadOnLeft(bool value) async {
    state = state.copyWith(trackpadOnLeft: value);
    await _saveCurrentState();
  }

  Future<void> updateKeyboardKind(KeyboardKind value) async {
    state = state.copyWith(keyboardKind: value);
    await _saveCurrentState();
  }

  Future<void> updateInvertTwoFingerScroll(bool value) async {
    state = state.copyWith(invertTwoFingerScroll: value);
    await _saveCurrentState();
  }

  Future<void> updateScrollSensitivity(double value) async {
    final rounded = (value * 10).roundToDouble() / 10.0;
    state = state.copyWith(scrollSensitivity: rounded);
    await _saveCurrentState();
  }

  Future<void> updateScrollMomentum(double value) async {
    state = state.copyWith(scrollMomentum: value);
    await _saveCurrentState();
  }

  Future<void> _saveCurrentState() async {
    final connection = ref.read(connectionStateProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    if (connection.isConnected && connection.connectedDeviceAddress != null) {
      final address = connection.connectedDeviceAddress!;
      await prefs.setDouble(
        _deviceKey(address, 'sensitivity'),
        state.sensitivity,
      );
      await prefs.setBool(
        _deviceKey(address, 'mouse_acceleration'),
        state.mouseAcceleration,
      );
      await prefs.setBool(
        _deviceKey(address, 'trackpad_on_left'),
        state.trackpadOnLeft,
      );
      await prefs.setInt(
        _deviceKey(address, 'keyboard_kind'),
        state.keyboardKind.index,
      );
      await prefs.setBool(
        _deviceKey(address, 'invert_two_finger_scroll'),
        state.invertTwoFingerScroll,
      );
      await prefs.setDouble(
        _deviceKey(address, 'scroll_sensitivity'),
        state.scrollSensitivity,
      );
      await prefs.setDouble(
        _deviceKey(address, 'scroll_momentum'),
        state.scrollMomentum,
      );
    } else {
      await prefs.setDouble(_keyGlobalSensitivity, state.sensitivity);
      await prefs.setBool(_keyGlobalMouseAcceleration, state.mouseAcceleration);
      await prefs.setBool(_keyGlobalTrackpadOnLeft, state.trackpadOnLeft);
      await prefs.setInt(_keyGlobalKeyboardKind, state.keyboardKind.index);
      await prefs.setBool(
        _keyGlobalInvertTwoFingerScroll,
        state.invertTwoFingerScroll,
      );
      await prefs.setDouble(
        _keyGlobalScrollSensitivity,
        state.scrollSensitivity,
      );
      await prefs.setDouble(
        _keyGlobalScrollMomentum,
        state.scrollMomentum,
      );
    }
  }

  Future<void> resetSettings() async {
    final connection = ref.read(connectionStateProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    if (connection.isConnected && connection.connectedDeviceAddress != null) {
      final address = connection.connectedDeviceAddress!;
      await prefs.remove(_deviceKey(address, 'sensitivity'));
      await prefs.remove(_deviceKey(address, 'mouse_acceleration'));
      await prefs.remove(_deviceKey(address, 'trackpad_on_left'));
      await prefs.remove(_deviceKey(address, 'keyboard_kind'));
      await prefs.remove(_deviceKey(address, 'invert_two_finger_scroll'));
      await prefs.remove(_deviceKey(address, 'scroll_sensitivity'));
      await prefs.remove(_deviceKey(address, 'scroll_momentum'));
    } else {
      await prefs.remove(_keyGlobalSensitivity);
      await prefs.remove(_keyGlobalMouseAcceleration);
      await prefs.remove(_keyGlobalTrackpadOnLeft);
      await prefs.remove(_keyGlobalKeyboardKind);
      await prefs.remove(_keyGlobalInvertTwoFingerScroll);
      await prefs.remove(_keyGlobalScrollSensitivity);
      await prefs.remove(_keyGlobalScrollMomentum);
    }

    ref.invalidateSelf();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, CouchMouseSettings>(
  SettingsNotifier.new,
);

final pairedDevicesProvider =
    FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
      final prefs = ref.watch(sharedPreferencesProvider);
      const channel = MethodChannel('com.example.couchmouse/hid');
      final List<dynamic>? devices = await channel.invokeMethod(
        'getPairedDevices',
      );
      if (devices == null) return [];

      final history =
          prefs.getStringList('connected_device_addresses_history') ?? [];

      final mappedDevices = devices.map((d) {
        final map = d as Map;
        return {
          'name': (map['name'] ?? 'Unknown Device').toString(),
          'address': (map['address'] ?? '').toString(),
        };
      }).toList();

      mappedDevices.sort((a, b) {
        final addrA = a['address'] ?? '';
        final addrB = b['address'] ?? '';
        final idxA = history.indexOf(addrA);
        final idxB = history.indexOf(addrB);

        if (idxA != -1 && idxB != -1) {
          return idxA.compareTo(idxB);
        } else if (idxA != -1) {
          return -1;
        } else if (idxB != -1) {
          return 1;
        } else {
          return 0;
        }
      });

      return mappedDevices;
    });

class DiscoverableState {
  final bool isDiscoverable;
  final int remainingSeconds;
  final DateTime? expirationTime;

  DiscoverableState({
    required this.isDiscoverable,
    this.remainingSeconds = 0,
    this.expirationTime,
  });

  DiscoverableState copyWith({
    bool? isDiscoverable,
    int? remainingSeconds,
    DateTime? expirationTime,
  }) {
    return DiscoverableState(
      isDiscoverable: isDiscoverable ?? this.isDiscoverable,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      expirationTime: expirationTime ?? this.expirationTime,
    );
  }
}

class DiscoverableNotifier extends Notifier<DiscoverableState> {
  Timer? _timer;

  @override
  DiscoverableState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return DiscoverableState(isDiscoverable: false);
  }

  void setDiscoverable(bool isDiscoverable, {int durationSeconds = 120}) {
    _timer?.cancel();
    if (isDiscoverable) {
      final now = DateTime.now();
      final currentExpiration = state.expirationTime;

      DateTime expiration;
      if (currentExpiration != null &&
          currentExpiration.isAfter(now) &&
          state.isDiscoverable) {
        expiration = currentExpiration;
      } else {
        expiration = now.add(Duration(seconds: durationSeconds));
      }

      final remaining = expiration.difference(now).inSeconds;
      state = DiscoverableState(
        isDiscoverable: true,
        remainingSeconds: remaining,
        expirationTime: expiration,
      );

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final currentNow = DateTime.now();
        if (expiration.isAfter(currentNow)) {
          state = state.copyWith(
            remainingSeconds: expiration.difference(currentNow).inSeconds,
          );
        } else {
          _timer?.cancel();
          state = DiscoverableState(
            isDiscoverable: false,
            remainingSeconds: 0,
            expirationTime: null,
          );
        }
      });
    } else {
      state = DiscoverableState(
        isDiscoverable: false,
        remainingSeconds: 0,
        expirationTime: null,
      );
    }
  }
}

final discoverableProvider =
    NotifierProvider<DiscoverableNotifier, DiscoverableState>(
      DiscoverableNotifier.new,
    );
