// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:couchmouse/settings_providers.dart';

import 'package:couchmouse/main.dart';

void main() {
  testWidgets('CouchMouse App smoke test', (WidgetTester tester) async {
    // Set a portrait mobile screen size (540x960 logical pixels)
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Mock Bluetooth/HID channel
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.example.couchmouse/hid'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isSupported') {
          return true;
        }
        if (methodCall.method == 'getSdkVersion') {
          return 31;
        }
        return null;
      },
    );

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
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const CouchMouseApp(),
      ),
    );

    // Allow async permission and support checks to resolve
    await tester.pumpAndSettle();

    // Verify that our app renders and shows the title.
    expect(find.text('CouchMouse'), findsOneWidget);
  });

  testWidgets('Swipe up below trackpad in portrait mode shows keyboard accessory bar', (WidgetTester tester) async {
    // Set a portrait mobile screen size (540x960 logical pixels)
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Mock Bluetooth/HID channel
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.example.couchmouse/hid'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isSupported') {
          return true;
        }
        if (methodCall.method == 'getSdkVersion') {
          return 31;
        }
        return null;
      },
    );

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
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const CouchMouseApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initially the keyboard is not active (click buttons are shown, accessory bar is not)
    expect(find.text('LEFT CLICK'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_hide), findsNothing);

    // Perform a vertical drag upward on the click buttons
    await tester.drag(find.text('LEFT CLICK'), const Offset(0, -100));

    // Rebuild UI to process keyboard activation
    await tester.pumpAndSettle();

    // Verify keyboard accessory bar is now shown (one in AppBar, one in accessory bar)
    expect(find.byIcon(Icons.keyboard_hide), findsNWidgets(2));
  });
}
