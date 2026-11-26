import 'package:flutter/material.dart';
import 'package:agrisphere/modules/module_05_orders/widgets/order_actions.dart';
import 'package:agrisphere/modules/module_05_orders/widgets/invoice.dart';
import 'package:agrisphere/modules/module_05_orders/widgets/review_card.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_05_orders/widgets/payment_card.dart';

// ---------------- Orders list (Orders tab) ----------------
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/orders');
  }

  void _reload() => setState(() => _f = AgriApi.get('/orders'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final items = (((data as Map)['items']) as List?) ?? [];
          return RefreshIndicator(
            color: C.green,
            onRefresh: () async {
              _reload();
              await _f;
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                GreenHeader(
                  title: tr('My orders'),
                  subtitle: tr('Track your purchases'),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (items.isEmpty)
                        AppCard(
                          child: Text(
                            tr('No orders yet. Buy something from the marketplace.'),
                            style: TextStyle(color: C.grey),
                          ),
                        ),
                      ...items.map((o) {
                        final s = '${o['status']}';
                        return AppCard(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderTrackingScreen(orderId: '${o['id']}'),
                              ),
                            );
                            if (mounted) _reload();
                          },
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: C.light,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.local_shipping,
                                  color: C.green,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order #${o['number']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      tr('${o['summary']}'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: C.grey,
                                      ),
                                    ),
                                    Text(
                                      fmtIso(o['createdAt']),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: C.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Pill(statusLabel(s), color: statusColor(s)),
                                  const SizedBox(height: 4),
                                  Text(
                                    rs(toNum(o['total'])),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------- Single order tracking ----------------
class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});
  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/orders/${widget.orderId}');
  }

  void _reload() =>
      setState(() => _f = AgriApi.get('/orders/${widget.orderId}'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final o = data as Map;
          final s = '${o['status']}';
          final steps = (o['steps'] as List?) ?? [];
          final courier = (o['courier'] as Map?) ?? {};
          final delivered = s == 'delivered';
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              GreenHeader(
                title: 'Order #${o['number']}',
                subtitle: '${o['summary']}',
                bottom: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              delivered ? 'Delivered' : 'Arriving ${o['eta']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              tr('${o['address']}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Pill(statusLabel(s), color: Colors.white),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 150,
                        width: double.infinity,
                        child: CustomPaint(painter: _MapPainter()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: C.light,
                            child: Text(
                              '${courier['name'] ?? 'D'}'[0],
                              style: const TextStyle(
                                color: C.green,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${courier['name'] ?? 'Driver'} - Delivery partner',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  tr('${courier['vehicle'] ?? ''}'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: C.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.call, color: C.green),
                            onPressed: () =>
                                snack(context, 'Calling driver...'),
                          ),
                        ],
                      ),
                    ),
                    const SectionTitle('Delivery progress'),
                    AppCard(
                      child: Column(
                        children: List.generate(steps.length, (i) {
                          final st = steps[i] as Map;
                          final done = st['done'] == true;
                          final last = i == steps.length - 1;
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: done ? C.green : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: done ? C.green : C.line,
                                          width: 2,
                                        ),
                                      ),
                                      child: done
                                          ? const Icon(
                                              Icons.check,
                                              size: 12,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    if (!last)
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          color: done ? C.green : C.line,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tr('${st['label']}'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: done ? C.text : C.grey,
                                          ),
                                        ),
                                        Text(
                                          st['at'] != null
                                              ? fmtIso(st['at'])
                                              : 'Pending',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: C.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    AppCard(
                      child: Column(
                        children: [
                          ...((o['items'] as List?) ?? []).map(
                            (i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${i['title']} - ${toNum(i['qtyKg']).round()} kg',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    rs(
                                      toNum(i['qtyKg']) *
                                          toNum(i['pricePerKg']),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('Total (incl. delivery)'),
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                rs(toNum(o['total'])),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: C.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    OrderActions(order: o, onChanged: _reload),
                    const SectionTitle('Contact'),
                    OrderPeopleCard(order: o),
                    PaymentCard(order: o, onChanged: _reload),
                    ReviewCard(order: o, onChanged: _reload),
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: InvoiceButton(order: o)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEAF3EC),
    );
    final grid = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    for (double x = 20; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 20; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path()
      ..moveTo(30, size.height - 30)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.1,
        size.width * 0.6,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.8,
        size.width - 30,
        30,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = C.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(Offset(30, size.height - 30), 7, Paint()..color = C.dark);
    canvas.drawCircle(Offset(size.width - 30, 30), 7, Paint()..color = C.amber);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
