import 'package:flutter/material.dart';

class C {
  static const green = Color(0xFF16803C);
  static const dark = Color(0xFF0F5F2C);
  static const light = Color(0xFFE8F5EC);
  static const bg = Color(0xFFF4F7F4);
  static const text = Color(0xFF1F2937);
  static const grey = Color(0xFF6B7280);
  static const amber = Color(0xFFF59E0B);
  static const line = Color(0xFFE5E7EB);
}

num toNum(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);

String rs(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return 'Rs $b';
}

String rsShort(num n) {
  if (n >= 1000) {
    final k = n / 1000;
    final txt = k == k.roundToDouble() ? k.round().toString() : k.toStringAsFixed(1);
    return 'Rs ${txt}k';
  }
  return 'Rs ${n.round()}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String fmtIso(dynamic iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse('$iso');
  if (d == null) return '';
  final l = d.toLocal();
  final hr = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final mn = l.minute.toString().padLeft(2, '0');
  final ap = l.hour >= 12 ? 'PM' : 'AM';
  return '${l.day} ${_months[l.month - 1]}, $hr:$mn $ap';
}

IconData catIcon(dynamic c) {
  switch ('$c'.toLowerCase()) {
    case 'grains':
      return Icons.grass;
    case 'veggies':
      return Icons.eco;
    case 'fruits':
      return Icons.local_florist;
    case 'seeds':
      return Icons.spa;
    case 'tools':
      return Icons.build;
    default:
      return Icons.shopping_basket;
  }
}

Color catColor(dynamic c) {
  switch ('$c'.toLowerCase()) {
    case 'grains':
      return const Color(0xFFD97706);
    case 'veggies':
      return const Color(0xFFDC2626);
    case 'fruits':
      return const Color(0xFFEA580C);
    case 'seeds':
      return C.green;
    case 'tools':
      return const Color(0xFF4B5563);
    default:
      return C.green;
  }
}

String statusLabel(String s) {
  switch (s) {
    case 'placed':
      return 'Pending';
    case 'confirmed':
      return 'Confirmed';
    case 'picked_up':
      return 'Picked up';
    case 'out_for_delivery':
      return 'In transit';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
      return 'Cancelled';
    default:
      return s;
  }
}

Color statusColor(String s) {
  if (s == 'delivered') return C.green;
  if (s == 'cancelled') return Colors.red;
  if (s == 'placed') return C.amber;
  return Colors.blue;
}

void snack(BuildContext c, String m, {bool error = false}) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Text(m),
    backgroundColor: error ? Colors.red.shade700 : C.dark,
    behavior: SnackBarBehavior.floating,
  ));
}

String cleanErr(Object e) => '$e'.replaceFirst('Exception: ', '');

class CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const CircleBtn({super.key, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
}

class GreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? trailing;
  final Widget? bottom;
  const GreenHeader({super.key, required this.title, this.subtitle, this.eyebrow, this.trailing, this.bottom});

  @override
  Widget build(BuildContext context) {
    final canBack = Navigator.canPop(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 14, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [C.dark, C.green], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (canBack) ...[
            CircleBtn(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (eyebrow != null) Text(eyebrow!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
        if (bottom != null) ...[const SizedBox(height: 16), bottom!],
      ]),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.line),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, {super.key, this.color = C.green});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.text))),
          if (trailing != null) trailing!,
        ]),
      );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: C.green,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
        ),
      );
}

class Ring extends StatelessWidget {
  final num percent;
  final double size;
  const Ring(this.percent, {super.key, this.size = 56});
  @override
  Widget build(BuildContext context) => Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0).toDouble(),
            strokeWidth: 6,
            backgroundColor: C.light,
            color: C.green,
          ),
        ),
        Text('${percent.round()}%', style: TextStyle(fontSize: size / 4.2, fontWeight: FontWeight.w700)),
      ]);
}

class QtyStepper extends StatelessWidget {
  final num value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final String unit;
  const QtyStepper({super.key, required this.value, required this.onMinus, required this.onPlus, this.unit = ''});
  Widget _b(IconData i, VoidCallback t) => InkWell(
        onTap: t,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(8)),
          child: Icon(i, size: 16, color: C.green),
        ),
      );
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _b(Icons.remove, onMinus),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('${value.round()}$unit', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        _b(Icons.add, onPlus),
      ]);
}

class ChipRow extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelect;
  const ChipRow({super.key, required this.items, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map((e) => ChoiceChip(
                  label: Text(e),
                  selected: e == selected,
                  showCheckmark: false,
                  onSelected: (_) => onSelect(e),
                  selectedColor: C.green,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(color: e == selected ? Colors.white : C.text, fontSize: 12),
                ))
            .toList(),
      );
}

OutlineInputBorder _ob(Color c) =>
    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c));

Widget field(String label, TextEditingController c,
    {String? hint, TextInputType? type, int lines = 1, IconData? icon, ValueChanged<String>? onChanged, bool readOnly = false, VoidCallback? onTap}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: c,
        keyboardType: type,
        maxLines: lines,
        onChanged: onChanged,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon, size: 18, color: C.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: _ob(C.line),
          enabledBorder: _ob(C.line),
          focusedBorder: _ob(C.green),
        ),
      ),
    ]),
  );
}

class Async extends StatelessWidget {
  final Future<dynamic> future;
  final Widget Function(dynamic data) builder;
  final VoidCallback onRetry;
  const Async({super.key, required this.future, required this.builder, required this.onRetry});
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
        future: future,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: C.green)));
          }
          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off, size: 48, color: C.grey),
                  const SizedBox(height: 8),
                  Text(cleanErr(s.error!), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  const Text('Is the backend running (npm start)?', style: TextStyle(color: C.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
                ]),
              ),
            );
          }
          return builder(s.data);
        },
      );
}