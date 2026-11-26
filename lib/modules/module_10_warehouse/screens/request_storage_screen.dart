import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// Crop, quantity, how many days, start date: shows the price before you send.
class RequestStorageScreen extends StatefulWidget {
  final Map warehouse;
  const RequestStorageScreen({super.key, required this.warehouse});
  @override
  State<RequestStorageScreen> createState() => _RequestStorageScreenState();
}

class _RequestStorageScreenState extends State<RequestStorageScreen> {
  final _crop = TextEditingController();
  final _tons = TextEditingController();
  final _days = TextEditingController(text: tr('30'));
  final _notes = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _start;
  late String _type;
  bool _loading = false;
  bool _needLoading = false;

  Map get w => widget.warehouse;

  @override
  void initState() {
    super.initState();
    final t = (w['storageTypes'] as List?) ?? [];
    _type = t.isEmpty ? 'Dry Store' : '${t.first}';
    _tons.text = numStr(toNum(w['minTons']));
  }

  @override
  void dispose() {
    for (final c in [_crop, _tons, _days, _notes, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  num get _t => num.tryParse(_tons.text.trim()) ?? 0;
  num get _d => num.tryParse(_days.text.trim()) ?? 0;
  num get _cost => (_t * _d * toNum(w['ratePerTonDay'])).round();

  Future<void> _submit() async {
    if (_crop.text.trim().isEmpty) return snack(context, 'Enter the crop you want to store', error: true);
    if (_t < toNum(w['minTons'])) return snack(context, 'Minimum is ${numStr(toNum(w['minTons']))} tons', error: true);
    if (_t > toNum(w['availableTons'])) return snack(context, 'Only ${numStr(toNum(w['availableTons']))} tons are free', error: true);
    if (_d < 1) return snack(context, 'Enter the number of days', error: true);
    if (_start == null) return snack(context, 'Pick the date you will bring the crop', error: true);
    setState(() => _loading = true);
    final ok = await runAction(
      context,
      () => AgriApi.post('/warehouses/${w['id']}/request', {
        'crop': _crop.text.trim(),
        'quantityTons': _t,
        'days': _d,
        'startDate': _start!.toIso8601String(),
        'storageType': _type,
        'notes': _notes.text.trim(),
        'phone': _phone.text.trim(),
        'needLoading': _needLoading,
      }),
      ok: 'Request sent to ${w['ownerName'] ?? 'the warehouse'}',
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final types = ((w['storageTypes'] as List?) ?? []).map((e) => '$e').toList();
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(
        children: [
          GreenHeader(title: tr('Request storage'), subtitle: '${w['name']}  -  ${w['city'] ?? ''}'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                field('Crop', _crop, hint: tr('e.g. Wheat'), icon: Icons.grass),
                Row(
                  children: [
                    Expanded(child: field('Quantity (tons)', _tons, type: TextInputType.number, onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 10),
                    Expanded(child: field('Days', _days, type: TextInputType.number, onChanged: (_) => setState(() {}))),
                  ],
                ),
                pickerField('Bring the crop on', _start == null ? 'Pick a date' : fmtDate(_start!), Icons.event, () async {
                  final d = await pickDate(context, initial: _start);
                  if (d != null) setState(() => _start = d);
                }),
                if (types.length > 1) ...[
                  Text(tr('Storage type'), style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ChipRow(items: types, selected: _type, onSelect: (v) => setState(() => _type = v)),
                  const SizedBox(height: 12),
                ],
                switchRow('I need loading / unloading help', 'The warehouse will schedule labour and tell you the charge', _needLoading, (v) => setState(() => _needLoading = v)),
                field('Your phone', _phone, type: TextInputType.phone, icon: Icons.phone_outlined),
                field('Notes', _notes, lines: 2, hint: tr('Bags, moisture, anything the warehouse should know')),
                const SectionTitle('Estimated storage cost'),
                AppCard(
                  child: Column(
                    children: [
                      InfoRow('${numStr(_t)} t x ${numStr(_d)} days', rs(_cost)),
                      InfoRow('Rate', '${rs(toNum(w['ratePerTonDay']))}/ton/day'),
                      const Divider(),
                      InfoRow('Total (before handling)', rs(_cost), bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                PrimaryButton(label: tr('Send request'), icon: Icons.send, loading: _loading, onPressed: _submit),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
