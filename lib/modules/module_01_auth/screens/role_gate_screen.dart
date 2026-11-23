import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_02_dashboard/screens/farmer_buyer_shell.dart';
import 'package:agrisphere/modules/module_07_supplier/screens/supplier_shell.dart';
import 'package:agrisphere/modules/module_06_expert/screens/expert_home_screen.dart';
import 'package:agrisphere/modules/module_08_admin/screens/admin_home_screen.dart';

/// Open this after login / verification. It asks the backend who the user is
/// (this also creates the supplier / expert profile on first login) and shows the right home.
class RoleGateScreen extends StatefulWidget {
  const RoleGateScreen({super.key});
  @override
  State<RoleGateScreen> createState() => _RoleGateScreenState();
}

class _RoleGateScreenState extends State<RoleGateScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/me');
  }

  void _reload() => setState(() => _f = AgriApi.get('/me'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          switch ('${(data as Map)['role']}') {
            case 'supplier':
              return const SupplierShell();
            case 'expert':
              return const ExpertHomeScreen();
            case 'admin':
              return const AdminHomeScreen();
            default:
              return const FarmerBuyerShell();
          }
        },
      ),
    );
  }
}