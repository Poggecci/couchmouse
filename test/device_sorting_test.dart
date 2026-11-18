import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:couchmouse/settings_providers.dart';
import 'package:couchmouse/main.dart';

void main() {
  group('Device Sorting & Connection History Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test(
      'ConnectionStateNotifier updates connection history list in SharedPreferences',
      () async {
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(connectionStateProvider.notifier);

        // Initially empty
        expect(prefs.getStringList('connected_device_addresses_history'), null);

        // Connect to Device A
        await notifier.updateConnectionState(
          isConnected: true,
          connectedDeviceName: 'Device A',
          connectedDeviceAddress: 'AA:BB:CC:DD:EE:01',
        );

        expect(prefs.getStringList('connected_device_addresses_history'), [
          'AA:BB:CC:DD:EE:01',
        ]);

        // Connect to Device B
        await notifier.updateConnectionState(
          isConnected: true,
          connectedDeviceName: 'Device B',
          connectedDeviceAddress: 'AA:BB:CC:DD:EE:02',
        );

        expect(prefs.getStringList('connected_device_addresses_history'), [
          'AA:BB:CC:DD:EE:02',
          'AA:BB:CC:DD:EE:01',
        ]);

        // Connect to Device A again (should move to front)
        await notifier.updateConnectionState(
          isConnected: true,
          connectedDeviceName: 'Device A',
          connectedDeviceAddress: 'AA:BB:CC:DD:EE:01',
        );

        expect(prefs.getStringList('connected_device_addresses_history'), [
          'AA:BB:CC:DD:EE:01',
          'AA:BB:CC:DD:EE:02',
        ]);
      },
    );

    testWidgets(
      'The paired-device sheet sorts by history and refreshes when a bond changes',
      (WidgetTester tester) async {
        // Set a portrait mobile screen size
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await prefs.setString('global_tutorial_status', 'completed');
        // Device B was connected most recently, followed by Device C.
        await prefs.setStringList('connected_device_addresses_history', [
          'AA:BB:CC:DD:EE:02', // Device B
          'AA:BB:CC:DD:EE:03', // Device C
        ]);

        const hidChannel = MethodChannel('com.example.couchmouse/hid');
        final messenger = tester.binding.defaultBinaryMessenger;
        final pairedDevices = [
          {'name': 'Device A', 'address': 'AA:BB:CC:DD:EE:01'},
          {'name': 'Device B', 'address': 'AA:BB:CC:DD:EE:02'},
          {'name': 'Device C', 'address': 'AA:BB:CC:DD:EE:03'},
        ];

        messenger.setMockMethodCallHandler(hidChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'isSupported') {
            return true;
          }
          if (methodCall.method == 'getSdkVersion') {
            return 31;
          }
          if (methodCall.method == 'registerAppProfile') {
            return null;
          }
          if (methodCall.method == 'getConnectionState') {
            return {
              'connected': false,
              'deviceName': null,
              'deviceAddress': null,
              'registered': true,
            };
          }
          if (methodCall.method == 'getPairedDevices') {
            return pairedDevices;
          }
          return null;
        });

        // Mock permissions channel
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'checkPermissionStatus') {
              return 1; // PermissionStatus.granted
            }
            return null;
          },
        );

        // Build our app and trigger a frame.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: const CouchMouseApp(),
          ),
        );

        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Find the Bluetooth icon button and tap it to open the connection sheet
        final bluetoothBtn = find.byIcon(CupertinoIcons.bluetooth);
        expect(bluetoothBtn, findsOneWidget);
        await tester.tap(bluetoothBtn);
        await tester.pumpAndSettle();

        // Find ListTiles representing paired devices in the bottom sheet
        final listTiles = find.byType(ListTile);
        expect(listTiles, findsNWidgets(3));

        // Get the texts from the ListTiles in order
        final texts = listTiles.evaluate().map((element) {
          final listTile = element.widget as ListTile;
          return (listTile.title as Text).data;
        }).toList();

        // Order should be Device B (most recent), Device C (next), Device A (not in history)
        expect(texts, ['Device B', 'Device C', 'Device A']);

        pairedDevices.removeAt(1);
        await messenger.handlePlatformMessage(
          hidChannel.name,
          hidChannel.codec.encodeMethodCall(
            const MethodCall('onBondStateChanged'),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();

        expect(find.text('Device B'), findsNothing);
        expect(listTiles, findsNWidgets(2));
      },
    );
  });
}
