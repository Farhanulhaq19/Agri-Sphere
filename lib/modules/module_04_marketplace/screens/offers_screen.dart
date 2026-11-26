import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// Negotiate a price: offers you sent and offers you received.
class OffersScreen extends StatefulWidget {
  final bool startReceived;
  const OffersScreen({super.key, this.startReceived = false});
  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  late String _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.startReceived ? 'Received' : 'Sent';
  }

  Future<void> _answer(Map o, String action, Future<void> Function() reload) async {
    Map<String, dynamic> body = {'action': action};
    if (action == 'counter') {
      final price = TextEditingController(text: '${toNum(o['pricePerKg']).round()}');
      final note = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(tr('Counter offer')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: price, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Your price (Rs/kg)'), border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: note, decoration: InputDecoration(labelText: tr('Message (optional)'), border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
            TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Send'))),
          ],
        ),
      );
      if (ok != true) return;
      body = {'action': 'counter', 'pricePerKg': price.text.trim(), 'note': note.text.trim()};
    } else if (action == 'accept') {
      if (!await confirmDialog(context, 'Accept this offer?', '${numStr(toNum(o['qtyKg']))} kg at ${rs(toNum(o['pricePerKg']))}/kg = ${rs(toNum(o['total']))}. An order will be created.', yes: 'Accept')) return;
    }
    if (!mounted) return;
    final done = await runAction(context, () => AgriApi.patch('/offers/${o['id']}/respond', body), ok: action == 'accept' ? 'Deal done - order created' : 'Sent');
    if (done) await reload();
  }

  Widget _tile(Map o, Future<void> Function() reload) {
    final s = '${o['status']}';
    final received = _tab == 'Received';
    final rounds = (o['rounds'] as List?) ?? [];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_outlined, color: C.green),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('${o['listingTitle']}'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              Pill(flowLabel(s), color: flowColor(s)),
            ],
          ),
          const SizedBox(height: 6),
          Text(received ? 'From ${o['buyerName']}' : 'To ${o['sellerName']}', style: const TextStyle(fontSize: 12, color: C.grey)),
          Text('${numStr(toNum(o['qtyKg']))} kg at ${rs(toNum(o['pricePerKg']))}/kg  (asking ${rs(toNum(o['listPrice']))})', style: const TextStyle(fontSize: 12.5)),
          Text('Total ${rs(toNum(o['total']))}', style: const TextStyle(fontWeight: FontWeight.w800, color: C.green)),
          if (rounds.length > 1) ...[
            const SizedBox(height: 4),
            Text(rounds.map((r) => '${(r as Map)['by'] == 'seller' ? 'Seller' : 'Buyer'}: ${rs(toNum(r['pricePerKg']))}').join('  >  '), style: const TextStyle(fontSize: 11, color: C.grey)),
          ],
          if (o['canAnswer'] == true) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => _answer(o, 'reject', reload), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)), child: Text(tr('Decline'), style: TextStyle(color: Colors.red)))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _answer(o, 'counter', reload), child: Text(tr('Counter')))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: () => _answer(o, 'accept', reload), style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white), child: Text(tr('Accept')))),
              ],
            ),
          ] else if (!received && ['pending', 'countered'].contains(s)) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  final ok = await runAction(context, () => AgriApi.patch('/offers/${o['id']}/cancel'), ok: 'Offer withdrawn');
                  if (ok) await reload();
                },
                child: Text(tr('Withdraw offer')),
              ),
            ),
          ] else if (['pending', 'countered'].contains(s))
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('Waiting for the ${o['waitingFor']} to answer', style: const TextStyle(fontSize: 11.5, color: C.grey))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = _tab == 'Received' ? 'received' : 'sent';
    return ListPage(
      key: ValueKey(_tab),
      title: tr('Offers & negotiation'),
      subtitle: tr('Agree a price, then the order is created'),
      headerBottom: Wrap(
        spacing: 8,
        children: ['Sent', 'Received'].map((k) => ChoiceChip(
          label: Text(tr(k)),
          selected: k == _tab,
          showCheckmark: false,
          selectedColor: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          labelStyle: TextStyle(color: k == _tab ? C.dark : Colors.white, fontWeight: FontWeight.w600),
          onSelected: (_) => setState(() => _tab = k),
        )).toList(),
      ),
      load: () => AgriApi.get('/offers?box=$box'),
      empty: box == 'sent' ? 'You have not made any offers.\nOpen a product and tap "Offer".' : 'No offers on your produce yet',
      emptyIcon: Icons.local_offer_outlined,
      item: (ctx, o, reload) => _tile(o, reload),
    );
  }
}
