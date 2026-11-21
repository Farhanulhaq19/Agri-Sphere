import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

class AddCropScreen extends StatefulWidget {
  const AddCropScreen({super.key});
  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _name = TextEditingController();
  final _variety = TextEditingController();
  final _fieldName = TextEditingController(text: 'Field A');
  final _area = TextEditingController();
  final _date = TextEditingController();
  final _harvest = TextEditingController();
  DateTime? _sow;
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
      body: Column(children: [
        const GreenHeader(title: 'Add new crop'),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            field('Crop name', _name, hint: 'Wheat', icon: Icons.grass),
            field('Variety', _variety, hint: 'Sehar 2006'),
            field('Field', _fieldName, hint: 'Field A', icon: Icons.landscape_outlined),
            Row(children: [
              Expanded(child: field('Land area (acres)', _area, hint: '4', type: const TextInputType.numberWithOptions(decimal: true), icon: Icons.crop_square)),
              const SizedBox(width: 12),
              Expanded(child: field('Sowing date', _date, hint: 'Pick date', icon: Icons.calendar_today, readOnly: true, onTap: _pickDate)),
            ]),
            field('Expected harvest', _harvest, hint: 'April 2027', icon: Icons.event_available),
            const SizedBox(height: 8),
            PrimaryButton(label: 'Save crop', icon: Icons.check, loading: _busy, onPressed: _save),
          ]),
        ),
      ]),
    );
  }
}