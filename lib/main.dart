import 'package:flutter/material.dart';
import 'package:agrisphere/core/theme/app_theme.dart';
import 'package:agrisphere/modules/module_01_auth/screens/onboarding_screen.dart';
import 'package:agrisphere/modules/module_02_dashboard/screens/farmer_buyer_shell.dart';
// ignore: unused_import
import 'package:agrisphere/core/widgets/app_ui.dart';

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
      routes: {
        '/farmer': (_) => const FarmerBuyerShell(),
      },
    );
  }
}