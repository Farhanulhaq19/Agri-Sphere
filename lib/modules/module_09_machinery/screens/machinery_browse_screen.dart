import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/voice.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machine_detail_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machinery_widgets.dart';

/// Farmers (and warehouse owners) browse machinery to rent or buy.
class MachineryBrowseScreen extends StatefulWidget {
  const MachineryBrowseScreen({super.key});
  @override
  State<MachineryBrowseScreen> createState() => _MachineryBrowseScreenState();
}

class _MachineryBrowseScreenState extends State<MachineryBrowseScreen> {
  static const _cats = ['All', 'Tractor', 'Harvester', 'Thresher', 'Sprayer', 'Plough', 'Seeder', 'Trolley', 'Water Pump', 'Other'];
  static const _modes = {'All': '', 'Rent': 'rent', 'Buy': 'sale'};
  final _q = TextEditingController();
  String _cat = 'All';
  String _mode = 'All';
  bool _technician = false;
  bool _freeNow = false;
  bool _near = false;
  String _applied = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String get _query {
    final p = <String>[];
    if (_cat != 'All') p.add('category=${Uri.encodeQueryComponent(_cat)}');
    if (_modes[_mode]!.isNotEmpty) p.add('mode=${_modes[_mode]}');
    if (_technician) p.add('operator=1');
    if (_freeNow) p.add('availableNow=1');
    if (_applied.isNotEmpty) p.add('q=${Uri.encodeQueryComponent(_applied)}');
    return '?${p.join('&')}${_near ? MyLocation.query() : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      key: ValueKey(_query),
      title: tr('Rent or buy machinery'),
      subtitle: tr('Book in advance and track your machine'),
      headerBottom: TextField(
        controller: _q,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) => setState(() => _applied = v.trim()),
        decoration: InputDecoration(
          hintText: tr('Search tractor, harvester, city...'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _applied.isEmpty
              ? VoiceSearchButton(onResult: (t) {
                  _q.text = t;
                  setState(() => _applied = t.trim());
                })
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _q.clear();
                    setState(() => _applied = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      load: () => AgriApi.get('/machinery$_query'),
      empty: 'No machines match your search',
      emptyIcon: Icons.agriculture_outlined,
      top: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroBanner(image: 'assets/img/hero_tractor.png', title: tr('Rent or buy machinery'), subtitle: tr('Tractors, harvesters and more'), height: 130),
          const SizedBox(height: 12),
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _cats.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(tr(c)),
                  selected: c == _cat,
                  showCheckmark: false,
                  selectedColor: C.green,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(color: c == _cat ? Colors.white : C.text, fontSize: 12),
                  onSelected: (_) => setState(() => _cat = c),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._modes.keys.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tr(c)),
                    selected: c == _mode,
                    showCheckmark: false,
                    selectedColor: C.dark,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(color: c == _mode ? Colors.white : C.text, fontSize: 12),
                    onSelected: (_) => setState(() => _mode = c),
                  ),
                )),
                FilterChip(
                  label: Text(tr('With technician')),
                  selected: _technician,
                  showCheckmark: false,
                  selectedColor: C.amber,
                  backgroundColor: Colors.white,
                  onSelected: (v) => setState(() => _technician = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(tr('Free now')),
                  selected: _freeNow,
                  showCheckmark: false,
                  selectedColor: C.amber,
                  backgroundColor: Colors.white,
                  onSelected: (v) => setState(() => _freeNow = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.near_me, size: 16),
                  label: Text(tr('Near me')),
                  selected: _near,
                  showCheckmark: false,
                  selectedColor: C.amber,
                  backgroundColor: Colors.white,
                  onSelected: (v) async {
                    if (v && await MyLocation.get(context: context) == null) return;
                    setState(() => _near = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
        ],
      ),
      item: (ctx, m, reload) => MachineTile(
        m: m,
        onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => MachineDetailScreen(machineId: '${m['id']}'))),
      ),
    );
  }
}
