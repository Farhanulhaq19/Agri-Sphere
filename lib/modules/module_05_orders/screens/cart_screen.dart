import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_05_orders/screens/order_tracking_screen.dart';

class CartScreen extends StatefulWidget {
  final void Function(int) goTab;
  const CartScreen({super.key, required this.goTab});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map? _cart;
  String? _err;
  bool _placing = false;
  String _pay = 'Cash';
  final _addr = TextEditingController(text: 'House 12, Street 5, G-11/3, Islamabad');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AgriApi.get('/cart');
      if (!mounted) return;
      setState(() {
        _cart = d as Map;
        _err = null;
      });
    } catch (e) {
      if (mounted) setState(() => _err = cleanErr(e));
    }
  }

  Future<void> _apply(Future<dynamic> Function() call) async {
    try {
      final d = await call();
      if (mounted) setState(() => _cart = d as Map);
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  Future<void> _place() async {
    setState(() => _placing = true);
    try {
      final o = await AgriApi.post('/orders', {'payment': _pay, 'address': _addr.text.trim()}) as Map;
      if (!mounted) return;
      snack(context, 'Order #${o['number']} placed');
      await _load();
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: '${o['id']}')));
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _placing = false);
  }

  Widget _payBtn(String label, IconData icon) {
    final sel = _pay == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _pay = label),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: sel ? C.light : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? C.green : C.line, width: sel ? 2 : 1),
          ),
          child: Column(children: [
            Icon(icon, color: sel ? C.green : C.grey),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }

  Widget _row(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: bold ? C.text : C.grey))),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? C.green : C.text)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (_cart == null && _err == null) {
      return const Scaffold(backgroundColor: C.bg, body: Center(child: CircularProgressIndicator(color: C.green)));
    }
    if (_cart == null) {
      return Scaffold(
        backgroundColor: C.bg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48, color: C.grey),
            const SizedBox(height: 8),
            Text(_err!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    final items = (_cart!['items'] as List?) ?? [];
    final farmers = _cart!['farmers'];
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        GreenHeader(title: 'Cart & checkout', subtitle: '${items.length} items from $farmers farmers'),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.shopping_cart_outlined, size: 56, color: C.grey),
                    const SizedBox(height: 8),
                    const Text('Your cart is empty', style: TextStyle(color: C.grey)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () => widget.goTab(2), child: const Text('Browse marketplace')),
                  ]),
                )
              : ListView(padding: const EdgeInsets.all(16), children: [
                  ...items.map((it) {
                    final qty = toNum(it['qtyKg']);
                    final max = toNum(it['maxKg']);
                    final col = catColor(it['category']);
                    return AppCard(
                      child: Row(children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: Icon(catIcon(it['category']), color: col),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${it['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('${qty.round()} kg x ${rs(toNum(it['pricePerKg']))}', style: const TextStyle(fontSize: 11, color: C.grey)),
                            Text(rs(toNum(it['amount'])), style: const TextStyle(fontWeight: FontWeight.w700, color: C.green, fontSize: 13)),
                          ]),
                        ),
                        Column(children: [
                          QtyStepper(
                            value: qty,
                            onMinus: () {
                              if (qty > 10) _apply(() => AgriApi.patch('/cart/${it['id']}', {'qtyKg': qty - 10}));
                            },
                            onPlus: () {
                              if (qty + 10 <= max) _apply(() => AgriApi.patch('/cart/${it['id']}', {'qtyKg': qty + 10}));
                            },
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _apply(() => AgriApi.delete('/cart/${it['id']}')),
                            child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 11)),
                          ),
                        ]),
                      ]),
                    );
                  }),
                  field('Delivery address', _addr, icon: Icons.home_outlined),
                  const Text('Payment method', style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(children: [_payBtn('Cash', Icons.payments_outlined), _payBtn('Card', Icons.credit_card), _payBtn('JazzCash', Icons.phone_android)]),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(children: [
                      _row('Subtotal', rs(toNum(_cart!['subtotal']))),
                      _row('Delivery', rs(toNum(_cart!['delivery']))),
                      const Divider(),
                      _row('Total', rs(toNum(_cart!['total'])), bold: true),
                    ]),
                  ),
                  PrimaryButton(label: 'Place order - ${rs(toNum(_cart!['total']))}', icon: Icons.local_shipping_outlined, loading: _placing, onPressed: _place),
                ]),
        ),
      ]),
    );
  }
}