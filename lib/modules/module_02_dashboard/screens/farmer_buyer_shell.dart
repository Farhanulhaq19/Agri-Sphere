import 'package:flutter/material.dart';
import 'package:agrisphere/modules/module_04_marketplace/widgets/product_card.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_02_dashboard/screens/dashboard_screen.dart';
import 'package:agrisphere/modules/module_03_crops/screens/my_crops_screen.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/marketplace_screen.dart';
import 'package:agrisphere/modules/module_05_orders/screens/cart_screen.dart';
import 'package:agrisphere/modules/module_05_orders/screens/order_tracking_screen.dart';

class FarmerBuyerShell extends StatefulWidget {
  const FarmerBuyerShell({super.key});
  @override
  State<FarmerBuyerShell> createState() => _FarmerBuyerShellState();
}

class _FarmerBuyerShellState extends State<FarmerBuyerShell> {
  int _i = 0;
  void _go(int i) => setState(() => _i = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(goTab: _go),
      const MyCropsScreen(),
      MarketplaceScreen(goTab: _go),
      CartScreen(goTab: _go),
      const OrdersScreen(),
    ];
    return Scaffold(
      body: KeyedSubtree(key: ValueKey(_i), child: pages[_i]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: _go,
        backgroundColor: Colors.white,
        indicatorColor: C.green,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Colors.white),
            label: tr('Home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.grass_outlined),
            selectedIcon: Icon(Icons.grass, color: Colors.white),
            label: tr('Crops'),
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search, color: Colors.white),
            label: tr('Explore'),
          ),
          NavigationDestination(
            icon: ValueListenableBuilder<int>(
              valueListenable: CartBadge.count,
              builder: (_, n, _) => Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.shopping_cart_outlined)),
            ),
            selectedIcon: const Icon(Icons.shopping_cart, color: Colors.white),
            label: tr('Cart'),
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping, color: Colors.white),
            label: tr('Orders'),
          ),
        ],
      ),
    );
  }
}
