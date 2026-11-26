import 'package:flutter/material.dart';
import 'package:agrisphere/modules/module_06_expert/screens/expert_home_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/my_storage_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_browse_screen.dart';
import 'package:agrisphere/modules/module_12_ai/agri_chatbot_screen.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

class SupplierDashboardScreen extends StatefulWidget {
  final void Function(int) goTab;
  const SupplierDashboardScreen({super.key, required this.goTab});
  @override
  State<SupplierDashboardScreen> createState() =>
      _SupplierDashboardScreenState();
}

class _SupplierDashboardScreenState extends State<SupplierDashboardScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/supplier/dashboard');
  }

  void _reload() => setState(() => _f = AgriApi.get('/supplier/dashboard'));

  Widget _stat(dynamic v, String l, Color c) => Expanded(
    child: AppCard(
      margin: const EdgeInsets.only(right: 8, bottom: 12),
      child: Column(
        children: [
          Text(
            tr('$v'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
          Text(tr(l), style: const TextStyle(fontSize: 11, color: C.grey)),
        ],
      ),
    ),
  );

  Widget _service(IconData icon, String title, String sub, Widget page) => Expanded(
        child: AppCard(
          margin: EdgeInsets.zero,
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
            if (mounted) _reload();
          },
          child: Row(children: [
            CircleAvatar(radius: 18, backgroundColor: C.light, child: Icon(icon, color: C.green, size: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(tr(sub), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: C.grey)),
              ]),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      floatingActionButton: const AgriChatBotFab(role: 'supplier'),
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final m = data as Map;
          final low = (m['lowStock'] as List?) ?? [];
          final recent = (m['recentOrders'] as List?) ?? [];
          return RefreshIndicator(
            color: C.green,
            onRefresh: () async {
              _reload();
              await _f;
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                GreenHeader(
                  eyebrow: m['verified'] == true
                      ? 'Verified supplier'
                      : 'Verification pending',
                  title: '${m['businessName']}',
                  bottom: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('Total sales'),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rs(toNum(m['earnings'])),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.trending_up,
                          color: Colors.white,
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _stat(m['products'], 'Products', C.green),
                          _stat(m['pending'], 'New orders', C.amber),
                          _stat(m['inProgress'], 'In progress', Colors.blue),
                          _stat(m['delivered'], 'Delivered', C.green),
                        ],
                      ),
                      const SectionTitle('More services'),
                      Row(children: [
                        _service(Icons.warehouse_outlined, 'Rent storage', 'Keep stock in a warehouse', const WarehouseBrowseScreen()),
                        const SizedBox(width: 8),
                        _service(Icons.inventory_2_outlined, 'My stored stock', 'Monitor stock & payments', const MyStorageScreen()),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        _service(Icons.support_agent, 'Expert advice', 'Answer farmers\' questions', const ExpertHomeScreen()),
                        const SizedBox(width: 8),
                        _service(Icons.smart_toy_outlined, 'AgriChatBot', 'AI help any time', const AgriChatBotScreen(role: 'supplier')),
                      ]),
                      if (low.isNotEmpty) ...[
                        const SectionTitle('Low stock'),
                        ...low.map(
                          (p) => AppCard(
                            onTap: () => widget.goTab(1),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber, color: C.amber),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    tr('${p['title']}'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${toNum(p['quantityKg']).round()} left',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      SectionTitle(
                        'Recent orders',
                        trailing: TextButton(
                          onPressed: () => widget.goTab(2),
                          child: Text(tr('See all')),
                        ),
                      ),
                      if (recent.isEmpty)
                        AppCard(
                          child: Text(
                            tr('No orders yet. They appear here when farmers buy your products.'),
                            style: TextStyle(color: C.grey),
                          ),
                        ),
                      ...recent.map((o) {
                        final s = '${o['status']}';
                        return AppCard(
                          onTap: () => widget.goTab(2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '#${o['number']} - ${o['buyer']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      tr('${o['summary']}'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: C.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Pill(statusLabel(s), color: statusColor(s)),
                                  const SizedBox(height: 4),
                                  Text(
                                    rsShort(toNum(o['total'])),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: C.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
