import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'add_product_screen.dart';

class SupplierProductsScreen extends StatefulWidget {
  const SupplierProductsScreen({super.key});
  @override
  State<SupplierProductsScreen> createState() => _SupplierProductsScreenState();
}

class _SupplierProductsScreenState extends State<SupplierProductsScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/supplier/products');
  }

  void _reload() => setState(() => _f = AgriApi.get('/supplier/products'));

  Future<void> _add() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    );
    if (mounted) _reload();
  }

  Future<void> _edit(Map p) async {
    final price = TextEditingController(
      text: '${toNum(p['pricePerKg']).round()}',
    );
    final qty = TextEditingController(
      text: '${toNum(p['quantityKg']).round()}',
    );
    bool active = '${p['status']}' != 'paused';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setS) => AlertDialog(
          title: Text(tr('${p['title']}')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('Price')),
              ),
              TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('Stock')),
              ),
              SwitchListTile(
                value: active,
                onChanged: (v) => setS(() => active = v),
                title: Text(tr('Visible in marketplace')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(tr('Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(tr('Save')),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await AgriApi.patch('/supplier/products/${p['id']}', {
        'pricePerKg': double.tryParse(price.text) ?? 0,
        'quantityKg': double.tryParse(qty.text) ?? 0,
        'status': active ? 'active' : 'paused',
      });
      if (mounted) {
        snack(context, 'Product updated');
        _reload();
      }
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  Future<void> _delete(Map p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Delete product?')),
        content: Text('${p['title']} will be removed from the marketplace.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Delete'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AgriApi.delete('/supplier/products/${p['id']}');
      if (mounted) _reload();
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final items = (((data as Map)['items']) as List?) ?? [];
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              GreenHeader(
                title: tr('My products'),
                subtitle: '${items.length} listed',
                trailing: CircleBtn(icon: Icons.add, onTap: _add),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (items.isEmpty)
                      AppCard(
                        child: Text(
                          tr('No products yet. Tap + to add seeds, fertilizer or tools.'),
                          style: TextStyle(color: C.grey),
                        ),
                      ),
                    ...items.map((p) {
                      final paused = '${p['status']}' == 'paused';
                      return AppCard(
                        onTap: () => _edit(p as Map),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: catColor(
                                  p['category'],
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                catIcon(p['category']),
                                color: catColor(p['category']),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('${p['title']}'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${rs(toNum(p['pricePerKg']))} / ${p['unit']} - ${toNum(p['quantityKg']).round()} in stock',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: C.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      Pill(
                                        paused ? 'Hidden' : 'Live',
                                        color: paused ? C.grey : C.green,
                                      ),
                                      if (p['verified'] == true)
                                        const Pill(
                                          'Verified',
                                          color: Colors.blue,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _delete(p as Map),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
