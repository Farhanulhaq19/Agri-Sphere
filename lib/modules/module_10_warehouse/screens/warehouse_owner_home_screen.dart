import 'package:flutter/material.dart';
import 'package:agrisphere/modules/module_12_ai/agri_chatbot_screen.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/account_button.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machinery_browse_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/my_machine_bookings_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/labour_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/storage_booking_detail_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_form_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_widgets.dart';

class WarehouseOwnerHomeScreen extends StatefulWidget {
  final void Function(int) goTab;
  const WarehouseOwnerHomeScreen({super.key, required this.goTab});
  @override
  State<WarehouseOwnerHomeScreen> createState() => _WarehouseOwnerHomeScreenState();
}

class _WarehouseOwnerHomeScreenState extends State<WarehouseOwnerHomeScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/warehouse-owner/dashboard');
  }

  void _reload() => setState(() => _f = AgriApi.get('/warehouse-owner/dashboard'));

  Future<void> _open(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    if (mounted) _reload();
  }

  Widget _quick(IconData i, String l, VoidCallback t) => Expanded(
    child: InkWell(
      onTap: t,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(14)),
            child: Icon(i, color: C.green),
          ),
          const SizedBox(height: 6),
          Text(tr(l), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      floatingActionButton: const AgriChatBotFab(role: 'warehouse'),
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final m = data as Map;
          final recent = (m['recent'] as List?) ?? [];
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
                  eyebrow: 'Warehouse owner',
                  title: '${m['name']}',
                  trailing: const AccountButton(),
                  bottom: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Space used: ${numStr(toNum(m['usedTons']))} of ${numStr(toNum(m['capacityTons']))} tons', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(value: (toNum(m['occupancy']) / 100).clamp(0.0, 1.0).toDouble(), minHeight: 8, backgroundColor: Colors.white24, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text('${m['occupancy']}% full', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: HeroBanner(image: 'assets/img/hero_warehouse.png', title: tr('Fill your warehouse'), subtitle: tr('Approve requests and track every bag')),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatGrid([
                        StatCard(icon: Icons.mark_email_unread_outlined, label: tr('New requests'), value: '${m['pendingRequests']}', color: C.amber, onTap: () => widget.goTab(2)),
                        StatCard(icon: Icons.inventory_2_outlined, label: tr('Lots in store'), value: '${m['storedLots']}', onTap: () => widget.goTab(2)),
                        StatCard(icon: Icons.account_balance_wallet_outlined, label: tr('Received'), value: rsShort(toNum(m['earnings'])), onTap: () => widget.goTab(3)),
                        StatCard(icon: Icons.pending_actions, label: tr('Outstanding'), value: rsShort(toNum(m['outstanding'])), color: Colors.red, onTap: () => widget.goTab(3)),
                      ]),
                      const SectionTitle('Quick actions'),
                      Row(
                        children: [
                          _quick(Icons.add_business_outlined, 'Add warehouse', () => _open(const WarehouseFormScreen())),
                          _quick(Icons.groups_outlined, 'Labour (${m['labour']})', () => _open(const LabourScreen())),
                          _quick(Icons.agriculture_outlined, 'Book machinery', () => _open(const MachineryBrowseScreen())),
                          _quick(Icons.local_shipping_outlined, 'Track machinery', () => _open(const MyMachineBookingsScreen())),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SectionTitle('Recent requests', trailing: TextButton(onPressed: () => widget.goTab(2), child: Text(tr('See all')))),
                      if (recent.isEmpty) AppCard(child: Text(tr('No storage requests yet. List a warehouse so farmers can book space.'), style: TextStyle(color: C.grey))),
                      ...recent.map((b) => StorageBookingTile(
                        b: b as Map,
                        ownerView: true,
                        onTap: () => _open(StorageBookingDetailScreen(bookingId: '${b['id']}', ownerView: true)),
                      )),
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
