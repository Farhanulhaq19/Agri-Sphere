import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';

/// Pick the time, how long, and whether you want a technician (and for how many hours).
class BookMachineScreen extends StatefulWidget {
  final Map machine;
  const BookMachineScreen({super.key, required this.machine});
  @override
  State<BookMachineScreen> createState() => _BookMachineScreenState();
}

class _BookMachineScreenState extends State<BookMachineScreen> {
  late String _unit;
  DateTime? _start;
  int _qty = 1;
  bool _tech = false;
  int _techHours = 1;
  bool _busy = false;
  final _field = TextEditingController();
  final _notes = TextEditingController();
  final _phone = TextEditingController();
  Place? _fieldPlace;

  Map get m => widget.machine;
  bool get _hasHour => toNum(m['rentPerHour']) > 0;
  bool get _hasDay => toNum(m['rentPerDay']) > 0;
  int get _span => _unit == 'hour' ? _qty : _qty * 24;
  num get _rent => _unit == 'hour' ? _qty * toNum(m['rentPerHour']) : _qty * toNum(m['rentPerDay']);
  num get _techCost => _tech ? _techHours * toNum(m['operatorRatePerHour']) : 0;

  @override
  void initState() {
    super.initState();
    _unit = _hasHour ? 'hour' : 'day';
    _qty = _unit == 'hour' ? toNum(m['minHours']).round().clamp(1, 240).toInt() : 1;
    _techHours = _unit == 'hour' ? _qty : 8;
  }

  @override
  void dispose() {
    _field.dispose();
    _notes.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _setUnit(String u) {
    setState(() {
      _unit = u;
      _qty = u == 'hour' ? toNum(m['minHours']).round().clamp(1, 240).toInt() : 1;
      _techHours = u == 'hour' ? _qty : 8;
    });
  }

  void _setQty(int q) {
    final min = _unit == 'hour' ? toNum(m['minHours']).round() : 1;
    final max = _unit == 'hour' ? 240 : 60;
    setState(() {
      _qty = q.clamp(min < 1 ? 1 : min, max).toInt();
      // keep the technician hours sensible: by default they work the whole booking (max 8 h a day)
      final natural = _unit == 'hour' ? _qty : _qty * 8;
      if (_techHours > _span || _techHours == 0) _techHours = natural;
      if (_unit == 'hour') _techHours = _techHours.clamp(1, _span).toInt();
    });
  }

  Future<void> _submit() async {
    if (_start == null) return snack(context, 'Pick the date and time you need the machine', error: true);
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => AgriApi.post('/machinery/${m['id']}/book', {
        'type': 'rent',
        'startAt': _start!.toIso8601String(),
        'rateUnit': _unit,
        'quantity': _qty,
        'withTechnician': _tech,
        'techHours': _tech ? _techHours : 0,
        'fieldLocation': _field.text.trim(),
        if (_fieldPlace != null) ...{'fieldLat': _fieldPlace!.lat, 'fieldLng': _fieldPlace!.lng},
        'notes': _notes.text.trim(),
        'phone': _phone.text.trim(),
      }),
      ok: 'Request sent to ${m['ownerName'] ?? 'the owner'}',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = _unit == 'hour' ? 'hour(s)' : 'day(s)';
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(
        children: [
          GreenHeader(title: 'Book ${m['name']}', subtitle: '${m['ownerName'] ?? ''}  -  ${m['city'] ?? ''}'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_hasHour && _hasDay) ...[
                  Text(tr('Rent by'), style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ChoiceChip(label: Text('Hour  ${rs(toNum(m['rentPerHour']))}'), selected: _unit == 'hour', showCheckmark: false, selectedColor: C.green, labelStyle: TextStyle(color: _unit == 'hour' ? Colors.white : C.text), onSelected: (_) => _setUnit('hour')),
                      const SizedBox(width: 8),
                      ChoiceChip(label: Text('Day  ${rs(toNum(m['rentPerDay']))}'), selected: _unit == 'day', showCheckmark: false, selectedColor: C.green, labelStyle: TextStyle(color: _unit == 'day' ? Colors.white : C.text), onSelected: (_) => _setUnit('day')),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                pickerField('Start date & time', _start == null ? 'Pick date and time' : fmtIso(_start!.toIso8601String()), Icons.event, () async {
                  final d = await pickDateTime(context, initial: _start);
                  if (d != null) setState(() => _start = d);
                }),
                AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text('How many $unitLabel?', style: const TextStyle(fontWeight: FontWeight.w600))),
                      QtyStepper(value: _qty, onMinus: () => _setQty(_qty - 1), onPlus: () => _setQty(_qty + 1)),
                    ],
                  ),
                ),
                if (m['operatorAvailable'] == true) ...[
                  switchRow('Add a technician / operator', '${rs(toNum(m['operatorRatePerHour']))} per hour worked', _tech, (v) => setState(() => _tech = v)),
                  if (_tech)
                    AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(tr('Technician hours'), style: TextStyle(fontWeight: FontWeight.w600))),
                              QtyStepper(
                                value: _techHours,
                                unit: ' h',
                                onMinus: () => setState(() => _techHours = (_techHours - 1).clamp(1, _span).toInt()),
                                onPlus: () => setState(() => _techHours = (_techHours + 1).clamp(1, _span).toInt()),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('How many hours you want the technician to work (1 to $_span).', style: const TextStyle(fontSize: 11.5, color: C.grey)),
                        ],
                      ),
                    ),
                ],
                field('Field location', _field, hint: tr('Village / field name'), icon: Icons.location_on_outlined),
                LocationField(
                  label: 'Pin your field on the map (owner gets directions)',
                  value: _fieldPlace,
                  onChanged: (p) => setState(() {
                    _fieldPlace = p;
                    if (_field.text.trim().isEmpty) _field.text = p.address;
                  }),
                ),
                field('Your phone', _phone, type: TextInputType.phone, icon: Icons.phone_outlined),
                field('Notes for the owner', _notes, lines: 2, hint: tr('Crop, field size, attachments needed...')),
                const SectionTitle('Price'),
                AppCard(
                  child: Column(
                    children: [
                      InfoRow('Machine ($_qty $unitLabel)', rs(_rent)),
                      if (_tech) InfoRow('Technician ($_techHours h)', rs(_techCost)),
                      const Divider(),
                      InfoRow('Total', rs(_rent + _techCost), bold: true),
                    ],
                  ),
                ),
                Text(tr('You pay after the owner accepts your request.'), style: TextStyle(fontSize: 11.5, color: C.grey)),
                const SizedBox(height: 14),
                PrimaryButton(label: tr('Send booking request'), icon: Icons.send, loading: _busy, onPressed: _submit),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
