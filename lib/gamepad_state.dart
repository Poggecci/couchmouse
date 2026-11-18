import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_providers.dart' show sharedPreferencesProvider;

/// Bit indices of the HID gamepad report's button field.
///
/// Must match `GamepadButton` in `android/.../GamepadReport.kt`.
abstract final class GamepadButtons {
  static const a = 0;
  static const b = 1;
  static const x = 3;
  static const y = 4;
  static const l1 = 6;
  static const r1 = 7;
  static const l2 = 8;
  static const r2 = 9;
  static const select = 10;
  static const start = 11;
  static const mode = 12;
  static const l3 = 13;
  static const r3 = 14;
}

/// HID hat switch values (0 = up, clockwise; 8 = centred).
abstract final class GamepadHat {
  static const up = 0;
  static const upRight = 1;
  static const right = 2;
  static const downRight = 3;
  static const down = 4;
  static const downLeft = 5;
  static const left = 6;
  static const upLeft = 7;
  static const centered = 8;
}

/// What the native side last read from the physical controller.
class GamepadSnapshot {
  final int buttons;
  final int hat;
  final double leftX;
  final double leftY;
  final double rightX;
  final double rightY;
  final double leftTrigger;
  final double rightTrigger;

  const GamepadSnapshot({
    this.buttons = 0,
    this.hat = GamepadHat.centered,
    this.leftX = 0,
    this.leftY = 0,
    this.rightX = 0,
    this.rightY = 0,
    this.leftTrigger = 0,
    this.rightTrigger = 0,
  });

  static const neutral = GamepadSnapshot();

  factory GamepadSnapshot.fromMap(Map<dynamic, dynamic> map) {
    double d(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return GamepadSnapshot(
      buttons: (map['buttons'] as num?)?.toInt() ?? 0,
      hat: (map['hat'] as num?)?.toInt() ?? GamepadHat.centered,
      leftX: d('leftX'),
      leftY: d('leftY'),
      rightX: d('rightX'),
      rightY: d('rightY'),
      leftTrigger: d('leftTrigger'),
      rightTrigger: d('rightTrigger'),
    );
  }

  bool isPressed(int button) => (buttons & (1 << button)) != 0;

  bool get dpadUp =>
      hat == GamepadHat.up ||
      hat == GamepadHat.upRight ||
      hat == GamepadHat.upLeft;
  bool get dpadDown =>
      hat == GamepadHat.down ||
      hat == GamepadHat.downRight ||
      hat == GamepadHat.downLeft;
  bool get dpadLeft =>
      hat == GamepadHat.left ||
      hat == GamepadHat.upLeft ||
      hat == GamepadHat.downLeft;
  bool get dpadRight =>
      hat == GamepadHat.right ||
      hat == GamepadHat.upRight ||
      hat == GamepadHat.downRight;
}

/// Whether the app forwards physical controller input as a HID gamepad.
/// Persisted globally (not per host) so a handheld reopens in gamepad mode.
class GamepadModeNotifier extends Notifier<bool> {
  static const String _key = 'global_gamepad_mode';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref.read(sharedPreferencesProvider).setBool(_key, enabled);
  }
}

final gamepadModeProvider = NotifierProvider<GamepadModeNotifier, bool>(
  GamepadModeNotifier.new,
);

/// Maximum rate (Hz) at which changed controller state is sent to the host.
///
/// The Bluetooth link's real capacity depends on the host and on Wi-Fi
/// sharing the radio, and Android gives no feedback about it. Sending faster
/// than the link drains makes inputs lag and drop, so this is user-tunable.
class GamepadReportRateNotifier extends Notifier<int> {
  static const String _key = 'global_gamepad_report_rate_hz';
  static const List<int> options = [30, 60, 90, 125];
  static const int defaultHz =
      125; // must match GamepadReportPump.DEFAULT_RATE_HZ

  @override
  int build() {
    final saved = ref.watch(sharedPreferencesProvider).getInt(_key);
    return options.contains(saved) ? saved! : defaultHz;
  }

  Future<void> setRate(int hz) async {
    if (!options.contains(hz)) return;
    state = hz;
    await ref.read(sharedPreferencesProvider).setInt(_key, hz);
  }
}

final gamepadReportRateProvider =
    NotifierProvider<GamepadReportRateNotifier, int>(
      GamepadReportRateNotifier.new,
    );

class GamepadLiveStateNotifier extends Notifier<GamepadSnapshot> {
  @override
  GamepadSnapshot build() => GamepadSnapshot.neutral;

  void update(GamepadSnapshot snapshot) => state = snapshot;
}

final gamepadLiveStateProvider =
    NotifierProvider<GamepadLiveStateNotifier, GamepadSnapshot>(
      GamepadLiveStateNotifier.new,
    );

class GamepadControllersNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void update(List<String> names) => state = List.unmodifiable(names);
}

/// Names of physical controllers Android currently reports.
final gamepadControllersProvider =
    NotifierProvider<GamepadControllersNotifier, List<String>>(
      GamepadControllersNotifier.new,
    );
