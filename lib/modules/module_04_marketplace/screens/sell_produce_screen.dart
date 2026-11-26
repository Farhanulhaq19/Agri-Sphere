import 'package:flutter/material.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/market_insight_screen.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/media.dart';

class SellProduceScreen extends StatefulWidget {
  final String? cropName;
  const SellProduceScreen({super.key, this.cropName});
  @override
  State<SellProduceScreen> createState() => _SellProduceScreenState();
}

class _SellProduceScreenState extends State<SellProduceScreen> {
  final _fc = FormCheck();
  final _phone = TextEditingController();
  late final TextEditingController _title;
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _loc = TextEditingController(text: tr('Haripur, Khyber Pakhtunkhwa'));
  final _until = TextEditingController();
  final _desc = TextEditingController();
  List<String> _photos = [];
  Place? _place;
  String _cat = 'Grains';
  String _grade = 'Grade A';
  DateTime? _untilDate;
  num _avg = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.cropName ?? '');
    // contact number is required on every post: fill it from the profile
    AgriApi.get('/me').then((d) {
      final m = d as Map;
      final p = '${m['phone'] ?? ((m['profile'] as Map?)?['phone']) ?? ''}';
      if (mounted && _phone.text.isEmpty && p.isNotEmpty) setState(() => _phone.text = p);
    }).catchError((_) {});
    if ((widget.cropName ?? '').isNotEmpty) _checkAvg(widget.cropName!);
  }

  Future<void> _checkAvg(String q) async {
    if (q.trim().length < 3) {
      if (_avg != 0) setState(() => _avg = 0);
      return;
    }
    try {
      final r = await AgriApi.get(
        '/market-average?q=${Uri.encodeQueryComponent(q.trim())}',
      );
      if (mounted && _title.text == q)
        setState(() => _avg = toNum(r['average']));
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (d != null) {
      setState(() {
        _untilDate = d;
        _until.text = fmtDate(d);
      });
    }
  }

  Future<void> _publish() async {
    final formErr = _fc.validate();
    if (formErr != null) {
      snack(context, formErr, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AgriApi.post('/listings', {
        'title': _title.text.trim(),
        'category': _cat,
        'grade': _grade,
        'quantityKg': double.tryParse(_qty.text.trim()) ?? 0,
        'pricePerKg': double.tryParse(_price.text.trim()) ?? 0,
        'location': _loc.text.trim(),
        'description': _desc.text.trim(),
        'photos': _photos,
        'phone': _phone.text.trim(),
        if (_place != null) ...{'lat': _place!.lat, 'lng': _place!.lng, 'address': _place!.address},
        if (_untilDate != null) 'availableUntil': _untilDate!.toIso8601String(),
      });
      if (!mounted) return;
      snack(context, 'Listing published');
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
          GreenHeader(title: tr('List produce for sale')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PhotoPickerField(
                  photos: _photos,
                  folder: 'listings',
                  label: 'Produce photos (first one is the cover)',
                  onChanged: (v) => _photos = v,
                ),
                LiveField('Crop / produce', _title, form: _fc, check: V.minLen(2, 'Produce name'),
                  hint: tr('Wheat grain'),
                  icon: Icons.grass,
                  onChanged: _checkAvg,
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
                  items: const ['Grains', 'Veggies', 'Fruits', 'Seeds'],
                  selected: _cat,
                  onSelect: (v) => setState(() => _cat = v),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: LiveField('Quantity (kg)', _qty, form: _fc, check: V.number('Quantity', min: 1),
                        hint: tr('2000'),
                        type: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LiveField('Price / kg (Rs)', _price, form: _fc, check: V.number('Price', min: 1),
                        hint: tr('120'),
                        type: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                Text(
                  tr('Quality grade'),
                  style: TextStyle(
                    fontSize: 12,
                    color: C.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ChipRow(
                  items: const ['Grade A', 'Grade B', 'Grade C'],
                  selected: _grade,
                  onSelect: (v) => setState(() => _grade = v),
                ),
                const SizedBox(height: 14),
                field(
                  'Pickup location',
                  _loc,
                  icon: Icons.location_on_outlined,
                ),
                LiveField('Mobile number (buyers will call you)', _phone, form: _fc, check: V.phone(), icon: Icons.phone_outlined, type: TextInputType.phone, hint: '03001234567'),
                LocationField(
                  label: 'Pickup point on map (buyers see distance)',
                  value: _place,
                  onChanged: (p) => setState(() {
                    _place = p;
                    if (p.city.isNotEmpty) _loc.text = p.city;
                  }),
                ),
                field('Description', _desc, lines: 3, hint: 'Freshly harvested, moisture, packing...', icon: Icons.notes),
                field(
                  'Available until',
                  _until,
                  hint: tr('Pick date'),
                  icon: Icons.calendar_today,
                  readOnly: true,
                  onTap: _pickDate,
                ),
                if (_avg > 0)
                  AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.bar_chart, color: C.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Market average ${rs(_avg)}/kg. Your price is ${(double.tryParse(_price.text) ?? 0) <= _avg ? 'competitive' : 'above average'} in your area.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_title.text.trim().length >= 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MarketInsightScreen(product: _title.text.trim()))),
                      icon: const Icon(Icons.show_chart),
                      label: Text(tr('See price trend: sell now or hold?')),
                    ),
                  ),
                PrimaryButton(
                  label: tr('Publish listing'),
                  icon: Icons.check,
                  loading: _busy,
                  onPressed: _publish,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
