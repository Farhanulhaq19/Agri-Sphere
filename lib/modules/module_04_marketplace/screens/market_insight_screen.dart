import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_browse_screen.dart';

/// Price trend + forecast for a crop: "should I sell now or hold?"
class MarketInsightScreen extends StatefulWidget {
  final String product;
  const MarketInsightScreen({super.key, this.product = 'Wheat'});
  @override
  State<MarketInsightScreen> createState() => _MarketInsightScreenState();
}

class _MarketInsightScreenState extends State<MarketInsightScreen> {
  late final _q = TextEditingController(text: widget.product);
  late Future<dynamic> _f = _fetch();
  static const _quick = ['Wheat', 'Rice', 'Potato', 'Onion', 'Tomato', 'Kinnow', 'Cotton', 'Maize'];

  Future<dynamic> _fetch() => AgriApi.get('/market-insight?q=${Uri.encodeQueryComponent(_q.text.trim())}');
  void _go([String? v]) {
    if (v != null) _q.text = v;
    setState(() => _f = _fetch());
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        body: Column(children: [
          GreenHeader(
            title: tr('Price trends'),
            subtitle: tr('Sell now or hold? Based on AgriSphere prices'),
            trailing: CircleBtn(icon: Icons.close, onTap: () => Navigator.pop(context)),
            bottom: TextField(
              controller: _q,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _go(),
              decoration: InputDecoration(
                hintText: tr('Product, e.g. wheat'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              children: _quick
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(label: Text(tr(c)), onPressed: () => _go(c), backgroundColor: Colors.white),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: Async(
              future: _f,
              onRetry: _go,
              builder: (d) {
                final m = d as Map;
                final series = ((m['series'] as List?) ?? const []).cast<Map>();
                final trend = '${m['trend']}';
                final tc = trend == 'rising' ? C.green : (trend == 'falling' ? const Color(0xFFDC2626) : const Color(0xFF2563EB));
                final season = m['season'] as Map?;
                Widget fc(String label, dynamic v) => Expanded(
                      child: AppCard(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(children: [
                          Text(tr(label), style: const TextStyle(fontSize: 11.5, color: C.grey)),
                          const SizedBox(height: 4),
                          Text(v == null ? '-' : rs(toNum(v)), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          Text(tr('per kg'), style: const TextStyle(fontSize: 10, color: C.grey)),
                        ]),
                      ),
                    );
                return ListView(padding: const EdgeInsets.all(12), children: [
                  AppCard(
                    child: Row(children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: tc.withValues(alpha: 0.12),
                        child: Icon(trend == 'rising' ? Icons.trending_up : (trend == 'falling' ? Icons.trending_down : Icons.trending_flat), color: tc, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${tr('${m['product']}')}: ${tr(trend == 'unknown' ? 'Not enough data' : 'Prices $trend')}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: tc)),
                          Text('${tr('Based on')} ${m['points']} ${tr('prices in the last 90 days')}', style: const TextStyle(fontSize: 11.5, color: C.grey)),
                        ]),
                      ),
                    ]),
                  ),
                  Row(children: [
                    fc('Now', m['current']),
                    fc('In 7 days', m['forecast7']),
                    fc('In 14 days', m['forecast14']),
                  ]),
                  const SizedBox(height: 12),
                  if (series.length >= 2)
                    AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('Price per kg, last 90 days'), style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 180,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 900),
                            builder: (_, v, _) => CustomPaint(
                              size: Size.infinite,
                              painter: _LineChart(series.map((s) => toNum(s['price']).toDouble()).toList(), toNum(m['forecast14']).toDouble(), tc, v),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(children: [
                          Text('${series.first['date']}', style: const TextStyle(fontSize: 10, color: C.grey)),
                          const Spacer(),
                          Container(width: 14, height: 2, color: tc),
                          Text('  ${tr('forecast')}', style: const TextStyle(fontSize: 10, color: C.grey)),
                          const Spacer(),
                          Text('${series.last['date']}', style: const TextStyle(fontSize: 10, color: C.grey)),
                        ]),
                      ]),
                    ),
                  AppCard(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.lightbulb_outline, color: Color(0xFFD97706)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tr('${m['advice']}'), style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4))),
                    ]),
                  ),
                  if (season != null)
                    AppCard(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.calendar_month_outlined, color: C.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tr(season['now'] == 'low' ? 'Low-price season now' : (season['now'] == 'high' ? 'High-price season now' : 'Normal season')),
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(tr('${season['tip']}'), style: const TextStyle(color: C.grey, height: 1.35)),
                          ]),
                        ),
                      ]),
                    ),
                  if (m['suggestStorage'] == true)
                    AppCard(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseBrowseScreen())),
                      child: Row(children: [
                        const Icon(Icons.warehouse_outlined, color: Color(0xFF0E7490)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(tr('Holding your crop? Find warehouse space nearby'), style: const TextStyle(fontWeight: FontWeight.w700))),
                        const Icon(Icons.chevron_right, color: C.grey),
                      ]),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(tr('${m['note']}'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: C.grey)),
                  ),
                ]);
              },
            ),
          ),
        ]),
      );
}

/// Simple line chart with a dashed forecast segment.
class _LineChart extends CustomPainter {
  final List<double> ys;
  final double forecast;
  final Color color;
  final double progress;
  _LineChart(this.ys, this.forecast, this.color, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...ys, if (forecast > 0) forecast];
    final lo = all.reduce((a, b) => a < b ? a : b) * 0.95;
    final hi = all.reduce((a, b) => a > b ? a : b) * 1.05;
    final n = ys.length + (forecast > 0 ? 1 : 0);
    double x(int i) => n <= 1 ? 0 : size.width * i / (n - 1);
    double y(double v) => size.height - (hi == lo ? 0.5 : (v - lo) / (hi - lo)) * size.height;

    final grid = Paint()..color = const Color(0xFFE5E7EB)..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final gy = size.height * i / 3;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), grid);
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final v in [hi, lo]) {
      tp.text = TextSpan(text: 'Rs ${v.round()}', style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)));
      tp.layout();
      tp.paint(canvas, Offset(0, v == hi ? 0 : size.height - 12));
    }

    final shown = (ys.length * progress).clamp(1, ys.length).round();
    final path = Path()..moveTo(x(0), y(ys[0]));
    for (var i = 1; i < shown; i++) {
      path.lineTo(x(i), y(ys[i]));
    }
    final fill = Path.from(path)
      ..lineTo(x(shown - 1), size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(path, Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);
    for (var i = 0; i < shown; i++) {
      canvas.drawCircle(Offset(x(i), y(ys[i])), 2.5, Paint()..color = color);
    }
    if (forecast > 0 && progress >= 1) {
      final a = Offset(x(ys.length - 1), y(ys.last));
      final b = Offset(x(ys.length), y(forecast));
      const dash = 6.0;
      final d = b - a;
      final len = d.distance;
      for (double t = 0; t < len; t += dash * 2) {
        canvas.drawLine(a + d * (t / len), a + d * ((t + dash).clamp(0, len) / len), Paint()
          ..color = color
          ..strokeWidth = 2);
      }
      canvas.drawCircle(b, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChart old) => old.progress != progress || old.ys != ys;
}
