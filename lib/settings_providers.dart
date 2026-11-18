import 'dart:async';
import 'dart:convert';
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
  final bool trackball;
  final double trackballFriction;
  final bool typingBox;
  final String tutorialStatus;
  final bool gamepadMode;
  final int gamepadReportRate;

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
  static const gamepadReportRates = [30, 60, 90, 125];
  static const _defaultGamepadReportRate = 125;
  static const _gamepadModeKey = 'global_gamepad_mode';
  static const _gamepadRateKey = 'global_gamepad_report_rate_hz';
  static const _storageKey = 'portable_settings';
  static const _backupFormat = 'couchmouse-settings';
  static const _globalPrefix = 'global_';
  static const _tutorialKey = 'global_tutorial_status';
  static final _deviceKeyPattern = RegExp(
    r'^device_(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}_(.+)$',
  );

  Future<void> _pendingWrites = Future.value();
  int _writeRevision = 0;

  @override
  CouchMouseSettings build() {
    final connection = ref.watch(connectionStateProvider);
    final stored = _readSettings(ref.watch(sharedPreferencesProvider));
    final address = connection.isConnected
        ? connection.connectedDeviceAddress
        : null;
    return _settingsFor(stored, address);
  }

  CouchMouseSettings _settingsFor(Map<String, Object> stored, String? address) {
    final devicePrefix = _prefix(address);
    final prefix = stored.containsKey('${devicePrefix}sensitivity')
        ? devicePrefix
        : _globalPrefix;
    final values = _profileValues(stored, prefix);

    return CouchMouseSettings(
      sensitivity: values['sensitivity']! as double,
      mouseAcceleration: values['mouse_acceleration']! as bool,
      trackpadOnLeft: values['trackpad_on_left']! as bool,
      keyboardKind: KeyboardKind.values[values['keyboard_kind']! as int],
      invertTwoFingerScroll: values['invert_two_finger_scroll']! as bool,
      scrollSensitivity: values['scroll_sensitivity']! as double,
      scrollMomentum: values['scroll_momentum']! as double,
      trackball: values['trackball']! as bool,
      trackballFriction: values['trackball_friction']! as double,
      typingBox: values['typing_box']! as bool,
      tutorialStatus: stored[_tutorialKey] as String? ?? 'none',
      gamepadMode: stored[_gamepadModeKey] as bool? ?? false,
      gamepadReportRate:
          stored[_gamepadRateKey] as int? ?? _defaultGamepadReportRate,
    );
  }

  Map<String, Object> _profileValues(
    Map<String, Object> stored,
    String prefix,
  ) {
    var sensitivity =
        (stored['${prefix}sensitivity'] as num?)?.toDouble() ?? 800.0;
    if (sensitivity < 150.0) {
      sensitivity = (sensitivity * 160.0).clamp(200.0, 8000.0);
    }
    return {
      'sensitivity': sensitivity,
      'mouse_acceleration': stored['${prefix}mouse_acceleration'] ?? false,
      'trackpad_on_left': stored['${prefix}trackpad_on_left'] ?? false,
      'keyboard_kind':
          stored['${prefix}keyboard_kind'] ?? KeyboardKind.seventyFive.index,
      'invert_two_finger_scroll':
          stored['${prefix}invert_two_finger_scroll'] ?? false,
      'scroll_sensitivity':
          (stored['${prefix}scroll_sensitivity'] as num?)?.toDouble() ?? 2.0,
      'scroll_momentum':
          (stored['${prefix}scroll_momentum'] as num?)?.toDouble() ?? 0.05,
      'trackball': stored['${prefix}trackball'] ?? false,
      'trackball_friction':
          (stored['${prefix}trackball_friction'] as num?)?.toDouble() ?? 0.7,
      'typing_box': stored['${prefix}typing_box'] ?? false,
    };
  }

  String _prefix(String? address) =>
      address == null ? _globalPrefix : 'device_${address}_';

  String? get _connectedAddress {
    final connection = ref.read(connectionStateProvider);
    return connection.isConnected ? connection.connectedDeviceAddress : null;
  }

  bool _validSetting(String key, Object? value) {
    if (key == _tutorialKey) {
      return value == 'none' || value == 'completed' || value == 'dismissed';
    }
    if (key == _gamepadModeKey) return value is bool;
    if (key == _gamepadRateKey) {
      return value is int && gamepadReportRates.contains(value);
    }
    final name = key.startsWith(_globalPrefix)
        ? key.substring(_globalPrefix.length)
        : _deviceKeyPattern.firstMatch(key)?.group(1);
    return switch (name) {
      'sensitivity' => value is num && value >= 0 && value <= 8000,
      'scroll_sensitivity' => value is num && value >= 1 && value <= 5,
      'scroll_momentum' ||
      'trackball_friction' => value is num && value >= 0 && value <= 1,
      'keyboard_kind' =>
        value is int && value >= 0 && value < KeyboardKind.values.length,
      'mouse_acceleration' ||
      'trackpad_on_left' ||
      'invert_two_finger_scroll' ||
      'trackball' ||
      'typing_box' => value is bool,
      _ => false,
    };
  }

  Map<String, Object> _readSettings(SharedPreferences prefs) {
    final saved = prefs.getString(_storageKey);
    if (saved != null) {
      return Map<String, Object>.from(jsonDecode(saved) as Map);
    }

    // Older installations stored each setting separately.
    final legacy = <String, Object>{};
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      if (_validSetting(key, value)) legacy[key] = value!;
    }
    return legacy;
  }

  // Store one snapshot so a backup can be restored as a single preference write.
  Future<void> _writeSettings(void Function(Map<String, Object>) edit) {
    final prefs = ref.read(sharedPreferencesProvider);
    final revision = ++_writeRevision;
    final write = _pendingWrites.then((_) async {
      final stored = _readSettings(prefs);
      edit(stored);
      try {
        if (!await prefs.setString(_storageKey, jsonEncode(stored))) {
          throw StateError('Could not save settings');
        }
      } catch (_) {
        // SharedPreferences updates its cache before the platform write finishes.
        await prefs.reload();
        rethrow;
      } finally {
        if (ref.mounted && revision == _writeRevision) {
          state = _settingsFor(_readSettings(prefs), _connectedAddress);
        }
      }
    });
    _pendingWrites = write.then<void>((_) {}, onError: (Object _) {});
    return write;
  }

  Future<String> exportSettings() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await _pendingWrites;
    return const JsonEncoder.withIndent('  ').convert({
      'format': _backupFormat,
      'version': 1,
      'settings': _readSettings(prefs),
    });
  }

  Future<void> importSettings(String backup) async {
    final decoded = jsonDecode(backup);
    if (decoded is! Map ||
        decoded['format'] != _backupFormat ||
        decoded['version'] != 1 ||
        decoded['settings'] is! Map<String, dynamic>) {
      throw const FormatException('Choose a Couch Mouse settings backup.');
    }

    final imported = <String, Object>{};
    final settings = decoded['settings'] as Map<String, dynamic>;
    for (final entry in settings.entries) {
      if (!_validSetting(entry.key, entry.value)) {
        throw const FormatException('The backup contains invalid settings.');
      }
      imported[entry.key] = entry.value as Object;
    }

    await _writeSettings(
      (stored) => stored
        ..clear()
        ..addAll(imported),
    );
  }

  Future<void> _saveSetting(String name, Object value) {
    final address = _connectedAddress;
    final prefix = _prefix(address);
    return _writeSettings((stored) {
      if (address != null && !stored.containsKey('${prefix}sensitivity')) {
        final global = _profileValues(stored, _globalPrefix);
        stored.addAll(
          global.map((key, value) => MapEntry('$prefix$key', value)),
        );
      }
      stored['$prefix$name'] = value;
    });
  }

  Future<void> updateSensitivity(double value) {
    state = state.copyWith(sensitivity: value);
    return _saveSetting('sensitivity', value);
  }

  Future<void> updateMouseAcceleration(bool value) {
    state = state.copyWith(mouseAcceleration: value);
    return _saveSetting('mouse_acceleration', value);
  }

  Future<void> updateTrackpadOnLeft(bool value) {
    state = state.copyWith(trackpadOnLeft: value);
    return _saveSetting('trackpad_on_left', value);
  }

  Future<void> updateKeyboardKind(KeyboardKind value) {
    state = state.copyWith(keyboardKind: value);
    return _saveSetting('keyboard_kind', value.index);
  }

  Future<void> updateInvertTwoFingerScroll(bool value) {
    state = state.copyWith(invertTwoFingerScroll: value);
    return _saveSetting('invert_two_finger_scroll', value);
  }

  Future<void> updateScrollSensitivity(double value) {
    final rounded = (value * 10).roundToDouble() / 10.0;
    state = state.copyWith(scrollSensitivity: rounded);
    return _saveSetting('scroll_sensitivity', rounded);
  }

  Future<void> updateScrollMomentum(double value) {
    final rounded = (value * 10).roundToDouble() / 10.0;
    state = state.copyWith(scrollMomentum: rounded);
    return _saveSetting('scroll_momentum', rounded);
  }

  Future<void> updateTrackball(bool value) {
    state = state.copyWith(trackball: value);
    return _saveSetting('trackball', value);
  }

  Future<void> updateTrackballFriction(double value) {
    final rounded = (value * 10).roundToDouble() / 10.0;
    state = state.copyWith(trackballFriction: rounded);
    return _saveSetting('trackball_friction', rounded);
  }

  Future<void> updateTypingBox(bool value) {
    state = state.copyWith(typingBox: value);
    return _saveSetting('typing_box', value);
  }

  Future<void> updateTutorialStatus(String status) {
    state = state.copyWith(tutorialStatus: status);
    return _writeSettings((stored) => stored[_tutorialKey] = status);
  }

  Future<void> updateGamepadMode(bool enabled) {
    state = state.copyWith(gamepadMode: enabled);
    return _writeSettings((stored) => stored[_gamepadModeKey] = enabled);
  }

  Future<void> updateGamepadReportRate(int hz) async {
    if (!gamepadReportRates.contains(hz)) return;
    state = state.copyWith(gamepadReportRate: hz);
    await _writeSettings((stored) => stored[_gamepadRateKey] = hz);
  }

  Future<void> resetSettings() async {
    final prefix = _prefix(_connectedAddress);
    await _writeSettings(
      (stored) => stored.removeWhere((key, _) => key.startsWith(prefix)),
    );
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
