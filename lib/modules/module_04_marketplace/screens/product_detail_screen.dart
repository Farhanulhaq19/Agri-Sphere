import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

class ProductDetailScreen extends StatefulWidget {
  final String listingId;
  const ProductDetailScreen({super.key, required this.listingId});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<dynamic> _f;
  int _qty = 100;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/listings/${widget.listingId}');
  }

  void _reload() => setState(() => _f = AgriApi.get('/listings/${widget.listingId}'));

  Future<void> _addToCart(num max) async {
    setState(() => _busy = true);
    try {
      await AgriApi.post('/cart', {'listingId': widget.listingId, 'qtyKg': _qty});
      if (!mounted) return;
      snack(context, 'Added $_qty kg to cart');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
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
          final col = catColor(p['category']);
          final max = toNum(p['quantityKg']);
          return Column(children: [
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
                Stack(children: [
                  Container(
                    height: 230,
                    width: double.infinity,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [col.withOpacity(0.35), col.withOpacity(0.12)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                    child: Center(child: Icon(catIcon(p['category']), size: 110, color: col)),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 16,
                    child: CircleBtn(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${p['title']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('${p['rating']} (${p['reviews']} reviews)', style: const TextStyle(fontSize: 12, color: C.grey)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(rs(toNum(p['pricePerKg'])), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.green)),
                        const Text('per kg', style: TextStyle(fontSize: 11, color: C.grey)),
                      ]),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      Pill('${p['grade']}'),
                      if (p['verified'] == true) const Pill('Verified farmer', color: Colors.blue),
                      Pill('${max.round()} kg left', color: C.amber),
                    ]),
                    const SizedBox(height: 12),
                    Text('${p['description'] ?? ''}', style: const TextStyle(fontSize: 13, color: C.grey, height: 1.4)),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Row(children: [
                        CircleAvatar(backgroundColor: C.light, child: Text('${p['sellerName']}'.isEmpty ? '?' : '${p['sellerName']}'[0], style: const TextStyle(color: C.green, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${p['sellerName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${p['location']} - ${p['sales']} sales', style: const TextStyle(fontSize: 11, color: C.grey)),
                          ]),
                        ),
                        IconButton(icon: const Icon(Icons.chat_bubble_outline, color: C.green), onPressed: () => snack(context, 'Chat with seller coming soon')),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
              child: Row(children: [
                QtyStepper(
                  value: _qty,
                  unit: ' kg',
                  onMinus: () => setState(() => _qty = _qty > 10 ? _qty - 10 : 10),
                  onPlus: () => setState(() => _qty = (_qty + 10) <= max ? _qty + 10 : _qty),
                ),
                const SizedBox(width: 16),
                Expanded(child: PrimaryButton(label: 'Add to cart', icon: Icons.shopping_cart_outlined, loading: _busy, onPressed: () => _addToCart(max))),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}