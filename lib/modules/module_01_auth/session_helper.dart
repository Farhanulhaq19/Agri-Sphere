import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/push.dart';
import 'package:agrisphere/core/services/realtime.dart';
import 'package:agrisphere/core/services/api_service.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/modules/module_01_auth/screens/onboarding_screen.dart';

/// Clears the saved login (token, roles, name) and returns to the first screen.
Future<void> logout(BuildContext context) async {
  await Push.stop();
  Realtime.disconnect();
  await ApiService.instance.logout();
  AgriApi.token = null;
  await AgriApi.clearCache();
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    (route) => false,
  );
}
