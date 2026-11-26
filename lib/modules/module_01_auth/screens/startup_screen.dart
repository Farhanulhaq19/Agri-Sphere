import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/api_service.dart';
import 'package:agrisphere/core/theme/app_theme.dart';
import 'package:agrisphere/modules/module_01_auth/screens/onboarding_screen.dart';
import 'package:agrisphere/modules/module_01_auth/screens/role_gate_screen.dart';

/// First screen: if the person ticked "Remember me" and has a saved login,
/// open their home straight away. Otherwise show onboarding / login.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    Widget next = const OnboardingScreen();
    try {
      final s = await ApiService.instance.session();
      final remember = await ApiService.instance.remembered();
      if (s != null && remember) next = const RoleGateScreen();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
