import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/media.dart';

/// Add a warehouse, or edit one when [warehouse] is given.
class WarehouseFormScreen extends StatefulWidget {
  final Map? warehouse;
  const WarehouseFormScreen({super.key, this.warehouse});
  @override
  State<WarehouseFormScreen> createState() => _WarehouseFormScreenState();
}

class _WarehouseFormScreenState extends State<WarehouseFormScreen> {
  final _fc = FormCheck();
  final _phone = TextEditingController();
  static const _types = ['Dry Store', 'Cold Storage', 'Grain Silo', 'Open Yard'];
  static const _facilities = ['Security guard', 'CCTV', 'Fumigation', 'Loading dock', 'Power backup', 'Weighbridge', 'Insurance'];
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _capacity = TextEditingController();
  final _rate = TextEditingController();
  final _minTons = TextEditingController(text: tr('1'));
  final _desc = TextEditingController();
  final Set<String> _selTypes = {};
  final Set<String> _selFac = {};
  bool _busy = false;
  List<String> _photos = [];
  Place? _place;

  bool get _edit => widget.warehouse != null;

  @override
  void initState() {
    super.initState();
    final w = widget.warehouse;
    // contact number is required on every post: fill it from the profile
    AgriApi.get('/me').then((d) {
      final m = d as Map;
      final p = '${m['phone'] ?? ((m['profile'] as Map?)?['phone']) ?? ''}';
      if (mounted && _phone.text.isEmpty && p.isNotEmpty) setState(() => _phone.text = p);
    }).catchError((_) {});
    if (w != null) {
      _name.text = '${w['name']}';
      _city.text = '${w['city'] ?? ''}';
      _address.text = '${w['address'] ?? ''}';
      _capacity.text = numStr(toNum(w['capacityTons']));
      _rate.text = '${toNum(w['ratePerTonDay']).round()}';
      _minTons.text = numStr(toNum(w['minTons']));
      _desc.text = '${w['description'] ?? ''}';
      _photos = ((w['photos'] as List?) ?? []).map((e) => '$e').toList();
      _place = Place.fromItem(w);
      _phone.text = '${w['ownerPhone'] ?? ''}';
      _selTypes.addAll(((w['storageTypes'] as List?) ?? []).map((e) => '$e'));
      _selFac.addAll(((w['facilities'] as List?) ?? []).map((e) => '$e'));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _city, _address, _capacity, _rate, _minTons, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final formErr = _fc.validate();
    if (formErr != null) {
      snack(context, formErr, error: true);
      return;
    }
    if (_name.text.trim().length < 2) return snack(context, 'Enter the warehouse name', error: true);
    if (_city.text.trim().isEmpty) return snack(context, 'Enter the city', error: true);
    if (_capacity.text.trim().isEmpty) return snack(context, 'Enter the capacity in tons', error: true);
    if (_rate.text.trim().isEmpty) return snack(context, 'Enter the rate per ton per day', error: true);
    if (_selTypes.isEmpty) return snack(context, 'Select at least one storage type', error: true);
    final body = {
      'name': _name.text.trim(),
      'city': _city.text.trim(),
      'address': _address.text.trim(),
      'capacityTons': _capacity.text.trim(),
      'ratePerTonDay': _rate.text.trim(),
      'minTons': _minTons.text.trim(),
      'description': _desc.text.trim(),
      'photos': _photos,
      'phone': _phone.text.trim(),
      'lat': _place?.lat,
      'lng': _place?.lng,
      'storageTypes': _selTypes.toList(),
      'facilities': _selFac.toList(),
    };
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => _edit ? AgriApi.put('/warehouse-owner/warehouses/${widget.warehouse!['id']}', body) : AgriApi.post('/warehouse-owner/warehouses', body),
      ok: _edit ? 'Warehouse updated' : 'Warehouse added',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: Text(tr(t), style: const TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(
        children: [
          GreenHeader(title: _edit ? 'Edit warehouse' : 'Add warehouse', subtitle: tr('Space, rate and facilities')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PhotoPickerField(photos: _photos, folder: 'warehouses', label: 'Warehouse photos (first one is the cover)', onChanged: (v) => _photos = v),
                LiveField('Warehouse name', _name, form: _fc, check: V.minLen(2, 'Warehouse name'), hint: tr('e.g. Al-Rehman Grain Store'), icon: Icons.warehouse_outlined),
                Row(
                  children: [
                    Expanded(child: LiveField('City', _city, form: _fc, check: V.required('the city'), hint: tr('Faisalabad'), icon: Icons.location_city)),
                    const SizedBox(width: 10),
                    Expanded(child: field('Area / road', _address, hint: tr('Jhang Road'))),
                  ],
                ),
                LiveField('Mobile number (farmers will call you)', _phone, form: _fc, check: V.phone(), icon: Icons.phone_outlined, type: TextInputType.phone, hint: '03001234567'),
                LocationField(
                  label: 'Warehouse location on map (farmers see distance)',
                  value: _place,
                  onChanged: (p) => setState(() {
                    _place = p;
                    if (_city.text.trim().isEmpty && p.city.isNotEmpty) _city.text = p.city;
                  }),
                ),
                Row(
                  children: [
                    Expanded(child: LiveField('Capacity (tons)', _capacity, form: _fc, check: V.number('Capacity', min: 1), type: TextInputType.number, hint: tr('800'))),
                    const SizedBox(width: 10),
                    Expanded(child: LiveField('Rs per ton per day', _rate, form: _fc, check: V.number('Rate', min: 1), type: TextInputType.number, hint: tr('35'))),
                  ],
                ),
                field('Minimum booking (tons)', _minTons, type: TextInputType.number, icon: Icons.scale_outlined),
                _label('Storage types'),
                ToggleChips(items: _types, selected: _selTypes, onChanged: (e, on) => setState(() => on ? _selTypes.add(e) : _selTypes.remove(e))),
                const SizedBox(height: 14),
                _label('Facilities'),
                ToggleChips(items: _facilities, selected: _selFac, onChanged: (e, on) => setState(() => on ? _selFac.add(e) : _selFac.remove(e))),
                const SizedBox(height: 14),
                field('Description', _desc, lines: 3, hint: tr('What can be stored, how it is protected...')),
                PrimaryButton(label: _edit ? 'Save changes' : 'Add warehouse', icon: Icons.check, loading: _busy, onPressed: _save),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
