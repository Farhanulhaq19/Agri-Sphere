import 'package:flutter/material.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_01_auth/session_helper.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<dynamic> _f;

  Future<dynamic> _fetch() => Future.wait([AgriApi.get('/admin/stats'), AgriApi.get('/admin/users?role=supplier')]);

  @override
  void initState() {
    super.initState();
    _f = _fetch();
  }

  void _reload() => setState(() => _f = _fetch());

  Future<void> _verify(Map u) async {
    try {
      await AgriApi.patch('/admin/verify/${u['id']}', {'verified': u['verified'] != true});
      if (mounted) _reload();
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  Widget _tile(String l, dynamic v) => Expanded(
        child: AppCard(
          margin: const EdgeInsets.only(right: 8, bottom: 12),
          child: Column(children: [
            Text('$v', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.green)),
            Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: C.grey)),
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
          final list = data as List;
          final s = list[0] as Map;
          final users = (((list[1] as Map)['items']) as List?) ?? [];
          final byRole = ((s['users'] as Map?)?['byRole'] as Map?) ?? {};
          return ListView(padding: EdgeInsets.zero, children: [
            GreenHeader(
              title: 'Admin',
              subtitle: 'Platform overview',
              trailing: CircleBtn(icon: Icons.logout, onTap: () => logout(context)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _tile('Users', (s['users'] as Map?)?['total'] ?? 0),
                  _tile('Listings', s['listings']),
                  _tile('Orders', s['orders']),
                  _tile('Sales', rsShort(toNum(s['gmv']))),
                ]),
                Wrap(spacing: 6, runSpacing: 6, children: byRole.entries.map((e) => Pill('${e.key}: ${e.value}')).toList()),
                SectionTitle('Suppliers (${s['suppliersPending']} pending)'),
                if (users.isEmpty) const AppCard(child: Text('No suppliers have registered yet.', style: TextStyle(color: C.grey))),
                ...users.map((u) {
                  final ok = u['verified'] == true;
                  return AppCard(
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${(u['businessName'] ?? '').toString().isEmpty ? u['name'] : u['businessName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${u['email']}', style: const TextStyle(fontSize: 11, color: C.grey)),
                        ]),
                      ),
                      Pill(ok ? 'Verified' : 'Pending', color: ok ? C.green : C.amber),
                      TextButton(onPressed: () => _verify(u as Map), child: Text(ok ? 'Revoke' : 'Verify')),
                    ]),
                  );
                }),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}