import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// Service, repair and inspection plans for each machine.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  Future<void> _add(BuildContext context, Future<void> Function() reload) async {
    List machines = [];
    try {
      machines = ((await AgriApi.get('/machinery-owner/machines') as Map)['items'] as List?) ?? [];
    } catch (e) {
      if (context.mounted) snack(context, cleanErr(e), error: true);
      return;
    }
    if (!context.mounted) return;
    if (machines.isEmpty) {
      snack(context, 'Add a machine first', error: true);
      return;
    }
    String? machineId = '${machines.first['id']}';
    var kind = 'Service';
    DateTime? when;
    final cost = TextEditingController();
    final note = TextEditingController();
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
                Text(tr('Plan maintenance'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(tr('Machine'), style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ChipRow(
                  items: machines.map((m) => '${m['name']}').toList(),
                  selected: '${machines.firstWhere((m) => '${m['id']}' == machineId)['name']}',
                  onSelect: (v) => setM(() => machineId = '${machines.firstWhere((m) => '${m['name']}' == v)['id']}'),
                ),
                const SizedBox(height: 12),
                Text(tr('Type'), style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ChipRow(items: const ['Service', 'Repair', 'Inspection', 'Tyres', 'Oil change'], selected: kind, onSelect: (v) => setM(() => kind = v)),
                const SizedBox(height: 12),
                pickerField('Date', when == null ? 'Pick a date' : fmtDate(when!), Icons.event, () async {
                  final d = await pickDate(ctx);
                  if (d != null) setM(() => when = d);
                }),
                field('Estimated cost (Rs)', cost, type: TextInputType.number),
                field('Note', note, lines: 2),
                PrimaryButton(
                  label: tr('Save'),
                  icon: Icons.check,
                  onPressed: () {
                    if (when == null) {
                      snack(ctx, 'Pick a date', error: true);
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    final ok = await runAction(
      context,
      () => AgriApi.post('/machinery-owner/maintenance', {'machineId': machineId, 'kind': kind, 'date': when!.toIso8601String(), 'cost': cost.text.trim(), 'note': note.text.trim()}),
      ok: 'Maintenance planned',
    );
    if (ok) await reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: tr('Maintenance'),
      subtitle: tr('Keep every machine in good shape'),
      load: () => AgriApi.get('/machinery-owner/maintenance'),
      empty: 'No maintenance planned yet',
      emptyIcon: Icons.build_circle_outlined,
      fab: (reload) => FloatingActionButton.extended(
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        onPressed: () => _add(context, reload),
        icon: const Icon(Icons.add),
        label: Text(tr('Plan')),
      ),
      item: (ctx, m, reload) {
        final done = '${m['status']}' == 'done';
        return AppCard(
          child: Row(
            children: [
              Icon(done ? Icons.check_circle : Icons.build_outlined, color: done ? C.green : C.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m['machineName']} - ${m['kind']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('${fmtDate(DateTime.tryParse('${m['date']}')?.toLocal() ?? DateTime.now())}  -  ${rs(toNum(m['cost']))}', style: const TextStyle(fontSize: 11.5, color: C.grey)),
                    if ('${m['note'] ?? ''}'.isNotEmpty) Text(tr('${m['note']}'), style: const TextStyle(fontSize: 11.5, color: C.grey)),
                  ],
                ),
              ),
              if (!done)
                TextButton(
                  onPressed: () async {
                    final ok = await runAction(ctx, () => AgriApi.patch('/machinery-owner/maintenance/${m['id']}/done'), ok: 'Marked done');
                    if (ok) await reload();
                  },
                  child: Text(tr('Done')),
                ),
            ],
          ),
        );
      },
    );
  }
}
