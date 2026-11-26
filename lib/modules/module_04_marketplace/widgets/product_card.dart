import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/media.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/product_detail_screen.dart';
import 'package:agrisphere/modules/module_11_social/favorites.dart';

/// Number of lines in the cart, for badges on the marketplace and bottom bar.
class CartBadge {
  static final ValueNotifier<int> count = ValueNotifier<int>(0);
  static Future<void> refresh() async {
    try {
      count.value = toNum(((await AgriApi.get('/cart/count')) as Map)['count']).round();
    } catch (_) {}
  }
}

String unitOf(Map p) => '${p['unit'] ?? 'kg'}';

/// Smallest amount a buyer can add in one tap (10 kg for produce, 1 for bags / pieces).
int minQty(Map p) => unitOf(p) == 'kg' ? 10 : 1;

/// Adds the minimum quantity to the cart. Returns true on success.
Future<bool> quickAdd(BuildContext context, Map p, {int? qty}) async {
  final q = qty ?? minQty(p);
  try {
    await AgriApi.post('/cart', {'listingId': '${p['id']}', 'qtyKg': q});
    CartBadge.refresh();
    if (context.mounted) snack(context, '${tr('Added')} $q ${unitOf(p)} · ${tr('${p['title']}')}');
    return true;
  } catch (e) {
    if (context.mounted) snack(context, cleanErr(e), error: true);
    return false;
  }
}

/// Five small stars + "4.8 (124)".
class Stars extends StatelessWidget {
  final num rating;
  final num? count;
  final double size;
  const Stars(this.rating, {super.key, this.count, this.size = 12});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i ? Icons.star_rounded : (rating >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size,
            color: const Color(0xFFF5A524),
          ),
        const SizedBox(width: 3),
        Text(count == null ? rating.toStringAsFixed(1) : '${rating.toStringAsFixed(1)} (${count!.round()})',
            style: TextStyle(fontSize: size - 1, color: C.grey, fontWeight: FontWeight.w600)),
      ]);
}

/// Product card used in every marketplace list and grid.
class ProductCard extends StatefulWidget {
  final Map p;
  final double? width;
  final VoidCallback? onChanged;
  const ProductCard({super.key, required this.p, this.width, this.onChanged});
  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _adding = false;
  bool _added = false;

  Future<void> _add() async {
    if (_adding) return;
    setState(() => _adding = true);
    final ok = await quickAdd(context, widget.p);
    if (!mounted) return;
    setState(() {
      _adding = false;
      _added = ok;
    });
    if (ok) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) setState(() => _added = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final col = catColor(p['category']);
    final photo = firstPhoto(p);
    final deal = toNum(p['dealPct']);
    final unit = unitOf(p);
    final mine = p['mine'] == true;
    return SizedBox(
      width: widget.width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(listingId: '${p['id']}')));
            widget.onChanged?.call();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.line),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 118,
                child: Stack(children: [
                  Positioned.fill(
                    child: photo.isNotEmpty
                        ? NetPhoto(url: photo, radius: 18, thumb: true)
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [col.withValues(alpha: 0.22), col.withValues(alpha: 0.08)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                            ),
                            child: Center(child: Icon(catIcon(p['category']), size: 52, color: col)),
                          ),
                  ),
                  Positioned(
                    top: 7,
                    left: 7,
                    child: Wrap(spacing: 4, children: [
                      if (deal > 0) _tag('-${deal.round()}%', const Color(0xFFDC2626)),
                      if (p['isNew'] == true && deal == 0) _tag(tr('NEW'), const Color(0xFF2563EB)),
                      if ('${p['kind']}' == 'input') _tag(tr('Input'), const Color(0xFF7C3AED)),
                    ]),
                  ),
                  Positioned(top: 5, right: 5, child: FavoriteButton(kind: 'listing', id: '${p['id']}', onImage: true)),
                  if (p['distanceKm'] != null) Positioned(bottom: 6, left: 6, child: DistanceBadge(p['distanceKm'])),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(tr('${p['title']}'),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    ),
                    if (p['verified'] == true) const Icon(Icons.verified, size: 14, color: C.green),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: C.grey),
                    Expanded(
                      child: Text('${p['location'] ?? ''}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.grey)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Stars(toNum(p['rating']), count: toNum(p['reviews']), size: 11.5),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(children: [
                          TextSpan(text: rs(toNum(p['pricePerKg'])), style: const TextStyle(color: C.green, fontWeight: FontWeight.w900, fontSize: 15)),
                          TextSpan(text: ' /${tr(unit)}', style: const TextStyle(color: C.grey, fontSize: 10.5)),
                        ]),
                      ),
                    ),
                    if (!mine)
                      InkWell(
                        onTap: _add,
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(color: _added ? C.dark : C.green, borderRadius: BorderRadius.circular(10)),
                          child: _adding
                              ? const Padding(padding: EdgeInsets.all(9), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Icon(_added ? Icons.check : Icons.add_shopping_cart, color: Colors.white, size: 18),
                        ),
                      ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

/// Horizontal row of product cards with a title and "See all".
class ProductStrip extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List items;
  final VoidCallback? onSeeAll;
  final VoidCallback? onChanged;
  const ProductStrip({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.color = C.green,
    this.onSeeAll,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Expanded(child: Text(tr(title), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800))),
          if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: Text(tr('See all'))),
        ]),
      ),
      SizedBox(
        height: 252,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => ProductCard(p: items[i] as Map, width: 168, onChanged: onChanged),
        ),
      ),
    ]);
  }
}
