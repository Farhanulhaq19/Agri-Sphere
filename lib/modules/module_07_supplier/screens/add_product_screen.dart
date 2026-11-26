import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/media.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _fc = FormCheck();
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    // contact number is required on every post: fill it from the profile
    AgriApi.get('/me').then((d) {
      final m = d as Map;
      final p = '${m['phone'] ?? ((m['profile'] as Map?)?['phone']) ?? ''}';
      if (mounted && _phone.text.isEmpty && p.isNotEmpty) setState(() => _phone.text = p);
    }).catchError((_) {});
  }
  final _title = TextEditingController();
  final _brand = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _desc = TextEditingController();
  List<String> _photos = [];
  Place? _place;
  String _cat = 'Seeds';
  String _unit = 'kg';
  bool _busy = false;

  Future<void> _save() async {
    final formErr = _fc.validate();
    if (formErr != null) {
      snack(context, formErr, error: true);
      return;
    }
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
        'photos': _photos,
        'phone': _phone.text.trim(),
        if (_place != null) ...{'lat': _place!.lat, 'lng': _place!.lng, 'address': _place!.address, if (_place!.city.isNotEmpty) 'location': _place!.city},
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
      body: Column(
        children: [
          GreenHeader(title: tr('Add product')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PhotoPickerField(
                  photos: _photos,
                  folder: 'listings',
                  label: 'Product photos (first one is the cover)',
                  onChanged: (v) => _photos = v,
                ),
                LiveField('Product name', _title, form: _fc, check: V.minLen(2, 'Product name'),
                  hint: tr('DAP Fertilizer'),
                  icon: Icons.inventory_2_outlined,
                ),
                Text(
                  tr('Category'),
                  style: TextStyle(
                    fontSize: 12,
                    color: C.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ChipRow(
                  items: const [
                    'Seeds',
                    'Fertilizer',
                    'Pesticide',
                    'Tools',
                    'Other',
                  ],
                  selected: _cat,
                  onSelect: (v) => setState(() => _cat = v),
                ),
                const SizedBox(height: 14),
                field('Brand', _brand, hint: tr('Engro')),
                Text(
                  tr('Unit'),
                  style: TextStyle(
                    fontSize: 12,
                    color: C.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ChipRow(
                  items: const ['kg', 'bag', 'piece', 'litre'],
                  selected: _unit,
                  onSelect: (v) => setState(() => _unit = v),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: LiveField('Stock', _qty, form: _fc, check: V.number('Stock', min: 1),
                        hint: tr('500'),
                        type: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LiveField('Price per unit (Rs)', _price, form: _fc, check: V.number('Price', min: 1),
                        hint: tr('260'),
                        type: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                field(
                  'Description',
                  _desc,
                  hint: tr('What is it and who is it for?'),
                  lines: 3,
                ),
                LiveField('Mobile number (buyers will call you)', _phone, form: _fc, check: V.phone(), icon: Icons.phone_outlined, type: TextInputType.phone, hint: '03001234567'),
                LocationField(
                  label: 'Shop / pickup location',
                  value: _place,
                  onChanged: (p) => setState(() => _place = p),
                ),
                PrimaryButton(
                  label: tr('Publish product'),
                  icon: Icons.check,
                  loading: _busy,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
