import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color teal = Color(0xFF00B8A9);
  static const Color danger = Color(0xFFD94A4A);
  static const Color lightBackground = Color(0xFFE5E8EB);
  static const Color darkBackground = Color(0xFF202428);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.teal,
        error: AppColors.danger,
        surface: Colors.white.withValues(alpha: 0.5),
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.teal,
        error: AppColors.danger,
        surface: Colors.white.withValues(alpha: 0.08),
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
