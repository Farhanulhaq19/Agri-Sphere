import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_form_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_widgets.dart';

class MyWarehousesScreen extends StatelessWidget {
  const MyWarehousesScreen({super.key});

  void _menu(BuildContext context, Map w, Future<void> Function() reload) {
    final paused = '${w['status']}' == 'paused';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: C.green),
              title: Text(tr('Edit details, rate & capacity')),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(context, MaterialPageRoute(builder: (_) => WarehouseFormScreen(warehouse: w)));
                await reload();
              },
            ),
            ListTile(
              leading: Icon(paused ? Icons.play_circle_outline : Icons.pause_circle_outline, color: paused ? C.green : C.amber),
              title: Text(paused ? 'Accept bookings again' : 'Pause new bookings'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await runAction(context, () => AgriApi.put('/warehouse-owner/warehouses/${w['id']}', {'status': paused ? 'active' : 'paused'}), ok: 'Updated');
                if (ok) await reload();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(tr('Delete warehouse'), style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                if (await confirmDialog(context, 'Delete ${w['name']}?', 'This cannot be undone.', yes: 'Delete') && context.mounted) {
                  final ok = await runAction(context, () => AgriApi.delete('/warehouse-owner/warehouses/${w['id']}'), ok: 'Deleted');
                  if (ok) await reload();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: tr('My warehouses'),
      subtitle: tr('Space, rates and facilities'),
      load: () => AgriApi.get('/warehouse-owner/warehouses'),
      empty: 'No warehouses yet.\nTap "Add warehouse" to list your first one.',
      emptyAction: EmptyAction('Add your first warehouse', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseFormScreen()))),
      emptyIcon: Icons.warehouse_outlined,
      fab: (reload) => FloatingActionButton.extended(
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseFormScreen()));
          await reload();
        },
        icon: const Icon(Icons.add),
        label: Text(tr('Add warehouse')),
      ),
      item: (ctx, w, reload) => WarehouseTile(
        w: w,
        onTap: () => _menu(ctx, w, reload),
        footer: Align(alignment: Alignment.centerRight, child: Text(tr('Tap for options'), style: TextStyle(fontSize: 11.5, color: C.green))),
      ),
    );
  }
}
