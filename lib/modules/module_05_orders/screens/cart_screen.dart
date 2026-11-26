import 'package:flutter/material.dart';
import 'package:agrisphere/modules/module_04_marketplace/widgets/product_card.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_05_orders/screens/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final void Function(int) goTab;
  const CartScreen({super.key, required this.goTab});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map? _cart;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    CartBadge.refresh();
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
    Future<void>.delayed(const Duration(milliseconds: 600), CartBadge.refresh);
    try {
      final d = await call();
      if (mounted) setState(() => _cart = d as Map);
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  Future<void> _checkout() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(cart: _cart!)),
    );
    _load();
  }

  Widget _row(String l, String v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            tr(l),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: bold ? C.text : C.grey,
            ),
          ),
        ),
        Text(
          v,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: bold ? C.green : C.text,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_cart == null && _err == null) {
      return const Scaffold(
        backgroundColor: C.bg,
        body: Center(child: CircularProgressIndicator(color: C.green)),
      );
    }
    if (_cart == null) {
      return Scaffold(
        backgroundColor: C.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: C.grey),
              const SizedBox(height: 8),
              Text(_err!),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: Text(tr('Retry'))),
            ],
          ),
        ),
      );
    }
    final items = (_cart!['items'] as List?) ?? [];
    final farmers = _cart!['farmers'];
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(
        children: [
          GreenHeader(
            title: tr('Cart & checkout'),
            subtitle: '${items.length} items from $farmers farmers',
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shopping_cart_outlined,
                          size: 56,
                          color: C.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('Your cart is empty'),
                          style: TextStyle(color: C.grey),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => widget.goTab(2),
                          child: Text(tr('Browse marketplace')),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...items.map((it) {
                        final qty = toNum(it['qtyKg']);
                        final max = toNum(it['maxKg']);
                        final col = catColor(it['category']);
                        return AppCard(
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: col.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  catIcon(it['category']),
                                  color: col,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr('${it['title']}'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${qty.round()} kg x ${rs(toNum(it['pricePerKg']))}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: C.grey,
                                      ),
                                    ),
                                    Text(
                                      rs(toNum(it['amount'])),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: C.green,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  QtyStepper(
                                    value: qty,
                                    onMinus: () {
                                      if (qty > 10)
                                        _apply(
                                          () => AgriApi.patch(
                                            '/cart/${it['id']}',
                                            {'qtyKg': qty - 10},
                                          ),
                                        );
                                    },
                                    onPlus: () {
                                      if (qty + 10 <= max)
                                        _apply(
                                          () => AgriApi.patch(
                                            '/cart/${it['id']}',
                                            {'qtyKg': qty + 10},
                                          ),
                                        );
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _apply(
                                      () => AgriApi.delete('/cart/${it['id']}'),
                                    ),
                                    child: Text(
                                      tr('Remove'),
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
                      AppCard(
                        child: Column(
                          children: [
                            _row('Subtotal', rs(toNum(_cart!['subtotal']))),
                            _row('Delivery (standard)', rs(toNum(_cart!['delivery']))),
                            const Divider(),
                            _row(
                              'Total',
                              rs(toNum(_cart!['total'])),
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                      PrimaryButton(
                        label: tr('Proceed to checkout'),
                        icon: Icons.arrow_forward,
                        onPressed: _checkout,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
