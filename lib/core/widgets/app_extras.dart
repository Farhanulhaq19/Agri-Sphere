import 'package:flutter/material.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

// ---------------------------------------------------------------- small helpers
/// 12 -> "12", 12.5 -> "12.5"
String numStr(num n) => n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);

Future<bool> confirmDialog(BuildContext context, String title, String text, {String yes = 'Yes'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(tr(title)),
      content: Text(tr(text)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
        TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr(yes))),
      ],
    ),
  );
  return r == true;
}

Future<DateTime?> pickDateTime(BuildContext context, {DateTime? initial}) async {
  final now = DateTime.now();
  final start = initial ?? now.add(const Duration(hours: 2));
  final d = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365)),
  );
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now.add(const Duration(days: 1)),
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 730)),
  );
}

/// Generic status colours used by machinery, storage and offers.
Color flowColor(String s) {
  switch (s) {
    case 'requested':
    case 'pending':
      return C.amber;
    case 'accepted':
    case 'approved':
    case 'countered':
      return Colors.blue;
    case 'in_progress':
    case 'stored':
      return Colors.indigo;
    case 'completed':
    case 'released':
      return C.green;
    case 'declined':
    case 'rejected':
    case 'cancelled':
      return Colors.red;
    default:
      return C.grey;
  }
}

String flowLabel(String s) => tr(_flowLabelEn(s));

String _flowLabelEn(String s) {
  switch (s) {
    case 'in_progress':
      return 'In progress';
    case 'requested':
      return 'Requested';
    default:
      return s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
  }
}

IconData machineIcon(dynamic category) {
  switch ('$category'.toLowerCase()) {
    case 'tractor':
      return Icons.agriculture;
    case 'harvester':
      return Icons.grass;
    case 'sprayer':
      return Icons.water_drop_outlined;
    case 'water pump':
      return Icons.water;
    case 'trolley':
      return Icons.local_shipping_outlined;
    default:
      return Icons.build_circle_outlined;
  }
}

// ---------------------------------------------------------------- widgets
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const StatCard({super.key, required this.icon, required this.label, required this.value, this.color = C.green, this.onTap});

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 28, color: color),
        ),
        const SizedBox(height: 8),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(tr(label), style: const TextStyle(fontSize: 12.5, color: C.grey)),
      ],
    ),
  );
}

/// Two cards per row.
class StatGrid extends StatelessWidget {
  final List<StatCard> cards;
  const StatGrid(this.cards, {super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(child: cards[i]),
          const SizedBox(width: 12),
          Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
        ],
      ));
      rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final EmptyAction? action;
  const EmptyState({super.key, required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/img/empty.png',
            height: 120,
            errorBuilder: (context, error, stack) => Icon(icon, size: 64, color: C.line),
          ),
          const SizedBox(height: 10),
          Text(tr(text), textAlign: TextAlign.center, style: const TextStyle(color: C.grey)),
          if (action != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(onPressed: () => action!.onTap(), icon: Icon(action!.icon), label: Text(tr(action!.label))),
          ],
        ],
      ),
    ),
  );
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const InfoRow(this.label, this.value, {super.key, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(tr(label), style: const TextStyle(color: C.grey, fontSize: 12.5))),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? C.green : C.text),
          ),
        ),
      ],
    ),
  );
}

/// Multi-select chips (facilities, storage types, ...).
class ToggleChips extends StatelessWidget {
  final List<String> items;
  final Set<String> selected;
  final void Function(String item, bool on) onChanged;
  const ToggleChips({super.key, required this.items, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: items.map((e) {
      final on = selected.contains(e);
      return FilterChip(
        label: Text(tr(e)),
        selected: on,
        showCheckmark: false,
        selectedColor: C.green,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(color: on ? Colors.white : C.text, fontSize: 12),
        onSelected: (v) => onChanged(e, v),
      );
    }).toList(),
  );
}

/// Date / time field that opens a picker.
Widget pickerField(String label, String value, IconData icon, VoidCallback onTap) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr(label), style: const TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: C.grey),
              const SizedBox(width: 10),
              Expanded(child: Text(value, style: TextStyle(color: value.startsWith('Pick') ? C.grey : C.text))),
            ],
          ),
        ),
      ),
    ],
  ),
);

/// Simple "Yes / No" switch row inside forms.
Widget switchRow(String title, String sub, bool value, ValueChanged<bool> onChanged) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(title), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            Text(tr(sub), style: const TextStyle(fontSize: 11.5, color: C.grey)),
          ],
        ),
      ),
      Switch(value: value, onChanged: onChanged, activeTrackColor: C.green),
    ],
  ),
);

/// Vertical history / timeline from a list of {status, at, note}.
class HistoryTimeline extends StatelessWidget {
  final List history;
  const HistoryTimeline(this.history, {super.key});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox();
    return Column(
      children: List.generate(history.length, (i) {
        final h = history[i] as Map;
        final last = i == history.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: last ? C.green : flowColor('${h['status']}'), shape: BoxShape.circle),
                ),
                if (!last) Container(width: 2, height: 30, color: C.line),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(flowLabel('${h['status']}'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                    Text(
                      '${fmtIso(h['at'])}${(h['note'] ?? '').toString().isEmpty ? '' : ' - ${h['note']}'}',
                      style: const TextStyle(fontSize: 11, color: C.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Lets a parent (for example a floating button) reload a [ListBody].
class ListController {
  Future<void> Function()? _reload;
  Future<void> reload() async {
    final r = _reload;
    if (r != null) await r();
  }
}

/// Pull-to-refresh list that loads from the API (no header, no Scaffold).
/// Give it a new [key] when the filter changes so it reloads.
class ListBody extends StatefulWidget {
  final Future<dynamic> Function() load;
  final Widget Function(BuildContext context, Map item, Future<void> Function() reload) item;
  final String empty;
  final IconData emptyIcon;
  final Widget? top;
  final String listKey;
  final ListController? controller;
  final EmptyAction? emptyAction;
  const ListBody({
    super.key,
    required this.load,
    required this.item,
    this.empty = 'Nothing here yet',
    this.emptyIcon = Icons.inbox_outlined,
    this.top,
    this.listKey = 'items',
    this.controller,
    this.emptyAction,
  });

  @override
  State<ListBody> createState() => _ListBodyState();
}

class _ListBodyState extends State<ListBody> {
  late Future<dynamic> _f;

  @override
  void initState() {
    super.initState();
    _f = widget.load();
    widget.controller?._reload = _reload;
  }

  Future<void> _reload() async {
    final f = widget.load();
    if (mounted) setState(() => _f = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Async(
      future: _f,
      onRetry: _reload,
      builder: (data) {
        final items = (data is Map ? data[widget.listKey] : data) as List? ?? [];
        return RefreshIndicator(
          color: C.green,
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              if (widget.top != null) widget.top!,
              if (items.isEmpty) SizedBox(height: 300, child: EmptyState(
                  icon: widget.emptyIcon,
                  text: widget.empty,
                  action: widget.emptyAction == null
                      ? null
                      : EmptyAction(widget.emptyAction!.label, () async {
                          await widget.emptyAction!.onTap();
                          await _reload();
                        }, icon: widget.emptyAction!.icon),
                )),
              ...items.map((e) => widget.item(context, e as Map, _reload)),
            ],
          ),
        );
      },
    );
  }
}

/// Green header + [ListBody].
class ListPage extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? headerBottom;
  final Widget? trailing;
  final Future<dynamic> Function() load;
  final Widget Function(BuildContext context, Map item, Future<void> Function() reload) item;
  final String empty;
  final IconData emptyIcon;
  final Widget Function(Future<void> Function() reload)? fab;
  final Widget? top;
  final String listKey;
  final EmptyAction? emptyAction;
  const ListPage({
    super.key,
    required this.title,
    required this.load,
    required this.item,
    this.subtitle,
    this.headerBottom,
    this.trailing,
    this.empty = 'Nothing here yet',
    this.emptyIcon = Icons.inbox_outlined,
    this.fab,
    this.top,
    this.listKey = 'items',
    this.emptyAction,
  });

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final _c = ListController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      floatingActionButton: widget.fab?.call(_c.reload),
      body: Column(
        children: [
          GreenHeader(title: widget.title, subtitle: widget.subtitle, trailing: widget.trailing, bottom: widget.headerBottom),
          Expanded(
            child: ListBody(
              controller: _c,
              load: widget.load,
              item: widget.item,
              empty: widget.empty,
              emptyIcon: widget.emptyIcon,
              top: widget.top,
              listKey: widget.listKey,
              emptyAction: widget.emptyAction,
            ),
          ),
        ],
      ),
    );
  }
}

/// Run an API call with a loading snack and error handling. Returns true on success.
Future<bool> runAction(BuildContext context, Future<dynamic> Function() call, {String? ok}) async {
  try {
    await call();
    if (ok != null && context.mounted) snack(context, ok);
    return true;
  } catch (e) {
    if (context.mounted) snack(context, cleanErr(e), error: true);
    return false;
  }
}


/// Big picture banner with a title on top (used on home screens).
class HeroBanner extends StatelessWidget {
  final String image;
  final String title;
  final String? subtitle;
  final double height;
  final Widget? action;
  const HeroBanner({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    this.height = 150,
    this.action,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            image,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(color: C.light),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.62),
                  Colors.black.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(title),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          tr(subtitle!),
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                        ),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Round role picture (farmer, machinery owner, ...).
class RoleBadge extends StatelessWidget {
  final String role;
  final double size;
  const RoleBadge(this.role, {super.key, this.size = 64});

  static String assetFor(String role) {
    switch (role.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')) {
      case 'machineryowner':
        return 'assets/img/role_machinery.png';
      case 'warehouseowner':
        return 'assets/img/role_warehouse.png';
      case 'buyer':
        return 'assets/img/role_market.png';
      case 'supplier':
        return 'assets/img/role_supplier.png';
      case 'expert':
      case 'admin':
        return 'assets/img/role_expert.png';
      default:
        return 'assets/img/role_farmer.png';
    }
  }

  @override
  Widget build(BuildContext context) => Image.asset(
    assetFor(role),
    width: size,
    height: size,
    errorBuilder: (context, error, stack) =>
        Icon(Icons.account_circle, size: size, color: C.green),
  );
}
