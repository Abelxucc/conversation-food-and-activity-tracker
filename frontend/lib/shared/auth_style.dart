import 'package:flutter/material.dart';

class AuthStyle {
  static const green = Color(0xFF009B58);
  static const background = Color(0xFFF0F3E7);
  static const muted = Color(0xFF858782);
  static const serif = TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: ['serif'],
  );

  static InputDecoration inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF525252), fontSize: 16),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFD5D5D5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFD5D5D5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: green, width: 2),
      ),
    );
  }

  static ButtonStyle get primaryButton => FilledButton.styleFrom(
    backgroundColor: green,
    foregroundColor: Colors.white,
    disabledBackgroundColor: green.withValues(alpha: 0.55),
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: serif.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
  );
}
