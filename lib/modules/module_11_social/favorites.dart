import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/media.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/product_detail_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machine_detail_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_detail_screen.dart';

/// Which items the user saved (keys like `listing:ID`, `machine:ID`, `warehouse:ID`), loaded once and kept in sync.
class Favs {
  static final ValueNotifier<Set<String>> ids = ValueNotifier<Set<String>>({});
  static bool _loaded = false;

  static Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    try {
      final r = await AgriApi.get('/favorites/ids') as Map;
      ids.value = ((r['ids'] as List?) ?? []).map((e) => '$e').toSet();
      _loaded = true;
    } catch (_) {}
  }

  static bool has(String kind, String id) => ids.value.contains('$kind:$id');
}

/// Heart button. Tap to save / unsave; updates everywhere instantly.
class FavoriteButton extends StatefulWidget {
  final String kind; // listing | machine | warehouse
  final String id;
  final bool onImage; // white round background, for use on top of photos
  const FavoriteButton({super.key, required this.kind, required this.id, this.onImage = false});
  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Favs.load();
  }

  Future<void> _tap() async {
    if (_busy) return;
    final key = '${widget.kind}:${widget.id}';
    final was = Favs.ids.value.contains(key);
    final next = {...Favs.ids.value};
    was ? next.remove(key) : next.add(key);
    Favs.ids.value = next; // instant feedback
    setState(() => _busy = true);
    try {
      await AgriApi.post('/favorites/toggle', {'kind': widget.kind, 'id': widget.id});
      if (mounted) snack(context, was ? 'Removed from saved' : 'Saved. Find it under Saved items.');
    } catch (e) {
      final undo = {...Favs.ids.value};
      was ? undo.add(key) : undo.remove(key);
      Favs.ids.value = undo;
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Set<String>>(
        valueListenable: Favs.ids,
        builder: (_, ids, _) {
          final on = ids.contains('${widget.kind}:${widget.id}');
          final icon = AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(on ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(on), color: on ? Colors.red : (widget.onImage ? C.grey : C.grey), size: 20),
          );
          return InkWell(
            onTap: _tap,
            customBorder: const CircleBorder(),
            child: widget.onImage
                ? CircleAvatar(radius: 15, backgroundColor: Colors.white, child: icon)
                : Padding(padding: const EdgeInsets.all(6), child: icon),
          );
        },
      );
}

/// Saved items, grouped by type.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String _kind = 'All';
  static const _kinds = {'All': '', 'Produce & inputs': 'listing', 'Machines': 'machine', 'Warehouses': 'warehouse'};

  Widget _open(Map f) {
    switch ('${f['kind']}') {
      case 'machine':
        return MachineDetailScreen(machineId: '${f['ref']}');
      case 'warehouse':
        return WarehouseDetailScreen(warehouseId: '${f['ref']}');
      default:
        return ProductDetailScreen(listingId: '${f['ref']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _kinds[_kind]!;
    return ListPage(
      key: ValueKey(_kind),
      title: tr('Saved items'),
      subtitle: tr('Your favourite produce, machines and warehouses'),
      load: () => AgriApi.get('/favorites${k.isEmpty ? '' : '?kind=$k'}'),
      empty: 'Nothing saved yet.\nTap the heart on any item to save it here.',
      emptyIcon: Icons.favorite_border,
      top: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ChipRow(items: _kinds.keys.toList(), selected: _kind, onSelect: (v) => setState(() => _kind = v)),
      ),
      item: (ctx, f, reload) => AppCard(
        onTap: () async {
          await Navigator.push(ctx, MaterialPageRoute(builder: (_) => _open(f)));
          reload();
        },
        child: Row(children: [
          NetPhoto(
            url: photoUrl(f['photo']),
            kind: '${f['kind']}' == 'machine' ? 'machine' : ('${f['kind']}' == 'warehouse' ? 'warehouse' : 'listing'),
            width: 64,
            height: 64,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('${f['title']}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${f['sub'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.grey)),
              const SizedBox(height: 2),
              Text('${f['price'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: C.green, fontSize: 12.5)),
            ]),
          ),
          FavoriteButton(kind: '${f['kind']}', id: '${f['ref']}'),
        ]),
      ),
    );
  }
}
