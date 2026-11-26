import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machine_form_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machinery_widgets.dart';

/// All machines the owner has listed (tractor, harvester, sprayer ...).
class MyMachinesScreen extends StatelessWidget {
  const MyMachinesScreen({super.key});

  Future<void> _status(BuildContext context, Map m, String status, Future<void> Function() reload) async {
    final ok = await runAction(context, () => AgriApi.patch('/machinery-owner/machines/${m['id']}/status', {'status': status}), ok: 'Status updated');
    if (ok) await reload();
  }

  Future<void> _location(BuildContext context, Map m, Future<void> Function() reload) async {
    final city = TextEditingController(text: '${m['city'] ?? ''}');
    final note = TextEditingController(text: '${m['locationNote'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Machine location')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: city, decoration: InputDecoration(labelText: tr('City / area'), border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: InputDecoration(labelText: tr('Where exactly? (optional)'), border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Save'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await runAction(context, () => AgriApi.patch('/machinery-owner/machines/${m['id']}/status', {'city': city.text.trim(), 'locationNote': note.text.trim()}), ok: 'Location updated');
    if (done) await reload();
  }

  void _menu(BuildContext context, Map m, Future<void> Function() reload) {
    final sold = '${m['status']}' == 'sold';
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
              title: Text(tr('Edit details & prices')),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(context, MaterialPageRoute(builder: (_) => MachineFormScreen(machine: m)));
                await reload();
              },
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined, color: C.green),
              title: Text(tr('Update location')),
              onTap: () {
                Navigator.pop(ctx);
                _location(context, m, reload);
              },
            ),
            if (!sold && '${m['status']}' != 'available')
              ListTile(leading: const Icon(Icons.check_circle_outline, color: C.green), title: Text(tr('Mark available')), onTap: () { Navigator.pop(ctx); _status(context, m, 'available', reload); }),
            if (!sold && '${m['status']}' != 'maintenance')
              ListTile(leading: const Icon(Icons.build_outlined, color: C.amber), title: Text(tr('Send to maintenance')), onTap: () { Navigator.pop(ctx); _status(context, m, 'maintenance', reload); }),
            if (!sold && '${m['status']}' != 'inactive')
              ListTile(leading: const Icon(Icons.pause_circle_outline, color: C.grey), title: Text(tr('Hide from farmers')), onTap: () { Navigator.pop(ctx); _status(context, m, 'inactive', reload); }),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(tr('Delete machine'), style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                if (await confirmDialog(context, 'Delete ${m['name']}?', 'This cannot be undone.', yes: 'Delete') && context.mounted) {
                  final ok = await runAction(context, () => AgriApi.delete('/machinery-owner/machines/${m['id']}'), ok: 'Deleted');
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
      title: tr('My machinery'),
      subtitle: tr('Tractors, harvesters and more'),
      load: () => AgriApi.get('/machinery-owner/machines'),
      empty: 'No machines yet.\nTap "Add machine" to list your first one.',
      emptyAction: EmptyAction('Add your first machine', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MachineFormScreen()))),
      emptyIcon: Icons.agriculture_outlined,
      fab: (reload) => FloatingActionButton.extended(
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const MachineFormScreen()));
          await reload();
        },
        icon: const Icon(Icons.add),
        label: Text(tr('Add machine')),
      ),
      item: (ctx, m, reload) => MachineTile(
        m: m,
        onTap: () => _menu(ctx, m, reload),
        footer: Row(
          children: [
            Text('${toNum(m['totalBookings']).round()} jobs done', style: const TextStyle(fontSize: 11.5, color: C.grey)),
            const Spacer(),
            Text(tr('Tap for options'), style: TextStyle(fontSize: 11.5, color: C.green)),
          ],
        ),
      ),
    );
  }
}
