import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_01_auth/screens/account_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/my_warehouses_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/owner_storage_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_owner_home_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_payments_screen.dart';

/// Home of the Warehouse Owner role.
class WarehouseOwnerShell extends StatefulWidget {
  const WarehouseOwnerShell({super.key});
  @override
  State<WarehouseOwnerShell> createState() => _WarehouseOwnerShellState();
}

class _WarehouseOwnerShellState extends State<WarehouseOwnerShell> {
  int _i = 0;
  void _go(int i) => setState(() => _i = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      WarehouseOwnerHomeScreen(goTab: _go),
      const MyWarehousesScreen(),
      const OwnerStorageScreen(),
      const WarehousePaymentsScreen(),
      const AccountScreen(),
    ];
    return Scaffold(
      body: KeyedSubtree(key: ValueKey(_i), child: pages[_i]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: _go,
        backgroundColor: Colors.white,
        indicatorColor: C.green,
        destinations: [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: Colors.white), label: tr('Home')),
          NavigationDestination(icon: Icon(Icons.warehouse_outlined), selectedIcon: Icon(Icons.warehouse, color: Colors.white), label: tr('Warehouses')),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2, color: Colors.white), label: tr('Storage')),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet, color: Colors.white), label: tr('Payments')),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: Colors.white), label: tr('Account')),
        ],
      ),
    );
  }
}
