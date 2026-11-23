import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

class AskExpertScreen extends StatefulWidget {
  const AskExpertScreen({super.key});
  @override
  State<AskExpertScreen> createState() => _AskExpertScreenState();
}

class _AskExpertScreenState extends State<AskExpertScreen> {
  final _subject = TextEditingController();
  final _details = TextEditingController();
  String _cat = 'Crop disease';
  bool _busy = false;
  Map? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AgriApi.get('/queries');
      if (mounted) setState(() => _data = d as Map);
    } catch (_) {}
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await AgriApi.post('/queries', {'category': _cat, 'subject': _subject.text.trim(), 'details': _details.text.trim()});
      if (!mounted) return;
      _subject.clear();
      _details.clear();
      snack(context, 'Question sent. An expert will reply soon.');
      await _load();
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final online = _data == null ? 12 : toNum(_data!['expertsOnline']).round();
    final hrs = _data == null ? 2 : toNum(_data!['avgReplyHours']).round();
    final items = ((_data?['items']) as List?) ?? [];
    return Scaffold(
      backgroundColor: C.bg,
      body: ListView(padding: EdgeInsets.zero, children: [
        GreenHeader(
          title: 'Ask an Expert',
          bottom: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.support_agent, color: Colors.white),
              const SizedBox(width: 10),
              Text('$online experts online - avg reply $hrs hours', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Category', style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ChipRow(items: const ['Crop disease', 'Soil', 'Irrigation', 'Pests', 'Fertilizer', 'Market'], selected: _cat, onSelect: (v) => setState(() => _cat = v)),
            const SizedBox(height: 14),
            field('Subject', _subject, hint: 'Yellow patches on wheat leaves', icon: Icons.search),
            field('Describe the problem', _details, hint: 'Symptoms, when they started and the affected area...', lines: 4),
            PrimaryButton(label: 'Submit query', icon: Icons.send, loading: _busy, onPressed: _submit),
            const SectionTitle('Your questions'),
            if (items.isEmpty) const AppCard(child: Text('No questions yet', style: TextStyle(color: C.grey))),
            ...items.map((q) => AppCard(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${q['subject']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('${q['category']} - ${fmtIso(q['createdAt'])}', style: const TextStyle(fontSize: 11, color: C.grey)),
                        if (q['answer'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${q['answer']}', style: const TextStyle(fontSize: 12))),
                      ]),
                    ),
                    Pill('${q['status']}' == 'open' ? 'Waiting' : 'Answered', color: '${q['status']}' == 'open' ? C.amber : C.green),
                  ]),
                )),
          ]),
        ),
      ]),
    );
  }
}