import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/voice.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_detail_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_widgets.dart';

/// Farmers find nearby warehouses, compare space and rates, then request storage.
class WarehouseBrowseScreen extends StatefulWidget {
  const WarehouseBrowseScreen({super.key});
  @override
  State<WarehouseBrowseScreen> createState() => _WarehouseBrowseScreenState();
}

class _WarehouseBrowseScreenState extends State<WarehouseBrowseScreen> {
  static const _types = ['All', 'Dry Store', 'Cold Storage', 'Grain Silo', 'Open Yard'];
  static const _sorts = {'Newest': '', 'Near me': 'near', 'Cheapest': 'price', 'Top rated': 'rating'};
  final _q = TextEditingController();
  String _type = 'All';
  String _sort = 'Newest';
  String _applied = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String get _query {
    final p = <String>[];
    if (_type != 'All') p.add('type=${Uri.encodeQueryComponent(_type)}');
    if (_sorts[_sort]!.isNotEmpty && _sort != 'Near me') p.add('sort=${_sorts[_sort]}');
    if (_applied.isNotEmpty) p.add('q=${Uri.encodeQueryComponent(_applied)}');
    return '?${p.join('&')}${MyLocation.query(sortNear: _sort == 'Near me')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      key: ValueKey(_query),
      title: tr('Store your crop'),
      subtitle: tr('Find warehouses, compare space and book'),
      headerBottom: TextField(
        controller: _q,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) => setState(() => _applied = v.trim()),
        decoration: InputDecoration(
          hintText: tr('Search city or warehouse...'),
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
      load: () => AgriApi.get('/warehouses$_query'),
      empty: 'No warehouses match your search',
      emptyIcon: Icons.warehouse_outlined,
      top: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroBanner(image: 'assets/img/hero_warehouse.png', title: tr('Store your crop'), subtitle: tr('Find warehouses, compare space and book'), height: 130),
          const SizedBox(height: 12),
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _types.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(tr(c)),
                  selected: c == _type,
                  showCheckmark: false,
                  selectedColor: C.green,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(color: c == _type ? Colors.white : C.text, fontSize: 12),
                  onSelected: (_) => setState(() => _type = c),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _sorts.keys.map((c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tr(c)),
                selected: c == _sort,
                showCheckmark: false,
                selectedColor: C.dark,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(color: c == _sort ? Colors.white : C.text, fontSize: 12),
                onSelected: (_) async {
                  if (c == 'Near me' && MyLocation.last == null && await MyLocation.get(context: context) == null) return;
                  setState(() => _sort = c);
                },
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ),
        ],
      ),
      item: (ctx, w, reload) => WarehouseTile(
        w: w,
        onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => WarehouseDetailScreen(warehouseId: '${w['id']}'))),
      ),
    );
  }
}
