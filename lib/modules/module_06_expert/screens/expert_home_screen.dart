import 'package:flutter/material.dart';
import 'package:agrisphere/modules/module_12_ai/agri_chatbot_screen.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/account_button.dart';

class ExpertHomeScreen extends StatefulWidget {
  const ExpertHomeScreen({super.key});
  @override
  State<ExpertHomeScreen> createState() => _ExpertHomeScreenState();
}

class _ExpertHomeScreenState extends State<ExpertHomeScreen> {
  String _tab = 'Open';
  late Future<dynamic> _f;

  Future<dynamic> _fetch() => AgriApi.get(
    '/expert/queries?status=${_tab == 'Open' ? 'open' : 'answered'}',
  );

  @override
  void initState() {
    super.initState();
    _f = _fetch();
  }

  void _reload() => setState(() => _f = _fetch());

  Future<void> _answer(Map q) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('${q['subject']}')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('${q['details']}'),
                style: const TextStyle(fontSize: 12, color: C.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: tr('Write your advice...'),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Send')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AgriApi.post('/expert/queries/${q['id']}/answer', {
        'answer': c.text.trim(),
      });
      if (mounted) {
        snack(context, 'Answer sent to the farmer');
        _reload();
      }
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      floatingActionButton: const AgriChatBotFab(role: 'expert'),
      body: Column(
        children: [
          GreenHeader(
            title: tr('Expert desk'),
            subtitle: tr('Answer farmers\' questions'),
            trailing: const AccountButton(),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ChipRow(
                items: const ['Open', 'Answered by me'],
                selected: _tab == 'Open' ? 'Open' : 'Answered by me',
                onSelect: (v) {
                  _tab = v == 'Open' ? 'Open' : 'Answered';
                  _reload();
                },
              ),
            ),
          ),
          Expanded(
            child: Async(
              future: _f,
              onRetry: _reload,
              builder: (data) {
                final items = (((data as Map)['items']) as List?) ?? [];
                if (items.isEmpty)
                  return Center(
                    child: Text(
                      tr('Nothing here'),
                      style: TextStyle(color: C.grey),
                    ),
                  );
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: items.map((q) {
                    final open = '${q['status']}' == 'open';
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('${q['subject']}'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Pill('${q['category']}'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${q['ownerName'] ?? 'Farmer'} - ${fmtIso(q['createdAt'])}',
                            style: const TextStyle(fontSize: 11, color: C.grey),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr('${q['details']}'),
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (!open && q['answer'] != null) ...[
                            const Divider(),
                            Text(
                              tr('${q['answer']}'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: C.green,
                              ),
                            ),
                          ],
                          if (open)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _answer(q as Map),
                                child: Text(tr('Answer')),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
