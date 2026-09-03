import 'package:flutter/services.dart';
import 'package:flutter_id_card/shared/utils/input_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Applies a formatter the way a Flutter text field does: previous value in,
/// candidate new value in, formatted value out.
TextEditingValue apply(
  TextInputFormatter formatter,
  String oldText,
  String newText, {
  int? selection,
}) {
  return formatter.formatEditUpdate(
    TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: oldText.length),
    ),
    TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection ?? newText.length),
    ),
  );
}

void main() {
  group('UpperCaseTextInputFormatter', () {
    const UpperCaseTextInputFormatter formatter = UpperCaseTextInputFormatter();

    test('upper-cases the stored value, not just the display', () {
      expect(apply(formatter, '', 'ramesh').text, 'RAMESH');
    });

    test('leaves already-capital text untouched', () {
      final TextEditingValue result = apply(formatter, 'RAM', 'RAMESH');
      expect(result.text, 'RAMESH');
    });

    test('passes digits, spaces and punctuation through unchanged', () {
      expect(apply(formatter, '', '12/A, MG ROAD').text, '12/A, MG ROAD');
    });

    test('keeps the caret where the user put it on a mid-string edit', () {
      // Typing 'x' into "ABDE" at index 2 -> "ABXDE", caret after the X.
      final TextEditingValue result =
          apply(formatter, 'ABDE', 'abxde', selection: 3);
      expect(result.text, 'ABXDE');
      expect(result.selection.baseOffset, 3);
    });

    test('applies simple case mapping without changing length', () {
      // Dart uses simple (1:1) Unicode case mapping, so the sharp s is left
      // alone rather than expanding to 'SS'. Pinning this down because the
      // formatter's caret handling depends on the length being stable.
      final TextEditingValue result = apply(formatter, '', 'straße');
      expect(result.text, 'STRAßE');
      expect(result.text.length, 'straße'.length);
    });

    test('never leaves the caret outside the text', () {
      final TextEditingValue result = apply(formatter, '', 'ramesh', selection: 99);
      expect(
        result.selection.baseOffset,
        lessThanOrEqualTo(result.text.length),
        reason: 'an out-of-range offset throws when Flutter applies it',
      );
    });

    test('handles an empty field', () {
      expect(apply(formatter, 'A', '').text, '');
    });
  });

  group('DigitsOnlyFormatter', () {
    const DigitsOnlyFormatter formatter = DigitsOnlyFormatter(maxLength: 10);

    test('strips non-digits from a pasted number', () {
      expect(apply(formatter, '', '+91 98765-43210').text, '919876543210'.substring(0, 10));
    });

    test('caps at maxLength', () {
      expect(apply(formatter, '', '12345678901234').text, '1234567890');
    });

    test('allows a partial number while typing', () {
      expect(apply(formatter, '987', '9876').text, '9876');
    });

    test('caret never lands outside the trimmed text', () {
      final TextEditingValue result =
          apply(formatter, '', '98-76-54-32-10-99', selection: 17);
      expect(result.selection.baseOffset, lessThanOrEqualTo(result.text.length));
    });
  });

  group('CollapseWhitespaceFormatter', () {
    const CollapseWhitespaceFormatter formatter = CollapseWhitespaceFormatter();

    test('collapses double spaces that would push the address to 3 lines', () {
      expect(
        apply(formatter, '', 'MG  ROAD,   HUBLI').text,
        'MG ROAD, HUBLI',
      );
    });

    test('leaves single spaces alone', () {
      final TextEditingValue result = apply(formatter, '', 'MG ROAD HUBLI');
      expect(result.text, 'MG ROAD HUBLI');
    });
  });
}
