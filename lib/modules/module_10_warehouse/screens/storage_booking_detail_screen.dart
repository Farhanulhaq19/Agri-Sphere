import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_05_orders/widgets/payment_helpers.dart';

/// One storage booking. The farmer uses it to monitor stock, pay and rate;
/// the warehouse owner uses it to approve, receive, schedule labour, log readings and release.
class StorageBookingDetailScreen extends StatefulWidget {
  final String bookingId;
  final bool ownerView;
  const StorageBookingDetailScreen({super.key, required this.bookingId, this.ownerView = false});

  @override
  State<StorageBookingDetailScreen> createState() => _StorageBookingDetailScreenState();
}

class _StorageBookingDetailScreenState extends State<StorageBookingDetailScreen> {
  late Future<dynamic> _f;
  bool _busy = false;

  String get _p => '/storage-bookings/${widget.bookingId}';

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get(_p);
  }

  void _reload() => setState(() => _f = AgriApi.get(_p));

  Future<void> _do(Future<dynamic> Function() call, String ok) async {
    setState(() => _busy = true);
    final done = await runAction(context, call, ok: ok);
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) _reload();
  }

  Future<String?> _ask(String title, String label, {String initial = '', TextInputType? type}) async {
    final c = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr(title)),
        content: TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('OK'))),
        ],
      ),
    );
    return ok == true ? c.text.trim() : null;
  }

  // ----- farmer
  Future<void> _pay(Map b) async {
    final bal = toNum(b['balance']) - toNum(b['pendingAmount']);
    final v = await _ask('Amount to pay', 'Amount (Rs)', initial: '${bal.round()}', type: TextInputType.number);
    if (v == null || !mounted) return;
    final amount = num.tryParse(v.trim()) ?? 0;
    if (amount <= 0 || amount > bal) {
      snack(context, 'Enter an amount between 1 and ${bal.round()}', error: true);
      return;
    }
    final ok = await payBooking(context, payPath: '$_p/pay', id: widget.bookingId, amount: amount, extra: {'amount': amount});
    if (ok) _reload();
  }

  Future<void> _verify(Map pay, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await askRejectReason(context);
      if (reason == null) return;
    }
    await _do(() => AgriApi.patch('$_p/payments/${pay['_id']}', {'action': approve ? 'approve' : 'reject', 'reason': reason ?? ''}),
        approve ? 'Payment approved' : 'Payment rejected');
  }

  Future<void> _rate() async {
    var stars = 5;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(tr('Rate this warehouse')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(icon: Icon(i < stars ? Icons.star : Icons.star_border, color: C.amber, size: 30), onPressed: () => setD(() => stars = i + 1))),
              ),
              TextField(controller: note, maxLines: 2, decoration: InputDecoration(hintText: tr('Short review (optional)'), border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
            TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Submit'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _do(() => AgriApi.post('$_p/rate', {'rating': stars, 'review': note.text.trim()}), 'Thanks for rating');
  }

  // ----- owner
  Future<void> _received(Map b) async {
    final v = await _ask('Cash received', 'Amount (Rs)', initial: '${toNum(b['balance']).round()}', type: TextInputType.number);
    if (v == null) return;
    await _do(() => AgriApi.post('$_p/mark-paid', {'amount': v}), 'Payment confirmed');
  }

  Future<void> _stored(Map b) async {
    final v = await _ask('Crop received', 'Weighed quantity (tons)', initial: numStr(toNum(b['quantityTons'])), type: TextInputType.number);
    if (v == null) return;
    await _do(() => AgriApi.patch('$_p/stored', {'tons': v}), 'Marked as stored');
  }

  Future<void> _release(Map b) async {
    final v = await _ask('Release stock', 'Tons to release (max ${numStr(toNum(b['currentTons']))})', initial: numStr(toNum(b['currentTons'])), type: TextInputType.number);
    if (v == null) return;
    await _do(() => AgriApi.patch('$_p/release', {'tons': v}), 'Stock released');
  }

  Future<void> _reading() async {
    final temp = TextEditingController();
    final hum = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Add stock reading')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: temp, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Temperature (C)'), border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: hum, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Humidity (%)'), border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: note, decoration: InputDecoration(labelText: tr('Note (optional)'), border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Save'))),
        ],
      ),
    );
    if (ok != true) return;
    await _do(() => AgriApi.post('$_p/readings', {'temperature': temp.text.trim(), 'humidity': hum.text.trim(), 'note': note.text.trim()}), 'Reading saved');
  }

  Future<void> _task() async {
    List workers = [];
    try {
      workers = ((await AgriApi.get('/warehouse-owner/labour') as Map)['items'] as List?) ?? [];
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
      return;
    }
    if (!mounted) return;
    if (workers.isEmpty) {
      snack(context, 'Add labour first (Home > Labour)', error: true);
      return;
    }
    var kind = 'loading';
    DateTime? when;
    final chosen = <String>{};
    final charge = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Schedule loading / unloading'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ChipRow(items: const ['loading', 'unloading'], selected: kind, onSelect: (v) => setM(() => kind = v)),
                const SizedBox(height: 12),
                Text(tr('Workers'), style: TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ToggleChips(
                  items: workers.map((w) => '${w['name']}').toList(),
                  selected: chosen,
                  onChanged: (n, on) => setM(() => on ? chosen.add(n) : chosen.remove(n)),
                ),
                const SizedBox(height: 12),
                pickerField('When', when == null ? 'Pick date and time' : fmtIso(when!.toIso8601String()), Icons.event, () async {
                  final d = await pickDateTime(ctx);
                  if (d != null) setM(() => when = d);
                }),
                field('Handling charge (Rs, leave empty = total daily wages)', charge, type: TextInputType.number),
                PrimaryButton(
                  label: tr('Schedule'),
                  icon: Icons.check,
                  onPressed: () {
                    if (chosen.isEmpty || when == null) {
                      snack(ctx, 'Choose workers and a time', error: true);
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final ids = workers.where((w) => chosen.contains('${w['name']}')).map((w) => '${w['id']}').toList();
    await _do(() => AgriApi.post('$_p/tasks', {'kind': kind, 'labourIds': ids, 'scheduledAt': when!.toIso8601String(), 'charge': charge.text.trim()}), 'Scheduled');
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap, {bool outline = false, Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: outline
        ? OutlinedButton.icon(
            onPressed: _busy ? null : onTap,
            icon: Icon(icon, color: color ?? C.green),
            label: Text(tr(label), style: TextStyle(color: color ?? C.green)),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: BorderSide(color: color ?? C.green)),
          )
        : PrimaryButton(label: label, icon: icon, loading: _busy, onPressed: onTap),
  );

  @override
  Widget build(BuildContext context) {
    final owner = widget.ownerView;
    return Scaffold(
      backgroundColor: C.bg,
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final b = data as Map;
          final s = '${b['status']}';
          final bal = toNum(b['balance']);
          final pending = toNum(b['pendingAmount']);
          final online = ((b['payments'] as List?) ?? []).where((x) => '${(x as Map)['proof'] ?? ''}'.isNotEmpty).toList().reversed.toList();
          final tasks = (b['tasks'] as List?) ?? [];
          final readings = ((b['readings'] as List?) ?? []).reversed.toList();
          final actions = <Widget>[];
          if (owner) {
            if (s == 'requested') {
              actions.add(_btn('Approve request', Icons.check, () => _do(() => AgriApi.patch('$_p/respond', {'action': 'approve'}), 'Approved')));
              actions.add(_btn('Reject', Icons.close, () async {
                final note = await _ask('Reject request', 'Reason (optional)');
                if (note == null) return;
                await _do(() => AgriApi.patch('$_p/respond', {'action': 'reject', 'note': note}), 'Rejected');
              }, outline: true, color: Colors.red));
            }
            if (s == 'approved') actions.add(_btn('Crop received - mark as stored', Icons.inventory_2, () => _stored(b)));
            if (['approved', 'stored'].contains(s)) actions.add(_btn('Schedule loading / unloading', Icons.groups_outlined, _task, outline: true));
            if (s == 'stored') {
              actions.add(_btn('Add temperature / humidity reading', Icons.thermostat, _reading, outline: true));
              actions.add(_btn('Release stock', Icons.output, () => _release(b), outline: true));
            }
            if (['approved', 'stored', 'released'].contains(s) && bal > 0) actions.add(_btn('Mark cash received', Icons.payments_outlined, () => _received(b), outline: true));
          } else {
            if (['approved', 'stored', 'released'].contains(s) && bal - pending > 0) actions.add(_btn('Pay ${rs(bal - pending)}', Icons.payments_outlined, () => _pay(b)));
            if (b['canCancel'] == true && toNum(b['paidAmount']) == 0) {
              actions.add(_btn('Cancel request', Icons.close, () async {
                if (await confirmDialog(context, 'Cancel this request?', 'The warehouse will be told.')) {
                  await _do(() => AgriApi.patch('$_p/cancel'), 'Cancelled');
                }
              }, outline: true, color: Colors.red));
            }
            if (s == 'released' && b['rating'] == null) actions.add(_btn('Rate this warehouse', Icons.star_outline, _rate, outline: true));
          }
          return Column(
            children: [
              GreenHeader(
                eyebrow: 'Storage #${b['number']}',
                title: '${b['crop']}  -  ${numStr(toNum(s == 'stored' ? b['currentTons'] : b['quantityTons']))} t',
                subtitle: '${b['warehouseName']}, ${b['city'] ?? ''}',
                trailing: Pill(flowLabel(s), color: Colors.white),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: C.green,
                  onRefresh: () async => _reload(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (s == 'stored' && readings.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(child: StatCard(icon: Icons.thermostat, label: tr('Temperature'), value: (readings.first as Map)['temperature'] == null ? '-' : '${(readings.first as Map)['temperature']} C', color: Colors.orange)),
                            const SizedBox(width: 12),
                            Expanded(child: StatCard(icon: Icons.water_drop_outlined, label: tr('Humidity'), value: (readings.first as Map)['humidity'] == null ? '-' : '${(readings.first as Map)['humidity']}%', color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      AppCard(
                        child: Column(
                          children: [
                            InfoRow(owner ? 'Farmer' : 'Warehouse owner', owner ? '${b['farmerName']}' : '${b['ownerName'] ?? ''}'),
                            if (owner && '${b['farmerPhone'] ?? ''}'.isNotEmpty) InfoRow('Phone', '${b['farmerPhone']}'),
                            InfoRow('Requested', '${numStr(toNum(b['quantityTons']))} t of ${b['crop']}'),
                            if (s == 'stored') InfoRow('In store now', '${numStr(toNum(b['currentTons']))} t', bold: true),
                            InfoRow('Storage type', '${b['storageType'] ?? ''}'),
                            InfoRow('From', fmtIso(b['startDate'])),
                            InfoRow('Until', fmtIso(b['endDate'])),
                            InfoRow('Period', '${toNum(b['days']).round()} days'),
                            if (b['needLoading'] == true) const InfoRow('Handling', 'Loading / unloading needed'),
                            if ('${b['notes'] ?? ''}'.isNotEmpty) InfoRow('Notes', '${b['notes']}'),
                            if ('${b['ownerNote'] ?? ''}'.isNotEmpty) InfoRow('Owner note', '${b['ownerNote']}'),
                          ],
                        ),
                      ),
                      const SectionTitle('Charges'),
                      AppCard(
                        child: Column(
                          children: [
                            InfoRow('Storage (${rs(toNum(b['rate']))}/t/day)', rs(toNum(b['storageCost']))),
                            InfoRow('Loading / unloading', rs(toNum(b['handlingCost']))),
                            const Divider(),
                            InfoRow('Total', rs(toNum(b['total'])), bold: true),
                            InfoRow('Paid', rs(toNum(b['paidAmount']))),
                            InfoRow('Balance', rs(bal), bold: bal > 0),
                            if (pending > 0) InfoRow('Under review', rs(pending)),
                          ],
                        ),
                      ),
                      if (online.isNotEmpty) ...[
                        const SectionTitle('Online payments'),
                        ...online.map((x) {
                          final pay = x as Map;
                          final review = '${pay['status']}' == 'under_review';
                          return ProofReview(
                            proof: '${pay['proof']}',
                            ref: '${pay['ref'] ?? ''}',
                            method: '${pay['method']}',
                            amount: toNum(pay['amount']),
                            status: '${pay['status']}',
                            note: '${pay['note'] ?? ''}',
                            onApprove: owner && review && !_busy ? () => _verify(pay, true) : null,
                            onReject: owner && review && !_busy ? () => _verify(pay, false) : null,
                          );
                        }),
                      ],
                      if (tasks.isNotEmpty) ...[
                        const SectionTitle('Loading & unloading'),
                        ...tasks.map((t) {
                          final done = '${(t as Map)['status']}' == 'done';
                          return AppCard(
                            child: Row(
                              children: [
                                Icon(done ? Icons.check_circle : Icons.schedule, color: done ? C.green : C.amber),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${flowLabel('${t['kind']}')}  -  ${rs(toNum(t['charge']))}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text('${fmtIso(t['scheduledAt'])}  -  ${((t['labourNames'] as List?) ?? []).join(', ')}', style: const TextStyle(fontSize: 11.5, color: C.grey)),
                                    ],
                                  ),
                                ),
                                if (owner && !done) TextButton(onPressed: _busy ? null : () => _do(() => AgriApi.patch('$_p/tasks/${t['id'] ?? t['_id']}'), 'Task done'), child: Text(tr('Done'))),
                              ],
                            ),
                          );
                        }),
                      ],
                      if (readings.isNotEmpty) ...[
                        const SectionTitle('Stock monitor'),
                        AppCard(
                          child: Column(
                            children: readings.take(8).map((r) {
                              final x = r as Map;
                              return InfoRow(fmtIso(x['at']), [
                                if (x['temperature'] != null) '${x['temperature']} C',
                                if (x['humidity'] != null) '${x['humidity']}%',
                                if ('${x['note'] ?? ''}'.isNotEmpty) '${x['note']}',
                              ].join('  -  '));
                            }).toList(),
                          ),
                        ),
                      ],
                      if (b['rating'] != null) ...[
                        const SectionTitle('Rating'),
                        AppCard(child: Row(children: [const Icon(Icons.star, color: C.amber), const SizedBox(width: 6), Text('${b['rating']}/5  ${b['review'] ?? ''}')])),
                      ],
                      const SectionTitle('Progress'),
                      HistoryTimeline((b['history'] as List?) ?? []),
                      const SizedBox(height: 8),
                      ...actions,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
