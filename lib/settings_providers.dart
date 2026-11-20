import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'generated/couchmouse_settings.pb.dart';
import 'keyboard_layouts.dart' show KeyboardKind;
import 'settings_store.dart';

class CouchMouseSettings {
  final double sensitivity;
  final bool mouseAcceleration;
  final bool trackpadOnLeft;
  final KeyboardKind keyboardKind;
  final bool invertTwoFingerScroll;
  final double scrollSensitivity;
  final double scrollMomentum;
  final bool trackball;
  final double trackballFriction;
  final bool typingBox;
  final String tutorialStatus;
  final bool gamepadMode;
  final int gamepadReportRate;
  final bool darkMode;

  CouchMouseSettings({
    required this.sensitivity,
    required this.mouseAcceleration,
    required this.trackpadOnLeft,
    required this.keyboardKind,
    required this.invertTwoFingerScroll,
    required this.scrollSensitivity,
    required this.scrollMomentum,
    required this.trackball,
    required this.trackballFriction,
    required this.typingBox,
    required this.tutorialStatus,
    required this.gamepadMode,
    required this.gamepadReportRate,
    required this.darkMode,
  });

  CouchMouseSettings copyWith({
    double? sensitivity,
    bool? mouseAcceleration,
    bool? trackpadOnLeft,
    KeyboardKind? keyboardKind,
    bool? invertTwoFingerScroll,
    double? scrollSensitivity,
    double? scrollMomentum,
    bool? trackball,
    double? trackballFriction,
    bool? typingBox,
    String? tutorialStatus,
    bool? gamepadMode,
    int? gamepadReportRate,
    bool? darkMode,
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
      trackball: trackball ?? this.trackball,
      trackballFriction: trackballFriction ?? this.trackballFriction,
      typingBox: typingBox ?? this.typingBox,
      tutorialStatus: tutorialStatus ?? this.tutorialStatus,
      gamepadMode: gamepadMode ?? this.gamepadMode,
      gamepadReportRate: gamepadReportRate ?? this.gamepadReportRate,
      darkMode: darkMode ?? this.darkMode,
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

final settingsStoreProvider = Provider<SettingsStore>((ref) {
  throw UnimplementedError('settingsStoreProvider must be overridden');
});

class SettingsNotifier extends Notifier<CouchMouseSettings> {
  static const gamepadReportRates = [30, 60, 90, 125];
  static const _defaultGamepadReportRate = 125;
  static const _tutorialStatuses = ['none', 'completed', 'dismissed'];
  static const _keyboardLayouts = [
    KeyboardKind.fullSize,
    KeyboardKind.compactFullSize,
    KeyboardKind.tenkeyless,
    KeyboardKind.seventyFive,
    KeyboardKind.sixtyFive,
    KeyboardKind.sixtyPercent,
  ];

  int _writeRevision = 0;

  @override
  CouchMouseSettings build() {
    final connection = ref.watch(connectionStateProvider);
    final store = ref.watch(settingsStoreProvider);
    return _settingsFor(store.snapshot, _addressFor(connection));
  }

  String? _addressFor(DeviceConnectionState connection) =>
      connection.isConnected
      ? connection.connectedDeviceAddress?.toUpperCase()
      : null;

  DeviceProfile? _deviceFor(PortableSettings stored, String? address) => stored
      .deviceProfiles
      .where((device) => device.bluetoothAddress == address)
      .firstOrNull;

  bool _hasKnownSettings(InputProfile profile) =>
      profile.info_.fieldInfo.keys.any(profile.hasField);

  double _inRange(double value, double min, double max, double fallback) =>
      value >= min && value <= max ? value : fallback;

  CouchMouseSettings _settingsFor(PortableSettings stored, String? address) {
    final device = _deviceFor(stored, address);
    final deviceInputs = device?.inputProfile;
    final profile = deviceInputs != null && _hasKnownSettings(deviceInputs)
        ? deviceInputs
        : stored.globalProfile;
    final keyboardId = profile.keyboardLayoutId;
    final tutorialId = stored.tutorialStatusId;
    final reportRate = stored.gamepadReportRateHz;

    return CouchMouseSettings(
      sensitivity: profile.hasSensitivity()
          ? _inRange(profile.sensitivity, 0, 8000, 800)
          : 800,
      mouseAcceleration: profile.mouseAcceleration,
      trackpadOnLeft: profile.trackpadOnLeft,
      keyboardKind:
          profile.hasKeyboardLayoutId() &&
              keyboardId >= 0 &&
              keyboardId < _keyboardLayouts.length
          ? _keyboardLayouts[keyboardId]
          : KeyboardKind.seventyFive,
      invertTwoFingerScroll: profile.invertTwoFingerScroll,
      scrollSensitivity: _inRange(profile.scrollSensitivity, 1, 5, 2),
      scrollMomentum: profile.hasScrollMomentum()
          ? _inRange(profile.scrollMomentum, 0, 1, 0.05)
          : 0.05,
      trackball: profile.trackballEnabled,
      trackballFriction: profile.hasTrackballFriction()
          ? _inRange(profile.trackballFriction, 0, 1, 0.7)
          : 0.7,
      typingBox: profile.typingBox,
      tutorialStatus: tutorialId >= 0 && tutorialId < _tutorialStatuses.length
          ? _tutorialStatuses[tutorialId]
          : _tutorialStatuses.first,
      gamepadMode: stored.gamepadMode,
      gamepadReportRate: gamepadReportRates.contains(reportRate)
          ? reportRate
          : _defaultGamepadReportRate,
      darkMode: stored.darkMode,
    );
  }

  Future<void> _refreshAfter(
    SettingsStore store,
    Future<void> Function() write,
  ) async {
    final revision = ++_writeRevision;
    try {
      await write();
    } finally {
      if (ref.mounted && revision == _writeRevision) {
        final connection = ref.read(connectionStateProvider);
        state = _settingsFor(store.snapshot, _addressFor(connection));
      }
    }
  }

  Future<void> _writeSettings(void Function(PortableSettings) edit) {
    final store = ref.read(settingsStoreProvider);
    return _refreshAfter(store, () => store.edit(edit));
  }

  Future<Uint8List> exportSettings() =>
      ref.read(settingsStoreProvider).exportBackup();

  Future<void> importSettings(Uint8List backup) {
    final store = ref.read(settingsStoreProvider);
    return _refreshAfter(store, () => store.importBackup(backup));
  }

  Future<void> _saveInput(void Function(InputProfile) edit) {
    final address = _addressFor(ref.read(connectionStateProvider));
    return _writeSettings((stored) {
      if (address == null) {
        edit(stored.ensureGlobalProfile());
        return;
      }

      var device = _deviceFor(stored, address);
      if (device == null) {
        device = DeviceProfile(bluetoothAddress: address);
        stored.deviceProfiles.add(device);
      }
      final profile = device.ensureInputProfile();
      if (!_hasKnownSettings(profile)) {
        // Start a device profile from the currently configured global settings.
        final global = stored.globalProfile.deepCopy();
        for (final tag in global.info_.fieldInfo.keys.where(global.hasField)) {
          profile.setField(tag, global.getField(tag) as Object);
        }
      }
      edit(profile);
    });
  }

  Future<void> updateSensitivity(double value) {
    state = state.copyWith(sensitivity: value);
    return _saveInput((profile) => profile.sensitivity = value);
  }

  Future<void> updateMouseAcceleration(bool value) {
    state = state.copyWith(mouseAcceleration: value);
    return _saveInput((profile) => profile.mouseAcceleration = value);
  }

  Future<void> updateTrackpadOnLeft(bool value) {
    state = state.copyWith(trackpadOnLeft: value);
    return _saveInput((profile) => profile.trackpadOnLeft = value);
  }

  Future<void> updateKeyboardKind(KeyboardKind value) {
    state = state.copyWith(keyboardKind: value);
    return _saveInput(
      (profile) => profile.keyboardLayoutId = _keyboardLayouts.indexOf(value),
    );
  }

  Future<void> updateInvertTwoFingerScroll(bool value) {
    state = state.copyWith(invertTwoFingerScroll: value);
    return _saveInput((profile) => profile.invertTwoFingerScroll = value);
  }

  Future<void> updateScrollSensitivity(double value) {
    final rounded = (value * 10).roundToDouble() / 10.0;
    state = state.copyWith(scrollSensitivity: rounded);
    return _saveInput((profile) => profile.scrollSensitivity = rounded);
  }

  Future<void> updateScrollMomentum(double value) {
    final rounded = (value * 10).roundToDouble() / 10.0;
    state = state.copyWith(scrollMomentum: rounded);
    return _saveInput((profile) => profile.scrollMomentum = rounded);
  }

  Future<void> updateTrackball(bool value) {
    state = state.copyWith(trackball: value);
    return _saveInput((profile) => profile.trackballEnabled = value);
  }

  Future<void> updateTrackballFriction(double value) {
    final rounded = (value * 10).roundToDouble() / 10.0;
    state = state.copyWith(trackballFriction: rounded);
    return _saveInput((profile) => profile.trackballFriction = rounded);
  }

  Future<void> updateTypingBox(bool value) {
    state = state.copyWith(typingBox: value);
    return _saveInput((profile) => profile.typingBox = value);
  }

  Future<void> updateTutorialStatus(String status) async {
    final id = _tutorialStatuses.indexOf(status);
    if (id < 0) return;
    state = state.copyWith(tutorialStatus: status);
    await _writeSettings((stored) => stored.tutorialStatusId = id);
  }

  Future<void> updateGamepadMode(bool enabled) {
    state = state.copyWith(gamepadMode: enabled);
    return _writeSettings((stored) => stored.gamepadMode = enabled);
  }

  Future<void> updateGamepadReportRate(int hz) async {
    if (!gamepadReportRates.contains(hz)) return;
    state = state.copyWith(gamepadReportRate: hz);
    await _writeSettings((stored) => stored.gamepadReportRateHz = hz);
  }

  Future<void> updateDarkMode(bool enabled) {
    state = state.copyWith(darkMode: enabled);
    return _writeSettings((stored) => stored.darkMode = enabled);
  }

  Future<void> resetSettings() {
    final address = _addressFor(ref.read(connectionStateProvider));
    return _writeSettings((stored) {
      if (address == null) {
        stored
          ..clearTutorialStatusId()
          ..clearGamepadMode()
          ..clearGamepadReportRateHz()
          ..clearDarkMode();
      }
      final device = _deviceFor(stored, address);
      final profile = address == null
          ? stored.globalProfile
          : device?.inputProfile;
      if (profile == null || !_hasKnownSettings(profile)) return;

      // An older app can reset the fields it knows while preserving newer ones.
      for (final tag in profile.info_.fieldInfo.keys) {
        profile.clearField(tag);
      }
      if (profile.unknownFields.isNotEmpty) return;
      if (address == null) {
        stored.clearGlobalProfile();
      } else if (device!.unknownFields.isEmpty) {
        stored.deviceProfiles.remove(device);
      } else {
        device.clearInputProfile();
      }
    });
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
