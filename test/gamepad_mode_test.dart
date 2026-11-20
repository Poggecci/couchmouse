import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:couchmouse/gamepad_state.dart';
import 'package:couchmouse/main.dart';
import 'package:couchmouse/settings_providers.dart';
import 'package:couchmouse/widgets/gamepad_view.dart';

const _hidChannel = MethodChannel('com.example.couchmouse/hid');

void main() {
  group('GamepadSnapshot', () {
    test('parses the native map and exposes buttons and D-pad', () {
      final s = GamepadSnapshot.fromMap({
        'buttons': (1 << GamepadButtons.a) | (1 << GamepadButtons.start),
        'hat': GamepadHat.upLeft,
        'leftX': -1.0,
        'leftY': 0.5,
        'rightX': 0,
        'rightY': 1,
        'leftTrigger': 0.25,
        'rightTrigger': 1.0,
      });
      expect(s.isPressed(GamepadButtons.a), isTrue);
      expect(s.isPressed(GamepadButtons.start), isTrue);
      expect(s.isPressed(GamepadButtons.b), isFalse);
      expect(s.dpadUp && s.dpadLeft, isTrue);
      expect(s.dpadDown || s.dpadRight, isFalse);
      expect(s.leftX, -1.0);
      expect(s.rightY, 1.0); // ints from the channel become doubles
      expect(s.leftTrigger, 0.25);
    });

    test('missing fields fall back to neutral', () {
      final s = GamepadSnapshot.fromMap({});
      expect(s.buttons, 0);
      expect(s.hat, GamepadHat.centered);
      expect(s.dpadUp || s.dpadDown || s.dpadLeft || s.dpadRight, isFalse);
    });

    test('Dart button bits match the Kotlin report layout', () {
      // Mirrors GamepadButton in GamepadReport.kt (Linux BTN_GAMEPAD order).
      expect(
        [
          GamepadButtons.a,
          GamepadButtons.b,
          GamepadButtons.x,
          GamepadButtons.y,
          GamepadButtons.l1,
          GamepadButtons.r1,
          GamepadButtons.l2,
          GamepadButtons.r2,
          GamepadButtons.select,
          GamepadButtons.start,
          GamepadButtons.mode,
          GamepadButtons.l3,
          GamepadButtons.r3,
        ],
        [0, 1, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14],
      );
    });
  });

  test('GamepadModeNotifier persists the mode globally', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(gamepadModeProvider), isFalse);
    await container.read(gamepadModeProvider.notifier).setEnabled(true);
    expect(container.read(gamepadModeProvider), isTrue);
    expect(
      await container.read(settingsProvider.notifier).exportSettings(),
      contains('"global_gamepad_mode": true'),
    );
  });

  group('GamepadReportRateNotifier', () {
    Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final sp = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('defaults to 125 Hz and persists a new rate', () async {
      final c = await containerWith({});
      expect(c.read(gamepadReportRateProvider), 125);
      await c.read(gamepadReportRateProvider.notifier).setRate(90);
      expect(c.read(gamepadReportRateProvider), 90);
      expect(
        await c.read(settingsProvider.notifier).exportSettings(),
        contains('"global_gamepad_report_rate_hz": 90'),
      );
    });

    test('ignores rates that are not offered', () async {
      final c = await containerWith({});
      await c.read(gamepadReportRateProvider.notifier).setRate(1000);
      expect(c.read(gamepadReportRateProvider), 125);
    });

    test('falls back to the default for an invalid saved value', () async {
      final c = await containerWith({'global_gamepad_report_rate_hz': 7});
      expect(c.read(gamepadReportRateProvider), 125);
    });
  });

  testWidgets('GamepadVisualizer renders neutral and active states', (
    tester,
  ) async {
    Future<void> show(GamepadSnapshot s) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200, // much smaller than the 360px design size
              child: FittedBox(child: GamepadVisualizer(snapshot: s)),
            ),
          ),
        ),
      ),
    );

    await show(GamepadSnapshot.neutral);
    expect(tester.takeException(), isNull);

    await show(
      const GamepadSnapshot(
        buttons: 0x7FFF,
        hat: GamepadHat.downRight,
        leftX: 1,
        leftY: -1,
        rightX: -1,
        rightY: 1,
        leftTrigger: 1,
        rightTrigger: 0.5,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('START'), findsOneWidget);
  });

  group('Gamepad mode in HomeScreen', () {
    late List<MethodCall> calls;

    Future<SharedPreferences> setUpApp(
      WidgetTester tester, {
      required bool gamepadMode,
      int? rateHz,
    }) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'global_tutorial_status': 'completed',
        'global_gamepad_mode': gamepadMode,
        'global_gamepad_report_rate_hz': ?rateHz,
      });
      final prefs = await SharedPreferences.getInstance();

      calls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _hidChannel,
        (call) async {
          calls.add(call);
          switch (call.method) {
            case 'isSupported':
              return true;
            case 'getSdkVersion':
              return 31;
            case 'setGamepadMode':
              return call.arguments['enabled'];
            case 'getGamepadControllers':
              return ['AYN Odin Controller'];
          }
          return null;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async => call.method == 'checkPermissionStatus' ? 1 : null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const CouchMouseApp(),
        ),
      );
      // Bounded pumps instead of pumpAndSettle (see docs/gamepad/PLAN.md).
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return prefs;
    }

    List<bool> gamepadModeCalls() => calls
        .where((c) => c.method == 'setGamepadMode')
        .map((c) => c.arguments['enabled'] as bool)
        .toList();

    Map<String, dynamic> savedSettings(SharedPreferences prefs) =>
        jsonDecode(prefs.getString('portable_settings')!)
            as Map<String, dynamic>;

    testWidgets('persisted gamepad mode shows the gamepad screen and syncs '
        'native', (tester) async {
      await setUpApp(tester, gamepadMode: true);

      expect(find.byType(GamepadModeView), findsOneWidget);
      expect(find.text('AYN Odin Controller'), findsOneWidget);
      expect(gamepadModeCalls(), [true]);
    });

    testWidgets('live state from native updates the visualizer', (
      tester,
    ) async {
      final container = await setUpApp(tester, gamepadMode: true).then(
        (_) => ProviderScope.containerOf(
          tester.element(find.byType(GamepadModeView)),
        ),
      );

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        _hidChannel.name,
        _hidChannel.codec.encodeMethodCall(
          const MethodCall('onGamepadState', {
            'buttons': 1 << GamepadButtons.a,
            'hat': GamepadHat.up,
            'leftX': 0.5,
            'leftY': 0.0,
            'rightX': 0.0,
            'rightY': 0.0,
            'leftTrigger': 0.0,
            'rightTrigger': 0.0,
          }),
        ),
        (_) {},
      );
      await tester.pump();

      final live = container.read(gamepadLiveStateProvider);
      expect(live.isPressed(GamepadButtons.a), isTrue);
      expect(live.dpadUp, isTrue);
      expect(live.leftX, 0.5);
    });

    testWidgets('exit button turns gamepad mode off and restores trackpad', (
      tester,
    ) async {
      final prefs = await setUpApp(tester, gamepadMode: true);

      await tester.ensureVisible(find.byKey(const Key('exitGamepadMode')));
      await tester.tap(find.byKey(const Key('exitGamepadMode')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(GamepadModeView), findsNothing);
      expect(savedSettings(prefs)['global_gamepad_mode'], isFalse);
      expect(gamepadModeCalls(), [true, false]);
    });

    List<int> rateCalls() => calls
        .where((c) => c.method == 'setGamepadReportRate')
        .map((c) => c.arguments['hz'] as int)
        .toList();

    testWidgets('saved report rate is sent to native at startup', (
      tester,
    ) async {
      await setUpApp(tester, gamepadMode: true, rateHz: 90);
      expect(rateCalls(), [90]);
    });

    testWidgets('choosing a rate in the drawer saves it and updates native', (
      tester,
    ) async {
      final prefs = await setUpApp(tester, gamepadMode: true);
      expect(rateCalls(), [125]);

      // The drawer's existing BlockSlider label rows overflow under the test
      // font (every glyph is a full square). This also happens on upstream
      // main without any gamepad changes, so tolerate exactly those errors.
      final tolerated = <String>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.toString();
        if (text.contains('RenderFlex overflowed') &&
            text.contains('control_drawer.dart')) {
          tolerated.add(text);
          return;
        }
        originalOnError?.call(details);
      };

      await tester.tap(find.byIcon(CupertinoIcons.bars));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final drawerList = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      final advanced = find.byKey(const Key('advancedSettingsSwitch'));
      await tester.scrollUntilVisible(advanced, 250, scrollable: drawerList);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(advanced);
      await tester.pump(const Duration(milliseconds: 50));
      final option = find.byKey(const Key('gamepadRate_30'));
      await tester.scrollUntilVisible(option, 250, scrollable: drawerList);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(option);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      FlutterError.onError = originalOnError;

      expect(savedSettings(prefs)['global_gamepad_report_rate_hz'], 30);
      expect(rateCalls(), [125, 30]);
      // Only the known slider overflow was tolerated, nothing from the new UI.
      for (final t in tolerated) {
        expect(t, isNot(contains('_RateOption')));
      }
    });

    testWidgets('imported mode and rate apply to the UI and native sender', (
      tester,
    ) async {
      await setUpApp(tester, gamepadMode: false);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      await container
          .read(settingsProvider.notifier)
          .importSettings(
            jsonEncode({
              'format': 'couchmouse-settings',
              'version': 1,
              'settings': {
                'global_tutorial_status': 'completed',
                'global_gamepad_mode': true,
                'global_gamepad_report_rate_hz': 60,
              },
            }),
          );
      await tester.pump();

      expect(find.byType(GamepadModeView), findsOneWidget);
      expect(gamepadModeCalls(), [false, true]);
      expect(rateCalls(), [125, 60]);
    });

    testWidgets('gamepad mode off by default keeps the trackpad UI', (
      tester,
    ) async {
      await setUpApp(tester, gamepadMode: false);

      expect(find.byType(GamepadModeView), findsNothing);
      expect(gamepadModeCalls(), [false]);
    });

    testWidgets('turning gamepad mode on releases held keyboard/mouse input', (
      tester,
    ) async {
      await setUpApp(tester, gamepadMode: false);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      calls.clear();

      await container.read(gamepadModeProvider.notifier).setEnabled(true);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(GamepadModeView), findsOneWidget);
      final methods = calls.map((c) => c.method).toList();
      expect(methods, contains('sendKeyboardReport'));
      expect(methods, contains('sendMouseReport'));
      expect(gamepadModeCalls(), [true]);
    });
  });
}
