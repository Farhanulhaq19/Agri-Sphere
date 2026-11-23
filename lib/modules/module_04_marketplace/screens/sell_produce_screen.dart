import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

class SellProduceScreen extends StatefulWidget {
  final String? cropName;
  const SellProduceScreen({super.key, this.cropName});
  @override
  State<SellProduceScreen> createState() => _SellProduceScreenState();
}

class _SellProduceScreenState extends State<SellProduceScreen> {
  late final TextEditingController _title;
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _loc = TextEditingController(text: 'Haripur, Khyber Pakhtunkhwa');
  final _until = TextEditingController();
  String _cat = 'Grains';
  String _grade = 'Grade A';
  DateTime? _untilDate;
  num _avg = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.cropName ?? '');
    if ((widget.cropName ?? '').isNotEmpty) _checkAvg(widget.cropName!);
  }

  Future<void> _checkAvg(String q) async {
    if (q.trim().length < 3) {
      if (_avg != 0) setState(() => _avg = 0);
      return;
    }
    try {
      final r = await AgriApi.get('/market-average?q=${Uri.encodeQueryComponent(q.trim())}');
      if (mounted && _title.text == q) setState(() => _avg = toNum(r['average']));
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
    setState(() => _busy = true);
    try {
      await AgriApi.post('/listings', {
        'title': _title.text.trim(),
        'category': _cat,
        'grade': _grade,
        'quantityKg': double.tryParse(_qty.text.trim()) ?? 0,
        'pricePerKg': double.tryParse(_price.text.trim()) ?? 0,
        'location': _loc.text.trim(),
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
      body: Column(children: [
        const GreenHeader(title: 'List produce for sale'),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            field('Crop / produce', _title, hint: 'Wheat grain', icon: Icons.grass, onChanged: _checkAvg),
            const Text('Category', style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ChipRow(items: const ['Grains', 'Veggies', 'Fruits', 'Seeds'], selected: _cat, onSelect: (v) => setState(() => _cat = v)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: field('Quantity (kg)', _qty, hint: '2000', type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: field('Price / kg (Rs)', _price, hint: '120', type: TextInputType.number)),
            ]),
            const Text('Quality grade', style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ChipRow(items: const ['Grade A', 'Grade B', 'Grade C'], selected: _grade, onSelect: (v) => setState(() => _grade = v)),
            const SizedBox(height: 14),
            field('Pickup location', _loc, icon: Icons.location_on_outlined),
            field('Available until', _until, hint: 'Pick date', icon: Icons.calendar_today, readOnly: true, onTap: _pickDate),
            if (_avg > 0)
              AppCard(
                child: Row(children: [
                  const Icon(Icons.bar_chart, color: C.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Market average ${rs(_avg)}/kg. Your price is ${(double.tryParse(_price.text) ?? 0) <= _avg ? 'competitive' : 'above average'} in your area.',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
            PrimaryButton(label: 'Publish listing', icon: Icons.check, loading: _busy, onPressed: _publish),
          ]),
        ),
      ]),
    );
  }
}