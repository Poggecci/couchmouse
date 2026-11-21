import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couchmouse/keyboard_layouts.dart';

import 'connected_home_screen.dart';

enum _PasteEnd { completed, sendFailure, cancelled, focusLost, disposed }

void main() {
  for (final (description, end) in [
    (
      'Paste sends one Enter per line ending and blocks taps until done',
      _PasteEnd.completed,
    ),
    ('A failed paste stops typing', _PasteEnd.sendFailure),
    ('A paste over 1,000 characters can be cancelled', _PasteEnd.cancelled),
    (
      'Focus loss releases the current key and drops the queue',
      _PasteEnd.focusLost,
    ),
    (
      'Disposing the screen releases the current key and drops the queue',
      _PasteEnd.disposed,
    ),
  ]) {
    testWidgets(description, (tester) async {
      final clipboardText = switch (end) {
        _PasteEnd.completed => 'A\r\nb\rc\nd',
        _PasteEnd.cancelled => 'A' * 1001,
        _ => 'Aa',
      };
      final reports = await pumpConnectedHomeScreen(
        tester,
        size: const Size(1200, 650),
        onKeyboardReport: (reports) {
          if (end == _PasteEnd.sendFailure && reports.length == 2) {
            throw PlatformException(
              code: 'UNAVAILABLE',
              message: 'No Bluetooth device currently connected.',
            );
          }
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.getData' ? {'text': clipboardText} : null,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paste'));
      await tester.pump();
      await tester.tap(find.text('B'), warnIfMissed: false);
      await tester.tap(find.text('X'), warnIfMissed: false);
      expect(reports.map((report) => report[2]), [0x04]);
      expect(reports.single[0], 0x02);

      if (end == _PasteEnd.cancelled) {
        await tester.pump(const Duration(milliseconds: 250));
        final progress = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(progress.persist, isTrue);
        await tester.tap(find.text('CANCEL'));
      } else if (end == _PasteEnd.focusLost) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.tap(find.text('A'), warnIfMissed: false);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      } else if (end == _PasteEnd.disposed) {
        await tester.pumpWidget(const SizedBox.shrink());
      }

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      if (end == _PasteEnd.focusLost || end == _PasteEnd.disposed) {
        expect(reports, [
          [0x02, 0, 0x04, 0, 0, 0, 0, 0],
          List<int>.filled(8, 0),
        ]);
        if (end == _PasteEnd.focusLost) {
          expect(find.textContaining('Paste cancelled'), findsOneWidget);
          await tester.tap(find.text('B'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 30));
          expect(reports.map((report) => report[2]), [0x04, 0, 0x05, 0]);
        }
      } else if (end == _PasteEnd.cancelled) {
        expect(reports.last, List<int>.filled(8, 0));
        expect(reports.length, lessThan(2 * clipboardText.length));
        await tester.pumpAndSettle();
        expect(find.textContaining('Paste cancelled'), findsOneWidget);
      } else if (end == _PasteEnd.sendFailure) {
        expect(reports.map((report) => report[2]), [0x04, 0, 0]);
        expect(find.text('Paste stopped after 0/2 characters'), findsOneWidget);
      } else {
        // A, Enter, b, Enter, c, Enter, d. The B and X taps were blocked.
        const presses = [0x04, 0x28, 0x05, 0x28, 0x06, 0x28, 0x07];
        expect(
          reports.map((report) => report[2]),
          presses.expand((key) => [key, 0]),
        );
        expect(reports.skip(1).map((report) => report[0]), everyElement(0));
      }
    });
  }

  group('Faux Clipboard Validation & Scancode Mapping Tests', () {
    test(
      'All standard alphanumeric and punctuation characters map to valid HID scancodes',
      () {
        const sampleText = "Hello World! 123 - = [ ] \\ ; ' , . /";
        for (final char in sampleText.runes.map(String.fromCharCode)) {
          final canType =
              KeyboardLayouts.charToScancode.containsKey(char) ||
              KeyboardLayouts.shiftCharToScancode.containsKey(char);
          expect(
            canType,
            isTrue,
            reason: "Character '$char' should be typable",
          );
        }
      },
    );

    test(
      'Special whitespace characters (tab, newline, space) map to valid HID scancodes',
      () {
        expect(KeyboardLayouts.charToScancode.containsKey('\t'), isTrue);
        expect(KeyboardLayouts.charToScancode.containsKey('\n'), isTrue);
        expect(KeyboardLayouts.charToScancode.containsKey('\r'), isTrue);
        expect(KeyboardLayouts.charToScancode.containsKey(' '), isTrue);
      },
    );

    test(
      'Unsupported Unicode / emojis / accented characters are identified as unmappable',
      () {
        const unsupportedText = "Test with emojis: 🚀🔥 and accents: é, ñ, ü";
        final unsupported = <String>{};
        for (final char in unsupportedText.runes.map(String.fromCharCode)) {
          if (!KeyboardLayouts.charToScancode.containsKey(char) &&
              !KeyboardLayouts.shiftCharToScancode.containsKey(char)) {
            unsupported.add(char);
          }
        }

        expect(unsupported, contains('🚀'));
        expect(unsupported, contains('🔥'));
        expect(unsupported, contains('é'));
        expect(unsupported, contains('ñ'));
        expect(unsupported, contains('ü'));
      },
    );

    test(
      'Shifted vs unshifted characters select appropriate scancode and modifier',
      () {
        // Lowercase 'a' -> scancode 0x04, unshifted
        expect(KeyboardLayouts.charToScancode['a'], 0x04);
        expect(KeyboardLayouts.shiftCharToScancode.containsKey('a'), isFalse);

        // Uppercase 'A' -> scancode 0x04, shifted
        expect(KeyboardLayouts.shiftCharToScancode['A'], 0x04);
        expect(KeyboardLayouts.charToScancode.containsKey('A'), isFalse);

        // Digit '1' vs '!'
        expect(KeyboardLayouts.charToScancode['1'], 0x1E);
        expect(KeyboardLayouts.shiftCharToScancode['!'], 0x1E);
      },
    );
  });
}
