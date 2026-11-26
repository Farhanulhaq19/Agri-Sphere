import 'package:flutter/material.dart';
import 'package:agrisphere/modules/module_06_expert/screens/ask_expert_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/my_storage_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_browse_screen.dart';
import 'package:agrisphere/modules/module_12_ai/agri_chatbot_screen.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/account_button.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/booking_detail_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machine_form_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machinery_widgets.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/maintenance_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/owner_schedule_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/technicians_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  final void Function(int) goTab;
  const OwnerHomeScreen({super.key, required this.goTab});
  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/machinery-owner/dashboard');
  }

  void _reload() => setState(() => _f = AgriApi.get('/machinery-owner/dashboard'));

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
      floatingActionButton: const AgriChatBotFab(role: 'machinery'),
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
                  eyebrow: 'Machinery owner',
                  title: '${m['name']}',
                  trailing: const AccountButton(),
                  bottom: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('Earned this month'), style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(rs(toNum(m['monthEarnings'])), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(tr('To collect'), style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(rsShort(toNum(m['pendingPayments'])), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: HeroBanner(image: 'assets/img/hero_tractor.png', title: tr('Put your machines to work'), subtitle: tr('Rent or sell and get paid on time')),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatGrid([
                        StatCard(icon: Icons.agriculture, label: 'Machines (${toNum(m['available']).round()} available)', value: '${m['machines']}', onTap: () => widget.goTab(1)),
                        StatCard(icon: Icons.mark_email_unread_outlined, label: tr('New requests'), value: '${m['pendingRequests']}', color: C.amber, onTap: () => widget.goTab(2)),
                        StatCard(icon: Icons.play_circle_outline, label: tr('Jobs running'), value: '${m['activeJobs']}', color: Colors.indigo),
                        StatCard(icon: Icons.engineering, label: tr('Technicians'), value: '${m['technicians']}', color: Colors.orange, onTap: () => _open(const TechniciansScreen())),
                      ]),
                      const SectionTitle('Quick actions'),
                      Row(
                        children: [
                          _quick(Icons.add_circle_outline, 'Add machine', () => _open(const MachineFormScreen())),
                          _quick(Icons.engineering_outlined, 'Technicians', () => _open(const TechniciansScreen())),
                          _quick(Icons.calendar_month_outlined, 'Schedule', () => _open(const OwnerScheduleScreen())),
                          _quick(Icons.build_outlined, 'Maintenance', () => _open(const MaintenanceScreen())),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // machinery owners also use other AgriSphere services: storage space and expert advice
                      Row(
                        children: [
                          _quick(Icons.warehouse_outlined, 'Rent storage', () => _open(const WarehouseBrowseScreen())),
                          _quick(Icons.inventory_2_outlined, 'My stored stock', () => _open(const MyStorageScreen())),
                          _quick(Icons.support_agent, 'Ask expert', () => _open(const AskExpertScreen())),
                          _quick(Icons.smart_toy_outlined, 'AgriChatBot', () => _open(const AgriChatBotScreen(role: 'machinery'))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SectionTitle('Recent bookings', trailing: TextButton(onPressed: () => widget.goTab(2), child: Text(tr('See all')))),
                      if (recent.isEmpty) AppCard(child: Text(tr('No bookings yet. Add a machine so farmers can find it.'), style: TextStyle(color: C.grey))),
                      ...recent.map((b) => MachineBookingTile(
                        b: b as Map,
                        ownerView: true,
                        onTap: () => _open(MachineBookingDetailScreen(bookingId: '${b['id']}', ownerView: true)),
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
