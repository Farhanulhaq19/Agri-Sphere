import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/booking_detail_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machinery_widgets.dart';

/// Requests, active jobs and history for the owner.
class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});
  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  static const _tabs = {'Requests': 'requests', 'Active': 'active', 'History': 'history'};
  String _tab = 'Requests';

  @override
  Widget build(BuildContext context) {
    final status = _tabs[_tab]!;
    return ListPage(
      key: ValueKey(_tab),
      title: tr('Bookings'),
      subtitle: tr('Manage requests and jobs'),
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
      load: () => AgriApi.get('/machinery-owner/bookings?status=$status'),
      empty: status == 'requests' ? 'No pending requests' : (status == 'active' ? 'No active jobs' : 'No past bookings'),
      emptyIcon: Icons.event_busy_outlined,
      item: (ctx, b, reload) => MachineBookingTile(
        b: b,
        ownerView: true,
        onTap: () async {
          await Navigator.push(ctx, MaterialPageRoute(builder: (_) => MachineBookingDetailScreen(bookingId: '${b['id']}', ownerView: true)));
          await reload();
        },
      ),
    );
  }
}
