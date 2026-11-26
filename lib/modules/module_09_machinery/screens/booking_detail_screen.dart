import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/modules/module_05_orders/widgets/payment_helpers.dart';

/// One machine booking: details, cost, tracking, history and the right buttons
/// for whoever is looking (the renter / buyer or the machinery owner).
class MachineBookingDetailScreen extends StatefulWidget {
  final String bookingId;
  final bool ownerView;
  const MachineBookingDetailScreen({super.key, required this.bookingId, this.ownerView = false});

  @override
  State<MachineBookingDetailScreen> createState() => _MachineBookingDetailScreenState();
}

class _MachineBookingDetailScreenState extends State<MachineBookingDetailScreen> {
  late Future<dynamic> _f;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/machinery-bookings/${widget.bookingId}');
  }

  void _reload() => setState(() => _f = AgriApi.get('/machinery-bookings/${widget.bookingId}'));

  Future<void> _do(Future<dynamic> Function() call, String ok) async {
    setState(() => _busy = true);
    final done = await runAction(context, call, ok: ok);
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) _reload();
  }

  String get _p => '/machinery-bookings/${widget.bookingId}';

  // ----- renter actions
  Future<void> _pay(Map b) async {
    final ok = await payBooking(context, payPath: '$_p/pay', id: widget.bookingId, amount: toNum(b['total']));
    if (ok) _reload();
  }

  Future<void> _verify(bool approve) async {
    String? reason;
    if (!approve) {
      reason = await askRejectReason(context);
      if (reason == null) return;
    }
    await _do(() => AgriApi.patch('$_p/payment', {'action': approve ? 'approve' : 'reject', 'reason': reason ?? ''}),
        approve ? 'Payment approved' : 'Payment rejected');
  }

  Future<void> _rate() async {
    var stars = 5;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(tr('Rate this job')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(i < stars ? Icons.star : Icons.star_border, color: C.amber, size: 30),
                  onPressed: () => setD(() => stars = i + 1),
                )),
              ),
              TextField(controller: note, maxLines: 2, decoration: InputDecoration(hintText: tr('Write a short review (optional)'), border: OutlineInputBorder())),
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

  // ----- owner actions
  Future<void> _accept(Map b) async {
    String? techId;
    if (b['withTechnician'] == true) {
      List list = [];
      try {
        list = ((await AgriApi.get('/machinery-owner/technicians') as Map)['items'] as List?) ?? [];
      } catch (e) {
        if (mounted) snack(context, cleanErr(e), error: true);
        return;
      }
      if (!mounted) return;
      final picked = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Who will operate? (${toNum(b['techHours']).round()} hours)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person, color: C.green),
                  title: Text(tr('I will operate it myself')),
                  onTap: () => Navigator.pop(ctx, ''),
                ),
                ...list.map((t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.engineering, color: C.green),
                  title: Text(tr('${t['name']}')),
                  subtitle: Text('${t['skill']}  -  ${t['status']}'),
                  onTap: () => Navigator.pop(ctx, '${t['id']}'),
                )),
                if (list.isEmpty) Padding(padding: EdgeInsets.only(top: 6), child: Text(tr('Add technicians from the Home tab to assign them here.'), style: TextStyle(color: C.grey, fontSize: 12))),
              ],
            ),
          ),
        ),
      );
      if (picked == null) return;
      techId = picked;
    }
    await _do(() => AgriApi.patch('$_p/respond', {'action': 'accept', if (techId != null && techId.isNotEmpty) 'technicianId': techId}), 'Request accepted');
  }

  Future<void> _decline() async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Decline request')),
        content: TextField(controller: note, decoration: InputDecoration(hintText: tr('Reason (optional)'), border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Back'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Decline'))),
        ],
      ),
    );
    if (ok != true) return;
    await _do(() => AgriApi.patch('$_p/respond', {'action': 'decline', 'note': note.text.trim()}), 'Request declined');
  }

  Future<void> _track() async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Update location / status')),
        content: TextField(controller: note, decoration: InputDecoration(hintText: tr('e.g. Reached Chak 45, starting work'), border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Send'))),
        ],
      ),
    );
    if (ok != true || note.text.trim().isEmpty) return;
    // also share the phone's GPS position so the customer sees the machine on the map
    final gps = await MyLocation.get(quiet: true);
    await _do(
      () => AgriApi.patch('$_p/location', {
        'note': note.text.trim(),
        if (gps != null) ...{'lat': gps.latitude, 'lng': gps.longitude},
      }),
      'Customer notified',
    );
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
    return Scaffold(
      backgroundColor: C.bg,
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final b = data as Map;
          final s = '${b['status']}';
          final buy = '${b['type']}' == 'buy';
          final ps = '${b['paymentStatus'] ?? 'unpaid'}';
          final paid = ps == 'paid';
          final reviewing = ps == 'under_review';
          final t = b['tracking'] as Map?;
          final owner = widget.ownerView;
          final actions = <Widget>[];
          if (owner) {
            if (s == 'requested') {
              actions.add(_btn('Accept request', Icons.check, () => _accept(b)));
              actions.add(_btn('Decline', Icons.close, _decline, outline: true, color: Colors.red));
            }
            if (s == 'accepted' && !buy) actions.add(_btn('Start work / on the way', Icons.play_arrow, () => _do(() => AgriApi.patch('$_p/progress', {'status': 'in_progress'}), 'Work started')));
            if (['accepted', 'in_progress'].contains(s)) {
              if (!paid && !reviewing) actions.add(_btn('Mark cash received', Icons.payments_outlined, () => _do(() => AgriApi.patch('$_p/mark-paid'), 'Payment confirmed'), outline: true));
              if (s == 'in_progress') actions.add(_btn('Update location / status', Icons.my_location, _track, outline: true));
              actions.add(_btn(buy ? 'Hand over machine' : 'Mark job completed', Icons.task_alt, () => _do(() => AgriApi.patch('$_p/progress', {'status': 'completed'}), 'Completed')));
            }
            if (s == 'completed' && !paid && !reviewing) actions.add(_btn('Mark cash received', Icons.payments_outlined, () => _do(() => AgriApi.patch('$_p/mark-paid'), 'Payment confirmed')));
          } else {
            if (['accepted', 'in_progress', 'completed'].contains(s) && !paid && !reviewing) actions.add(_btn(ps == 'rejected' ? 'Pay again / new screenshot' : 'Pay ${rs(toNum(b['total']))}', Icons.payments_outlined, () => _pay(b)));
            if (b['canCancel'] == true && !paid && !reviewing) {
              actions.add(_btn('Cancel request', Icons.close, () async {
                if (await confirmDialog(context, 'Cancel this request?', 'The owner will be told.')) {
                  await _do(() => AgriApi.patch('$_p/cancel'), 'Cancelled');
                }
              }, outline: true, color: Colors.red));
            }
            if (s == 'completed' && b['rating'] == null) actions.add(_btn('Rate this job', Icons.star_outline, _rate, outline: true));
          }
          return Column(
            children: [
              GreenHeader(
                eyebrow: 'Booking #${b['number']}',
                title: '${b['machineName']}',
                subtitle: buy ? 'Purchase' : 'Rental',
                trailing: Pill(flowLabel(s), color: Colors.white),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: C.green,
                  onRefresh: () async => _reload(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AppCard(
                        child: Column(
                          children: [
                            InfoRow(owner ? 'Customer' : 'Owner', owner ? '${b['farmerName']}' : '${b['ownerName'] ?? ''}'),
                            if (owner && '${b['farmerPhone'] ?? ''}'.isNotEmpty) InfoRow('Phone', '${b['farmerPhone']}'),
                            if (!buy) InfoRow('Start', fmtIso(b['startAt'])),
                            if (!buy) InfoRow('End', fmtIso(b['endAt'])),
                            if (!buy) InfoRow('Duration', '${toNum(b['quantity']).round()} ${'${b['rateUnit']}' == 'day' ? 'day(s)' : 'hour(s)'}'),
                            if ('${b['fieldLocation'] ?? ''}'.isNotEmpty) InfoRow('Field location', '${b['fieldLocation']}'),
                            if ('${b['notes'] ?? ''}'.isNotEmpty) InfoRow('Notes', '${b['notes']}'),
                            if ('${b['ownerNote'] ?? ''}'.isNotEmpty) InfoRow('Owner note', '${b['ownerNote']}'),
                          ],
                        ),
                      ),
                      const SectionTitle('Cost'),
                      AppCard(
                        child: Column(
                          children: [
                            InfoRow(buy ? 'Machine price' : 'Machine rent', rs(toNum(b['rentCost']))),
                            if (b['withTechnician'] == true) InfoRow('Technician (${toNum(b['techHours']).round()} hr)', rs(toNum(b['techCost']))),
                            if (b['withTechnician'] == true && '${b['technicianName'] ?? ''}'.isNotEmpty) InfoRow('Technician', '${b['technicianName']}'),
                            const Divider(),
                            InfoRow('Total', rs(toNum(b['total'])), bold: true),
                            InfoRow('Payment', paid ? 'Paid by ${b['payMethod'] ?? 'cash'}' : (ps == 'unpaid' && '${b['payMethod'] ?? ''}' == 'Cash' ? 'Cash (not yet received)' : payStatusLabel(ps))),
                          ],
                        ),
                      ),
                      if ('${b['paymentProof'] ?? ''}'.isNotEmpty) ...[
                        const SectionTitle('Payment proof'),
                        ProofReview(
                          proof: '${b['paymentProof']}',
                          ref: '${b['paymentRef'] ?? ''}',
                          method: '${b['payMethod'] ?? 'Easypaisa'}',
                          amount: toNum(b['total']),
                          status: ps,
                          note: '${b['paymentNote'] ?? ''}',
                          onApprove: owner && reviewing && !_busy ? () => _verify(true) : null,
                          onReject: owner && reviewing && !_busy ? () => _verify(false) : null,
                        ),
                      ],
                      if (b['fieldLat'] is num && b['fieldLng'] is num) ...[
                        const SectionTitle('Field on map'),
                        MapPreview(lat: toNum(b['fieldLat']).toDouble(), lng: toNum(b['fieldLng']).toDouble(), label: '${b['fieldLocation'] ?? ''}'),
                      ],
                      if (t != null && t['lat'] is num && t['lng'] is num) ...[
                        const SectionTitle('Machine on map'),
                        MapPreview(lat: toNum(t['lat']).toDouble(), lng: toNum(t['lng']).toDouble(), label: '${t['note'] ?? ''}'),
                      ],
                      if (t != null && ('${t['note'] ?? ''}'.isNotEmpty)) ...[
                        const SectionTitle('Machine tracking'),
                        AppCard(
                          child: Row(
                            children: [
                              const Icon(Icons.my_location, color: C.green),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tr('${t['note']}'), style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text('Updated ${fmtIso(t['updatedAt'])}', style: const TextStyle(fontSize: 11, color: C.grey)),
                                  ],
                                ),
                              ),
                            ],
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
