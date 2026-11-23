import 'package:agrisphere/modules/module_01_auth/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_03_crops/screens/add_crop_screen.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/sell_produce_screen.dart';
import 'package:agrisphere/modules/module_06_expert/screens/ask_expert_screen.dart';
import 'package:agrisphere/modules/module_05_orders/screens/order_tracking_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int) goTab;
  const DashboardScreen({super.key, required this.goTab});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/dashboard');
  }

  void _reload() => setState(() => _f = AgriApi.get('/dashboard'));

  Future<void> _open(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    if (mounted) _reload();
  }

  Widget _quick(IconData i, String l, VoidCallback t) => Expanded(
        child: InkWell(
          onTap: t,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(14)),
              child: Icon(i, color: C.green),
            ),
            const SizedBox(height: 6),
            Text(l, style: const TextStyle(fontSize: 11)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final m = data as Map;
          final orders = (m['recentOrders'] as List?) ?? [];
          final health = toNum(m['cropHealth']);
          final healthLabel = health >= 80 ? 'Excellent' : (health >= 60 ? 'Good' : 'Needs care');
          return RefreshIndicator(
            color: C.green,
            onRefresh: () async {
              _reload();
              await _f;
            },
            child: ListView(padding: EdgeInsets.zero, children: [
              GreenHeader(
                eyebrow: 'Good morning,',
                title: '${m['name']}',
                trailing: CircleBtn(icon: Icons.person_outline, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
                bottom: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Total earnings', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(rs(toNum(m['earnings'])), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                      child: Text('+${m['changePct']}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: AppCard(
                        child: Row(children: [
                          Ring(health, size: 48),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Crop health', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(healthLabel, style: const TextStyle(fontSize: 11, color: C.green)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppCard(
                        child: Row(children: [
                          const Icon(Icons.water_drop, color: Colors.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${m['nextIrrigation']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const Text('Next irrigation', style: TextStyle(fontSize: 11, color: C.grey)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                  const SectionTitle('Quick actions'),
                  Row(children: [
                    _quick(Icons.add, 'Add crop', () => _open(const AddCropScreen())),
                    _quick(Icons.sell_outlined, 'Sell', () => _open(const SellProduceScreen())),
                    _quick(Icons.chat_bubble_outline, 'Ask expert', () => _open(const AskExpertScreen())),
                    _quick(Icons.shopping_bag_outlined, 'Buy inputs', () => widget.goTab(2)),
                  ]),
                  const SizedBox(height: 8),
                  SectionTitle('Recent orders', trailing: TextButton(onPressed: () => widget.goTab(4), child: const Text('See all'))),
                  if (orders.isEmpty) const AppCard(child: Text('No orders yet', style: TextStyle(color: C.grey))),
                  ...orders.map((o) {
                    final s = '${o['status']}';
                    return AppCard(
                      onTap: () => _open(OrderTrackingScreen(orderId: '${o['id']}')),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.receipt_long, color: C.green, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${o['buyer']} - ${o['summary']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('Order #${o['number']} - ${statusLabel(s)}', style: const TextStyle(fontSize: 11, color: C.grey)),
                          ]),
                        ),
                        Text(rsShort(toNum(o['total'])), style: const TextStyle(fontWeight: FontWeight.w700, color: C.green)),
                      ]),
                    );
                  }),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}
