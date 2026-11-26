import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_05_orders/screens/payment_proof_screen.dart';

// Shared payment pieces for machinery and warehouse bookings.

const _methods = [
  ('Cash', Icons.payments_outlined, 'Pay the owner in cash. They will confirm it.'),
  ('Easypaisa', Icons.phone_android, 'Send to our Easypaisa account and upload the screenshot'),
  ('Card', Icons.credit_card, 'Pay by card in the Easypaisa app and upload the receipt'),
];

const _look = {
  'unpaid': ('Unpaid', Color(0xFFD97706), Icons.hourglass_top),
  'under_review': ('Payment under review', Color(0xFF2563EB), Icons.manage_search),
  'paid': ('Paid', Color(0xFF16803C), Icons.verified),
  'approved': ('Verified', Color(0xFF16803C), Icons.verified),
  'rejected': ('Payment rejected', Color(0xFFDC2626), Icons.error_outline),
};

String payStatusLabel(String s) => _look[s]?.$1 ?? s;

/// Bottom sheet: Cash / Easypaisa / Card. Returns the chosen method or null.
Future<String?> pickPayMethod(BuildContext context, num amount) => showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${tr('Pay')} ${rs(amount)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final m in _methods)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: C.light, child: Icon(m.$2, color: C.green)),
                title: Text(tr(m.$1 == 'Card' ? 'Debit / Credit card' : m.$1)),
                subtitle: Text(tr(m.$3), style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(ctx, m.$1),
              ),
          ]),
        ),
      ),
    );

/// The whole "pay" step for a booking. Returns true when something was submitted.
Future<bool> payBooking(
  BuildContext context, {
  required String payPath,
  required String id,
  required num amount,
  Map<String, dynamic> extra = const {},
}) async {
  final method = await pickPayMethod(context, amount);
  if (method == null || !context.mounted) return false;
  if (method == 'Cash') {
    try {
      await AgriApi.post(payPath, {...extra, 'method': 'Cash'});
      if (context.mounted) snack(context, 'The owner has been told you will pay in cash');
      return true;
    } catch (e) {
      if (context.mounted) snack(context, cleanErr(e), error: true);
      return false;
    }
  }
  final r = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => PaymentProofScreen(orderId: id, amount: amount, method: method, submitPath: payPath, extra: extra),
    ),
  );
  return r == true;
}

/// Asks for a rejection reason. Returns null if cancelled.
Future<String?> askRejectReason(BuildContext context) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(tr('Reject payment')),
      content: TextField(controller: c, decoration: InputDecoration(hintText: tr('Reason, e.g. amount does not match'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(tr('Cancel'))),
        TextButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(tr('Reject'))),
      ],
    ),
  );
}

/// Screenshot + transaction ID, with Approve / Reject for the owner.
class ProofReview extends StatelessWidget {
  final String proof;
  final String ref;
  final String method;
  final num amount;
  final String status;
  final String note;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const ProofReview({
    super.key,
    required this.proof,
    required this.ref,
    required this.method,
    required this.amount,
    required this.status,
    this.note = '',
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final st = _look[status] ?? _look['under_review']!;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(st.$3, size: 18, color: st.$2),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${rs(amount)} · ${tr(method == 'Card' ? 'Card (via Easypaisa)' : method)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text(tr(st.$1), style: TextStyle(fontSize: 11, color: st.$2, fontWeight: FontWeight.w700)),
        ]),
        if (ref.isNotEmpty) Text('${tr('Transaction ID')}: $ref', style: const TextStyle(fontSize: 12, color: C.grey)),
        if (note.isNotEmpty)
          Text(note, style: TextStyle(fontSize: 12, color: status == 'rejected' ? Colors.red : C.grey)),
        if (proof.isNotEmpty) ...[
          const SizedBox(height: 8),
          ReceiptImage(proof),
        ],
        if (onApprove != null && onReject != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close, color: Colors.red),
                label: Text(tr('Reject'), style: const TextStyle(color: Colors.red)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(onPressed: onApprove, icon: const Icon(Icons.check), label: Text(tr('Approve'))),
            ),
          ]),
        ],
      ]),
    );
  }
}


/// A payment receipt. Receipts are private, so they are downloaded with the login header
/// (a plain image link would not be allowed). Tap to zoom.
class ReceiptImage extends StatefulWidget {
  final String path; // "/uploads/payments/..."
  final double height;
  const ReceiptImage(this.path, {super.key, this.height = 150});
  @override
  State<ReceiptImage> createState() => _ReceiptImageState();
}

class _ReceiptImageState extends State<ReceiptImage> {
  static final Map<String, Uint8List> _mem = {};
  late Future<Uint8List> _f = _load();

  Future<Uint8List> _load() async {
    final hit = _mem[widget.path];
    if (hit != null) return hit;
    final b = Uint8List.fromList(await AgriApi.bytes('/receipt?p=${Uri.encodeQueryComponent(widget.path)}'));
    return _mem[widget.path] = b;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: _f,
        builder: (_, s) {
          if (s.connectionState != ConnectionState.done) {
            return Container(
              height: widget.height,
              decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: CircularProgressIndicator(color: C.green, strokeWidth: 2)),
            );
          }
          if (s.hasError || s.data == null) {
            return InkWell(
              onTap: () => setState(() => _f = _load()),
              child: Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(12)),
                child: Text('${cleanErr(s.error ?? 'Could not load')} · ${tr('Tap to retry')}', style: const TextStyle(fontSize: 12)),
              ),
            );
          }
          return InkWell(
            onTap: () => showDialog(
              context: context,
              builder: (d) => Dialog(child: InteractiveViewer(child: Image.memory(s.data!, fit: BoxFit.contain))),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(s.data!, height: widget.height, width: double.infinity, fit: BoxFit.cover),
            ),
          );
        },
      );
}
