import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_05_orders/screens/order_tracking_screen.dart';

/// Buyer sends money to the Easypaisa account, then attaches the screenshot + transaction ID.
class PaymentProofScreen extends StatefulWidget {
  final String orderId;
  final num amount;
  final String method; // Easypaisa | Card
  final Map account;
  /// true when opened from the order page: just go back there instead of replacing.
  final bool returnToOrder;
  /// For machinery / storage bookings: API path to post the proof to, plus extra body fields.
  final String? submitPath;
  final Map<String, dynamic> extra;
  const PaymentProofScreen({
    super.key,
    required this.orderId,
    required this.amount,
    required this.method,
    this.account = const {},
    this.returnToOrder = false,
    this.submitPath,
    this.extra = const {},
  });
  @override
  State<PaymentProofScreen> createState() => _PaymentProofScreenState();
}

class _PaymentProofScreenState extends State<PaymentProofScreen> {
  final _ref = TextEditingController();
  Uint8List? _bytes;
  String _mime = 'image/jpeg';
  bool _sending = false;
  late Map _acc = widget.account;

  String get _number => '${_acc['number'] ?? '03195082175'}';
  String get _name => '${_acc['name'] ?? 'Farhanulhaq'}';
  bool get _card => widget.method == 'Card';

  @override
  void initState() {
    super.initState();
    if (_acc.isEmpty) {
      AgriApi.get('/payment-info').then((d) {
        if (mounted && d is Map && d['account'] is Map) setState(() => _acc = d['account'] as Map);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 80);
      if (x == null) return;
      final b = await x.readAsBytes();
      final n = x.name.toLowerCase();
      setState(() {
        _bytes = b;
        _mime = n.endsWith('.png') ? 'image/png' : (n.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
      });
    } catch (e) {
      if (mounted) snack(context, 'Could not open the image: ${cleanErr(e)}', error: true);
    }
  }

  Future<void> _submit() async {
    if (_bytes == null) {
      snack(context, 'Attach the payment screenshot', error: true);
      return;
    }
    if (_ref.text.trim().length < 6) {
      snack(context, 'Enter the transaction ID from your receipt', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await AgriApi.post(widget.submitPath ?? '/orders/${widget.orderId}/payment-proof', {
        ...widget.extra,
        'method': widget.method,
        'image': 'data:$_mime;base64,${base64Encode(_bytes!)}',
        'ref': _ref.text.trim(),
      });
      if (!mounted) return;
      snack(context, 'Payment proof sent. It will be verified shortly.');
      if (widget.returnToOrder || widget.submitPath != null) {
        Navigator.pop(context, true);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: widget.orderId)),
      );
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  void _copy(String v, String what) {
    Clipboard.setData(ClipboardData(text: v));
    snack(context, '$what copied');
  }

  Widget _step(int n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: C.green,
            child: Text('$n', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(tr(text), style: const TextStyle(fontSize: 13))),
        ]),
      );

  Widget _copyRow(String label, String value) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(label), style: const TextStyle(fontSize: 11, color: Colors.white70)),
            Text(value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
          ]),
        ),
        IconButton(
          tooltip: tr('Copy'),
          onPressed: () => _copy(value, label),
          icon: const Icon(Icons.copy, color: Colors.white),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.returnToOrder || widget.submitPath != null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // leaving without paying keeps the order "awaiting payment"; the buyer can upload later
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: widget.orderId)),
        );
      },
      child: Scaffold(
        backgroundColor: C.bg,
        body: Column(children: [
          GreenHeader(
            title: tr(_card ? 'Pay by card' : 'Pay with Easypaisa'),
            subtitle: '${tr('Amount to pay')}: ${rs(widget.amount)}',
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1BA94C), Color(0xFF0F5F2C)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(tr('Easypaisa account'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 12),
                  _copyRow('Account number', _number),
                  const SizedBox(height: 6),
                  _copyRow('Account title', _name),
                  const Divider(color: Colors.white24),
                  _copyRow('Amount (PKR)', widget.amount.round().toString()),
                ]),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('How to pay'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (_card) ...[
                    _step(1, 'Open the Easypaisa app (or your bank app) and choose Send Money → Easypaisa account.'),
                    _step(2, 'Select "Pay with Debit/Credit card" and enter your card details there.'),
                  ] else ...[
                    _step(1, 'Open the Easypaisa app or dial *786#.'),
                    _step(2, 'Choose Send Money → Easypaisa account.'),
                  ],
                  _step(3, 'Send the exact amount to $_number ($_name).'),
                  _step(4, 'Take a screenshot of the receipt and attach it below with the transaction ID.'),
                ]),
              ),
              Text(tr('Payment screenshot'),
                  style: const TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _pick(ImageSource.gallery),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: _bytes == null ? 140 : 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _bytes == null ? C.line : C.green, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _bytes == null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.add_photo_alternate_outlined, size: 40, color: C.green),
                          const SizedBox(height: 6),
                          Text(tr('Tap to attach screenshot'), style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(tr('PNG or JPG, up to 5 MB'), style: const TextStyle(fontSize: 11, color: C.grey)),
                        ])
                      : Image.memory(_bytes!, fit: BoxFit.contain),
                ),
              ),
              Row(children: [
                TextButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(tr(_bytes == null ? 'Gallery' : 'Change')),
                ),
                TextButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(tr('Camera')),
                ),
              ]),
              field('Transaction ID (TID)', _ref, icon: Icons.tag, hint: 'e.g. 24851937562'),
              PrimaryButton(
                label: tr('Submit payment proof'),
                icon: Icons.upload_file,
                loading: _sending,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: Text(tr('I will pay later')),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
