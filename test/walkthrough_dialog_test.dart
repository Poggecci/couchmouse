import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couchmouse/settings_providers.dart';
import 'package:couchmouse/widgets/walkthrough_dialog.dart';

import 'connected_home_screen.dart';
import 'settings_test_support.dart';

void main() {
  testWidgets('Landscape walkthrough scrolls and keeps its controls visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = memorySettings();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.fromLTRB(24, 0, 0, 16),
              textScaler: TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    WalkthroughDialog.show(context, isFirstStart: true),
                child: const Text('Open tutorial'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open tutorial'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Get Started').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Get Started'));
    await tester.pump();

    final firstPage = find.byKey(const PageStorageKey<int>(0));
    final scrollable = find.descendant(
      of: firstPage,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(firstPage, Offset(0, -position.maxScrollExtent - 60));
    await tester.pump();
    expect(position.pixels, closeTo(position.maxScrollExtent, 1));
    expect(find.byTooltip('Close tutorial').hitTestable(), findsOneWidget);

    for (var step = 1; step <= 4; step++) {
      if (step == 2) {
        tester.view.physicalSize = const Size(375, 680);
        await tester.pump();
        expect(find.text('TUTORIAL: STEP 2 OF 4'), findsOneWidget);
        expect(find.text('Next').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.physicalSize = const Size(640, 300);
        await tester.pump();
      }
      expect(find.text('TUTORIAL: STEP $step OF 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final action = find.text(step == 4 ? 'Finish' : 'Next');
      expect(action.hitTestable(), findsOneWidget);
      await tester.tap(action);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(find.byType(WalkthroughDialog), findsNothing);
    expect(store.snapshot.tutorialStatusId, 1);
  });

  testWidgets('The landscape Settings menu opens the walkthrough', (
    tester,
  ) async {
    await pumpConnectedHomeScreen(tester, size: const Size(1200, 650));
    await tester.pumpAndSettle();
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pumpAndSettle();
    final tutorial = find.text('App Walkthrough Tutorial');
    await tester.scrollUntilVisible(
      tutorial,
      250,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(tutorial);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('1. Bluetooth Connection').hitTestable(), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
    expect(scaffold.isDrawerOpen, isFalse);
    await tester.tap(find.byTooltip('Close tutorial'));
    await tester.pumpAndSettle();
    expect(find.byType(WalkthroughDialog), findsNothing);
  });
}
