import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couchmouse/keyboard_layouts.dart';
import 'package:couchmouse/widgets/typing_box.dart';

import 'connected_home_screen.dart';

Future<List<List<int>>> _openPortraitKeyboard(
  WidgetTester tester, {
  required bool typingBox,
}) async {
  final reports = await pumpConnectedHomeScreen(
    tester,
    size: const Size(1080, 1920),
    devicePixelRatio: 2,
    prefs: {'global_typing_box': typingBox},
  );
  await tester.pump();
  await tester.pump();

  await tester.drag(find.text('LEFT CLICK'), const Offset(0, -100));
  await tester.pump();
  await tester.pump();
  return reports;
}

bool _inputBlocked(WidgetTester tester) => tester
    .widgetList<IgnorePointer>(
      find.ancestor(
        of: find.byType(TypingBox),
        matching: find.byType(IgnorePointer),
      ),
    )
    .any((widget) => widget.ignoring);

void main() {
  testWidgets('The typing box is off by default', (tester) async {
    await _openPortraitKeyboard(tester, typingBox: false);
    expect(find.byIcon(Icons.keyboard_hide), findsOneWidget);
    expect(find.byType(TypingBox), findsNothing);
  });

  testWidgets(
    'The typing box holds text until Send, then types it with the UI blocked',
    (tester) async {
      final reports = await _openPortraitKeyboard(tester, typingBox: true);
      expect(find.byType(TypingBox), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Don\u2019t\nGo');
      await tester.pump(const Duration(seconds: 1));
      expect(reports, isEmpty);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(_inputBlocked(tester), isTrue);

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      const presses = [0x07, 0x12, 0x11, 0x34, 0x17, 0x28, 0x0A, 0x12];
      expect(
        reports.map((report) => report[2]),
        presses.expand((key) => [key, 0]),
      );
      expect(reports[0][0], 0x02);
      expect(reports[12][0], 0x02);
      expect(_inputBlocked(tester), isFalse);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('Backspace in an empty typing box reaches the host', (
    tester,
  ) async {
    final reports = await _openPortraitKeyboard(tester, typingBox: true);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump(const Duration(milliseconds: 50));
    expect(reports, [
      [0, 0, 0x2A, 0, 0, 0, 0, 0],
      List<int>.filled(8, 0),
    ]);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump(const Duration(milliseconds: 50));
    expect(reports, hasLength(2));
  });

  test('Typographic characters from phone keyboards become typable', () {
    expect(
      KeyboardLayouts.typableText(
        '\u201CIt\u2019s\u2026\u201D \u2014 a\u00A0b\r\nc\rd',
      ),
      '"It\'s..." - a b\nc\nd',
    );
  });
}
