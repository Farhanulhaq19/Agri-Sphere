import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/media.dart';
import 'package:agrisphere/modules/module_06_expert/screens/ask_expert_screen.dart';

const _crops = ['Wheat', 'Rice', 'Cotton', 'Maize', 'Sugarcane', 'Potato', 'Tomato', 'Onion', 'Chilli', 'Citrus / Kinnow', 'Mango', 'Other'];

/// Crop Doctor: take a photo of a sick plant and get a diagnosis with treatment steps.
class CropDoctorScreen extends StatefulWidget {
  final String? crop;
  const CropDoctorScreen({super.key, this.crop});
  @override
  State<CropDoctorScreen> createState() => _CropDoctorScreenState();
}

class _CropDoctorScreenState extends State<CropDoctorScreen> {
  Uint8List? _bytes;
  String _mime = 'image/jpeg';
  late String? _crop = _crops.contains(widget.crop) ? widget.crop : null;
  final _note = TextEditingController();
  bool _busy = false;
  Map? _result;
  late Future<dynamic> _history = AgriApi.get('/ai/diagnoses');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 82);
      if (x == null) return;
      final b = await x.readAsBytes();
      final n = x.name.toLowerCase();
      setState(() {
        _bytes = b;
        _mime = n.endsWith('.png') ? 'image/png' : (n.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
        _result = null;
      });
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  Future<void> _diagnose() async {
    if (_bytes == null) {
      snack(context, 'Take or choose a photo first', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await AgriApi.post('/ai/diagnose', {
        'image': 'data:$_mime;base64,${base64Encode(_bytes!)}',
        'crop': _crop ?? '',
        'note': _note.text.trim(),
      }) as Map;
      if (!mounted) return;
      setState(() {
        _result = r;
        _history = AgriApi.get('/ai/diagnoses');
      });
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        body: ListView(padding: EdgeInsets.zero, children: [
          GreenHeader(
            eyebrow: 'AI',
            title: tr('Crop Doctor'),
            subtitle: tr('Photo of a sick leaf, fruit or plant → diagnosis and treatment'),
            trailing: CircleBtn(icon: Icons.close, onTap: () => Navigator.pop(context)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: () => _pick(ImageSource.camera),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: _bytes == null ? 190 : 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _bytes == null ? C.line : C.green, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _bytes == null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.add_a_photo_outlined, size: 46, color: C.green),
                          const SizedBox(height: 8),
                          Text(tr('Take a photo of the problem'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(tr('Close-up, in daylight, showing the affected part'), style: const TextStyle(fontSize: 12, color: C.grey)),
                        ])
                      : Image.memory(_bytes!, fit: BoxFit.cover, width: double.infinity),
                ),
              ),
              Row(children: [
                TextButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: Text(tr('Camera'))),
                TextButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: Text(tr('Gallery'))),
              ]),
              DropdownButtonFormField<String>(
                initialValue: _crop,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('Which crop? (optional)'),
                  prefixIcon: const Icon(Icons.grass, size: 18),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _crops.map((c) => DropdownMenuItem(value: c, child: Text(tr(c)))).toList(),
                onChanged: (v) => setState(() => _crop = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: tr('Anything else? e.g. started after rain, spreading fast'),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: tr(_busy ? 'Analysing photo...' : 'Diagnose'),
                icon: Icons.biotech_outlined,
                loading: _busy,
                onPressed: _diagnose,
              ),
              if (_result != null) _ResultCard(d: _result!),
              const SizedBox(height: 8),
              Text(tr('Previous diagnoses'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              FutureBuilder<dynamic>(
                future: _history,
                builder: (_, s) {
                  final items = s.data is Map ? (((s.data as Map)['items'] as List?) ?? const []) : const [];
                  if (items.isEmpty) return Text(tr('No diagnoses yet'), style: const TextStyle(color: C.grey));
                  return Column(
                    children: items.map((x) {
                      final d = x as Map;
                      final r = (d['result'] as Map?) ?? const {};
                      return AppCard(
                        onTap: () => setState(() => _result = d),
                        child: Row(children: [
                          NetPhoto(url: photoUrl(d['photo']), kind: 'crop', width: 52, height: 52, thumb: true),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${r['problem'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('${tr('${d['crop'] ?? r['crop'] ?? ''}')} · ${fmtIso(d['createdAt'])}', style: const TextStyle(fontSize: 11.5, color: C.grey)),
                            ]),
                          ),
                          _SeverityChip('${r['severity'] ?? 'none'}'),
                        ]),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(tr('AI diagnosis can be wrong. For severe or spreading problems, ask an expert.'),
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: C.grey)),
            ]),
          ),
        ]),
      );
}

class _SeverityChip extends StatelessWidget {
  final String s;
  const _SeverityChip(this.s);
  static const _c = {
    'none': (Color(0xFF16803C), 'Healthy'),
    'mild': (Color(0xFF65A30D), 'Mild'),
    'moderate': (Color(0xFFD97706), 'Moderate'),
    'severe': (Color(0xFFDC2626), 'Severe'),
  };
  @override
  Widget build(BuildContext context) {
    final v = _c[s] ?? _c['none']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: v.$1.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(tr(v.$2), style: TextStyle(color: v.$1, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map d;
  const _ResultCard({required this.d});

  Widget _list(String title, IconData icon, Color c, List? items) {
    final l = (items ?? const []).map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
    if (l.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 6),
          Text(tr(title), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 4),
        ...l.map((t) => Padding(
              padding: const EdgeInsets.only(left: 6, top: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('•  ', style: TextStyle(color: c, fontWeight: FontWeight.w900)),
                Expanded(child: Text(t, style: const TextStyle(height: 1.35))),
              ]),
            )),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = (d['result'] as Map?) ?? const {};
    final healthy = r['healthy'] == true;
    final isPlant = r['isPlantPhoto'] != false;
    final conf = '${r['confidence'] ?? 'low'}';
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: (healthy ? C.green : const Color(0xFFDC2626)).withValues(alpha: 0.12),
              child: Icon(!isPlant ? Icons.help_outline : (healthy ? Icons.eco : Icons.coronavirus_outlined), color: healthy ? C.green : const Color(0xFFDC2626)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(!isPlant ? tr('Could not see a crop in this photo') : '${r['problem']}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                Text('${tr('${r['crop'] ?? ''}')} · ${tr('${r['problemType'] ?? ''}')}', style: const TextStyle(fontSize: 12, color: C.grey)),
              ]),
            ),
            _SeverityChip('${r['severity'] ?? 'none'}'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text('${tr('Confidence')}: ', style: const TextStyle(fontSize: 12, color: C.grey)),
            ...List.generate(3, (i) {
              final on = i < (conf == 'high' ? 3 : (conf == 'medium' ? 2 : 1));
              return Container(
                margin: const EdgeInsets.only(right: 3),
                width: 22,
                height: 6,
                decoration: BoxDecoration(color: on ? C.green : C.line, borderRadius: BorderRadius.circular(3)),
              );
            }),
            Text(' ${tr(conf)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          if ('${r['urduSummary'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(12)),
              child: Text('${r['urduSummary']}', textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 14, height: 1.6)),
            ),
          ],
          if ('${r['cause'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('${r['cause']}', style: const TextStyle(color: C.grey, height: 1.4)),
          ],
          _list('What we see', Icons.visibility_outlined, const Color(0xFF2563EB), r['symptoms'] as List?),
          _list('Treatment now', Icons.medical_services_outlined, const Color(0xFFDC2626), r['treatment'] as List?),
          _list('Low-cost / organic options', Icons.spa_outlined, C.green, r['organic'] as List?),
          _list('Prevent it next time', Icons.shield_outlined, const Color(0xFF7C3AED), r['prevention'] as List?),
          if (r['askExpert'] == true || conf == 'low') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.support_agent, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(child: Text(tr('Please confirm this with an expert before spraying.'), style: const TextStyle(fontWeight: FontWeight.w600))),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskExpertScreen())),
                  child: Text(tr('Ask expert')),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 6),
          Text(tr('Always read the pesticide label, wear protection and respect the waiting period before harvest.'),
              style: const TextStyle(fontSize: 11, color: C.grey)),
        ]),
      ),
    );
  }
}
