import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:couchmouse/main.dart';
import 'package:couchmouse/settings_providers.dart';

/// Pumps [HomeScreen] connected to a mock host and returns the list that
/// collects every keyboard report sent. [onKeyboardReport] runs after each
/// report is recorded and may throw to simulate a failed send.
Future<List<List<int>>> pumpConnectedHomeScreen(
  WidgetTester tester, {
  required Size size,
  double devicePixelRatio = 1,
  Map<String, Object> prefs = const {},
  void Function(List<List<int>> reports)? onKeyboardReport,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'global_tutorial_status': 'completed',
    ...prefs,
  });
  final preferences = await SharedPreferences.getInstance();

  final reports = <List<int>>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.example.couchmouse/hid'),
    (call) async {
      switch (call.method) {
        case 'isSupported':
          return true;
        case 'getSdkVersion':
          return 31;
        case 'getConnectionState':
          return {'connected': true, 'registered': true};
        case 'sendKeyboardReport':
          reports.add(List<int>.from(call.arguments['bytes'] as List));
          onKeyboardReport?.call(reports);
      }
      return null;
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/permissions/methods'),
    (call) async => call.method == 'checkPermissionStatus' ? 1 : null,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  return reports;
}
