import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/storage_booking_detail_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_widgets.dart';

/// Requests, stored crops (stock monitor) and history for the warehouse owner.
class OwnerStorageScreen extends StatefulWidget {
  const OwnerStorageScreen({super.key});
  @override
  State<OwnerStorageScreen> createState() => _OwnerStorageScreenState();
}

class _OwnerStorageScreenState extends State<OwnerStorageScreen> {
  static const _tabs = {'Requests': 'requests', 'In store': 'stored', 'History': 'history'};
  String _tab = 'Requests';

  @override
  Widget build(BuildContext context) {
    final status = _tabs[_tab]!;
    return ListPage(
      key: ValueKey(_tab),
      title: tr('Storage'),
      subtitle: tr('Requests, stock and handling'),
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
      load: () => AgriApi.get('/warehouse-owner/bookings?status=$status'),
      empty: status == 'requests' ? 'No pending requests' : (status == 'stored' ? 'Nothing in store right now' : 'No past bookings'),
      emptyIcon: Icons.inventory_2_outlined,
      item: (ctx, b, reload) => StorageBookingTile(
        b: b,
        ownerView: true,
        onTap: () async {
          await Navigator.push(ctx, MaterialPageRoute(builder: (_) => StorageBookingDetailScreen(bookingId: '${b['id']}', ownerView: true)));
          await reload();
        },
      ),
    );
  }
}
