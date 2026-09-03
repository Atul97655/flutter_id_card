import 'package:flutter/services.dart';

/// Forces every keystroke to capitals **in the stored value**, not just
/// visually.
///
/// The spec requires the persisted string to be uppercase, because the card
/// renderer, the exports and the Firestore record all read the raw value.
/// Styling with `TextStyle` would leave lowercase data in the database.
///
/// A note on lengths: Dart's `String.toUpperCase` applies *simple* (1:1)
/// Unicode case mapping, so it never changes a string's length - 'straße'
/// becomes 'STRAßE', not 'STRASSE'. The selection is still clamped rather than
/// reused blindly, because an out-of-range offset throws and this code runs on
/// every keystroke in the app.
class UpperCaseTextInputFormatter extends TextInputFormatter {
  const UpperCaseTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String upper = newValue.text.toUpperCase();

    // Fast path: nothing to change (digits, spaces, already-capital letters).
    // Returning the value untouched preserves any active IME composing region.
    if (upper == newValue.text) return newValue;

    return TextEditingValue(
      text: upper,
      selection: _clampSelection(newValue.selection, upper.length),
    );
  }

  static TextSelection _clampSelection(TextSelection selection, int length) {
    if (selection.baseOffset <= length && selection.extentOffset <= length) {
      return selection;
    }
    return TextSelection.collapsed(offset: length);
  }
}

/// Collapses runs of whitespace to a single space as the operator types.
///
/// Double spaces are invisible on screen but push an address onto a third line
/// when rendered at 5 pt, where there is only room for two.
class CollapseWhitespaceFormatter extends TextInputFormatter {
  const CollapseWhitespaceFormatter();

  static final RegExp _runs = RegExp(r'[ \t]{2,}');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!_runs.hasMatch(newValue.text)) return newValue;

    final String collapsed = newValue.text.replaceAll(_runs, ' ');
    final int removed = newValue.text.length - collapsed.length;
    final int offset = (newValue.selection.baseOffset - removed).clamp(0, collapsed.length);

    return TextEditingValue(
      text: collapsed,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Digits only, capped at [maxLength]. Used for the mobile number so the
/// operator physically cannot type an 11th digit or paste in punctuation.
class DigitsOnlyFormatter extends TextInputFormatter {
  const DigitsOnlyFormatter({this.maxLength});

  final int? maxLength;

  static final RegExp _nonDigit = RegExp(r'[^0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(_nonDigit, '');
    if (maxLength != null && digits.length > maxLength!) {
      digits = digits.substring(0, maxLength!);
    }
    if (digits == newValue.text) return newValue;

    final int removed = newValue.text.length - digits.length;
    final int offset = (newValue.selection.baseOffset - removed).clamp(0, digits.length);

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
