import 'package:flutter/material.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machinery_browse_screen.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/booking_detail_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machinery_widgets.dart';

/// The renter's own machine bookings (track, pay, rate).
class MyMachineBookingsScreen extends StatefulWidget {
  const MyMachineBookingsScreen({super.key});
  @override
  State<MyMachineBookingsScreen> createState() => _MyMachineBookingsScreenState();
}

class _MyMachineBookingsScreenState extends State<MyMachineBookingsScreen> {
  static const _tabs = {'Active': 'active', 'Past': 'past'};
  String _tab = 'Active';

  @override
  Widget build(BuildContext context) {
    final status = _tabs[_tab]!;
    return ListPage(
      key: ValueKey(_tab),
      title: tr('My machinery bookings'),
      subtitle: tr('Track, pay and rate'),
      headerBottom: Wrap(
        spacing: 8,
        children: _tabs.keys.map((k) => ChoiceChip(
          label: Text(tr(k)),
          selected: k == _tab,
          showCheckmark: false,
          selectedColor: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          labelStyle: TextStyle(color: k == _tab ? C.dark : Colors.white, fontWeight: FontWeight.w600),
          onSelected: (_) => setState(() => _tab = k),
        )).toList(),
      ),
      load: () => AgriApi.get('/machinery-bookings/mine?status=$status'),
      empty: status == 'active' ? 'No active bookings.\nRent or buy a machine to get started.' : 'No past bookings',
      emptyAction: status == 'active' ? EmptyAction('Find a machine', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MachineryBrowseScreen())), icon: Icons.search) : null,
      emptyIcon: Icons.agriculture_outlined,
      item: (ctx, b, reload) => MachineBookingTile(
        b: b,
        onTap: () async {
          await Navigator.push(ctx, MaterialPageRoute(builder: (_) => MachineBookingDetailScreen(bookingId: '${b['id']}')));
          await reload();
        },
      ),
    );
  }
}
