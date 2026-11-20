import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:couchmouse/gamepad_state.dart';
import 'package:couchmouse/main.dart';
import 'package:couchmouse/settings_providers.dart';

const _hostAddress = '00:11:22:33:44:55';

String _backup(Map<String, Object> settings) => jsonEncode({
  'format': 'couchmouse-settings',
  'version': 1,
  'settings': settings,
});

Future<ProviderContainer> _settingsContainer(
  Map<String, Object> initial,
) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('Gamepad preferences round-trip and update live providers', () async {
    final source = await _settingsContainer({
      'global_gamepad_mode': true,
      'global_gamepad_report_rate_hz': 60,
    });
    final backup = await source
        .read(settingsProvider.notifier)
        .exportSettings();
    final destination = await _settingsContainer({});
    expect(destination.read(gamepadModeProvider), isFalse);
    expect(destination.read(gamepadReportRateProvider), 125);

    final settings = destination.read(settingsProvider.notifier);
    await settings.importSettings(backup);
    expect(destination.read(gamepadModeProvider), isTrue);
    expect(destination.read(gamepadReportRateProvider), 60);

    await settings.importSettings(_backup({'global_sensitivity': 1600}));
    expect(destination.read(gamepadModeProvider), isFalse);
    expect(destination.read(gamepadReportRateProvider), 125);
  });

  test('Dark mode is global and survives a backup', () async {
    final source = await _settingsContainer({});
    expect(source.read(settingsProvider).darkMode, isFalse);
    await source.read(settingsProvider.notifier).updateDarkMode(true);
    final backup = await source
        .read(settingsProvider.notifier)
        .exportSettings();

    final destination = await _settingsContainer({});
    await destination.read(settingsProvider.notifier).importSettings(backup);
    expect(destination.read(settingsProvider).darkMode, isTrue);

    await destination
        .read(connectionStateProvider.notifier)
        .updateConnectionState(
          isConnected: true,
          connectedDeviceName: 'Host',
          connectedDeviceAddress: _hostAddress,
        );
    expect(destination.read(settingsProvider).darkMode, isTrue);
  });

  test(
    'Restores legacy global and per-computer settings on a new install',
    () async {
      final source = await _settingsContainer({
        'global_sensitivity': 5.0,
        'global_mouse_acceleration': true,
        'global_tutorial_status': 'completed',
        'device_${_hostAddress}_sensitivity': 1600.0,
        'device_${_hostAddress}_scroll_momentum': 0.8,
        'last_connected_device_address': _hostAddress,
      });
      final sourceSettings = source.read(settingsProvider.notifier);
      await sourceSettings.updateScrollSensitivity(3.2);
      final backup = await sourceSettings.exportSettings();
      expect(backup, isNot(contains('last_connected_device_address')));

      final destination = await _settingsContainer({
        'global_trackpad_on_left': true,
        'connected_device_addresses_history': ['AA:BB:CC:DD:EE:FF'],
      });
      await destination.read(settingsProvider.notifier).importSettings(backup);
      final global = destination.read(settingsProvider);
      expect(global.sensitivity, 800.0);
      expect(global.scrollSensitivity, 3.2);
      expect(global.mouseAcceleration, isTrue);
      expect(global.trackpadOnLeft, isFalse);
      expect(global.tutorialStatus, 'completed');
      final prefs = destination.read(sharedPreferencesProvider);
      expect(prefs.getStringList('connected_device_addresses_history'), [
        'AA:BB:CC:DD:EE:FF',
      ]);

      await destination
          .read(connectionStateProvider.notifier)
          .updateConnectionState(
            isConnected: true,
            connectedDeviceAddress: _hostAddress,
          );
      final device = destination.read(settingsProvider);
      expect(device.sensitivity, 1600.0);
      expect(device.scrollMomentum, 0.8);
    },
  );

  test('Validates the entire file before replacing settings', () async {
    final container = await _settingsContainer({'global_sensitivity': 1200.0});
    final settings = container.read(settingsProvider.notifier);
    final original = await settings.exportSettings();
    for (final invalid in [
      'not JSON',
      '{"format":"couchmouse-settings","version":2,"settings":{}}',
      _backup({'global_sensitivity': 1500, 'global_keyboard_kind': -1}),
      _backup({'global_gamepad_mode': 1}),
      _backup({'global_gamepad_report_rate_hz': 144}),
      _backup({'global_dark_mode': 'yes'}),
      _backup({'last_connected_device_address': _hostAddress}),
    ]) {
      await expectLater(
        settings.importSettings(invalid),
        throwsFormatException,
      );
      expect(await settings.exportSettings(), original);
      expect(container.read(settingsProvider).sensitivity, 1200.0);
    }
  });

  test(
    'Edits queued during restore retain the other restored preferences',
    () async {
      final container = await _settingsContainer({});
      final settings = container.read(settingsProvider.notifier);
      final restoring = settings.importSettings(
        _backup({'global_sensitivity': 2600, 'global_scroll_momentum': 0.4}),
      );
      final editing = settings.updateMouseAcceleration(true);
      await Future.wait([restoring, editing]);
      final restored = container.read(settingsProvider);
      expect(restored.sensitivity, 2600);
      expect(restored.scrollMomentum, 0.4);
      expect(restored.mouseAcceleration, isTrue);
      expect(
        await settings.exportSettings(),
        contains('"global_mouse_acceleration": true'),
      );
    },
  );

  test(
    'Trackball defaults and computer overrides survive a backup round trip',
    () async {
      final source = await _settingsContainer({});
      final sourceSettings = source.read(settingsProvider.notifier);
      await sourceSettings.updateTrackball(true);
      await sourceSettings.updateTrackballFriction(0.83);
      await source
          .read(connectionStateProvider.notifier)
          .updateConnectionState(
            isConnected: true,
            connectedDeviceAddress: _hostAddress,
          );
      expect(source.read(settingsProvider).trackball, isTrue);
      expect(source.read(settingsProvider).trackballFriction, 0.8);
      await sourceSettings.updateTrackball(false);
      await sourceSettings.updateTrackballFriction(0.2);
      final backup = await sourceSettings.exportSettings();

      final destination = await _settingsContainer({});
      final restored = destination.read(settingsProvider.notifier);
      await restored.importSettings(backup);
      expect(destination.read(settingsProvider).trackball, isTrue);
      expect(destination.read(settingsProvider).trackballFriction, 0.8);
      await destination
          .read(connectionStateProvider.notifier)
          .updateConnectionState(
            isConnected: true,
            connectedDeviceAddress: _hostAddress,
          );
      expect(destination.read(settingsProvider).trackball, isFalse);
      expect(destination.read(settingsProvider).trackballFriction, 0.2);

      await restored.importSettings(_backup({'global_sensitivity': 1600}));
      expect(destination.read(settingsProvider).trackball, isFalse);
      expect(destination.read(settingsProvider).trackballFriction, 0.7);
    },
  );

  testWidgets(
    'Settings drawer exports and imports through the file picker channel',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = await _settingsContainer({
        'global_sensitivity': 1200.0,
        'global_tutorial_status': 'completed',
      });
      const hidChannel = MethodChannel('com.example.couchmouse/hid');
      const permissionsChannel = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      const settingsChannel = MethodChannel('com.example.couchmouse/settings');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(hidChannel, (call) async {
        return switch (call.method) {
          'isSupported' => true,
          'getSdkVersion' => 31,
          _ => null,
        };
      });
      messenger.setMockMethodCallHandler(
        permissionsChannel,
        (call) async => call.method == 'checkPermissionStatus' ? 1 : null,
      );
      String? exported;
      messenger.setMockMethodCallHandler(settingsChannel, (call) async {
        if (call.method == 'exportSettings') {
          exported = call.arguments['contents'] as String;
          return true;
        }
        return _backup({
          'global_sensitivity': 2000.0,
          'global_tutorial_status': 'completed',
        });
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(drawerTheme: const DrawerThemeData(width: 440)),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
      final drawerList = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      scaffold.openDrawer();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Export Settings'),
        250,
        scrollable: drawerList,
      );
      await tester.tap(find.text('Export Settings'));
      await tester.pumpAndSettle();
      expect(exported, contains('"global_sensitivity": 1200.0'));
      expect(find.text('Settings backup saved.'), findsOneWidget);

      scaffold.openDrawer();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Import Settings'),
        250,
        scrollable: drawerList,
      );
      await tester.tap(find.text('Import Settings'));
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).sensitivity, 2000.0);
    },
  );
}
