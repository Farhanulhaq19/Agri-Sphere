import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/contact.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/seller_profile_screen.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/media.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/offer_sheet.dart';
import 'package:agrisphere/modules/module_04_marketplace/widgets/product_card.dart';
import 'package:agrisphere/modules/module_05_orders/screens/checkout_screen.dart';
import 'package:agrisphere/modules/module_11_social/chat.dart';
import 'package:agrisphere/modules/module_11_social/favorites.dart';

/// Full product page: photos, price vs market, quantity + live total, delivery & payment info,
/// seller card with chat, pickup map, similar products, and a sticky Add to cart / Buy now bar.
class ProductDetailScreen extends StatefulWidget {
  final String listingId;
  const ProductDetailScreen({super.key, required this.listingId});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<dynamic> _f;
  int? _qty;
  bool _busy = false;
  bool _buying = false;
  bool _more = false;
  bool _allReviews = false;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/listings/${widget.listingId}');
  }

  void _reload() => setState(() => _f = AgriApi.get('/listings/${widget.listingId}'));

  Future<void> _add(Map p) async {
    setState(() => _busy = true);
    await quickAdd(context, p, qty: _qty);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _buyNow(Map p) async {
    setState(() => _buying = true);
    try {
      await AgriApi.post('/cart', {'listingId': '${p['id']}', 'qtyKg': _qty});
      final cart = await AgriApi.get('/cart') as Map;
      CartBadge.refresh();
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(cart: cart)));
      CartBadge.refresh();
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _buying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final p = data as Map;
          final unit = unitOf(p);
          final step = minQty(p);
          final max = toNum(p['quantityKg']).floor();
          _qty ??= (unit == 'kg' ? 100 : 1).clamp(step, max < step ? step : max);
          final qty = _qty!;
          final price = toNum(p['pricePerKg']);
          final mine = p['mine'] == true;
          return Column(children: [
            Expanded(
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(child: _hero(p)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _titleBlock(p),
                      const SizedBox(height: 14),
                      _priceCard(p, price, unit, max),
                      if (!mine) ...[const SizedBox(height: 12), _qtyCard(p, qty, step, max, price, unit)],
                      const SizedBox(height: 12),
                      _infoCard(p),
                      if ('${p['description'] ?? ''}'.trim().isNotEmpty) _description(p),
                      const SizedBox(height: 12),
                      _sellerCard(p, mine),
                      _reviews(p),
                      if (Place.fromItem(p) != null) ...[
                        const SectionTitle('Pickup location'),
                        MapPreview(lat: Place.fromItem(p)!.lat, lng: Place.fromItem(p)!.lng, label: '${p['address'] ?? p['location'] ?? ''}'),
                      ],
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ProductStrip(title: 'Similar products', icon: Icons.auto_awesome, items: (p['similar'] as List?) ?? const []),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ]),
            ),
            _bottomBar(p, qty, price, unit, mine),
          ]);
        },
      ),
    );
  }

  // ------------------------------------------------------------ sections
  Widget _hero(Map p) {
    final photos = (p['photos'] as List?) ?? const [];
    final col = catColor(p['category']);
    final top = MediaQuery.of(context).padding.top;
    return Stack(children: [
      if (photos.isNotEmpty)
        PhotoGallery(photos: photos, height: 300)
      else
        Container(
          height: 260,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [col.withValues(alpha: 0.35), col.withValues(alpha: 0.1)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          child: Center(child: Icon(catIcon(p['category']), size: 120, color: col)),
        ),
      Positioned(top: top + 10, left: 14, child: CircleBtn(icon: Icons.arrow_back, onTap: () => Navigator.pop(context))),
      Positioned(top: top + 10, right: 14, child: FavoriteButton(kind: 'listing', id: '${p['id']}', onImage: true)),
    ]);
  }

  Widget _titleBlock(Map p) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill(tr('${p['category']}'), color: catColor(p['category'])),
          if ('${p['grade'] ?? ''}'.isNotEmpty && '${p['kind']}' != 'input') Pill('${p['grade']}'),
          if (p['verified'] == true) Pill(tr('${p['kind']}' == 'input' ? 'Verified supplier' : 'Verified farmer'), color: Colors.blue),
          if ('${p['brand'] ?? ''}'.isNotEmpty) Pill('${p['brand']}', color: C.grey),
          if (p['distanceKm'] != null) DistanceBadge(p['distanceKm']),
        ]),
        const SizedBox(height: 8),
        Text(tr('${p['title']}'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Row(children: [
          Stars(toNum(p['rating']), count: toNum(p['reviews']), size: 14),
          const SizedBox(width: 10),
          Text('· ${toNum(p['sales']).round()} ${tr('sold')}', style: const TextStyle(fontSize: 12, color: C.grey)),
        ]),
      ]);

  Widget _priceCard(Map p, num price, String unit, int max) {
    final avg = toNum(p['marketAvg']);
    final diff = avg > 0 ? ((price - avg) / avg * 100).round() : 0;
    final until = DateTime.tryParse('${p['availableUntil'] ?? ''}');
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(rs(price), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: C.green)),
          Padding(
            padding: const EdgeInsets.only(bottom: 5, left: 4),
            child: Text('/ ${tr(unit)}', style: const TextStyle(color: C.grey)),
          ),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$max ${tr(unit)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(tr('in stock'), style: const TextStyle(fontSize: 11, color: C.grey)),
          ]),
        ]),
        if (avg > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: diff <= 0 ? C.light : const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(diff <= 0 ? Icons.trending_down : Icons.trending_up, color: diff <= 0 ? C.green : C.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  diff == 0
                      ? '${tr('Same as market average')} (${rs(avg)}/${tr(unit)})'
                      : '${diff.abs()}% ${tr(diff < 0 ? 'below' : 'above')} ${tr('market average')} (${rs(avg)}/${tr(unit)})',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: diff <= 0 ? C.dark : const Color(0xFF92400E)),
                ),
              ),
            ]),
          ),
        ],
        if (until != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.event_available, size: 15, color: C.grey),
            const SizedBox(width: 4),
            Text('${tr('Available until')} ${fmtDate(until)}', style: const TextStyle(fontSize: 12, color: C.grey)),
          ]),
        ],
      ]),
    );
  }

  Widget _qtyCard(Map p, int qty, int step, int max, num price, String unit) {
    final presets = unit == 'kg' ? [10, 50, 100, 500, 1000] : [1, 5, 10, 25, 50];
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(tr('Quantity'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          QtyStepper(
            value: qty,
            unit: ' ${tr(unit)}',
            onMinus: () => setState(() => _qty = (qty - step).clamp(step, max)),
            onPlus: () => setState(() => _qty = (qty + step).clamp(step, max)),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: presets
              .where((v) => v <= max)
              .map((v) => ChoiceChip(
                    label: Text('$v ${tr(unit)}'),
                    selected: qty == v,
                    selectedColor: C.light,
                    showCheckmark: false,
                    side: BorderSide(color: qty == v ? C.green : C.line),
                    labelStyle: TextStyle(color: qty == v ? C.green : C.text, fontWeight: FontWeight.w600, fontSize: 12),
                    onSelected: (_) => setState(() => _qty = v),
                  ))
              .toList(),
        ),
        const Divider(height: 22),
        Row(children: [
          Text(tr('Total'), style: const TextStyle(color: C.grey)),
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween(end: (qty * price).toDouble()),
            duration: const Duration(milliseconds: 300),
            builder: (_, v, _) => Text(rs(v), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ),
        ]),
      ]),
    );
  }

  Widget _infoCard(Map p) {
    Widget row(IconData i, Color c, String t, String s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            CircleAvatar(radius: 17, backgroundColor: c.withValues(alpha: 0.12), child: Icon(i, size: 18, color: c)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(t), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(tr(s), style: const TextStyle(fontSize: 11.5, color: C.grey)),
              ]),
            ),
          ]),
        );
    return AppCard(
      child: Column(children: [
        row(Icons.local_shipping_outlined, C.green, 'Delivery to your door', 'Standard Rs 500 (2-3 days) · Express Rs 900 (next day)'),
        row(Icons.payments_outlined, const Color(0xFFD97706), 'Cash on Delivery', 'Pay when the order arrives'),
        row(Icons.phone_android, const Color(0xFF059669), 'Easypaisa & card', 'Pay online and upload the receipt'),
        row(Icons.verified_user_outlined, const Color(0xFF2563EB), 'Safe buying', 'The order is confirmed only after the payment is verified'),
      ]),
    );
  }

  Widget _description(Map p) {
    final d = tr('${p['description']}');
    final long = d.length > 160;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('About this product'),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: Text(
          d,
          maxLines: _more || !long ? null : 3,
          overflow: _more || !long ? null : TextOverflow.ellipsis,
          style: const TextStyle(color: C.grey, height: 1.5, fontSize: 13.5),
        ),
      ),
      if (long)
        TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () => setState(() => _more = !_more),
          child: Text(tr(_more ? 'Show less' : 'Read more')),
        ),
    ]);
  }

  Widget _sellerCard(Map p, bool mine) {
    final st = (p['sellerStats'] as Map?) ?? const {};
    final name = '${p['sellerName'] ?? 'Seller'}';
    Widget stat(String v, String l) => Expanded(
          child: Column(children: [
            Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            Text(tr(l), style: const TextStyle(fontSize: 11, color: C.grey)),
          ]),
        );
    return AppCard(
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: C.light,
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: C.green, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(tr(name), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                if (p['verified'] == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 16, color: C.green)),
              ]),
              Text('${tr('${p['kind']}' == 'input' ? 'Supplier' : 'Farmer')} · ${p['location'] ?? ''}', style: const TextStyle(fontSize: 12, color: C.grey)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          stat('${toNum(st['rating']) > 0 ? toNum(st['rating']) : '-'}', 'Rating'),
          stat('${toNum(st['listings']).round()}', 'Products'),
          stat('${toNum(st['sales']).round()}', 'Sales'),
        ]),
        if (!mine && '${p['sellerPhone'] ?? ''}'.isNotEmpty) ...[
          const Divider(height: 18),
          ContactRow(
            label: 'Contact the seller',
            name: name,
            phone: '${p['sellerPhone']}',
            whatsappText: 'Assalam o Alaikum, I saw your ${p['title']} on AgriSphere.',
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SellerProfileScreen(sellerId: '${p['seller']}'))),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: Text(tr('View seller profile')),
          ),
        ),
        if (!mine) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ChatWithButton(
                to: '${p['seller']}',
                toName: name,
                kind: 'listing',
                refId: '${p['id']}',
                title: '${p['title']}',
                label: 'Chat with seller',
              ),
            ),
            if ('${p['kind']}' == 'produce') ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final sent = await showOfferSheet(context, p, qty: _qty ?? 100);
                    if (sent && mounted) _reload();
                  },
                  icon: const Icon(Icons.local_offer_outlined, size: 18),
                  label: Text(tr('Make offer')),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF9333EA), side: const BorderSide(color: Color(0xFF9333EA))),
                ),
              ),
            ],
          ]),
        ],
      ]),
    );
  }

  Widget _reviews(Map p) {
    final list = ((p['reviewList'] as List?) ?? const []).cast<Map>();
    final rating = toNum(p['rating']);
    final count = toNum(p['reviews']).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Reviews', trailing: count > 0 ? Text('$count', style: const TextStyle(color: C.grey)) : null),
      AppCard(
        child: count == 0
            ? Row(children: [
                const Icon(Icons.rate_review_outlined, color: C.grey),
                const SizedBox(width: 10),
                Expanded(child: Text(tr('No reviews yet. Buyers can rate after delivery.'), style: const TextStyle(color: C.grey))),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Stars(rating, size: 16),
                    Text('$count ${tr('ratings')}', style: const TextStyle(fontSize: 12, color: C.grey)),
                  ]),
                ]),
                if (list.isNotEmpty) const Divider(height: 22),
                ...list.take(_allReviews ? list.length : 3).map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: C.light,
                          child: Text('${r['name'] ?? '?'}'.isEmpty ? '?' : '${r['name']}'[0].toUpperCase(),
                              style: const TextStyle(color: C.green, fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${r['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                              Text(fmtIso(r['at']), style: const TextStyle(fontSize: 10.5, color: C.grey)),
                            ]),
                            Stars(toNum(r['rating']), size: 12),
                            if ('${r['text'] ?? ''}'.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text('${r['text']}', style: const TextStyle(fontSize: 12.5, height: 1.35)),
                              ),
                          ]),
                        ),
                      ]),
                    )),
                if (list.length > 3)
                  TextButton(
                    onPressed: () => setState(() => _allReviews = !_allReviews),
                    child: Text(tr(_allReviews ? 'Show less' : 'See all reviews')),
                  ),
              ]),
      ),
    ]);
  }

  Widget _bottomBar(Map p, int qty, num price, String unit, bool mine) => Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: mine
            ? Row(children: [
                const Icon(Icons.storefront, color: C.green),
                const SizedBox(width: 10),
                Expanded(child: Text(tr('This is your listing. Buyers see it in the marketplace.'), style: const TextStyle(color: C.grey))),
              ])
            : Row(children: [
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$qty ${tr(unit)}', style: const TextStyle(fontSize: 11, color: C.grey)),
                  Text(rs(qty * price), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _add(p),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      side: const BorderSide(color: C.green),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.green))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.add_shopping_cart, color: C.green, size: 18),
                            const SizedBox(width: 4),
                            Flexible(child: Text(tr('Add to cart'), overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.green, fontWeight: FontWeight.w700))),
                          ]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _buying ? null : () => _buyNow(p),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: C.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _buying
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(tr('Buy now'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
      );
}
