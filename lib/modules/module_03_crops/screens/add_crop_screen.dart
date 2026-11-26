import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/media.dart';

class AddCropScreen extends StatefulWidget {
  const AddCropScreen({super.key});
  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _name = TextEditingController();
  final _variety = TextEditingController();
  final _fieldName = TextEditingController(text: tr('Field A'));
  final _area = TextEditingController();
  final _date = TextEditingController();
  final _harvest = TextEditingController();
  DateTime? _sow;
  List<String> _photos = [];
  Place? _place;
  bool _busy = false;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _sow ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) {
      setState(() {
        _sow = d;
        _date.text = fmtDate(d);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await AgriApi.post('/crops', {
        'name': _name.text.trim(),
        'variety': _variety.text.trim(),
        'field': _fieldName.text.trim(),
        'areaAcres': double.tryParse(_area.text.trim()) ?? 0,
        'sowingDate': (_sow ?? DateTime.now()).toIso8601String(),
        'expectedHarvest': _harvest.text.trim(),
        'photos': _photos,
        if (_place != null) ...{'lat': _place!.lat, 'lng': _place!.lng, 'location': _place!.city.isNotEmpty ? _place!.city : _place!.address},
      });
      if (!mounted) return;
      snack(context, 'Crop saved');
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
          GreenHeader(title: tr('Add new crop')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PhotoPickerField(photos: _photos, folder: 'crops', label: 'Field / crop photos', onChanged: (v) => _photos = v),
                field('Crop name', _name, hint: tr('Wheat'), icon: Icons.grass),
                LocationField(label: 'Farm location', value: _place, onChanged: (p) => setState(() => _place = p)),
                field('Variety', _variety, hint: tr('Sehar 2006')),
                field(
                  'Field',
                  _fieldName,
                  hint: tr('Field A'),
                  icon: Icons.landscape_outlined,
                ),
                Row(
                  children: [
                    Expanded(
                      child: field(
                        'Land area (acres)',
                        _area,
                        hint: tr('4'),
                        type: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        icon: Icons.crop_square,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: field(
                        'Sowing date',
                        _date,
                        hint: tr('Pick date'),
                        icon: Icons.calendar_today,
                        readOnly: true,
                        onTap: _pickDate,
                      ),
                    ),
                  ],
                ),
                field(
                  'Expected harvest',
                  _harvest,
                  hint: tr('April 2027'),
                  icon: Icons.event_available,
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: tr('Save crop'),
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
