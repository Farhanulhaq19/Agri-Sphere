import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_04_marketplace/widgets/product_card.dart';

/// Public page of a farmer / supplier: trust info, all their products and buyer reviews.
class SellerProfileScreen extends StatefulWidget {
  final String sellerId;
  const SellerProfileScreen({super.key, required this.sellerId});
  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  late Future<dynamic> _f = AgriApi.get('/sellers/${widget.sellerId}');
  void _reload() => setState(() => _f = AgriApi.get('/sellers/${widget.sellerId}'));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        body: Async(
          future: _f,
          onRetry: _reload,
          builder: (d) {
            final m = d as Map;
            final st = (m['stats'] as Map?) ?? const {};
            final items = (m['items'] as List?) ?? const [];
            final reviews = ((m['reviews'] as List?) ?? const []).cast<Map>();
            final name = '${m['name']}';
            final since = DateTime.tryParse('${m['memberSince'] ?? ''}');
            final w = MediaQuery.of(context).size.width;
            Widget stat(String v, String l, IconData i) => Expanded(
                  child: Column(children: [
                    Icon(i, color: Colors.white70, size: 18),
                    Text(v, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    Text(tr(l), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                );
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF1BA94C), C.dark]),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleBtn(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                    const SizedBox(height: 10),
                    Row(children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: C.green, fontSize: 26, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(tr(name), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900))),
                            if (m['verified'] == true) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, color: Colors.white, size: 20)),
                          ]),
                          Text('${tr('${m['role']}' == 'supplier' ? 'Supplier' : 'Farmer')} · ${m['city'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                          if (since != null) Text('${tr('Member since')} ${fmtDate(since)}', style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
                        ]),
                      ),
                    ]),
                    if ('${m['bio'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('${m['bio']}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      stat('${toNum(st['rating']) > 0 ? toNum(st['rating']) : '-'}', 'Rating', Icons.star_rounded),
                      stat('${toNum(st['reviews']).round()}', 'Reviews', Icons.rate_review_outlined),
                      stat('${toNum(st['products']).round()}', 'Products', Icons.storefront_outlined),
                      stat('${toNum(st['sales']).round()}', 'Sales', Icons.shopping_bag_outlined),
                    ]),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                  child: Text('${tr('Products')} (${items.length})', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                ),
              ),
              if (items.isEmpty)
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Text(tr('No products right now'), style: const TextStyle(color: C.grey))))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: w > 900 ? 4 : (w > 600 ? 3 : 2),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 252,
                    ),
                    delegate: SliverChildBuilderDelegate((_, i) => ProductCard(p: items[i] as Map), childCount: items.length),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('What buyers say'), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (reviews.isEmpty) Text(tr('No reviews yet'), style: const TextStyle(color: C.grey)),
                    ...reviews.map((r) => AppCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                              Stars(toNum(r['rating']), size: 13),
                            ]),
                            if ('${r['product'] ?? ''}'.isNotEmpty) Text('${tr('Bought')}: ${r['product']}', style: const TextStyle(fontSize: 11, color: C.green)),
                            if ('${r['text'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${r['text']}')),
                            Text(fmtIso(r['at']), style: const TextStyle(fontSize: 10.5, color: C.grey)),
                          ]),
                        )),
                  ]),
                ),
              ),
            ]);
          },
        ),
      );
}
