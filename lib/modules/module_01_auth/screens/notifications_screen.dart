import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// Orders, offers, bookings and replies, newest first.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<dynamic> _load() async {
    final d = await AgriApi.get('/notifications');
    try {
      await AgriApi.post('/notifications/read');
    } catch (_) {}
    return d;
  }

  void _reload() => setState(() => _f = _load());

  IconData _icon(String t) {
    switch (t) {
      case 'order':
        return Icons.receipt_long;
      case 'offer':
        return Icons.local_offer_outlined;
      case 'machinery':
        return Icons.agriculture;
      case 'warehouse':
        return Icons.warehouse_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(
        children: [
          GreenHeader(title: tr('Notifications')),
          Expanded(
            child: Async(
              future: _f,
              onRetry: _reload,
              builder: (data) {
                final items = ((data as Map)['items'] as List?) ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(tr('You are all caught up'), style: TextStyle(color: C.grey)),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: items.map((n) {
                    return AppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: C.light,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_icon('${n['type']}'), color: C.green, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr('${n['title']}'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(tr('${n['body']}'), style: const TextStyle(fontSize: 12, color: C.grey)),
                                const SizedBox(height: 4),
                                Text(fmtIso(n['createdAt']), style: const TextStyle(fontSize: 10.5, color: C.grey)),
                              ],
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
