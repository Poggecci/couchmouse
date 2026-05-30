// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const CouchMouseApp(),
      ),
    );

    // Allow async permission and support checks to resolve
    await tester.pumpAndSettle();

    // Verify that our app renders and shows the title.
    expect(find.text('CouchMouse'), findsOneWidget);
  });

  testWidgets(
    'Swipe up below trackpad in portrait mode shows keyboard accessory bar',
    (WidgetTester tester) async {
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
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
      expect(find.byIcon(Icons.keyboard_hide), findsOneWidget);
      expect(
        find.byIcon(CupertinoIcons.keyboard_chevron_compact_down),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Unfocusing the keyboard focus node exits keyboard mode and shows click buttons',
    (WidgetTester tester) async {
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
          if (methodCall.method == 'isSupported') return true;
          if (methodCall.method == 'getSdkVersion') return 31;
          return null;
        },
      );

      // Mock permissions channel
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'checkPermissionStatus') return 1;
          return null;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const CouchMouseApp(),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Drag up to open keyboard
      await tester.drag(find.text('LEFT CLICK'), const Offset(0, -100));
      await tester.pumpAndSettle();

      // Verify keyboard is active
      expect(find.byIcon(Icons.keyboard_hide), findsOneWidget);
      expect(
        find.byIcon(CupertinoIcons.keyboard_chevron_compact_down),
        findsOneWidget,
      );
      expect(find.text('LEFT CLICK'), findsNothing);

      // 2. Unfocus the focus node (simulating Android back gesture/soft keyboard dismiss)
      final FocusNode focusNode = tester
          .widget<TextField>(find.byType(TextField))
          .focusNode!;
      focusNode.unfocus();
      await tester.pumpAndSettle();

      // Verify keyboard accessory bar is hidden and click buttons are back
      expect(find.text('LEFT CLICK'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_hide), findsNothing);
    },
  );

  testWidgets(
    'Soft keyboard dismissal (bottom insets going to 0) exits keyboard mode even if focus node retains focus',
    (WidgetTester tester) async {
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
          if (methodCall.method == 'isSupported') return true;
          if (methodCall.method == 'getSdkVersion') return 31;
          return null;
        },
      );

      // Mock permissions channel
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'checkPermissionStatus') return 1;
          return null;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const CouchMouseApp(),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Drag up to open keyboard
      await tester.drag(find.text('LEFT CLICK'), const Offset(0, -100));
      await tester.pumpAndSettle();

      // Verify keyboard is active
      expect(find.byIcon(Icons.keyboard_hide), findsOneWidget);
      expect(
        find.byIcon(CupertinoIcons.keyboard_chevron_compact_down),
        findsOneWidget,
      );
      expect(find.text('LEFT CLICK'), findsNothing);

      // 2. Simulate keyboard appearing (view insets bottom > 0)
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      // 3. Simulate keyboard being dismissed (view insets bottom -> 0) while focus is still retained
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();

      // Verify keyboard accessory bar is hidden and click buttons are back
      expect(find.text('LEFT CLICK'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_hide), findsNothing);
    },
  );

  testWidgets(
    'App lifecycle state changes (paused/inactive) exit keyboard mode and unfocus keyboard node',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.example.couchmouse/hid'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'isSupported') return true;
          if (methodCall.method == 'getSdkVersion') return 31;
          return null;
        },
      );

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'checkPermissionStatus') return 1;
          return null;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const CouchMouseApp(),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Drag up to open keyboard
      await tester.drag(find.text('LEFT CLICK'), const Offset(0, -100));
      await tester.pumpAndSettle();

      // Verify keyboard is active
      expect(find.byIcon(Icons.keyboard_hide), findsOneWidget);
      expect(
        find.byIcon(CupertinoIcons.keyboard_chevron_compact_down),
        findsOneWidget,
      );

      // 2. Simulate app going to background (inactive)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      // Verify keyboard accessory bar is hidden and click buttons are back
      expect(find.text('LEFT CLICK'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_hide), findsNothing);
    },
  );

  testWidgets(
    'Resuming app when permissions are denied does not request them again',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      int permissionCheckCount = 0;
      int permissionRequestCount = 0;

      // Mock Bluetooth/HID channel
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.example.couchmouse/hid'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'isSupported') return true;
          if (methodCall.method == 'getSdkVersion') return 31;
          return null;
        },
      );

      // Mock permissions channel
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'checkPermissionStatus') {
            permissionCheckCount++;
            return 0; // PermissionStatus.denied
          }
          if (methodCall.method == 'requestPermissions') {
            permissionRequestCount++;
            final permissions = methodCall.arguments as List<dynamic>;
            return {for (var p in permissions) p as int: 0};
          }
          return null;
        },
      );

      // Build app (will trigger initial check and request)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const CouchMouseApp(),
        ),
      );

      await tester.pumpAndSettle();

      final initialRequests = permissionRequestCount;
      expect(initialRequests, greaterThan(0));

      // Simulate app going to background (paused) and then resuming
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // The request count should NOT have increased
      expect(permissionRequestCount, equals(initialRequests));
      expect(permissionCheckCount, greaterThan(0));
    },
  );
}
