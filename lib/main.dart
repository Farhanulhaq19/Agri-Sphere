import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'modules/module_01_auth/screens/onboarding_screen.dart';

void main() {
  runApp(const AgriSphereApp());
}

class AgriSphereApp extends StatelessWidget {
  const AgriSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriSphere',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const OnboardingScreen(),
    );
  }
}