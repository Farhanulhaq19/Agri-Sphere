import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// Loaders, unloaders and supervisors of the warehouse.
class LabourScreen extends StatelessWidget {
  const LabourScreen({super.key});

  static const _roles = ['Loader', 'Unloader', 'Supervisor', 'Driver', 'Guard'];

  Future<void> _form(BuildContext context, Future<void> Function() reload, [Map? l]) async {
    final name = TextEditingController(text: l == null ? '' : '${l['name']}');
    final phone = TextEditingController(text: l == null ? '' : '${l['phone'] ?? ''}');
    final wage = TextEditingController(text: l == null || toNum(l['dailyWage']) == 0 ? '' : '${toNum(l['dailyWage']).round()}');
    var role = l == null ? _roles.first : '${l['role']}';
    var status = l == null ? 'available' : '${l['status']}';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l == null ? 'Add worker' : 'Edit worker', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                field('Full name', name, icon: Icons.person_outline),
                field('Phone', phone, type: TextInputType.phone, icon: Icons.phone_outlined),
                Text(tr('Role'), style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ChipRow(items: _roles, selected: role, onSelect: (v) => setM(() => role = v)),
                const SizedBox(height: 12),
                field('Daily wage (Rs)', wage, type: TextInputType.number),
                if (l != null) ...[
                  Text(tr('Status'), style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ChipRow(items: const ['available', 'busy', 'off'], selected: status, onSelect: (v) => setM(() => status = v)),
                  const SizedBox(height: 12),
                ],
                PrimaryButton(label: tr('Save'), icon: Icons.check, onPressed: () => Navigator.pop(ctx, true)),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    final body = {'name': name.text.trim(), 'phone': phone.text.trim(), 'role': role, 'dailyWage': wage.text.trim(), 'status': status};
    final ok = await runAction(context, () => l == null ? AgriApi.post('/warehouse-owner/labour', body) : AgriApi.put('/warehouse-owner/labour/${l['id']}', body), ok: 'Saved');
    if (ok) await reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: tr('Labour'),
      subtitle: tr('Loading and unloading team'),
      load: () => AgriApi.get('/warehouse-owner/labour'),
      empty: 'No workers yet.\nAdd labour to schedule loading and unloading.',
      emptyIcon: Icons.groups_outlined,
      fab: (reload) => FloatingActionButton.extended(
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        onPressed: () => _form(context, reload),
        icon: const Icon(Icons.person_add_alt),
        label: Text(tr('Add worker')),
      ),
      item: (ctx, l, reload) => AppCard(
        onTap: () => _form(ctx, reload, l),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.groups, color: C.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('${l['name']}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${l['role']}  -  ${rs(toNum(l['dailyWage']))}/${tr('day')}', style: const TextStyle(fontSize: 12, color: C.grey)),
                  if ('${l['phone'] ?? ''}'.isNotEmpty) Text(tr('${l['phone']}'), style: const TextStyle(fontSize: 11.5, color: C.grey)),
                ],
              ),
            ),
            Pill(flowLabel('${l['status']}'), color: '${l['status']}' == 'available' ? C.green : ('${l['status']}' == 'busy' ? C.amber : C.grey)),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: () async {
                if (await confirmDialog(ctx, 'Remove ${l['name']}?', 'They will no longer be available for tasks.', yes: 'Remove') && ctx.mounted) {
                  final ok = await runAction(ctx, () => AgriApi.delete('/warehouse-owner/labour/${l['id']}'), ok: 'Removed');
                  if (ok) await reload();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
