import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_05_orders/screens/order_tracking_screen.dart';
import 'package:agrisphere/modules/module_05_orders/screens/payment_proof_screen.dart';

const pkCities = [
  'Islamabad', 'Rawalpindi', 'Lahore', 'Karachi', 'Peshawar', 'Quetta',
  'Faisalabad', 'Multan', 'Gujranwala', 'Sialkot', 'Hyderabad', 'Sargodha',
  'Bahawalpur', 'Sahiwal', 'Sheikhupura', 'Abbottabad', 'Mardan', 'Haripur',
  'Swat', 'Sukkur', 'Larkana', 'Dera Ismail Khan', 'Muzaffarabad',
];

/// Step 2 of buying: delivery details, delivery speed, payment method, summary.
class CheckoutScreen extends StatefulWidget {
  final Map cart;
  const CheckoutScreen({super.key, required this.cart});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _fc = FormCheck();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _addr = TextEditingController();
  final _note = TextEditingController();
  String? _city;
  String _delivery = 'standard';
  String _pay = 'Cash';
  bool _placing = false;
  Map _fees = {
    'standard': {'fee': 500, 'eta': '2 - 3 days'},
    'express': {'fee': 900, 'eta': 'Tomorrow 4:00 - 6:00 PM'},
  };

  @override
  void initState() {
    super.initState();
    AgriApi.get('/payment-info').then((d) {
      if (mounted && d is Map && d['delivery'] is Map) {
        setState(() => _fees = d['delivery'] as Map);
      }
    }).catchError((_) {});
    AgriApi.get('/me').then((d) {
      if (!mounted || d is! Map) return;
      final p = (d['profile'] as Map?) ?? const {};
      if (_name.text.isEmpty) _name.text = '${d['name'] ?? ''}';
      if (_phone.text.isEmpty) _phone.text = '${d['phone'] ?? p['phone'] ?? ''}';
      if (_addr.text.isEmpty) _addr.text = '${p['address'] ?? ''}';
      final city = '${p['city'] ?? ''}';
      if (_city == null && pkCities.contains(city)) setState(() => _city = city);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _addr, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _sellers => toNum(widget.cart['farmers']).round().clamp(1, 99);
  num get _subtotal => toNum(widget.cart['subtotal']);
  num get _deliveryFee => toNum((_fees[_delivery] as Map)['fee']) * _sellers;
  num get _total => _subtotal + _deliveryFee;

  String? _validate() {
    if (_name.text.trim().length < 3) return 'Enter the receiver name';
    final p = _phone.text.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^(\+92|0)3\d{9}$').hasMatch(p)) {
      return 'Enter a valid mobile number, e.g. 03001234567';
    }
    if (_city == null) return 'Select your city';
    if (_addr.text.trim().length < 10) return 'Enter the full delivery address';
    return null;
  }

  Future<void> _place() async {
    final formErr = _fc.validate();
    if (formErr != null) {
      snack(context, formErr, error: true);
      return;
    }
    final err = _validate();
    if (err != null) {
      snack(context, err, error: true);
      return;
    }
    setState(() => _placing = true);
    try {
      final o = await AgriApi.post('/orders', {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'city': _city,
        'address': _addr.text.trim(),
        'note': _note.text.trim(),
        'deliveryType': _delivery,
        'payment': _pay,
      }) as Map;
      if (!mounted) return;
      final id = '${o['id']}';
      if (_pay == 'Cash') {
        snack(context, 'Order #${o['number']} placed');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: id)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentProofScreen(
              orderId: id,
              amount: toNum(o['grandTotal'] ?? o['total']),
              method: _pay,
              account: (o['account'] as Map?) ?? const {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _placing = false);
  }

  Widget _title(String t, IconData i) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(children: [
          Icon(i, size: 18, color: C.green),
          const SizedBox(width: 6),
          Text(tr(t), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      );

  Widget _option({
    required bool selected,
    required IconData icon,
    required String title,
    required String sub,
    String? trailing,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? C.light : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? C.green : C.line, width: selected ? 2 : 1),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (selected ? C.green : C.grey).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: selected ? C.green : C.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(title), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(tr(sub), style: const TextStyle(fontSize: 11, color: C.grey)),
              ]),
            ),
            if (trailing != null)
              Text(trailing, style: const TextStyle(fontWeight: FontWeight.w700, color: C.green)),
            const SizedBox(width: 6),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? C.green : C.grey),
          ]),
        ),
      );

  Widget _row(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
            child: Text(tr(l),
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    color: bold ? C.text : C.grey)),
          ),
          Text(v,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: bold ? C.green : C.text)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final items = (widget.cart['items'] as List?) ?? [];
    final std = _fees['standard'] as Map;
    final exp = _fees['express'] as Map;
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(children: [
        GreenHeader(
          title: tr('Checkout'),
          subtitle: '${items.length} items from $_sellers sellers',
          trailing: CircleBtn(icon: Icons.close, onTap: () => Navigator.pop(context)),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _title('Delivery details', Icons.location_on_outlined),
            AppCard(
              child: Column(children: [
                LiveField('Receiver name', _name, form: _fc, check: V.minLen(3, 'Receiver name'), icon: Icons.person_outline),
                LiveField('Mobile number', _phone, form: _fc, check: V.phone(),
                    icon: Icons.phone_outlined, type: TextInputType.phone, hint: '03001234567'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _city,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('City'),
                      prefixIcon: const Icon(Icons.location_city_outlined, size: 18, color: C.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: pkCities
                        .map((c) => DropdownMenuItem(value: c, child: Text(tr(c))))
                        .toList(),
                    onChanged: (v) => setState(() => _city = v),
                  ),
                ),
                LiveField('Full address', _addr, form: _fc, check: V.minLen(10, 'Full address'),
                    icon: Icons.home_outlined, lines: 2, hint: 'House, street, area / village'),
                field('Note for seller (optional)', _note, icon: Icons.sticky_note_2_outlined),
              ]),
            ),
            _title('Delivery option', Icons.local_shipping_outlined),
            _option(
              selected: _delivery == 'standard',
              icon: Icons.local_shipping_outlined,
              title: 'Standard delivery',
              sub: '${std['eta']} · ${rs(toNum(std['fee']))} per seller',
              trailing: rs(toNum(std['fee']) * _sellers),
              onTap: () => setState(() => _delivery = 'standard'),
            ),
            _option(
              selected: _delivery == 'express',
              icon: Icons.bolt,
              title: 'Express delivery',
              sub: '${exp['eta']} · ${rs(toNum(exp['fee']))} per seller',
              trailing: rs(toNum(exp['fee']) * _sellers),
              onTap: () => setState(() => _delivery = 'express'),
            ),
            _title('Payment method', Icons.account_balance_wallet_outlined),
            _option(
              selected: _pay == 'Cash',
              icon: Icons.payments_outlined,
              title: 'Cash on Delivery',
              sub: 'Pay the rider in cash when your order arrives',
              onTap: () => setState(() => _pay = 'Cash'),
            ),
            _option(
              selected: _pay == 'Easypaisa',
              icon: Icons.phone_android,
              title: 'Easypaisa',
              sub: 'Send money to our Easypaisa account, then upload the screenshot',
              onTap: () => setState(() => _pay = 'Easypaisa'),
            ),
            _option(
              selected: _pay == 'Card',
              icon: Icons.credit_card,
              title: 'Debit / Credit card',
              sub: 'Pay by card to our Easypaisa account, then upload the receipt',
              onTap: () => setState(() => _pay = 'Card'),
            ),
            _title('Order summary', Icons.receipt_long_outlined),
            AppCard(
              child: Column(children: [
                ...items.map((it) => _row(
                      '${tr('${it['title']}')} · ${toNum(it['qtyKg']).round()} kg',
                      rs(toNum(it['amount'])),
                    )),
                const Divider(),
                _row('Subtotal', rs(_subtotal)),
                _row('Delivery', rs(_deliveryFee)),
                const Divider(),
                _row('Total', rs(_total), bold: true),
              ]),
            ),
            const SizedBox(height: 4),
            PrimaryButton(
              label: _pay == 'Cash'
                  ? '${tr('Place order')} - ${rs(_total)}'
                  : '${tr('Continue to payment')} - ${rs(_total)}',
              icon: _pay == 'Cash' ? Icons.check_circle_outline : Icons.lock_outline,
              loading: _placing,
              onPressed: _place,
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }
}
