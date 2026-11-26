import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/services/api_service.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_01_auth/screens/login_screen.dart';
import 'package:agrisphere/modules/module_02_dashboard/screens/farmer_buyer_shell.dart';
import 'package:agrisphere/modules/module_06_expert/screens/expert_home_screen.dart';
import 'package:agrisphere/modules/module_07_supplier/screens/supplier_shell.dart';
import 'package:agrisphere/modules/module_08_admin/screens/admin_home_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machinery_owner_shell.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_owner_shell.dart';

/// Open this after login / verification / role switch. It asks the backend who the
/// user is (this also creates the role profile on first login) and opens the home
/// of the ACTIVE role.
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
    _f = _load();
  }

  Future<dynamic> _load() async {
    try {
      return await AgriApi.get('/me');
    } catch (e) {
      // expired / invalid token: go back to the login screen
      if ('$e'.contains('Session expired') || '$e'.contains('Please log in')) {
        await ApiService.instance.logout();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
      rethrow;
    }
  }

  void _reload() => setState(() => _f = _load());

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
            case 'machinery_owner':
              return const MachineryOwnerShell();
            case 'warehouse_owner':
              return const WarehouseOwnerShell();
            default:
              return const FarmerBuyerShell();
          }
        },
      ),
    );
  }
}
