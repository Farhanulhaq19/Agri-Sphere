import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// Operators and mechanics the owner can send with a machine (paid per hour).
class TechniciansScreen extends StatelessWidget {
  const TechniciansScreen({super.key});

  static const _skills = ['Tractor Operator', 'Harvester Operator', 'Mechanic', 'Driver', 'Sprayer Operator'];

  Future<void> _form(BuildContext context, Future<void> Function() reload, [Map? t]) async {
    final name = TextEditingController(text: t == null ? '' : '${t['name']}');
    final phone = TextEditingController(text: t == null ? '' : '${t['phone'] ?? ''}');
    final rate = TextEditingController(text: t == null || toNum(t['hourlyRate']) == 0 ? '' : '${toNum(t['hourlyRate']).round()}');
    final exp = TextEditingController(text: t == null || toNum(t['experienceYears']) == 0 ? '' : '${toNum(t['experienceYears']).round()}');
    var skill = t == null ? _skills.first : ('${t['skill']}');
    var status = t == null ? 'available' : '${t['status']}';
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
                Text(t == null ? 'Add technician' : 'Edit technician', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                field('Full name', name, icon: Icons.person_outline),
                field('Phone', phone, type: TextInputType.phone, icon: Icons.phone_outlined),
                Text(tr('Skill'), style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ChipRow(items: _skills, selected: skill, onSelect: (v) => setM(() => skill = v)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: field('Rs per hour', rate, type: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: field('Experience (years)', exp, type: TextInputType.number)),
                  ],
                ),
                if (t != null) ...[
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
    final body = {'name': name.text.trim(), 'phone': phone.text.trim(), 'skill': skill, 'hourlyRate': rate.text.trim(), 'experienceYears': exp.text.trim(), 'status': status};
    final ok = await runAction(
      context,
      () => t == null ? AgriApi.post('/machinery-owner/technicians', body) : AgriApi.put('/machinery-owner/technicians/${t['id']}', body),
      ok: 'Saved',
    );
    if (ok) await reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: tr('Technicians'),
      subtitle: tr('Operators you can send with your machines'),
      load: () => AgriApi.get('/machinery-owner/technicians'),
      empty: 'No technicians yet.\nAdd operators so farmers can book a machine with a driver.',
      emptyIcon: Icons.engineering_outlined,
      fab: (reload) => FloatingActionButton.extended(
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        onPressed: () => _form(context, reload),
        icon: const Icon(Icons.person_add_alt),
        label: Text(tr('Add technician')),
      ),
      item: (ctx, t, reload) => AppCard(
        onTap: () => _form(ctx, reload, t),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.engineering, color: C.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('${t['name']}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${t['skill']}  -  ${rs(toNum(t['hourlyRate']))}/${tr('hr')}', style: const TextStyle(fontSize: 12, color: C.grey)),
                  if ('${t['phone'] ?? ''}'.isNotEmpty) Text(tr('${t['phone']}'), style: const TextStyle(fontSize: 11.5, color: C.grey)),
                ],
              ),
            ),
            Pill(flowLabel('${t['status']}'), color: '${t['status']}' == 'available' ? C.green : ('${t['status']}' == 'busy' ? C.amber : C.grey)),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: () async {
                if (await confirmDialog(ctx, 'Remove ${t['name']}?', 'They will no longer be available to assign.', yes: 'Remove') && ctx.mounted) {
                  final ok = await runAction(ctx, () => AgriApi.delete('/machinery-owner/technicians/${t['id']}'), ok: 'Removed');
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
