import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// "Make an offer": propose your own price and quantity on a produce listing.
/// Returns true when the offer was sent.
Future<bool> showOfferSheet(BuildContext context, Map listing, {int qty = 100}) async {
  final price = TextEditingController(text: '${toNum(listing['pricePerKg']).round()}');
  final qtyCtrl = TextEditingController(text: '$qty');
  final address = TextEditingController();
  final msg = TextEditingController();
  var sending = false;
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setM) {
        final p = num.tryParse(price.text.trim()) ?? 0;
        final q = num.tryParse(qtyCtrl.text.trim()) ?? 0;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Offer for ${listing['title']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Asking ${rs(toNum(listing['pricePerKg']))}/kg  -  ${numStr(toNum(listing['quantityKg']))} kg available', style: const TextStyle(color: C.grey, fontSize: 12)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: field('Your price (Rs/kg)', price, type: TextInputType.number, onChanged: (_) => setM(() {}))),
                    const SizedBox(width: 10),
                    Expanded(child: field('Quantity (kg)', qtyCtrl, type: TextInputType.number, onChanged: (_) => setM(() {}))),
                  ],
                ),
                field('Delivery / pickup address', address, icon: Icons.location_on_outlined),
                field('Message to the seller (optional)', msg, lines: 2),
                AppCard(child: InfoRow('Offer total', rs(p * q), bold: true)),
                PrimaryButton(
                  label: tr('Send offer'),
                  icon: Icons.local_offer_outlined,
                  loading: sending,
                  onPressed: () async {
                    setM(() => sending = true);
                    final ok = await runAction(
                      ctx,
                      () => AgriApi.post('/listings/${listing['id']}/offers', {'pricePerKg': p, 'qtyKg': q, 'address': address.text.trim(), 'message': msg.text.trim()}),
                      ok: 'Offer sent to ${listing['sellerName'] ?? 'the seller'}',
                    );
                    if (ctx.mounted) {
                      setM(() => sending = false);
                      if (ok) Navigator.pop(ctx, true);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  return sent == true;
}
