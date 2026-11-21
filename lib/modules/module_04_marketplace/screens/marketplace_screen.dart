import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/product_detail_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  final void Function(int) goTab;
  const MarketplaceScreen({super.key, required this.goTab});
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _q = TextEditingController();
  String _cat = 'All';
  late Future<dynamic> _f;
  static const _cats = ['Grains', 'Veggies', 'Fruits', 'Seeds', 'Tools'];

  @override
  void initState() {
    super.initState();
    _f = _fetch();
  }

  Future<dynamic> _fetch() {
    final p = <String>[];
    if (_cat != 'All') p.add('category=' + Uri.encodeQueryComponent(_cat));
    if (_q.text.trim().isNotEmpty) p.add('q=' + Uri.encodeQueryComponent(_q.text.trim()));
    final qs = p.isEmpty ? '' : '?' + p.join('&');
    return AgriApi.get('/listings' + qs);
  }

  void _reload() => setState(() => _f = _fetch());

  Future<void> _add(String id) async {
    try {
      await AgriApi.post('/cart', {'listingId': id, 'qtyKg': 10});
      if (mounted) snack(context, 'Added 10 kg to cart');
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  Widget _card(Map p) {
    final col = catColor(p['category']);
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(listingId: '${p['id']}'))),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 100,
            decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Center(child: Icon(catIcon(p['category']), size: 48, color: col)),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text('${p['rating']} - ${p['sellerName']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.grey)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text('${rs(toNum(p['pricePerKg']))}/kg', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: C.green, fontSize: 12))),
                InkWell(
                  onTap: () => _add('${p['id']}'),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: ListView(padding: EdgeInsets.zero, children: [
        GreenHeader(
          eyebrow: 'Deliver to',
          title: 'Islamabad, PK',
          trailing: CircleBtn(icon: Icons.shopping_cart_outlined, onTap: () => widget.goTab(3)),
          bottom: TextField(
            controller: _q,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _reload(),
            decoration: InputDecoration(
              hintText: 'Search wheat, tomato, seeds...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(icon: const Icon(Icons.tune, size: 20), onPressed: _reload),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _cats.map((c) {
                final sel = _cat == c;
                return InkWell(
                  onTap: () {
                    _cat = sel ? 'All' : c;
                    _reload();
                  },
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sel ? C.green : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sel ? C.green : C.line),
                      ),
                      child: Icon(catIcon(c), color: sel ? Colors.white : catColor(c)),
                    ),
                    const SizedBox(height: 4),
                    Text(c, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                  ]),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF5A524), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Fresh harvest deals', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                    Text('Up to 20% off direct from farms', style: TextStyle(fontSize: 11, color: Colors.white)),
                  ]),
                ),
                const Icon(Icons.shopping_basket, color: Colors.white, size: 38),
              ]),
            ),
            SectionTitle(_cat == 'All' ? 'Featured near you' : _cat),
            Async(
              future: _f,
              onRetry: _reload,
              builder: (data) {
                final items = ((data as Map)['items'] as List?) ?? [];
                if (items.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No products found', style: TextStyle(color: C.grey))));
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 205),
                  itemBuilder: (_, i) => _card(items[i] as Map),
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }
}