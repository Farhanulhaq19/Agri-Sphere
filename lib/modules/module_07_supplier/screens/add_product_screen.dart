import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _title = TextEditingController();
  final _brand = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _desc = TextEditingController();
  String _cat = 'Seeds';
  String _unit = 'kg';
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await AgriApi.post('/supplier/products', {
        'title': _title.text.trim(),
        'category': _cat,
        'brand': _brand.text.trim(),
        'unit': _unit,
        'quantityKg': double.tryParse(_qty.text.trim()) ?? 0,
        'pricePerKg': double.tryParse(_price.text.trim()) ?? 0,
        'description': _desc.text.trim(),
      });
      if (!mounted) return;
      snack(context, 'Product published to the marketplace');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        const GreenHeader(title: 'Add product'),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            field('Product name', _title, hint: 'DAP Fertilizer', icon: Icons.inventory_2_outlined),
            const Text('Category', style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ChipRow(items: const ['Seeds', 'Fertilizer', 'Pesticide', 'Tools', 'Other'], selected: _cat, onSelect: (v) => setState(() => _cat = v)),
            const SizedBox(height: 14),
            field('Brand', _brand, hint: 'Engro'),
            const Text('Unit', style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ChipRow(items: const ['kg', 'bag', 'piece', 'litre'], selected: _unit, onSelect: (v) => setState(() => _unit = v)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: field('Stock', _qty, hint: '500', type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: field('Price per unit (Rs)', _price, hint: '260', type: TextInputType.number)),
            ]),
            field('Description', _desc, hint: 'What is it and who is it for?', lines: 3),
            PrimaryButton(label: 'Publish product', icon: Icons.check, loading: _busy, onPressed: _save),
          ]),
        ),
      ]),
    );
  }
}