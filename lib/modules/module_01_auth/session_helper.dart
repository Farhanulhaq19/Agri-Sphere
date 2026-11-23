import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrisphere/modules/module_01_auth/screens/onboarding_screen.dart';

Future<void> logout(BuildContext context) async {
  AgriApi.token = null;
  try {
    final sp = await SharedPreferences.getInstance();
    for (final k in ['token', 'auth_token', 'authToken', 'jwt', 'access_token', 'accessToken']) {
      await sp.remove(k);
    }
  } catch (_) {}
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    (route) => false,
  );
}