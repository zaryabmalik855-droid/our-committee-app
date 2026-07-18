import 'package:flutter/services.dart';

class CnicValidator {
  // Regex pattern for XXXXX-XXXXXXX-X format
  static final RegExp _cnicRegExp = RegExp(r'^\d{5}-\d{7}-\d{1}$');

  static bool isValid(String cnic) {
    return _cnicRegExp.hasMatch(cnic);
  }
}

class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String text = newValue.text;

    // If text was deleted, do not re-add characters
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) {
      return newValue;
    }

    final StringBuffer newText = StringBuffer();
    int selectionIndex = newValue.selection.end;

    // Filter characters to digits only
    final List<String> digits = text.replaceAll(RegExp(r'\D'), '').split('');
    
    // Construct the formatted CNIC string (XXXXX-XXXXXXX-X)
    for (int i = 0; i < digits.length; i++) {
      if (i == 5) {
        newText.write('-');
        if (selectionIndex > 5) selectionIndex++;
      } else if (i == 12) {
        newText.write('-');
        if (selectionIndex > 12) selectionIndex++;
      }
      
      // Limit to 13 digits (15 characters total with 2 hyphens)
      if (i < 13) {
        newText.write(digits[i]);
      }
    }

    // Clamp selection index to the actual written string length to avoid crashes
    selectionIndex = selectionIndex.clamp(0, newText.length);

    return TextEditingValue(
      text: newText.toString(),
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}
