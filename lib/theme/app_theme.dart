import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme Color Palette
  static const Color primaryLight = Color(0xFFF8FAFC); // Clean slate white scaffold background
  static const Color secondaryLight = Color(0xFFFFFFFF); // Pure white card surfaces
  static const Color accentIndigo = Color(0xFF4F46E5); // Royal indigo for main actions
  static const Color accentGreen = Color(0xFF10B981); // Vibrant Emerald Green for positive elements/loans
  static const Color accentTeal = Color(0xFF0D9488); // Deep Teal for standard actions
  static const Color accentGold = Color(0xFFD97706); // Amber Gold for Lucky Draw & Premium flows
  static const Color accentOrange = Color(0xFFEA580C); // Radiant Orange for warnings/reminders
  static const Color textPrimary = Color(0xFF0F172A); // Slate charcoal body text
  static const Color textSecondary = Color(0xFF475569); // Slate grey subtle captions
  static const Color borderLight = Color(0xFFE2E8F0); // Subtle light grey borders

  // Lighten Theme Map (aliases for dark colors to prevent compile errors while keeping it light)
  static const Color primaryDark = Color(0xFFF1F5F9); // Very light slate gray/white scaffold background
  static const Color secondaryDark = Color(0xFFFFFFFF); // Pure white card surfaces
  static const Color borderDark = Color(0xFFCBD5E1); // Light borders

  // Base gradients
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFFEEF2F6), Color(0xFFF8FAFC)], // Light silver-blue gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)], // Soft light green gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)], // Warm light gold gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: primaryLight,
      primaryColor: primaryLight,
      colorScheme: const ColorScheme.light(
        primary: accentIndigo,
        secondary: accentGreen,
        surface: secondaryLight,
        error: Colors.redAccent,
      ),
      cardTheme: CardThemeData(
        color: secondaryLight,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: 1.0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentIndigo,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryLight,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentIndigo, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 15),
        hintStyle: const TextStyle(color: borderLight, fontSize: 15),
      ),
    );
  }
}
