import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/booking_detail_screen.dart';

/// What is booked next, plus upcoming maintenance.
class OwnerScheduleScreen extends StatefulWidget {
  const OwnerScheduleScreen({super.key});
  @override
  State<OwnerScheduleScreen> createState() => _OwnerScheduleScreenState();
}

class _OwnerScheduleScreenState extends State<OwnerScheduleScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/machinery-owner/schedule');
  }

  void _reload() => setState(() => _f = AgriApi.get('/machinery-owner/schedule'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(
        children: [
          GreenHeader(title: tr('Schedule'), subtitle: tr('Upcoming jobs and maintenance')),
          Expanded(
            child: Async(
              future: _f,
              onRetry: _reload,
              builder: (data) {
                final jobs = ((data as Map)['jobs'] as List?) ?? [];
                final maint = (data['maintenance'] as List?) ?? [];
                if (jobs.isEmpty && maint.isEmpty) return EmptyState(icon: Icons.calendar_month_outlined, text: tr('Nothing scheduled yet'));
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SectionTitle('Jobs'),
                    if (jobs.isEmpty) Text(tr('No upcoming jobs'), style: TextStyle(color: C.grey)),
                    ...jobs.map((j) => AppCard(
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => MachineBookingDetailScreen(bookingId: '${j['id']}', ownerView: true)));
                        _reload();
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(12)),
                            child: Icon(machineIcon(j['category']), color: C.green),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${j['machineName']} - ${j['farmerName']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                Text('${fmtIso(j['startAt'])}  to  ${fmtIso(j['endAt'])}', style: const TextStyle(fontSize: 11.5, color: C.grey)),
                                if (j['withTechnician'] == true) Text('Technician: ${j['technicianName'] ?? 'to assign'}', style: const TextStyle(fontSize: 11.5, color: C.grey)),
                              ],
                            ),
                          ),
                          Pill(flowLabel('${j['status']}'), color: flowColor('${j['status']}')),
                        ],
                      ),
                    )),
                    const SectionTitle('Maintenance'),
                    if (maint.isEmpty) Text(tr('No maintenance planned'), style: TextStyle(color: C.grey)),
                    ...maint.map((m) => AppCard(
                      child: Row(
                        children: [
                          const Icon(Icons.build_outlined, color: C.amber),
                          const SizedBox(width: 12),
                          Expanded(child: Text('${m['machineName']} - ${m['kind']}\n${fmtDate(DateTime.tryParse('${m['date']}')?.toLocal() ?? DateTime.now())}', style: const TextStyle(fontSize: 12.5))),
                          Text(rs(toNum(m['cost'])), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
