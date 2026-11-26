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
import 'package:agrisphere/modules/module_09_machinery/screens/book_machine_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/my_machine_bookings_screen.dart';

class MachineDetailScreen extends StatefulWidget {
  final String machineId;
  const MachineDetailScreen({super.key, required this.machineId});
  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen> {
  late Future<dynamic> _f;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/machinery/${widget.machineId}');
  }

  void _reload() => setState(() => _f = AgriApi.get('/machinery/${widget.machineId}'));

  Future<void> _book(Map m) async {
    final done = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => BookMachineScreen(machine: m)));
    if (done == true && mounted) {
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyMachineBookingsScreen()));
    }
  }

  Future<void> _buy(Map m) async {
    final field = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Buy ${m['name']}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: ${rs(toNum(m['salePrice']))}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(tr('The owner will confirm your request. You pay after it is accepted.'), style: TextStyle(fontSize: 12, color: C.grey)),
            const SizedBox(height: 10),
            TextField(controller: field, decoration: InputDecoration(labelText: tr('Your location / delivery address'), border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Send request'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final done = await runAction(context, () => AgriApi.post('/machinery/${widget.machineId}/book', {'type': 'buy', 'fieldLocation': field.text.trim()}), ok: 'Purchase request sent');
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) {
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyMachineBookingsScreen()));
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
          final m = data as Map;
          final slots = (m['bookedSlots'] as List?) ?? [];
          final reviews = (m['reviews'] as List?) ?? [];
          final features = (m['features'] as List?) ?? [];
          final canBook = '${m['status']}' == 'available' && m['isMine'] != true;
          return Column(
            children: [
              GreenHeader(
                eyebrow: '${m['category']}',
                title: '${m['name']}',
                subtitle: '${m['city'] ?? ''}',
                trailing: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                  child: Icon(machineIcon(m['category']), color: Colors.white),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    PhotoGallery(photos: (m['photos'] as List?) ?? const [], kind: 'machine'),
                    const SizedBox(height: 10),
                    if (m['isMine'] != true)
                      Row(children: [
                        Expanded(
                          child: ChatWithButton(
                            to: '${m['owner']}',
                            toName: '${m['ownerName'] ?? 'Owner'}',
                            kind: 'machine',
                            refId: '${m['id']}',
                            title: '${m['name']}',
                            label: 'Chat with owner',
                          ),
                        ),
                        const SizedBox(width: 8),
                        FavoriteButton(kind: 'machine', id: '${m['id']}'),
                      ]),
                    if (m['isMine'] != true && '${m['ownerPhone'] ?? ''}'.isNotEmpty)
                      AppCard(
                        margin: const EdgeInsets.only(top: 10),
                        child: ContactRow(
                          label: 'Contact the owner',
                          name: '${m['ownerName'] ?? 'Owner'}',
                          phone: '${m['ownerPhone']}',
                          whatsappText: 'Assalam o Alaikum, I saw your ${m['name']} on AgriSphere.',
                        ),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (m['distanceKm'] != null) DistanceBadge(m['distanceKm']),
                        Pill(m['availableNow'] == true ? 'Available now' : (m['busyUntil'] != null ? 'Busy until ${fmtIso(m['busyUntil'])}' : flowLabel('${m['status']}')), color: m['availableNow'] == true ? C.green : C.amber),
                        if ('${m['condition']}' == 'new') const Pill('New', color: Colors.teal),
                        if (m['operatorAvailable'] == true) const Pill('Technician available', color: Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        children: [
                          if (m['forRent'] == true && toNum(m['rentPerHour']) > 0) InfoRow('Rent per hour', rs(toNum(m['rentPerHour']))),
                          if (m['forRent'] == true && toNum(m['rentPerDay']) > 0) InfoRow('Rent per day', rs(toNum(m['rentPerDay']))),
                          if (m['forRent'] == true) InfoRow('Minimum booking', '${toNum(m['minHours']).round()} hr'),
                          if (m['operatorAvailable'] == true) InfoRow('Technician charge', '${rs(toNum(m['operatorRatePerHour']))}/${tr('hr')}'),
                          if (m['forSale'] == true) InfoRow('Sale price', rs(toNum(m['salePrice'])), bold: true),
                        ],
                      ),
                    ),
                    const SectionTitle('Details'),
                    AppCard(
                      child: Column(
                        children: [
                          if ('${m['brand'] ?? ''}'.isNotEmpty) InfoRow('Brand', '${m['brand']} ${m['modelName'] ?? ''}'),
                          if (m['year'] != null) InfoRow('Year', '${m['year']}'),
                          if (m['horsepower'] != null) InfoRow('Horsepower', '${m['horsepower']} HP'),
                          InfoRow('Condition', '${m['condition']}' == 'new' ? 'New' : 'Used'),
                          InfoRow('Owner', '${m['ownerName'] ?? ''}'),
                          if ('${m['address'] ?? ''}'.isNotEmpty) InfoRow('Address', '${m['address']}'),
                          if ('${m['locationNote'] ?? ''}'.isNotEmpty) InfoRow('Now at', '${m['locationNote']}'),
                          InfoRow('Jobs done', '${toNum(m['totalBookings']).round()}'),
                        ],
                      ),
                    ),
                    if (Place.fromItem(m) != null) ...[
                      const SectionTitle('Location'),
                      MapPreview(lat: Place.fromItem(m)!.lat, lng: Place.fromItem(m)!.lng, label: '${m['locationNote'] ?? m['address'] ?? m['city'] ?? ''}'),
                    ],
                    if ('${m['description'] ?? ''}'.isNotEmpty) ...[
                      const SectionTitle('About'),
                      Text(tr('${m['description']}'), style: const TextStyle(color: C.grey, height: 1.4)),
                    ],
                    if (features.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: features.map((e) => Pill('$e', color: C.grey)).toList()),
                    ],
                    if (slots.isNotEmpty) ...[
                      const SectionTitle('Already booked'),
                      AppCard(
                        child: Column(
                          children: slots.map((s) => InfoRow(fmtIso((s as Map)['startAt']), 'to ${fmtIso(s['endAt'])}')).toList(),
                        ),
                      ),
                    ],
                    if (reviews.isNotEmpty) ...[
                      const SectionTitle('Reviews'),
                      ...reviews.map((r) => AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(tr('${(r as Map)['farmerName']}'), style: const TextStyle(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              const Icon(Icons.star, size: 15, color: C.amber),
                              Text(tr('${r['rating']}')),
                            ]),
                            if ('${r['review']}'.isNotEmpty) Text(tr('${r['review']}'), style: const TextStyle(fontSize: 12, color: C.grey)),
                          ],
                        ),
                      )),
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
                    child: Row(
                      children: [
                        if (m['forSale'] == true)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : () => _buy(m),
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), side: const BorderSide(color: C.green)),
                              child: Text(tr('Buy'), style: TextStyle(color: C.green, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        if (m['forSale'] == true && m['forRent'] == true) const SizedBox(width: 10),
                        if (m['forRent'] == true) Expanded(flex: 2, child: PrimaryButton(label: tr('Book now'), icon: Icons.event_available, onPressed: () => _book(m))),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
