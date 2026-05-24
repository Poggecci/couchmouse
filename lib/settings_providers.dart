import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart' show KeyboardKind;

class CouchMouseSettings {
  final double sensitivity;
  final bool mouseAcceleration;
  final bool trackpadOnLeft;
  final KeyboardKind keyboardKind;

  CouchMouseSettings({
    required this.sensitivity,
    required this.mouseAcceleration,
    required this.trackpadOnLeft,
    required this.keyboardKind,
  });

  CouchMouseSettings copyWith({
    double? sensitivity,
    bool? mouseAcceleration,
    bool? trackpadOnLeft,
    KeyboardKind? keyboardKind,
  }) {
    return CouchMouseSettings(
      sensitivity: sensitivity ?? this.sensitivity,
      mouseAcceleration: mouseAcceleration ?? this.mouseAcceleration,
      trackpadOnLeft: trackpadOnLeft ?? this.trackpadOnLeft,
      keyboardKind: keyboardKind ?? this.keyboardKind,
    );
  }

  factory CouchMouseSettings.defaultSettings() {
    return CouchMouseSettings(
      sensitivity: 10.0,
      mouseAcceleration: false,
      trackpadOnLeft: false,
      keyboardKind: KeyboardKind.seventyFive,
    );
  }
}

class DeviceConnectionState {
  final bool isConnected;
  final String? connectedDeviceName;
  final String? connectedDeviceAddress;

  DeviceConnectionState({
    required this.isConnected,
    this.connectedDeviceName,
    this.connectedDeviceAddress,
  });

  DeviceConnectionState copyWith({
    bool? isConnected,
    String? connectedDeviceName,
    String? connectedDeviceAddress,
  }) {
    return DeviceConnectionState(
      isConnected: isConnected ?? this.isConnected,
      connectedDeviceName: connectedDeviceName ?? this.connectedDeviceName,
      connectedDeviceAddress: connectedDeviceAddress ?? this.connectedDeviceAddress,
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError("sharedPreferencesProvider must be overridden in ProviderScope");
});

class ConnectionStateNotifier extends Notifier<DeviceConnectionState> {
  @override
  DeviceConnectionState build() {
    return DeviceConnectionState(isConnected: false);
  }

  void updateConnectionState({
    required bool isConnected,
    String? connectedDeviceName,
    String? connectedDeviceAddress,
  }) {
    state = DeviceConnectionState(
      isConnected: isConnected,
      connectedDeviceName: connectedDeviceName,
      connectedDeviceAddress: connectedDeviceAddress,
    );
  }
}

final connectionStateProvider = NotifierProvider<ConnectionStateNotifier, DeviceConnectionState>(
  ConnectionStateNotifier.new,
);

class SettingsNotifier extends Notifier<CouchMouseSettings> {
  static const String _keyGlobalSensitivity = 'global_sensitivity';
  static const String _keyGlobalMouseAcceleration = 'global_mouse_acceleration';
  static const String _keyGlobalTrackpadOnLeft = 'global_trackpad_on_left';
  static const String _keyGlobalKeyboardKind = 'global_keyboard_kind';

  String _deviceKey(String address, String key) => 'device_${address}_$key';

  @override
  CouchMouseSettings build() {
    final connection = ref.watch(connectionStateProvider);
    final prefs = ref.watch(sharedPreferencesProvider);

    if (connection.isConnected && connection.connectedDeviceAddress != null) {
      final address = connection.connectedDeviceAddress!;
      final hasDeviceSettings = prefs.containsKey(_deviceKey(address, 'sensitivity'));
      if (hasDeviceSettings) {
        return CouchMouseSettings(
          sensitivity: prefs.getDouble(_deviceKey(address, 'sensitivity')) ?? 10.0,
          mouseAcceleration: prefs.getBool(_deviceKey(address, 'mouse_acceleration')) ?? false,
          trackpadOnLeft: prefs.getBool(_deviceKey(address, 'trackpad_on_left')) ?? false,
          keyboardKind: KeyboardKind.values[prefs.getInt(_deviceKey(address, 'keyboard_kind')) ?? KeyboardKind.seventyFive.index],
        );
      }
    }

    return CouchMouseSettings(
      sensitivity: prefs.getDouble(_keyGlobalSensitivity) ?? 10.0,
      mouseAcceleration: prefs.getBool(_keyGlobalMouseAcceleration) ?? false,
      trackpadOnLeft: prefs.getBool(_keyGlobalTrackpadOnLeft) ?? false,
      keyboardKind: KeyboardKind.values[prefs.getInt(_keyGlobalKeyboardKind) ?? KeyboardKind.seventyFive.index],
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

  Future<void> _saveCurrentState() async {
    final connection = ref.read(connectionStateProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    if (connection.isConnected && connection.connectedDeviceAddress != null) {
      final address = connection.connectedDeviceAddress!;
      await prefs.setDouble(_deviceKey(address, 'sensitivity'), state.sensitivity);
      await prefs.setBool(_deviceKey(address, 'mouse_acceleration'), state.mouseAcceleration);
      await prefs.setBool(_deviceKey(address, 'trackpad_on_left'), state.trackpadOnLeft);
      await prefs.setInt(_deviceKey(address, 'keyboard_kind'), state.keyboardKind.index);
    } else {
      await prefs.setDouble(_keyGlobalSensitivity, state.sensitivity);
      await prefs.setBool(_keyGlobalMouseAcceleration, state.mouseAcceleration);
      await prefs.setBool(_keyGlobalTrackpadOnLeft, state.trackpadOnLeft);
      await prefs.setInt(_keyGlobalKeyboardKind, state.keyboardKind.index);
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
    } else {
      await prefs.remove(_keyGlobalSensitivity);
      await prefs.remove(_keyGlobalMouseAcceleration);
      await prefs.remove(_keyGlobalTrackpadOnLeft);
      await prefs.remove(_keyGlobalKeyboardKind);
    }

    ref.invalidateSelf();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, CouchMouseSettings>(SettingsNotifier.new);
