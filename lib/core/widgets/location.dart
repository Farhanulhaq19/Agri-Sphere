import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

/// Maps use OpenStreetMap tiles + Nominatim search (free, no API key).
const _tiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _uaPackage = 'com.example.agrisphere';
const pakistanCenter = LatLng(33.6844, 73.0479); // Islamabad

class Place {
  final double lat;
  final double lng;
  final String address;
  final String city;
  const Place({required this.lat, required this.lng, this.address = '', this.city = ''});
  LatLng get point => LatLng(lat, lng);

  static Place? fromItem(Map m, {String latKey = 'lat', String lngKey = 'lng'}) {
    final la = m[latKey], ln = m[lngKey];
    if (la is! num || ln is! num) return null;
    return Place(lat: la.toDouble(), lng: ln.toDouble(), address: '${m['address'] ?? ''}', city: '${m['city'] ?? ''}');
  }
}

Map<String, String> get _osmHeaders => kIsWeb ? const {} : const {'User-Agent': 'AgriSphere-FYP/1.0'};

/// Address search (Pakistan only).
Future<List<Place>> searchPlaces(String q) async {
  if (q.trim().length < 3) return [];
  final u = Uri.https('nominatim.openstreetmap.org', '/search',
      {'q': q, 'format': 'json', 'addressdetails': '1', 'limit': '6', 'countrycodes': 'pk'});
  final r = await http.get(u, headers: _osmHeaders).timeout(const Duration(seconds: 12));
  if (r.statusCode != 200) return [];
  return (jsonDecode(r.body) as List).map((e) {
    final a = (e['address'] as Map?) ?? const {};
    return Place(
      lat: double.parse('${e['lat']}'),
      lng: double.parse('${e['lon']}'),
      address: '${e['display_name']}',
      city: '${a['city'] ?? a['town'] ?? a['village'] ?? a['county'] ?? ''}',
    );
  }).toList();
}

/// Point → readable address.
Future<Place> reversePlace(LatLng p) async {
  try {
    final u = Uri.https('nominatim.openstreetmap.org', '/reverse',
        {'lat': '${p.latitude}', 'lon': '${p.longitude}', 'format': 'json', 'zoom': '16', 'addressdetails': '1'});
    final r = await http.get(u, headers: _osmHeaders).timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final e = jsonDecode(r.body) as Map;
      final a = (e['address'] as Map?) ?? const {};
      return Place(
        lat: p.latitude,
        lng: p.longitude,
        address: '${e['display_name'] ?? ''}',
        city: '${a['city'] ?? a['town'] ?? a['village'] ?? a['county'] ?? ''}',
      );
    }
  } catch (_) {}
  return Place(lat: p.latitude, lng: p.longitude);
}

/// Device GPS position (asks for permission). Remembers the last fix for "near me" lists.
class MyLocation {
  static LatLng? last;
  static Future<LatLng?> get({bool quiet = false, BuildContext? context}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!quiet && context != null && context.mounted) snack(context, 'Turn on location (GPS)', error: true);
        return last;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!quiet && context != null && context.mounted) snack(context, 'Location permission denied', error: true);
        return last;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      return last = LatLng(p.latitude, p.longitude);
    } catch (_) {
      return last;
    }
  }

  /// Query string to add to list requests: "&lat=..&lng=..&sort=near"
  static String query({bool sortNear = true}) =>
      last == null ? '' : '&lat=${last!.latitude}&lng=${last!.longitude}${sortNear ? '&sort=near' : ''}';
}

String kmLabel(dynamic km) {
  final d = km is num ? km : num.tryParse('$km');
  if (d == null) return '';
  return d < 1 ? '${(d * 1000).round()} m' : '${d.toStringAsFixed(d < 10 ? 1 : 0)} km';
}

/// Small "3.2 km away" badge.
class DistanceBadge extends StatelessWidget {
  final dynamic km;
  const DistanceBadge(this.km, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = kmLabel(km);
    if (t.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.near_me, size: 11, color: C.green),
        const SizedBox(width: 3),
        Text('$t ${tr('away')}', style: const TextStyle(fontSize: 10, color: C.green, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

Future<void> openDirections(double lat, double lng) async {
  final u = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
  await launchUrl(u, mode: LaunchMode.externalApplication);
}

/// Read-only map with a pin and a Directions button (detail pages).
class MapPreview extends StatelessWidget {
  final double lat;
  final double lng;
  final String label;
  final double height;
  const MapPreview({super.key, required this.lat, required this.lng, this.label = '', this.height = 170});

  @override
  Widget build(BuildContext context) {
    final p = LatLng(lat, lng);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: height,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: p,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(urlTemplate: _tiles, userAgentPackageName: _uaPackage),
              MarkerLayer(markers: [
                Marker(point: p, width: 40, height: 40, child: const Icon(Icons.location_pin, color: Colors.red, size: 40)),
              ]),
              const SimpleAttributionWidget(source: Text('OpenStreetMap')),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: Text(label.isEmpty ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}' : label,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.grey)),
        ),
        TextButton.icon(
          onPressed: () => openDirections(lat, lng),
          icon: const Icon(Icons.directions, size: 18),
          label: Text(tr('Directions')),
        ),
      ]),
    ]);
  }
}

/// Form field that opens the map picker.
class LocationField extends StatelessWidget {
  final String label;
  final Place? value;
  final ValueChanged<Place> onChanged;
  const LocationField({super.key, this.label = 'Location on map', required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(label), style: const TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final p = await Navigator.push<Place>(
              context,
              MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: v)),
            );
            if (p != null) onChanged(p);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: v == null ? C.line : C.green),
            ),
            child: Row(children: [
              Icon(v == null ? Icons.add_location_alt_outlined : Icons.location_on, color: C.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  v == null
                      ? tr('Pick location on map')
                      : (v.address.isNotEmpty ? v.address : '${v.lat.toStringAsFixed(5)}, ${v.lng.toStringAsFixed(5)}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: v == null ? C.grey : C.text),
                ),
              ),
              const Icon(Icons.map_outlined, color: C.grey, size: 18),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Full-screen map: search an address, use GPS, or tap to drop the pin.
class LocationPickerScreen extends StatefulWidget {
  final Place? initial;
  const LocationPickerScreen({super.key, this.initial});
  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  final _q = TextEditingController();
  late LatLng _pin = widget.initial?.point ?? MyLocation.last ?? pakistanCenter;
  List<Place> _results = [];
  Timer? _debounce;
  bool _searching = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial == null && MyLocation.last == null) _gps(quiet: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _move(LatLng p, [double zoom = 15]) {
    setState(() => _pin = p);
    _map.move(p, zoom);
  }

  Future<void> _gps({bool quiet = false}) async {
    final p = await MyLocation.get(quiet: quiet, context: context);
    if (p != null && mounted) _move(p);
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _searching = true);
      try {
        final r = await searchPlaces(v);
        if (mounted) setState(() => _results = r);
      } catch (_) {}
      if (mounted) setState(() => _searching = false);
    });
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final p = await reversePlace(_pin);
    if (mounted) Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        title: Text(tr('Pick location')),
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _pin,
            initialZoom: widget.initial == null ? 12 : 15,
            onTap: (_, p) => setState(() => _pin = p),
          ),
          children: [
            TileLayer(urlTemplate: _tiles, userAgentPackageName: _uaPackage),
            MarkerLayer(markers: [
              Marker(
                point: _pin,
                width: 46,
                height: 46,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_pin, color: Colors.red, size: 46),
              ),
            ]),
            const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Column(children: [
              TextField(
                controller: _q,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: tr('Search village, city or address'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              if (_results.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView(
                    shrinkWrap: true,
                    children: _results
                        .map((p) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined, color: C.green),
                              title: Text(p.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                setState(() => _results = []);
                                _move(p.point);
                              },
                            ))
                        .toList(),
                  ),
                ),
            ]),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 100,
          child: FloatingActionButton(
            heroTag: 'gps',
            backgroundColor: Colors.white,
            onPressed: () => _gps(),
            child: const Icon(Icons.my_location, color: C.green),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: PrimaryButton(
            label: tr('Use this location'),
            icon: Icons.check,
            loading: _saving,
            onPressed: _confirm,
          ),
        ),
      ]),
    );
  }
}
