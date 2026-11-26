import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/contact.dart';

/// Buyer and seller, each with their phone (Call / WhatsApp).
class OrderPeopleCard extends StatelessWidget {
  final Map order;
  const OrderPeopleCard({super.key, required this.order});
  @override
  Widget build(BuildContext context) {
    final o = order;
    final n = '#${o['number']}';
    return AppCard(
      child: Column(children: [
        ContactRow(
          label: 'Seller',
          name: '${o['sellerName'] ?? ''}',
          phone: '${o['sellerPhone'] ?? ''}',
          whatsappText: 'Assalam o Alaikum, about my AgriSphere order $n',
        ),
        const Divider(height: 10),
        ContactRow(
          label: 'Buyer',
          name: '${o['receiverName'] ?? o['buyerName'] ?? ''}',
          phone: '${o['phone'] ?? ''}',
          whatsappText: 'Assalam o Alaikum, about your AgriSphere order $n',
        ),
      ]),
    );
  }
}

/// The right buttons for whoever opened the order:
///  - seller: move the order to the next step (Confirm -> Picked up -> Out for delivery -> Delivered) or cancel
///  - buyer: cancel while the order is still pending
class OrderActions extends StatefulWidget {
  final Map order;
  final VoidCallback onChanged;
  const OrderActions({super.key, required this.order, required this.onChanged});
  @override
  State<OrderActions> createState() => _OrderActionsState();
}

class _OrderActionsState extends State<OrderActions> {
  bool _busy = false;

  static const _icons = {
    'confirmed': Icons.check_circle_outline,
    'picked_up': Icons.inventory_2_outlined,
    'out_for_delivery': Icons.local_shipping_outlined,
    'delivered': Icons.home_outlined,
  };
  static const _buttonText = {
    'confirmed': 'Confirm order',
    'picked_up': 'Mark as picked up',
    'out_for_delivery': 'Mark out for delivery',
    'delivered': 'Mark as delivered',
  };

  Future<void> _run(Future<dynamic> Function() call, String ok) async {
    setState(() => _busy = true);
    final done = await runAction(context, call, ok: ok);
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final id = '${o['id']}';
    final next = o['nextStep'] as Map?;
    final widgets = <Widget>[];

    if (next != null) {
      final st = '${next['status']}';
      if (next['blocked'] == true) {
        widgets.add(Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.hourglass_top, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('Verify the buyer\'s payment above before confirming this order.'))),
          ]),
        ));
      } else {
        widgets.add(PrimaryButton(
          label: tr(_buttonText[st] ?? 'Next step'),
          icon: _icons[st] ?? Icons.arrow_forward,
          loading: _busy,
          onPressed: () async {
            if (st == 'delivered' &&
                !await confirmDialog(context, 'Mark as delivered?', 'Only do this when the buyer has received the goods.')) {
              return;
            }
            await _run(() => AgriApi.patch('/orders/$id/status', {'status': st}), '${tr(next['label'] ?? 'Updated')} ✓');
          },
        ));
      }
    }
    if (o['canCancelAsSeller'] == true) {
      widgets.add(OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () async {
                if (await confirmDialog(context, 'Cancel this order?', 'The buyer will be told and the stock goes back to your listing.')) {
                  await _run(() => AgriApi.patch('/orders/$id/status', {'status': 'cancelled'}), 'Order cancelled');
                }
              },
        icon: const Icon(Icons.close, color: Colors.red),
        label: Text(tr('Cancel order'), style: const TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: const BorderSide(color: Colors.red)),
      ));
    }
    if (o['canCancelAsBuyer'] == true) {
      widgets.add(OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () async {
                if (await confirmDialog(context, 'Cancel this order?', 'You can cancel until the seller confirms it.')) {
                  await _run(() => AgriApi.post('/orders/$id/cancel'), 'Order cancelled');
                }
              },
        icon: const Icon(Icons.close, color: Colors.red),
        label: Text(tr('Cancel order'), style: const TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: const BorderSide(color: Colors.red)),
      ));
    }
    if (o['isBuyer'] == true && o['isSeller'] != true && next == null && '${o['status']}' != 'delivered' && '${o['status']}' != 'cancelled') {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(tr('The seller updates the order as it moves. You will get a notification at every step.'),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: C.grey)),
      ));
    }
    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final w in widgets) Padding(padding: const EdgeInsets.only(bottom: 8), child: w)],
    );
  }
}
