import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_05_orders/screens/payment_proof_screen.dart';
import 'package:agrisphere/modules/module_05_orders/widgets/payment_helpers.dart' show ReceiptImage;

const _status = {
  'cod_pending': ('Cash on delivery', Color(0xFF6B7280), Icons.payments_outlined),
  'awaiting_proof': ('Awaiting payment', Color(0xFFD97706), Icons.hourglass_top),
  'under_review': ('Under review', Color(0xFF2563EB), Icons.manage_search),
  'paid': ('Paid', Color(0xFF16803C), Icons.verified),
  'rejected': ('Payment rejected', Color(0xFFDC2626), Icons.error_outline),
};

/// Payment block on the order page: status, screenshot, and the right action for buyer / seller.
class PaymentCard extends StatefulWidget {
  final Map order;
  final VoidCallback onChanged;
  const PaymentCard({super.key, required this.order, required this.onChanged});
  @override
  State<PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<PaymentCard> {
  bool _busy = false;

  Map get o => widget.order;
  String get _st => '${o['paymentStatus'] ?? (o['payment'] == 'Cash' ? 'cod_pending' : 'awaiting_proof')}';

  Future<void> _verify(bool approve) async {
    String? reason;
    if (!approve) {
      final c = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(tr('Reject payment')),
          content: TextField(
            controller: c,
            decoration: InputDecoration(hintText: tr('Reason, e.g. amount does not match')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text(tr('Cancel'))),
            TextButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(tr('Reject'))),
          ],
        ),
      );
      if (reason == null) return;
    }
    setState(() => _busy = true);
    try {
      await AgriApi.patch('/orders/${o['id']}/payment', {
        'action': approve ? 'approve' : 'reject',
        'reason': reason ?? '',
      });
      if (mounted) snack(context, approve ? 'Payment approved' : 'Payment rejected');
      widget.onChanged();
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _status[_st] ?? _status['awaiting_proof']!;
    final method = '${o['payment']}' == 'Cash' ? 'Cash on Delivery' : '${o['payment']}' == 'Card' ? 'Card (via Easypaisa)' : 'Easypaisa';
    final proof = '${o['paymentProof'] ?? ''}';
    final isBuyer = o['isBuyer'] == true;
    final canVerify = o['canVerify'] == true;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 18, color: C.green),
          const SizedBox(width: 6),
          Expanded(child: Text(tr('Payment'), style: const TextStyle(fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: s.$2.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(s.$3, size: 14, color: s.$2),
              const SizedBox(width: 4),
              Text(tr(s.$1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: s.$2)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Text('${tr('Method')}: ${tr(method)}', style: const TextStyle(fontSize: 12, color: C.grey)),
        if ('${o['paymentRef'] ?? ''}'.isNotEmpty)
          Text('${tr('Transaction ID')}: ${o['paymentRef']}', style: const TextStyle(fontSize: 12, color: C.grey)),
        if (_st == 'rejected' && '${o['paymentNote'] ?? ''}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${tr('Reason')}: ${o['paymentNote']}', style: const TextStyle(fontSize: 12, color: Colors.red)),
          ),
        if (proof.isNotEmpty) ...[
          const SizedBox(height: 10),
          ReceiptImage(proof, height: 160),
          Text(tr('Tap to view full screenshot'), style: const TextStyle(fontSize: 10, color: C.grey)),
        ],
        if (isBuyer && (_st == 'awaiting_proof' || _st == 'rejected')) ...[
          const SizedBox(height: 10),
          PrimaryButton(
            label: tr(_st == 'rejected' ? 'Upload new screenshot' : 'Pay now & upload screenshot'),
            icon: Icons.upload_file,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentProofScreen(
                    orderId: '${o['id']}',
                    amount: toNum(o['total']),
                    method: '${o['payment']}',
                    returnToOrder: true,
                  ),
                ),
              );
              widget.onChanged();
            },
          ),
        ],
        if (canVerify && _st == 'under_review') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _verify(false),
                icon: const Icon(Icons.close, color: Colors.red),
                label: Text(tr('Reject'), style: const TextStyle(color: Colors.red)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _verify(true),
                icon: const Icon(Icons.check),
                label: Text(tr('Approve')),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
