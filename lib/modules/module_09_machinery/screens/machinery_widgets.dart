import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/media.dart';

String rateText(Map m) {
  final parts = <String>[];
  if (m['forRent'] == true) {
    if (toNum(m['rentPerHour']) > 0) parts.add('${rs(toNum(m['rentPerHour']))}/${tr('hr')}');
    if (toNum(m['rentPerDay']) > 0) parts.add('${rs(toNum(m['rentPerDay']))}/${tr('day')}');
  }
  if (m['forSale'] == true && toNum(m['salePrice']) > 0) parts.add('${tr('Sale')} ${rsShort(toNum(m['salePrice']))}');
  return parts.isEmpty ? tr('Price on request') : parts.join('  |  ');
}

/// A machine row used in browse lists and in the owner's "My machines".
class MachineTile extends StatelessWidget {
  final Map m;
  final VoidCallback? onTap;
  final Widget? footer;
  const MachineTile({super.key, required this.m, this.onTap, this.footer});

  @override
  Widget build(BuildContext context) {
    final status = '${m['status']}';
    final available = m['availableNow'] == true;
    final sub = [
      if ('${m['brand'] ?? ''}'.isNotEmpty) '${m['brand']}',
      if (m['year'] != null) '${m['year']}',
      if (m['horsepower'] != null) '${m['horsepower']} HP',
    ].join(' - ');
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(children: [
                  Positioned.fill(child: NetPhoto(url: firstPhoto(m), kind: 'machine', radius: 14, thumb: true)),
                  Positioned(
                    right: 3,
                    bottom: 3,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white,
                      child: Icon(machineIcon(m['category']), color: C.green, size: 15),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('${m['name']}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    if (m['distanceKm'] != null) Padding(padding: const EdgeInsets.only(top: 2, bottom: 2), child: DistanceBadge(m['distanceKm'])),
                    if (sub.isNotEmpty) Text(tr(sub), style: const TextStyle(fontSize: 11.5, color: C.grey)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: C.grey),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text('${m['city'] ?? ''}${m['ownerName'] != null ? '  -  ${m['ownerName']}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.grey)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (toNum(m['ratingCount']) > 0)
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: C.amber),
                    Text(tr('${m['rating']}'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(rateText(m), style: const TextStyle(fontWeight: FontWeight.w800, color: C.green, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (m['forRent'] == true) const Pill('Rent'),
              if (m['forSale'] == true) const Pill('Buy', color: Colors.indigo),
              if ('${m['condition']}' == 'new') const Pill('New', color: Colors.teal),
              if (m['operatorAvailable'] == true) const Pill('Technician', color: Colors.orange),
              if (status == 'available')
                Pill(available ? 'Available now' : 'Booked now', color: available ? C.green : C.amber)
              else
                Pill(flowLabel(status), color: status == 'sold' ? Colors.red : C.grey),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 8), footer!],
        ],
      ),
    );
  }
}

/// A booking row (renter or owner side).
class MachineBookingTile extends StatelessWidget {
  final Map b;
  final bool ownerView;
  final VoidCallback? onTap;
  const MachineBookingTile({super.key, required this.b, this.ownerView = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = '${b['status']}';
    final buy = '${b['type']}' == 'buy';
    final when = buy
        ? 'Purchase request'
        : '${fmtIso(b['startAt'])}  -  ${toNum(b['quantity']).round()} ${'${b['rateUnit']}' == 'day' ? 'day(s)' : 'hr'}';
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(machineIcon(b['category']), color: C.green),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('${b['machineName']}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              Pill(flowLabel(s), color: flowColor(s)),
            ],
          ),
          const SizedBox(height: 6),
          Text(ownerView ? 'Customer: ${b['farmerName']}' : 'Owner: ${b['ownerName'] ?? ''}', style: const TextStyle(fontSize: 12, color: C.grey)),
          Text(when, style: const TextStyle(fontSize: 12, color: C.grey)),
          if (b['withTechnician'] == true)
            Text('Technician: ${toNum(b['techHours']).round()} hr${'${b['technicianName'] ?? ''}'.isEmpty ? '' : ' - ${b['technicianName']}'}', style: const TextStyle(fontSize: 12, color: C.grey)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(rs(toNum(b['total'])), style: const TextStyle(fontWeight: FontWeight.w800, color: C.green)),
              const Spacer(),
              Pill('${b['paymentStatus']}' == 'paid' ? 'Paid' : 'Unpaid', color: '${b['paymentStatus']}' == 'paid' ? C.green : C.amber),
            ],
          ),
        ],
      ),
    );
  }
}
