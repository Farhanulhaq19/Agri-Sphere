import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/media.dart';

class WarehouseTile extends StatelessWidget {
  final Map w;
  final VoidCallback? onTap;
  final Widget? footer;
  const WarehouseTile({super.key, required this.w, this.onTap, this.footer});

  @override
  Widget build(BuildContext context) {
    final occ = toNum(w['occupancy']).toDouble();
    final types = (w['storageTypes'] as List?) ?? [];
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetPhoto(url: firstPhoto(w), kind: 'warehouse', width: 76, height: 76, radius: 14, thumb: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('${w['name']}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: C.grey),
                        const SizedBox(width: 2),
                        Expanded(child: Text('${w['city'] ?? ''}${'${w['address'] ?? ''}'.isEmpty ? '' : ', ${w['address']}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.grey))),
                      ],
                    ),
                    Text(tr('${w['ownerName'] ?? ''}'), style: const TextStyle(fontSize: 11.5, color: C.grey)),
                    if (w['distanceKm'] != null) Padding(padding: const EdgeInsets.only(top: 3), child: DistanceBadge(w['distanceKm'])),
                  ],
                ),
              ),
              if (toNum(w['ratingCount']) > 0)
                Row(children: [const Icon(Icons.star, size: 14, color: C.amber), Text(tr('${w['rating']}'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${rs(toNum(w['ratePerTonDay']))}/ton/day', style: const TextStyle(fontWeight: FontWeight.w800, color: C.green, fontSize: 13)),
              const Spacer(),
              Text('${numStr(toNum(w['availableTons']))} t free of ${numStr(toNum(w['capacityTons']))} t', style: const TextStyle(fontSize: 11.5, color: C.grey)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: (occ / 100).clamp(0.0, 1.0).toDouble(), minHeight: 6, backgroundColor: C.light, color: occ > 85 ? Colors.red : C.green),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ...types.map((t) => Pill('$t', color: Colors.indigo)),
            if ('${w['status']}' == 'paused') const Pill('Paused', color: C.grey),
          ]),
          if (footer != null) ...[const SizedBox(height: 8), footer!],
        ],
      ),
    );
  }
}

class StorageBookingTile extends StatelessWidget {
  final Map b;
  final bool ownerView;
  final VoidCallback? onTap;
  const StorageBookingTile({super.key, required this.b, this.ownerView = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = '${b['status']}';
    final stored = s == 'stored';
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: C.green),
              const SizedBox(width: 10),
              Expanded(child: Text('${b['crop']}  -  ${numStr(toNum(stored ? b['currentTons'] : b['quantityTons']))} t', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              Pill(flowLabel(s), color: flowColor(s)),
            ],
          ),
          const SizedBox(height: 6),
          Text(ownerView ? 'Farmer: ${b['farmerName']}' : '${b['warehouseName']}, ${b['city'] ?? ''}', style: const TextStyle(fontSize: 12, color: C.grey)),
          Text('${fmtIso(b['startDate'])}  -  ${toNum(b['days']).round()} days  -  ${b['storageType'] ?? ''}', style: const TextStyle(fontSize: 12, color: C.grey)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(rs(toNum(b['total'])), style: const TextStyle(fontWeight: FontWeight.w800, color: C.green)),
              const Spacer(),
              Pill(toNum(b['balance']) <= 0 ? 'Paid' : (toNum(b['paidAmount']) > 0 ? 'Part paid' : 'Unpaid'), color: toNum(b['balance']) <= 0 ? C.green : C.amber),
            ],
          ),
        ],
      ),
    );
  }
}
