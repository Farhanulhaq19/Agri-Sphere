import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/media.dart';

/// Add a machine, or edit one when [machine] is given.
/// An owner can add as many machines as they have.
class MachineFormScreen extends StatefulWidget {
  final Map? machine;
  const MachineFormScreen({super.key, this.machine});
  @override
  State<MachineFormScreen> createState() => _MachineFormScreenState();
}

class _MachineFormScreenState extends State<MachineFormScreen> {
  final _fc = FormCheck();
  final _phone = TextEditingController();
  static const _cats = ['Tractor', 'Harvester', 'Thresher', 'Sprayer', 'Plough', 'Seeder', 'Trolley', 'Water Pump', 'Other'];
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _hp = TextEditingController();
  final _perHour = TextEditingController();
  final _perDay = TextEditingController();
  final _minHours = TextEditingController(text: tr('1'));
  final _salePrice = TextEditingController();
  final _techRate = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'Tractor';
  String _condition = 'used';
  bool _forRent = true;
  bool _forSale = false;
  bool _operator = false;
  bool _busy = false;
  List<String> _photos = [];
  Place? _place;

  bool get _edit => widget.machine != null;

  String _s(dynamic v) => v == null ? '' : '$v';

  @override
  void initState() {
    super.initState();
    final m = widget.machine;
    // contact number is required on every post: fill it from the profile
    AgriApi.get('/me').then((d) {
      final m = d as Map;
      final p = '${m['phone'] ?? ((m['profile'] as Map?)?['phone']) ?? ''}';
      if (mounted && _phone.text.isEmpty && p.isNotEmpty) setState(() => _phone.text = p);
    }).catchError((_) {});
    if (m != null) {
      _name.text = _s(m['name']);
      _brand.text = _s(m['brand']);
      _model.text = _s(m['modelName']);
      _year.text = _s(m['year']);
      _hp.text = _s(m['horsepower']);
      _perHour.text = toNum(m['rentPerHour']) > 0 ? _s(toNum(m['rentPerHour']).round()) : '';
      _perDay.text = toNum(m['rentPerDay']) > 0 ? _s(toNum(m['rentPerDay']).round()) : '';
      _minHours.text = _s(m['minHours'] ?? 1);
      _salePrice.text = toNum(m['salePrice']) > 0 ? _s(toNum(m['salePrice']).round()) : '';
      _techRate.text = toNum(m['operatorRatePerHour']) > 0 ? _s(toNum(m['operatorRatePerHour']).round()) : '';
      _city.text = _s(m['city']);
      _address.text = _s(m['address']);
      _desc.text = _s(m['description']);
      _photos = ((m['photos'] as List?) ?? []).map((e) => '$e').toList();
      _place = Place.fromItem(m);
      _phone.text = '${m['ownerPhone'] ?? ''}';
      _category = _cats.contains('${m['category']}') ? '${m['category']}' : 'Other';
      _condition = '${m['condition']}' == 'new' ? 'new' : 'used';
      _forRent = m['forRent'] == true;
      _forSale = m['forSale'] == true;
      _operator = m['operatorAvailable'] == true;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _brand, _model, _year, _hp, _perHour, _perDay, _minHours, _salePrice, _techRate, _city, _address, _desc]) {
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
    if (_name.text.trim().length < 2) return snack(context, 'Enter the machine name', error: true);
    if (!_forRent && !_forSale) return snack(context, 'Choose rent, sale or both', error: true);
    if (_forRent && _perHour.text.trim().isEmpty && _perDay.text.trim().isEmpty) {
      return snack(context, 'Enter a rent per hour or per day', error: true);
    }
    if (_forSale && _salePrice.text.trim().isEmpty) return snack(context, 'Enter the sale price', error: true);
    if (_operator && _techRate.text.trim().isEmpty) return snack(context, 'Enter the technician charge per hour', error: true);
    final body = {
      'name': _name.text.trim(),
      'category': _category,
      'brand': _brand.text.trim(),
      'modelName': _model.text.trim(),
      'year': _year.text.trim(),
      'horsepower': _hp.text.trim(),
      'condition': _condition,
      'forRent': _forRent,
      'forSale': _forSale,
      'rentPerHour': _forRent ? _perHour.text.trim() : '',
      'rentPerDay': _forRent ? _perDay.text.trim() : '',
      'minHours': _minHours.text.trim(),
      'salePrice': _forSale ? _salePrice.text.trim() : '',
      'operatorAvailable': _operator,
      'operatorRatePerHour': _operator ? _techRate.text.trim() : '',
      'city': _city.text.trim(),
      'address': _address.text.trim(),
      'description': _desc.text.trim(),
      'photos': _photos,
      'phone': _phone.text.trim(),
      'lat': _place?.lat,
      'lng': _place?.lng,
    };
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => _edit ? AgriApi.put('/machinery-owner/machines/${widget.machine!['id']}', body) : AgriApi.post('/machinery-owner/machines', body),
      ok: _edit ? 'Machine updated' : 'Machine added',
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
          GreenHeader(title: _edit ? 'Edit machine' : 'Add machine', subtitle: tr('Tractor, harvester, sprayer and more')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PhotoPickerField(photos: _photos, folder: 'machines', label: 'Machine photos (first one is the cover)', onChanged: (v) => _photos = v),
                _label('Type'),
                ChipRow(items: _cats, selected: _category, onSelect: (v) => setState(() => _category = v)),
                const SizedBox(height: 14),
                LiveField('Machine name', _name, form: _fc, check: V.minLen(2, 'Machine name'), hint: tr('e.g. Massey Ferguson 385'), icon: Icons.agriculture),
                Row(
                  children: [
                    Expanded(child: field('Brand', _brand, hint: tr('Massey'), icon: Icons.sell_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: field('Model', _model, hint: tr('385'))),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: LiveField('Year', _year, form: _fc, check: V.optionalNumber('Year'), type: TextInputType.number, hint: tr('2021'))),
                    const SizedBox(width: 10),
                    Expanded(child: LiveField('Horsepower', _hp, form: _fc, check: V.optionalNumber('Horsepower'), type: TextInputType.number, hint: tr('85'))),
                  ],
                ),
                _label('Condition'),
                ChipRow(items: const ['new', 'used'], selected: _condition, onSelect: (v) => setState(() => _condition = v)),
                const SizedBox(height: 14),
                switchRow('Rent it out', 'Farmers book it by the hour or day', _forRent, (v) => setState(() => _forRent = v)),
                if (_forRent) ...[
                  Row(
                    children: [
                      Expanded(child: LiveField('Rs per hour', _perHour, form: _fc, check: V.optionalNumber('Rent per hour'), type: TextInputType.number, hint: tr('1800'))),
                      const SizedBox(width: 10),
                      Expanded(child: LiveField('Rs per day', _perDay, form: _fc, check: V.optionalNumber('Rent per day'), type: TextInputType.number, hint: tr('12000'))),
                    ],
                  ),
                  field('Minimum hours per booking', _minHours, type: TextInputType.number, icon: Icons.timer_outlined),
                ],
                switchRow('Sell it', 'Buyers can send a purchase request (new or used)', _forSale, (v) => setState(() => _forSale = v)),
                if (_forSale) field('Sale price (Rs)', _salePrice, type: TextInputType.number, hint: tr('3150000'), icon: Icons.payments_outlined),
                switchRow('Technician / operator available', 'Customers can add a technician and choose the hours', _operator, (v) => setState(() => _operator = v)),
                if (_operator) field('Technician charge per hour (Rs)', _techRate, type: TextInputType.number, hint: tr('400'), icon: Icons.engineering_outlined),
                field('City', _city, hint: tr('Faisalabad'), icon: Icons.location_city),
                field('Address / area', _address, icon: Icons.location_on_outlined),
                LiveField('Mobile number (farmers will call you)', _phone, form: _fc, check: V.phone(), icon: Icons.phone_outlined, type: TextInputType.phone, hint: '03001234567'),
                LocationField(
                  label: 'Machine location on map (farmers see distance)',
                  value: _place,
                  onChanged: (p) => setState(() {
                    _place = p;
                    if (_city.text.trim().isEmpty && p.city.isNotEmpty) _city.text = p.city;
                    if (_address.text.trim().isEmpty) _address.text = p.address;
                  }),
                ),
                field('Description', _desc, lines: 3, hint: tr('Condition, attachments, what it is good for...')),
                const SizedBox(height: 6),
                PrimaryButton(label: _edit ? 'Save changes' : 'Add machine', icon: Icons.check, loading: _busy, onPressed: _save),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
