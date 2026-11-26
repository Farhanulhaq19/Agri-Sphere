import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';

// ============================================================ text size (accessibility)

class AppPrefs {
  static final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);
  static const _k = 'app_text_scale';
  static const sizes = {'Normal': 1.0, 'Large': 1.15, 'Extra large': 1.3};

  static Future<void> load() async {
    try {
      textScale.value = (await SharedPreferences.getInstance()).getDouble(_k) ?? 1.0;
    } catch (_) {}
  }

  static Future<void> setScale(double v) async {
    textScale.value = v;
    try {
      await (await SharedPreferences.getInstance()).setDouble(_k, v);
    } catch (_) {}
  }
}

/// Wraps the whole app: applies the chosen text size and shows an offline banner.
Widget appShell(BuildContext context, Widget? child) => ValueListenableBuilder<double>(
      valueListenable: AppPrefs.textScale,
      builder: (c, scale, _) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: Column(children: [
          Expanded(child: child ?? const SizedBox.shrink()),
          const _OfflineBanner(),
        ]),
      ),
    );

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: AgriApi.offline,
        builder: (_, off, _) => AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: !off
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: const Color(0xFF374151),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(tr('You are offline. Showing saved data.'),
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ]),
                    ),
                  ),
                ),
        ),
      );
}

/// Bottom sheet to pick the text size.
Future<void> showTextSizeSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ValueListenableBuilder<double>(
          valueListenable: AppPrefs.textScale,
          builder: (_, cur, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tr('Text size'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            for (final e in AppPrefs.sizes.entries)
              ListTile(
                onTap: () => AppPrefs.setScale(e.value),
                leading: Icon(cur == e.value ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: cur == e.value ? C.green : C.grey),
                title: Text(tr(e.key), style: TextStyle(fontSize: 15 * e.value)),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );

// ============================================================ loading skeletons

/// Grey shimmering placeholder rows shown while a page loads.
class SkeletonList extends StatefulWidget {
  final int rows;
  const SkeletonList({super.key, this.rows = 5});
  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Widget _bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Opacity(opacity: 0.05 + 0.06 * _a.value, child: child),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        itemCount: widget.rows,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _bar(double.infinity, 14),
                const SizedBox(height: 8),
                _bar(160, 11),
                const SizedBox(height: 8),
                _bar(90, 11),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============================================================ empty states

/// Button shown under an empty list. The list reloads after [onTap] finishes.
class EmptyAction {
  final String label;
  final IconData icon;
  final Future<void> Function() onTap;
  const EmptyAction(this.label, this.onTap, {this.icon = Icons.add});
}

// ============================================================ live validation

typedef Check = String? Function(String v);

/// Ready-made checks (return an error message or null).
class V {
  static Check required(String what) => (v) => v.trim().isEmpty ? 'Enter $what' : null;
  static Check minLen(int n, String what) => (v) => v.trim().length < n ? '$what must be at least $n characters' : null;
  static Check phone() => (v) {
        final p = v.replaceAll(RegExp(r'[\s-]'), '');
        if (p.isEmpty) return 'Enter a mobile number';
        return RegExp(r'^(\+92|0)3\d{9}$').hasMatch(p) ? null : 'Use the format 03001234567';
      };
  static Check number(String what, {num min = 0.0001, num? max}) => (v) {
        final n = num.tryParse(v.trim());
        if (v.trim().isEmpty) return 'Enter $what';
        if (n == null) return '$what must be a number';
        if (n < min) return '$what must be more than ${min < 1 ? 0 : min}';
        if (max != null && n > max) return '$what must be at most $max';
        return null;
      };
  static Check optionalNumber(String what) => (v) => v.trim().isEmpty || num.tryParse(v.trim()) != null ? null : '$what must be a number';
  static Check all(List<Check> checks) => (v) {
        for (final c in checks) {
          final e = c(v);
          if (e != null) return e;
        }
        return null;
      };
}

/// A text field that checks itself while the user types (after the first edit, or after [FormCheck.showAll]).
class LiveField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final Check? check;
  final String? hint;
  final IconData? icon;
  final TextInputType? type;
  final int lines;
  final ValueChanged<String>? onChanged;
  final FormCheck? form;
  const LiveField(
    this.label,
    this.controller, {
    super.key,
    this.check,
    this.hint,
    this.icon,
    this.type,
    this.lines = 1,
    this.onChanged,
    this.form,
  });
  @override
  State<LiveField> createState() => _LiveFieldState();
}

class _LiveFieldState extends State<LiveField> {
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    widget.form?._fields.add(this);
  }

  @override
  void dispose() {
    widget.form?._fields.remove(this);
    super.dispose();
  }

  String? get error => widget.check?.call(widget.controller.text);
  void _show() => setState(() => _touched = true);

  @override
  Widget build(BuildContext context) {
    final err = _touched ? error : null;
    final ok = _touched && err == null && widget.check != null && widget.controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(widget.label), style: const TextStyle(fontSize: 12, color: C.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          keyboardType: widget.type,
          maxLines: widget.lines,
          onChanged: (v) {
            if (!_touched) _touched = true;
            setState(() {});
            widget.onChanged?.call(v);
          },
          decoration: InputDecoration(
            hintText: widget.hint == null ? null : tr(widget.hint!),
            prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 18, color: err != null ? Colors.red : C.grey),
            suffixIcon: ok ? const Icon(Icons.check_circle, color: C.green, size: 18) : null,
            errorText: err == null ? null : tr(err),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ok ? C.green : C.line),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Groups LiveFields so a Submit button can check them all at once.
class FormCheck {
  final List<_LiveFieldState> _fields = [];

  /// Shows every error. Returns the first error message, or null when everything is valid.
  String? validate() {
    String? first;
    for (final f in List.of(_fields)) {
      f._show();
      first ??= f.error;
    }
    return first;
  }
}

// ============================================================ first-time tour

class AppTour {
  static const _k = 'tour_seen_v1';

  static Future<void> showIfFirstTime(BuildContext context) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(_k) == true) return;
      await p.setBool(_k, true);
    } catch (_) {
      return;
    }
    if (context.mounted) await show(context);
  }

  static Future<void> show(BuildContext context) => showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, _, _) => const _TourDialog(),
      );
}

class _TourDialog extends StatefulWidget {
  const _TourDialog();
  @override
  State<_TourDialog> createState() => _TourDialogState();
}

class _TourDialogState extends State<_TourDialog> {
  final _pc = PageController();
  int _i = 0;

  static const _steps = [
    ('assets/img/hero_field.png', 'Welcome to AgriSphere', 'Manage crops, sell produce, rent machines and store your harvest, all in one app.'),
    ('assets/img/hero_market.png', 'Buy and sell directly', 'List produce with photos. Buyers see the distance, make offers and pay by Cash, Easypaisa or card.'),
    ('assets/img/hero_tractor.png', 'Rent machinery near you', 'Tap "Near me" to find tractors and harvesters close to your field, then book and track them.'),
    ('assets/img/hero_warehouse.png', 'Store your crop safely', 'Find warehouses with free space, request storage and watch temperature and stock.'),
    ('assets/img/role_expert.png', 'Help is always close', 'Ask an expert, chat with sellers, check the weather tips and switch to Urdu from the top bar.'),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _steps.length - 1;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340,
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 360,
              child: PageView.builder(
                controller: _pc,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) {
                  final s = _steps[i];
                  return Column(children: [
                    Image.asset(s.$1, height: 190, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(height: 190, color: C.light)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Column(children: [
                        Text(tr(s.$2), textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(tr(s.$3), textAlign: TextAlign.center, style: const TextStyle(color: C.grey, height: 1.4)),
                      ]),
                    ),
                  ]);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _i ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(color: i == _i ? C.green : C.line, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                if (!last) TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Skip'))),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => last
                      ? Navigator.pop(context)
                      : _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  child: Text(tr(last ? 'Get started' : 'Next')),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
