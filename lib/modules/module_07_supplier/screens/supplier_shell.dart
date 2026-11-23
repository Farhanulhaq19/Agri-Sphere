import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'supplier_dashboard_screen.dart';
import 'supplier_products_screen.dart';
import 'supplier_orders_screen.dart';
import 'supplier_profile_screen.dart';

class SupplierShell extends StatefulWidget {
  const SupplierShell({super.key});
  @override
  State<SupplierShell> createState() => _SupplierShellState();
}

class _SupplierShellState extends State<SupplierShell> {
  int _i = 0;
  void _go(int i) => setState(() => _i = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      SupplierDashboardScreen(goTab: _go),
      const SupplierProductsScreen(),
      const SupplierOrdersScreen(),
      const SupplierProfileScreen(),
    ];
    return Scaffold(
      body: KeyedSubtree(key: ValueKey(_i), child: pages[_i]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: _go,
        backgroundColor: Colors.white,
        indicatorColor: C.green,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: Colors.white), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2, color: Colors.white), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping, color: Colors.white), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: Colors.white), label: 'Profile'),
        ],
      ),
    );
  }
}