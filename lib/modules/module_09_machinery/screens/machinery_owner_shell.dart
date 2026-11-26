import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_01_auth/screens/account_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/earnings_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/my_machines_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/owner_bookings_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/owner_home_screen.dart';

/// Home of the Machinery Owner role.
class MachineryOwnerShell extends StatefulWidget {
  const MachineryOwnerShell({super.key});
  @override
  State<MachineryOwnerShell> createState() => _MachineryOwnerShellState();
}

class _MachineryOwnerShellState extends State<MachineryOwnerShell> {
  int _i = 0;
  void _go(int i) => setState(() => _i = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      OwnerHomeScreen(goTab: _go),
      const MyMachinesScreen(),
      const OwnerBookingsScreen(),
      const EarningsScreen(),
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
          NavigationDestination(icon: Icon(Icons.agriculture_outlined), selectedIcon: Icon(Icons.agriculture, color: Colors.white), label: tr('Machines')),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note, color: Colors.white), label: tr('Bookings')),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet, color: Colors.white), label: tr('Earnings')),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: Colors.white), label: tr('Account')),
        ],
      ),
    );
  }
}
