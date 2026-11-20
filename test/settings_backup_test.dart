import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:couchmouse/gamepad_state.dart';
import 'package:couchmouse/main.dart';
import 'package:couchmouse/settings_providers.dart';

import 'settings_test_support.dart';

const _hostAddress = '00:11:22:33:44:55';

Future<ProviderContainer> _settingsContainer(
  PortableSettings initial, {
  Map<String, Object> localPrefs = const {},
  SettingsStore? store,
}) async {
  SharedPreferences.setMockInitialValues(localPrefs);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsStoreProvider.overrideWithValue(store ?? memorySettings(initial)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Gamepad preferences round-trip and update live providers', () async {
    final source = await _settingsContainer(
      PortableSettings(gamepadMode: true, gamepadReportRateHz: 60),
    );
    final backup = await source
        .read(settingsProvider.notifier)
        .exportSettings();
    final destination = await _settingsContainer(PortableSettings());
    expect(destination.read(gamepadModeProvider), isFalse);
    expect(destination.read(gamepadReportRateProvider), 125);

    final settings = destination.read(settingsProvider.notifier);
    await settings.importSettings(backup);
    expect(destination.read(gamepadModeProvider), isTrue);
    expect(destination.read(gamepadReportRateProvider), 60);

    await settings.importSettings(await backupFor(PortableSettings()));
    expect(destination.read(gamepadModeProvider), isFalse);
    expect(destination.read(gamepadReportRateProvider), 125);
  });

  test('Dark mode is global and survives a backup', () async {
    final source = await _settingsContainer(PortableSettings());
    expect(source.read(settingsProvider).darkMode, isFalse);
    await source.read(settingsProvider.notifier).updateDarkMode(true);
    final backup = await source
        .read(settingsProvider.notifier)
        .exportSettings();

    final destination = await _settingsContainer(PortableSettings());
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
    await destination.read(settingsProvider.notifier).resetSettings();
    expect(destination.read(settingsProvider).darkMode, isTrue);

    await destination
        .read(connectionStateProvider.notifier)
        .updateConnectionState(isConnected: false);
    await destination.read(settingsProvider.notifier).resetSettings();
    expect(destination.read(settingsProvider).darkMode, isFalse);
  });

  test(
    'Restores global and per-computer profiles and keeps local history',
    () async {
      final source = await _settingsContainer(
        PortableSettings(
          tutorialStatusId: 1,
          globalProfile: InputProfile(
            sensitivity: 800,
            mouseAcceleration: true,
          ),
          deviceProfiles: [
            DeviceProfile(
              bluetoothAddress: _hostAddress,
              inputProfile: InputProfile(
                sensitivity: 1600,
                scrollMomentum: 0.8,
              ),
            ),
          ],
        ),
      );
      final sourceSettings = source.read(settingsProvider.notifier);
      await sourceSettings.updateScrollSensitivity(3.2);
      await sourceSettings.updateTypingBox(true);
      final backup = await sourceSettings.exportSettings();

      final destination = await _settingsContainer(
        PortableSettings(globalProfile: InputProfile(trackpadOnLeft: true)),
        localPrefs: {
          'connected_device_addresses_history': ['AA:BB:CC:DD:EE:FF'],
        },
      );
      await destination.read(settingsProvider.notifier).importSettings(backup);
      final global = destination.read(settingsProvider);
      expect(global.sensitivity, 800);
      expect(global.scrollSensitivity, 3.2);
      expect(global.mouseAcceleration, isTrue);
      expect(global.typingBox, isTrue);
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
      expect(device.sensitivity, 1600);
      expect(device.scrollMomentum, 0.8);
      expect(device.typingBox, isFalse);
    },
  );

  test('Validates the backup before replacing settings', () async {
    final container = await _settingsContainer(
      PortableSettings(globalProfile: InputProfile(sensitivity: 1200)),
    );
    final settings = container.read(settingsProvider.notifier);
    final original = await settings.exportSettings();
    for (final invalid in [
      Uint8List.fromList('{"format":"couchmouse-settings"}'.codeUnits),
      Uint8List.fromList([...original, 0x80]),
      await backupFor(
        PortableSettings(
          deviceProfiles: [DeviceProfile(bluetoothAddress: 'bad')],
        ),
      ),
    ]) {
      await expectLater(
        settings.importSettings(invalid),
        throwsFormatException,
      );
      expect(await settings.exportSettings(), original);
      expect(container.read(settingsProvider).sensitivity, 1200);
    }
  });

  test(
    'Edits queued during restore retain the other restored preferences',
    () async {
      final container = await _settingsContainer(PortableSettings());
      final settings = container.read(settingsProvider.notifier);
      final backup = await backupFor(
        PortableSettings(
          globalProfile: InputProfile(sensitivity: 2600, scrollMomentum: 0.4),
        ),
      );
      final restoring = settings.importSettings(backup);
      final editing = settings.updateMouseAcceleration(true);
      await Future.wait([restoring, editing]);
      final restored = container.read(settingsProvider);
      expect(restored.sensitivity, 2600);
      expect(restored.scrollMomentum, 0.4);
      expect(restored.mouseAcceleration, isTrue);
    },
  );

  test('Trackball settings survive a backup round trip', () async {
    final source = await _settingsContainer(PortableSettings());
    final sourceSettings = source.read(settingsProvider.notifier);
    await sourceSettings.updateTrackball(true);
    await sourceSettings.updateTrackballFriction(0.83);
    final backup = await sourceSettings.exportSettings();

    final destination = await _settingsContainer(PortableSettings());
    await destination.read(settingsProvider.notifier).importSettings(backup);
    final restored = destination.read(settingsProvider);
    expect(restored.trackball, isTrue);
    expect(restored.trackballFriction, 0.8);
  });

  test('Future fields survive import, edit, disk reload, and export', () async {
    final imported = PortableSettings(
      gamepadReportRateHz: 144,
      deviceProfiles: [
        DeviceProfile(
          bluetoothAddress: _hostAddress,
          inputProfile: InputProfile(sensitivity: 800, keyboardLayoutId: 42)
            ..unknownFields.mergeLengthDelimitedField(20, [3]),
        )..unknownFields.mergeLengthDelimitedField(20, [2]),
      ],
    )..unknownFields.mergeLengthDelimitedField(20, [1]);

    Uint8List? persisted;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SettingsStore.channel, (call) async {
      switch (call.method) {
        case 'readSettings':
          return persisted;
        case 'writeSettings':
          persisted = call.arguments as Uint8List;
          return null;
        default:
          throw MissingPluginException();
      }
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SettingsStore.channel, null),
    );
    final container = await _settingsContainer(
      PortableSettings(),
      store: await SettingsStore.open(),
    );
    final settings = container.read(settingsProvider.notifier);
    await settings.importSettings(await backupFor(imported));
    await container
        .read(connectionStateProvider.notifier)
        .updateConnectionState(
          isConnected: true,
          connectedDeviceAddress: _hostAddress,
        );
    expect(container.read(settingsProvider).gamepadReportRate, 125);
    await settings.updateSensitivity(1600);

    final reopened = await SettingsStore.open();
    final receiver = memorySettings();
    await receiver.importBackup(await reopened.exportBackup());
    final result = receiver.snapshot;
    final device = result.deviceProfiles.single;
    expect(result.unknownFields, imported.unknownFields);
    expect(result.gamepadReportRateHz, 144);
    expect(device.unknownFields, imported.deviceProfiles.single.unknownFields);
    expect(
      device.inputProfile.unknownFields,
      imported.deviceProfiles.single.inputProfile.unknownFields,
    );
    expect(device.inputProfile.keyboardLayoutId, 42);
    expect(device.inputProfile.sensitivity, 1600);

    await settings.resetSettings();
    expect(container.read(settingsProvider).sensitivity, 800);
    final resetDevice =
        (await SettingsStore.open()).snapshot.deviceProfiles.single;
    expect(resetDevice.inputProfile.hasSensitivity(), isFalse);
    expect(
      resetDevice.inputProfile.unknownFields,
      device.inputProfile.unknownFields,
    );
  });

  test(
    'A failed commit keeps the previous snapshot and permits a retry',
    () async {
      var fail = true;
      final store = SettingsStore(PortableSettings(), (_) async {
        if (fail) throw StateError('write failed');
      });
      final container = await _settingsContainer(
        PortableSettings(),
        store: store,
      );
      final settings = container.read(settingsProvider.notifier);
      await expectLater(settings.updateSensitivity(2400), throwsStateError);
      expect(container.read(settingsProvider).sensitivity, 800);
      fail = false;
      await settings.updateSensitivity(2600);
      expect(container.read(settingsProvider).sensitivity, 2600);
    },
  );

  testWidgets(
    'Settings drawer exports and imports through the file picker channel',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = await _settingsContainer(
        PortableSettings(
          tutorialStatusId: 1,
          globalProfile: InputProfile(sensitivity: 1200),
        ),
      );
      final backup = await backupFor(
        PortableSettings(
          tutorialStatusId: 1,
          globalProfile: InputProfile(sensitivity: 2000),
        ),
      );
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
      Uint8List? exported;
      messenger.setMockMethodCallHandler(settingsChannel, (call) async {
        if (call.method == 'exportSettings') {
          exported = call.arguments['contents'] as Uint8List;
          return true;
        }
        return backup;
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
      final exportedSettings = memorySettings();
      await exportedSettings.importBackup(exported!);
      expect(exportedSettings.snapshot.globalProfile.sensitivity, 1200);
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
