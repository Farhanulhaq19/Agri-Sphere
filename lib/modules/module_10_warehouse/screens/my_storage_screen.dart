import 'package:flutter/material.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_browse_screen.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/storage_booking_detail_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_widgets.dart';

/// The farmer's stored crops: monitor stock, pay, rate.
class MyStorageScreen extends StatefulWidget {
  const MyStorageScreen({super.key});
  @override
  State<MyStorageScreen> createState() => _MyStorageScreenState();
}

class _MyStorageScreenState extends State<MyStorageScreen> {
  static const _tabs = {'Active': 'active', 'Past': 'past'};
  String _tab = 'Active';

  @override
  Widget build(BuildContext context) {
    final status = _tabs[_tab]!;
    return ListPage(
      key: ValueKey(_tab),
      title: tr('My stored crops'),
      subtitle: tr('Monitor stock and payments'),
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
      load: () => AgriApi.get('/storage-bookings/mine?status=$status'),
      empty: status == 'active' ? 'No storage bookings.\nFind a warehouse to store your crop.' : 'No past bookings',
      emptyAction: status == 'active' ? EmptyAction('Find a warehouse', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseBrowseScreen())), icon: Icons.search) : null,
      emptyIcon: Icons.inventory_2_outlined,
      item: (ctx, b, reload) => StorageBookingTile(
        b: b,
        onTap: () async {
          await Navigator.push(ctx, MaterialPageRoute(builder: (_) => StorageBookingDetailScreen(bookingId: '${b['id']}')));
          await reload();
        },
      ),
    );
  }
}
