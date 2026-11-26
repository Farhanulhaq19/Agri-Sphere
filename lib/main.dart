import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/theme/app_theme.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/services/api_service.dart';
import 'package:agrisphere/modules/module_01_auth/screens/onboarding_screen.dart';
import 'package:agrisphere/modules/module_01_auth/screens/startup_screen.dart';
import 'package:agrisphere/modules/module_02_dashboard/screens/farmer_buyer_shell.dart';

final appNavigator = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLang.load();
  await AppPrefs.load();
  var handling = false;
  AgriApi.onSessionExpired = () async {
    if (handling) return;
    handling = true;
    await ApiService.instance.logout();
    AgriApi.token = null;
    await AgriApi.clearCache();
    final nav = appNavigator.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const OnboardingScreen()), (r) => false);
      final ctx = appNavigator.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Your session expired. Please log in again.')));
      }
    }
    handling = false;
  };
  runApp(const AgriSphereApp());
}

class AgriSphereApp extends StatelessWidget {
  const AgriSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigator,
      title: tr('AgriSphere'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (c, child) => langDirection(c, appShell(c, child)),
      home: const StartupScreen(),
      routes: {'/farmer': (_) => const FarmerBuyerShell()},
    );
  }
}
