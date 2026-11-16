import 'package:flutter_test/flutter_test.dart';
import 'package:couchmouse/keyboard_layouts.dart';

void main() {
  group('Faux Clipboard Validation & Scancode Mapping Tests', () {
    test('All standard alphanumeric and punctuation characters map to valid HID scancodes', () {
      const sampleText = "Hello World! 123 - = [ ] \\ ; ' , . /";
      for (final char in sampleText.runes.map(String.fromCharCode)) {
        final canType = KeyboardLayouts.charToScancode.containsKey(char) ||
            KeyboardLayouts.shiftCharToScancode.containsKey(char);
        expect(canType, isTrue, reason: "Character '$char' should be typable");
      }
    });

    test('Special whitespace characters (tab, newline, space) map to valid HID scancodes', () {
      expect(KeyboardLayouts.charToScancode.containsKey('\t'), isTrue);
      expect(KeyboardLayouts.charToScancode.containsKey('\n'), isTrue);
      expect(KeyboardLayouts.charToScancode.containsKey('\r'), isTrue);
      expect(KeyboardLayouts.charToScancode.containsKey(' '), isTrue);
    });

    test('Unsupported Unicode / emojis / accented characters are identified as unmappable', () {
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
    });

    test('Windows CRLF and CR are properly normalized to LF', () {
      const rawText = "Line 1\r\nLine 2\rLine 3\nLine 4";
      final normalized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      expect(normalized, "Line 1\nLine 2\nLine 3\nLine 4");
      expect(normalized.contains('\r'), isFalse);
    });

    test('Shifted vs unshifted characters select appropriate scancode and modifier', () {
      // Lowercase 'a' -> scancode 0x04, unshifted
      expect(KeyboardLayouts.charToScancode['a'], 0x04);
      expect(KeyboardLayouts.shiftCharToScancode.containsKey('a'), isFalse);

      // Uppercase 'A' -> scancode 0x04, shifted
      expect(KeyboardLayouts.shiftCharToScancode['A'], 0x04);
      expect(KeyboardLayouts.charToScancode.containsKey('A'), isFalse);

      // Digit '1' vs '!'
      expect(KeyboardLayouts.charToScancode['1'], 0x1E);
      expect(KeyboardLayouts.shiftCharToScancode['!'], 0x1E);
    });
  });
}
