import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_03_crops/screens/add_crop_screen.dart';
import 'package:agrisphere/modules/module_03_crops/screens/crop_detail_screen.dart';

class MyCropsScreen extends StatefulWidget {
  const MyCropsScreen({super.key});
  @override
  State<MyCropsScreen> createState() => _MyCropsScreenState();
}

class _MyCropsScreenState extends State<MyCropsScreen> {
  late Future<dynamic> _f;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/crops');
  }

  void _reload() => setState(() => _f = AgriApi.get('/crops'));

  Future<void> _open(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    if (mounted) _reload();
  }

  Widget _stat(dynamic v, String l) => Expanded(
        child: Column(children: [
          Text('$v', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final m = data as Map;
          final st = (m['stats'] as Map?) ?? {};
          final all = (m['items'] as List?) ?? [];
          final items = _filter == 'All' ? all : all.where((c) => '${c['status']}' == _filter).toList();
          return RefreshIndicator(
            color: C.green,
            onRefresh: () async {
              _reload();
              await _f;
            },
            child: ListView(padding: EdgeInsets.zero, children: [
              GreenHeader(
                title: 'My Crops',
                subtitle: 'Season Rabi 2026',
                trailing: CircleBtn(icon: Icons.add, onTap: () => _open(const AddCropScreen())),
                bottom: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [_stat(st['total'] ?? 0, 'Total'), _stat(st['growing'] ?? 0, 'Growing'), _stat(st['ready'] ?? 0, 'Ready')]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ChipRow(items: const ['All', 'Growing', 'Ready', 'Harvested'], selected: _filter, onSelect: (v) => setState(() => _filter = v)),
                  const SizedBox(height: 14),
                  if (items.isEmpty)
                    const AppCard(child: Text('No crops here yet. Tap + to add one.', style: TextStyle(color: C.grey))),
                  ...items.map((c) {
                    final p = toNum(c['progress']);
                    final ready = '${c['status']}' == 'Ready';
                    return AppCard(
                      onTap: () => _open(CropDetailScreen(cropId: '${c['id']}')),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: catColor('grains').withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.grass, color: catColor('grains')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${c['name']} - ${c['variety']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                              Pill('${c['status']}', color: ready ? C.amber : C.green),
                            ]),
                            Text('${c['field']} - ${c['areaAcres']} acres', style: const TextStyle(fontSize: 11, color: C.grey)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(value: (p / 100).clamp(0.0, 1.0).toDouble(), minHeight: 6, backgroundColor: C.light, color: C.green),
                            ),
                            const SizedBox(height: 3),
                            Text('${p.round()}% grown', style: const TextStyle(fontSize: 10, color: C.grey)),
                          ]),
                        ),
                      ]),
                    );
                  }),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}