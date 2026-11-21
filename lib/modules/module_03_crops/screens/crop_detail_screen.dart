import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/sell_produce_screen.dart';

class CropDetailScreen extends StatefulWidget {
  final String cropId;
  const CropDetailScreen({super.key, required this.cropId});
  @override
  State<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends State<CropDetailScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/crops/${widget.cropId}');
  }

  void _reload() => setState(() => _f = AgriApi.get('/crops/${widget.cropId}'));

  Future<void> _toggle(String tid) async {
    try {
      await AgriApi.post('/crops/${widget.cropId}/tasks/$tid/toggle');
      _reload();
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  Future<void> _logProgress(num cur) async {
    try {
      await AgriApi.patch('/crops/${widget.cropId}', {'progress': (cur + 10).clamp(0, 100)});
      _reload();
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete crop?'),
        content: const Text('This removes the crop and its tasks.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AgriApi.delete('/crops/${widget.cropId}');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final m = data as Map;
          final p = toNum(m['progress']);
          final idx = toNum(m['stageIndex']).toInt();
          final stages = (m['stages'] as List).map((e) => '$e').toList();
          final tasks = (m['tasks'] as List?) ?? [];
          return ListView(padding: EdgeInsets.zero, children: [
            GreenHeader(
              title: '${m['name']} - ${m['variety']}',
              subtitle: '${m['field']} - ${m['areaAcres']} acres - ${m['location']}',
              trailing: CircleBtn(icon: Icons.delete_outline, onTap: _delete),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AppCard(
                  child: Row(children: [
                    Ring(p, size: 80),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Pill('${m['stage']} stage'),
                        const SizedBox(height: 8),
                        Text('Day ${m['dayNumber']} of ${m['totalDays']}', style: const TextStyle(fontSize: 12)),
                        Text('Harvest: ${m['expectedHarvest'] ?? '-'}', style: const TextStyle(fontSize: 12, color: C.grey)),
                        Text('Est. yield: ${toNum(m['estYieldKg']).round()} kg', style: const TextStyle(fontSize: 12, color: C.grey)),
                        Text('Health: ${toNum(m['health']).round()}%', style: const TextStyle(fontSize: 12, color: C.grey)),
                      ]),
                    ),
                  ]),
                ),
                const SectionTitle('Growth stages'),
                Row(
                  children: List.generate(
                    stages.length,
                    (i) => Expanded(
                      child: Column(children: [
                        Container(
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(color: i <= idx ? C.green : C.line, borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 6),
                        Text(stages[i], style: TextStyle(fontSize: 10, color: i == idx ? C.green : C.grey, fontWeight: i == idx ? FontWeight.w700 : FontWeight.w400)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const SectionTitle('Upcoming tasks'),
                if (tasks.isEmpty) const AppCard(child: Text('No tasks scheduled', style: TextStyle(color: C.grey))),
                ...tasks.map((t) {
                  final done = t['done'] == true;
                  return AppCard(
                    onTap: () => _toggle('${t['id']}'),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(color: done ? C.light : const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(10)),
                        child: Icon(done ? Icons.check : Icons.water_drop_outlined, size: 18, color: done ? C.green : C.amber),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${t['title']}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, decoration: done ? TextDecoration.lineThrough : null)),
                          Text('${t['when']} - ${t['field']}', style: const TextStyle(fontSize: 11, color: C.grey)),
                        ]),
                      ),
                      Pill(done ? 'Done' : 'Due', color: done ? C.green : C.amber),
                    ]),
                  );
                }),
                const SizedBox(height: 8),
                if (p < 100) PrimaryButton(label: 'Log progress (+10%)', icon: Icons.trending_up, onPressed: () => _logProgress(p)),
                if (p >= 100)
                  PrimaryButton(
                    label: 'Sell this crop',
                    icon: Icons.sell_outlined,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SellProduceScreen(cropName: '${m['name']}'))),
                  ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}