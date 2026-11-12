import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2E9B52);
  static const Color dark = Color(0xFF0F5A32);
  static const Color light = Color(0xFF3DAF63);
  static const Color bg = Color(0xFFF1F5F2);
  static const Color text = Color(0xFF1B2B22);
  static const Color muted = Color(0xFF6B7C72);
  static const Color border = Color(0xFFE3EBE5);
  static const Color sun = Color(0xFFF5C342);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0F5A32), Color(0xFF2E9B52)],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3DAF63), Color(0xFF237A41)],
  );
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.primary,
      );
}