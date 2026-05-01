// VaxTrace AI — App Theme
// High-contrast: Deep Navy #191E5B + Electric Cyan #00E5E5

import 'package:flutter/material.dart';

class VaxColors {
  static const deepNavy       = Color(0xFF191E5B);
  static const navyLight      = Color(0xFF252B7A);
  static const navyDark       = Color(0xFF0F1238);
  static const electricCyan   = Color(0xFF00E5E5);
  static const cyanLight      = Color(0xFF5FFAFA);
  static const cyanDark       = Color(0xFF00B2B2);
  static const surface        = Color(0xFF1E2466);
  static const surfaceLight   = Color(0xFF2A3180);
  static const white          = Color(0xFFFFFFFF);
  static const offWhite       = Color(0xFFF0F4FF);
  static const textSecondary  = Color(0xFFB0BEC5);

  // Risk colors
  static const riskLow        = Color(0xFF4CAF50);
  static const riskMedium     = Color(0xFFFFC107);
  static const riskHigh       = Color(0xFFFF5722);
  static const riskCritical   = Color(0xFFD32F2F);

  static Color riskColor(String level) {
    switch (level) {
      case 'low': return riskLow;
      case 'medium': return riskMedium;
      case 'high': return riskHigh;
      case 'critical': return riskCritical;
      default: return riskLow;
    }
  }
}

class VaxTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: VaxColors.electricCyan,
      secondary: VaxColors.cyanLight,
      surface: VaxColors.surface,
      background: VaxColors.deepNavy,
      onPrimary: VaxColors.deepNavy,
      onSecondary: VaxColors.deepNavy,
      onSurface: VaxColors.white,
      onBackground: VaxColors.white,
    ),
    scaffoldBackgroundColor: VaxColors.deepNavy,
    appBarTheme: const AppBarTheme(
      backgroundColor: VaxColors.navyDark,
      foregroundColor: VaxColors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: VaxColors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardTheme(
      color: VaxColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2A3180), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: VaxColors.electricCyan,
        foregroundColor: VaxColors.deepNavy,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VaxColors.surfaceLight,
      labelStyle: const TextStyle(color: VaxColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: VaxColors.electricCyan, width: 2),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: VaxColors.white, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(color: VaxColors.white, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: VaxColors.white, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: VaxColors.offWhite),
      bodyMedium: TextStyle(color: VaxColors.textSecondary),
    ),
  );
}
