import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/booking_detail_screen.dart';

/// Money received, money still to collect, and a 6-month chart.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/machinery-owner/earnings');
  }

  void _reload() => setState(() => _f = AgriApi.get('/machinery-owner/earnings'));

  Future<void> _open(Map b) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => MachineBookingDetailScreen(bookingId: '${b['id']}', ownerView: true)));
    if (mounted) _reload();
  }

  Widget _row(Map b, {bool paid = true}) => AppCard(
    onTap: () => _open(b),
    child: Row(
      children: [
        Icon(paid ? Icons.check_circle : Icons.schedule, color: paid ? C.green : C.amber),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${b['machineName']} - ${b['farmerName']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(paid ? '${b['payMethod'] ?? 'Cash'}  -  ${fmtIso(b['paidAt'])}' : flowLabel('${b['status']}'), style: const TextStyle(fontSize: 11.5, color: C.grey)),
            ],
          ),
        ),
        Text(rs(toNum(b['total'])), style: TextStyle(fontWeight: FontWeight.w800, color: paid ? C.green : C.amber)),
      ],
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
          final d = data as Map;
          final months = (d['months'] as List?) ?? [];
          final maxV = months.fold<num>(1, (a, m) => toNum((m as Map)['amount']) > a ? toNum(m['amount']) : a);
          final per = (d['byMachine'] as List?) ?? [];
          final paid = (d['payments'] as List?) ?? [];
          final unpaid = (d['unpaid'] as List?) ?? [];
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
                  eyebrow: 'Total earned',
                  title: rs(toNum(d['total'])),
                  subtitle: 'To collect: ${rs(toNum(d['pending']))}   |   Technician pay: ${rs(toNum(d['technicianShare']))}',
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Last 6 months'),
                      AppCard(
                        child: SizedBox(
                          height: 150,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: months.map((m) {
                              final v = toNum((m as Map)['amount']);
                              return Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(v > 0 ? rsShort(v) : '', style: const TextStyle(fontSize: 9.5, color: C.grey)),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 4 + 90 * (v / maxV).toDouble(),
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(color: v > 0 ? C.green : C.line, borderRadius: BorderRadius.circular(6)),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(tr('${m['label']}'), style: const TextStyle(fontSize: 11)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      if (per.isNotEmpty) ...[
                        const SectionTitle('By machine'),
                        AppCard(
                          child: Column(
                            children: per.map((p) => InfoRow('${(p as Map)['name']}', rs(toNum(p['amount'])))).toList(),
                          ),
                        ),
                      ],
                      if (unpaid.isNotEmpty) ...[
                        const SectionTitle('Waiting for payment'),
                        ...unpaid.map((b) => _row(b as Map, paid: false)),
                      ],
                      const SectionTitle('Payments received'),
                      if (paid.isEmpty) AppCard(child: Text(tr('No payments yet'), style: TextStyle(color: C.grey))),
                      ...paid.map((b) => _row(b as Map)),
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
