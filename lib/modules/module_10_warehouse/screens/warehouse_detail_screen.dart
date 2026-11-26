import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/contact.dart';
import 'package:agrisphere/modules/module_11_social/chat.dart';
import 'package:agrisphere/modules/module_11_social/favorites.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/media.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/my_storage_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/request_storage_screen.dart';

class WarehouseDetailScreen extends StatefulWidget {
  final String warehouseId;
  const WarehouseDetailScreen({super.key, required this.warehouseId});
  @override
  State<WarehouseDetailScreen> createState() => _WarehouseDetailScreenState();
}

class _WarehouseDetailScreenState extends State<WarehouseDetailScreen> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/warehouses/${widget.warehouseId}');
  }

  void _reload() => setState(() => _f = AgriApi.get('/warehouses/${widget.warehouseId}'));

  Future<void> _request(Map w) async {
    final done = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => RequestStorageScreen(warehouse: w)));
    if (done == true && mounted) {
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyStorageScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final w = data as Map;
          final types = (w['storageTypes'] as List?) ?? [];
          final fac = (w['facilities'] as List?) ?? [];
          final canBook = '${w['status']}' == 'active' && w['isMine'] != true && toNum(w['availableTons']) > 0;
          return Column(
            children: [
              GreenHeader(
                eyebrow: '${w['city'] ?? ''}',
                title: '${w['name']}',
                subtitle: '${w['ownerName'] ?? ''}',
                trailing: toNum(w['ratingCount']) > 0 ? Pill('${w['rating']} (${w['ratingCount']})', color: Colors.white) : null,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    PhotoGallery(photos: (w['photos'] as List?) ?? const [], kind: 'warehouse'),
                    const SizedBox(height: 10),
                    if (w['isMine'] != true)
                      Row(children: [
                        Expanded(
                          child: ChatWithButton(
                            to: '${w['owner']}',
                            toName: '${w['ownerName'] ?? 'Owner'}',
                            kind: 'warehouse',
                            refId: '${w['id']}',
                            title: '${w['name']}',
                            label: 'Chat with owner',
                          ),
                        ),
                        const SizedBox(width: 8),
                        FavoriteButton(kind: 'warehouse', id: '${w['id']}'),
                      ]),
                    if (w['isMine'] != true && '${w['ownerPhone'] ?? ''}'.isNotEmpty)
                      AppCard(
                        margin: const EdgeInsets.only(top: 10),
                        child: ContactRow(
                          label: 'Contact the owner',
                          name: '${w['ownerName'] ?? 'Owner'}',
                          phone: '${w['ownerPhone']}',
                          whatsappText: 'Assalam o Alaikum, I saw your ${w['name']} on AgriSphere.',
                        ),
                      ),
                    const SizedBox(height: 10),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${numStr(toNum(w['availableTons']))} t free of ${numStr(toNum(w['capacityTons']))} t', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(value: (toNum(w['occupancy']) / 100).clamp(0.0, 1.0).toDouble(), minHeight: 8, backgroundColor: C.light, color: toNum(w['occupancy']) > 85 ? Colors.red : C.green),
                          ),
                          const SizedBox(height: 10),
                          InfoRow('Rate', '${rs(toNum(w['ratePerTonDay']))} per ton per day'),
                          InfoRow('Minimum booking', '${numStr(toNum(w['minTons']))} t'),
                          if ('${w['address'] ?? ''}'.isNotEmpty) InfoRow('Address', '${w['address']}, ${w['city'] ?? ''}'),
                        ],
                      ),
                    ),
                    if (Place.fromItem(w) != null) ...[
                      const SectionTitle('Location'),
                      MapPreview(lat: Place.fromItem(w)!.lat, lng: Place.fromItem(w)!.lng, label: '${w['address'] ?? ''}, ${w['city'] ?? ''}'),
                    ],
                    if (types.isNotEmpty) ...[
                      const SectionTitle('Storage types'),
                      Wrap(spacing: 6, runSpacing: 6, children: types.map((e) => Pill('$e', color: Colors.indigo)).toList()),
                    ],
                    if (fac.isNotEmpty) ...[
                      const SectionTitle('Facilities'),
                      Wrap(spacing: 6, runSpacing: 6, children: fac.map((e) => Pill('$e')).toList()),
                    ],
                    if ('${w['description'] ?? ''}'.isNotEmpty) ...[
                      const SectionTitle('About'),
                      Text(tr('${w['description']}'), style: const TextStyle(color: C.grey, height: 1.4)),
                    ],
                    const SizedBox(height: 70),
                  ],
                ),
              ),
              if (canBook)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
                    child: PrimaryButton(label: tr('Request storage space'), icon: Icons.inventory_2_outlined, onPressed: () => _request(w)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
