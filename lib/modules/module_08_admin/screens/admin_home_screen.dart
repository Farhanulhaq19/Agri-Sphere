import 'package:flutter/material.dart' hide ListBody;
import 'package:agrisphere/modules/module_12_ai/agri_chatbot_screen.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/account_button.dart';
import 'package:agrisphere/modules/module_05_orders/screens/order_tracking_screen.dart';
import 'package:agrisphere/modules/module_05_orders/widgets/payment_helpers.dart';

/// Admin console: overview charts, payment verification, users, listing moderation and the activity log.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tab = 0;

  static const _tabs = [
    (Icons.dashboard_outlined, 'Overview'),
    (Icons.fact_check_outlined, 'Payments'),
    (Icons.people_outline, 'Users'),
    (Icons.storefront_outlined, 'Listings'),
    (Icons.history, 'Activity'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [const _Overview(), const _Payments(), const _Users(), const _Listings(), const _Logs()];
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        GreenHeader(
          eyebrow: 'Admin console',
          title: tr(_tabs[_tab].$2),
          trailing: const AccountButton(),
        ),
        Expanded(child: IndexedStack(index: _tab, children: pages)),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: _tabs.map((t) => NavigationDestination(icon: Icon(t.$1), label: tr(t.$2))).toList(),
      ),
    );
  }
}

// ================================================================ overview
class _Overview extends StatefulWidget {
  const _Overview();
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  late Future<dynamic> _f = AgriApi.get('/admin/overview');
  void _reload() => setState(() => _f = AgriApi.get('/admin/overview'));

  Widget _stat(IconData i, Color c, String v, String l) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
        child: Row(children: [
          CircleAvatar(backgroundColor: c.withValues(alpha: 0.12), child: Icon(i, color: c, size: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              Text(tr(l), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.grey)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => Async(
        future: _f,
        onRetry: _reload,
        builder: (d) {
          final m = d as Map;
          final users = (m['users'] as Map?) ?? const {};
          final roles = ((users['byRole'] as Map?) ?? const {}).entries.toList()..sort((a, b) => toNum(b.value).compareTo(toNum(a.value)));
          final days = ((m['revenue14d'] as List?) ?? const []).cast<Map>();
          final status = (m['ordersByStatus'] as Map?) ?? const {};
          final top = ((m['topProducts'] as List?) ?? const []).cast<Map>();
          final maxDay = days.fold<num>(0, (a, x) => toNum(x['amount']) > a ? toNum(x['amount']) : a);
          final maxRole = roles.isEmpty ? 1 : toNum(roles.first.value);
          return RefreshIndicator(
            color: C.green,
            onRefresh: () async => _reload(),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              const AgriChatBotCard(role: 'admin', subtitle: 'Ask about payments, fake listings or growing the platform'),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  _stat(Icons.people, C.green, '${users['total'] ?? 0}', 'Users (+${m['newUsers7d']} this week)'),
                  _stat(Icons.payments, const Color(0xFFD97706), rsShort(toNum(m['gmv'])), 'Total sales'),
                  _stat(Icons.receipt_long, const Color(0xFF2563EB), '${m['orders']}', 'Orders'),
                  _stat(Icons.storefront, const Color(0xFF7C3AED), '${m['activeListings']}/${m['listings']}', 'Active listings'),
                  _stat(Icons.fact_check, Colors.red, '${m['pendingPayments']}', 'Payments to verify'),
                  _stat(Icons.agriculture, const Color(0xFFB45309), '${m['machines']}', 'Machines'),
                  _stat(Icons.warehouse, const Color(0xFF0E7490), '${m['warehouses']}', 'Warehouses'),
                  _stat(Icons.help_outline, const Color(0xFF059669), '${m['openQueries']}', 'Open expert questions'),
                ],
              ),
              const SectionTitle('Sales in the last 14 days'),
              AppCard(
                child: SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: days.map((x) {
                      final h = maxDay == 0 ? 0.03 : (toNum(x['amount']) / maxDay).clamp(0.03, 1.0).toDouble();
                      return Expanded(
                        child: Tooltip(
                          message: '${x['date']}: ${rs(toNum(x['amount']))} · ${x['orders']} ${tr('orders')}',
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: h),
                              duration: const Duration(milliseconds: 700),
                              builder: (_, v, _) => Container(
                                height: 120 * v,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${x['date']}'.substring(8), style: const TextStyle(fontSize: 9, color: C.grey)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SectionTitle('Users by role'),
              AppCard(
                child: Column(
                  children: roles
                      .map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              SizedBox(width: 110, child: Text(tr(_roleLabel('${e.key}')), style: const TextStyle(fontSize: 12.5))),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(value: toNum(e.value) / maxRole, minHeight: 10, backgroundColor: C.light, color: C.green),
                                ),
                              ),
                              SizedBox(width: 36, child: Text('${e.value}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
                            ]),
                          ))
                      .toList(),
                ),
              ),
              const SectionTitle('Orders by status'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: status.entries.map((e) => Pill('${statusLabel('${e.key}')}: ${e.value}', color: statusColor('${e.key}'))).toList(),
              ),
              const SectionTitle('Top products'),
              ...top.map((p) => AppCard(
                    child: Row(children: [
                      Icon(catIcon(p['category']), color: catColor(p['category'])),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${p['title']} · ${p['sellerName'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${toNum(p['sales']).round()} ${tr('sales')}', style: const TextStyle(fontWeight: FontWeight.w800, color: C.green)),
                    ]),
                  )),
            ]),
          );
        },
      );

  static String _roleLabel(String r) => const {
        'farmer': 'Farmers',
        'buyer': 'Buyers',
        'expert': 'Experts',
        'supplier': 'Suppliers',
        'machineryowner': 'Machinery owners',
        'warehouseowner': 'Warehouse owners',
        'admin': 'Admins',
      }[r.replaceAll('_', '')] ??
      r;
}

// ================================================================ payments
class _Payments extends StatefulWidget {
  const _Payments();
  @override
  State<_Payments> createState() => _PaymentsState();
}

class _PaymentsState extends State<_Payments> {
  String _status = 'under_review';
  static const _labels = {'under_review': 'To verify', 'paid': 'Approved', 'rejected': 'Rejected'};

  Future<void> _verify(BuildContext ctx, Map o, bool ok, Future<void> Function() reload) async {
    String? reason;
    if (!ok) {
      reason = await askRejectReason(ctx);
      if (reason == null) return;
    }
    if (!ctx.mounted) return;
    if (await runAction(ctx, () => AgriApi.patch('/orders/${o['id']}/payment', {'action': ok ? 'approve' : 'reject', 'reason': reason ?? ''}),
        ok: ok ? 'Payment approved' : 'Payment rejected')) {
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) => ListBody(
        key: ValueKey(_status),
        load: () => AgriApi.get('/admin/payments?status=$_status'),
        empty: _status == 'under_review' ? 'No payments waiting. All caught up!' : 'Nothing here yet',
        emptyIcon: Icons.verified_outlined,
        top: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChipRow(
            items: _labels.values.toList(),
            selected: _labels[_status]!,
            onSelect: (v) => setState(() => _status = _labels.entries.firstWhere((e) => e.value == v).key),
          ),
        ),
        item: (ctx, o, reload) => Column(children: [
          AppCard(
            onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: '${o['id']}'))),
            margin: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${tr('Order')} #${o['number']} · ${o['buyerName']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${tr('Seller')}: ${o['sellerName'] ?? ''} · ${fmtIso(o['updatedAt'])}', style: const TextStyle(fontSize: 11.5, color: C.grey)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: C.grey),
            ]),
          ),
          ProofReview(
            proof: '${o['paymentProof'] ?? ''}',
            ref: '${o['paymentRef'] ?? ''}',
            method: '${o['payment']}',
            amount: toNum(o['total']),
            status: '${o['paymentStatus']}',
            note: '${o['paymentNote'] ?? ''}',
            onApprove: o['canVerify'] == true ? () => _verify(ctx, o, true, reload) : null,
            onReject: o['canVerify'] == true ? () => _verify(ctx, o, false, reload) : null,
          ),
          const SizedBox(height: 10),
        ]),
      );
}

// ================================================================ users
class _Users extends StatefulWidget {
  const _Users();
  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  String _role = 'all';
  String _q = '';
  final _c = TextEditingController();
  static const _roles = ['all', 'farmer', 'buyer', 'supplier', 'expert', 'machineryowner', 'warehouseowner'];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListBody(
        key: ValueKey('$_role|$_q'),
        load: () => AgriApi.get('/admin/users?role=$_role&q=${Uri.encodeQueryComponent(_q)}'),
        empty: 'No users found',
        emptyIcon: Icons.person_search,
        top: Column(children: [
          TextField(
            controller: _c,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(
              hintText: tr('Search name, email or phone'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          ChipRow(items: _roles, selected: _role, onSelect: (v) => setState(() => _role = v)),
          const SizedBox(height: 8),
        ]),
        item: (ctx, u, reload) => AppCard(
          child: Row(children: [
            CircleAvatar(
              backgroundColor: C.light,
              child: Text('${u['name']}'.isEmpty ? '?' : '${u['name']}'[0].toUpperCase(), style: const TextStyle(color: C.green, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text('${u['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (u['verified'] == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 15, color: C.green)),
                ]),
                Text('${u['email']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.grey)),
                Text(((u['roles'] as List?) ?? [u['role']]).join(', '), style: const TextStyle(fontSize: 11, color: C.green)),
              ]),
            ),
            Switch(
              value: u['verified'] == true,
              activeThumbColor: C.green,
              onChanged: (v) async {
                if (await runAction(ctx, () => AgriApi.patch('/admin/verify/${u['id']}', {'verified': v}), ok: v ? 'User verified' : 'Verification removed')) {
                  await reload();
                }
              },
            ),
          ]),
        ),
      );
}

// ================================================================ listings moderation
class _Listings extends StatefulWidget {
  const _Listings();
  @override
  State<_Listings> createState() => _ListingsState();
}

class _ListingsState extends State<_Listings> {
  String _status = 'all';
  String _q = '';
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _set(BuildContext ctx, Map l, String status, Future<void> Function() reload) async {
    var reason = '';
    if (status != 'active') {
      final r = await showDialog<String>(
        context: ctx,
        builder: (d) {
          final t = TextEditingController();
          return AlertDialog(
            title: Text(tr(status == 'removed' ? 'Remove listing' : 'Pause listing')),
            content: TextField(controller: t, decoration: InputDecoration(hintText: tr('Reason (the seller will see it)'))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d), child: Text(tr('Cancel'))),
              TextButton(onPressed: () => Navigator.pop(d, t.text.trim()), child: Text(tr('Confirm'))),
            ],
          );
        },
      );
      if (r == null) return;
      reason = r;
    }
    if (!ctx.mounted) return;
    if (await runAction(ctx, () => AgriApi.patch('/admin/listings/${l['id']}', {'status': status, 'reason': reason}), ok: 'Listing $status')) {
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) => ListBody(
        key: ValueKey('$_status|$_q'),
        load: () => AgriApi.get('/admin/listings?status=$_status&q=${Uri.encodeQueryComponent(_q)}'),
        empty: 'No listings found',
        emptyIcon: Icons.storefront_outlined,
        top: Column(children: [
          TextField(
            controller: _c,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(
              hintText: tr('Search product or seller'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          ChipRow(items: const ['all', 'active', 'paused', 'removed'], selected: _status, onSelect: (v) => setState(() => _status = v)),
          const SizedBox(height: 8),
        ]),
        item: (ctx, l, reload) {
          final st = '${l['status'] ?? 'active'}';
          return AppCard(
            child: Row(children: [
              Icon(catIcon(l['category']), color: catColor(l['category'])),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${l['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${l['sellerName'] ?? ''} · ${rs(toNum(l['pricePerKg']))}/${l['unit'] ?? 'kg'} · ${toNum(l['quantityKg']).round()} left',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.grey)),
                ]),
              ),
              Pill(st, color: st == 'active' ? C.green : (st == 'paused' ? C.amber : Colors.red)),
              PopupMenuButton<String>(
                onSelected: (v) => _set(ctx, l, v, reload),
                itemBuilder: (_) => [
                  if (st != 'active') PopupMenuItem(value: 'active', child: Text(tr('Make active'))),
                  if (st != 'paused') PopupMenuItem(value: 'paused', child: Text(tr('Pause'))),
                  if (st != 'removed') PopupMenuItem(value: 'removed', child: Text(tr('Remove'))),
                ],
              ),
            ]),
          );
        },
      );
}

// ================================================================ activity log
class _Logs extends StatelessWidget {
  const _Logs();
  static const _icons = {
    'payment.approve': (Icons.check_circle, C.green),
    'payment.reject': (Icons.cancel, Colors.red),
    'user.verify': (Icons.verified, C.green),
    'user.unverify': (Icons.remove_moderator, Colors.orange),
    'listing.removed': (Icons.delete_outline, Colors.red),
    'listing.paused': (Icons.pause_circle, Colors.orange),
    'listing.active': (Icons.play_circle, C.green),
  };

  @override
  Widget build(BuildContext context) => ListBody(
        load: () => AgriApi.get('/admin/logs'),
        empty: 'No admin actions yet',
        emptyIcon: Icons.history,
        item: (ctx, l, reload) {
          final look = _icons['${l['action']}'] ?? (Icons.info_outline, C.grey);
          return AppCard(
            child: Row(children: [
              Icon(look.$1, color: look.$2),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${l['adminName'] ?? 'Admin'} · ${l['action']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  if ('${l['detail'] ?? ''}'.isNotEmpty) Text('${l['detail']}', style: const TextStyle(fontSize: 12)),
                  Text(fmtIso(l['createdAt']), style: const TextStyle(fontSize: 11, color: C.grey)),
                ]),
              ),
            ]),
          );
        },
      );
}
