import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/storage_booking_detail_screen.dart';

/// Storage payments: what was received and what is still due.
class WarehousePaymentsScreen extends StatelessWidget {
  const WarehousePaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: tr('Payments'),
      subtitle: tr('Storage and handling charges'),
      load: () => AgriApi.get('/warehouse-owner/payments'),
      empty: 'No payments yet',
      emptyIcon: Icons.account_balance_wallet_outlined,
      item: (ctx, b, reload) {
        final bal = toNum(b['balance']);
        return AppCard(
          onTap: () async {
            await Navigator.push(ctx, MaterialPageRoute(builder: (_) => StorageBookingDetailScreen(bookingId: '${b['id']}', ownerView: true)));
            await reload();
          },
          child: Row(
            children: [
              Icon(bal <= 0 ? Icons.check_circle : Icons.schedule, color: bal <= 0 ? C.green : C.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${b['farmerName']} - ${b['crop']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${b['warehouseName']}  -  total ${rs(toNum(b['total']))}', style: const TextStyle(fontSize: 11.5, color: C.grey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(rs(toNum(b['paidAmount'])), style: const TextStyle(fontWeight: FontWeight.w800, color: C.green)),
                  if (bal > 0) Text('due ${rs(bal)}', style: const TextStyle(fontSize: 11, color: Colors.red)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
