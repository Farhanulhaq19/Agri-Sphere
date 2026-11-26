import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

class SupplierOrdersScreen extends StatefulWidget {
  const SupplierOrdersScreen({super.key});
  @override
  State<SupplierOrdersScreen> createState() => _SupplierOrdersScreenState();
}

class _SupplierOrdersScreenState extends State<SupplierOrdersScreen> {
  late Future<dynamic> _f;
  String _filter = 'All';

  static const Map<String, List<String>> _next = {
    'placed': ['confirmed', 'Confirm order'],
    'confirmed': ['picked_up', 'Mark picked up'],
    'picked_up': ['out_for_delivery', 'Out for delivery'],
    'out_for_delivery': ['delivered', 'Mark delivered'],
  };

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/supplier/orders');
  }

  void _reload() => setState(() => _f = AgriApi.get('/supplier/orders'));

  bool _match(String s) {
    switch (_filter) {
      case 'Pending':
        return s == 'placed';
      case 'In progress':
        return s == 'confirmed' || s == 'picked_up' || s == 'out_for_delivery';
      case 'Delivered':
        return s == 'delivered';
      default:
        return true;
    }
  }

  Future<void> _setStatus(Map o, String to) async {
    try {
      await AgriApi.patch('/orders/${o['id']}/status', {'status': to});
      if (mounted) {
        snack(context, 'Order #${o['number']} updated');
        _reload();
      }
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
  }

  Future<void> _cancel(Map o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Cancel order #${o['number']}?'),
        content: Text(
          tr('The buyer will be notified and the stock is returned.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Keep')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(
              tr('Cancel order'),
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok == true) _setStatus(o, 'cancelled');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final all = (((data as Map)['items']) as List?) ?? [];
          final items = all.where((o) => _match('${o['status']}')).toList();
          return RefreshIndicator(
            color: C.green,
            onRefresh: () async {
              _reload();
              await _f;
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                GreenHeader(title: tr('Orders'), subtitle: '${all.length} total'),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChipRow(
                        items: const [
                          'All',
                          'Pending',
                          'In progress',
                          'Delivered',
                        ],
                        selected: _filter,
                        onSelect: (v) => setState(() => _filter = v),
                      ),
                      const SizedBox(height: 14),
                      if (items.isEmpty)
                        AppCard(
                          child: Text(
                            tr('No orders here.'),
                            style: TextStyle(color: C.grey),
                          ),
                        ),
                      ...items.map((o) {
                        final s = '${o['status']}';
                        final nx = _next[s];
                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Order #${o['number']} - ${o['buyer']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Pill(statusLabel(s), color: statusColor(s)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr('${o['summary']}'),
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                '${o['address']} - ${o['payment']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: C.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      rs(toNum(o['total'])),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: C.green,
                                      ),
                                    ),
                                  ),
                                  if (s == 'placed')
                                    TextButton(
                                      onPressed: () => _cancel(o as Map),
                                      child: Text(
                                        tr('Cancel'),
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  if (nx != null)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: C.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () =>
                                          _setStatus(o as Map, nx[0]),
                                      child: Text(nx[1]),
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
