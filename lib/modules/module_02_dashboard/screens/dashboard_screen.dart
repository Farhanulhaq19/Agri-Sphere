import 'package:flutter/material.dart';
import 'package:agrisphere/main.dart' show appNavigator;
import 'dart:async';
import 'package:agrisphere/core/services/push.dart';
import 'package:agrisphere/core/services/realtime.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/market_insight_screen.dart';
import 'package:agrisphere/modules/module_12_ai/crop_doctor_screen.dart';
import 'package:agrisphere/modules/module_12_ai/agri_chatbot_screen.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/services/weather.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/media.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/modules/module_11_social/chat.dart';
import 'package:agrisphere/modules/module_11_social/favorites.dart';
import 'package:agrisphere/modules/module_01_auth/screens/notifications_screen.dart';
import 'package:agrisphere/modules/module_01_auth/widgets/account_button.dart';
import 'package:agrisphere/modules/module_03_crops/screens/add_crop_screen.dart';
import 'package:agrisphere/modules/module_03_crops/screens/crop_detail_screen.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/offers_screen.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/sell_produce_screen.dart';
import 'package:agrisphere/modules/module_05_orders/screens/order_tracking_screen.dart';
import 'package:agrisphere/modules/module_06_expert/screens/ask_expert_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/booking_detail_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/machinery_browse_screen.dart';
import 'package:agrisphere/modules/module_09_machinery/screens/my_machine_bookings_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/my_storage_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_browse_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int) goTab;
  const DashboardScreen({super.key, required this.goTab});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<dynamic> _f;
  Future<Weather>? _weather;
  Weather? _wx; // loaded weather, used to warn about irrigation before rain
  bool _showChart = false;
  final Set<String> _doneTasks = {};
  StreamSubscription<Map>? _noteSub;

  @override
  void dispose() {
    _noteSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _f = AgriApi.get('/dashboard');
    _loadWeather();
    ChatBadge.refresh();
    Favs.load(force: true);
    Realtime.connect();
    AgriApi.get('/me').then((d) => ChatBadge.listen('${(d as Map)['id']}')).catchError((_) {});
    Push.start(navigator: appNavigator);
    _noteSub = Realtime.notifications.listen((n) {
      if (!mounted || '${n['type']}' == 'chat') return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${n['title']}'),
        backgroundColor: C.dark,
        action: SnackBarAction(label: tr('Open'), textColor: Colors.white, onPressed: () => _open(const NotificationsScreen())),
      ));
      _reload();
    });
    // first launch: short tour of the app
    WidgetsBinding.instance.addPostFrameCallback((_) => AppTour.showIfFirstTime(context));
  }

  Future<void> _loadWeather() async {
    final p = MyLocation.last ?? await MyLocation.get(quiet: true) ?? pakistanCenter;
    if (!mounted) return;
    final f = Weather.fetch(p.latitude, p.longitude);
    setState(() => _weather = f);
    f.then((w) {
      if (mounted) setState(() => _wx = w);
    }).catchError((_) {});
  }

  void _reload() {
    ChatBadge.refresh();
    setState(() {
      _f = AgriApi.get('/dashboard');
      _doneTasks.clear();
    });
  }

  Future<void> _open(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    if (mounted) _reload();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _toggleTask(Map t) async {
    final key = '${t['cropId']}/${t['taskId']}';
    setState(() => _doneTasks.add(key));
    try {
      await AgriApi.post('/crops/${t['cropId']}/tasks/${t['taskId']}/toggle');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${tr('Done')}: ${tr('${t['title']}')}'),
        backgroundColor: C.dark,
        action: SnackBarAction(
          label: tr('Undo'),
          textColor: Colors.white,
          onPressed: () async {
            await AgriApi.post('/crops/${t['cropId']}/tasks/${t['taskId']}/toggle');
            if (mounted) setState(() => _doneTasks.remove(key));
          },
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _doneTasks.remove(key));
      snack(context, cleanErr(e), error: true);
    }
  }

  void _openAttention(Map a) {
    switch ('${a['kind']}') {
      case 'order':
        _open(OrderTrackingScreen(orderId: '${a['id']}'));
      case 'offers':
        _open(const OffersScreen(startReceived: true));
      case 'machine':
        _open(MachineBookingDetailScreen(bookingId: '${a['id']}'));
    }
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'agrichatbot',
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        onPressed: () => _open(const AgriChatBotScreen(role: 'farmer')),
        icon: const Text('🌱', style: TextStyle(fontSize: 18)),
        label: Text(tr('Ask AgriChatBot')),
      ),
      body: Async(
        future: _f,
        onRetry: _reload,
        builder: (data) {
          final m = data as Map;
          final counts = (m['counts'] as Map?) ?? const {};
          return RefreshIndicator(
            color: C.green,
            onRefresh: () async {
              _reload();
              _loadWeather();
              await _f;
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _header(m, counts),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FadeIn(delay: 0, child: _weatherCard()),
                      _FadeIn(delay: 1, child: _attention(m)),
                      _FadeIn(delay: 2, child: _stats(m, counts)),
                      _FadeIn(delay: 3, child: _crops(m)),
                      _FadeIn(delay: 4, child: _tasks(m)),
                      _FadeIn(delay: 5, child: _quickActions()),
                      _FadeIn(delay: 6, child: _recentOrders(m)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ header + earnings
  Widget _header(Map m, Map counts) {
    final change = m['changePct'];
    final week = (m['week'] as List?) ?? const [];
    final unread = toNum(counts['unread']).round();
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 14, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1BA94C), C.dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tr(_greeting)},', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text('${m['name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              Text(fmtDate(DateTime.now()), style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ]),
          ),
          ValueListenableBuilder<int>(
            valueListenable: ChatBadge.unread,
            builder: (_, n, _) => IconButton(
              tooltip: tr('Messages'),
              onPressed: () => _open(const ChatListScreen()),
              icon: Badge(
                isLabelVisible: n > 0,
                label: Text(n > 9 ? '9+' : '$n'),
                child: const Icon(Icons.forum_outlined, color: Colors.white, size: 24),
              ),
            ),
          ),
          Stack(clipBehavior: Clip.none, children: [
            IconButton(
              tooltip: tr('Notifications'),
              onPressed: () => _open(const NotificationsScreen()),
              icon: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text(unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
          const AccountButton(),
        ]),
        const SizedBox(height: 14),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _showChart = !_showChart),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Total earnings'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 2),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: toNum(m['earnings']).toDouble()),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Text(rs(v),
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                    ),
                    Text('${tr('Last 30 days')}: ${rs(toNum(m['last30']))}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: change == null
                          ? Colors.white.withValues(alpha: 0.2)
                          : (toNum(change) >= 0 ? Colors.white : const Color(0xFFFFE4E4)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (change != null)
                        Icon(toNum(change) >= 0 ? Icons.trending_up : Icons.trending_down,
                            size: 14, color: toNum(change) >= 0 ? C.green : Colors.red),
                      const SizedBox(width: 3),
                      Text(
                        change == null ? tr('New') : '${toNum(change) >= 0 ? '+' : ''}$change%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: change == null ? Colors.white : (toNum(change) >= 0 ? C.green : Colors.red),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(tr(_showChart ? 'Hide' : 'Last 7 days'),
                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                    Icon(_showChart ? Icons.expand_less : Icons.expand_more, color: Colors.white, size: 18),
                  ]),
                ]),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: _showChart ? _WeekBars(week: week) : const SizedBox(width: double.infinity),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------ weather
  Widget _weatherCard() {
    if (_weather == null) return const SizedBox.shrink();
    return FutureBuilder<Weather>(
      future: _weather,
      builder: (_, s) {
        if (s.connectionState != ConnectionState.done) {
          return const AppCard(
            child: SizedBox(height: 70, child: Center(child: CircularProgressIndicator(color: C.green, strokeWidth: 2))),
          );
        }
        if (s.hasError || !s.hasData) {
          return AppCard(
            onTap: _loadWeather,
            child: Row(children: [
              const Icon(Icons.cloud_off, color: C.grey),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('Weather unavailable. Tap to retry.'), style: const TextStyle(color: C.grey))),
            ]),
          );
        }
        final w = s.data!;
        return AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(w.icon, color: const Color(0xFFF5A524), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${w.temp.round()}°C  ·  ${tr(w.label)}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text('${tr('Humidity')} ${w.humidity}%  ·  ${tr('Wind')} ${w.wind.round()} km/h',
                      style: const TextStyle(fontSize: 11.5, color: C.grey)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Row(
              children: w.days.take(4).map((d) {
                final today = d.date.day == DateTime.now().day;
                return Expanded(
                  child: Column(children: [
                    Text(today ? tr('Today') : tr(_wd[d.date.weekday - 1]),
                        style: TextStyle(fontSize: 11, fontWeight: today ? FontWeight.w800 : FontWeight.w500)),
                    const SizedBox(height: 2),
                    Icon(weatherIcon(d.code), size: 20, color: C.green),
                    Text('${d.max.round()}° / ${d.min.round()}°', style: const TextStyle(fontSize: 11)),
                    Text('☔ ${d.rainChance}%', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                  ]),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.light, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.tips_and_updates_outlined, color: C.green, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(tr(w.tip), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            ),
          ]),
        );
      },
    );
  }

  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // ------------------------------------------------------------ needs attention
  Widget _attention(Map m) {
    final list = (m['attention'] as List?) ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    const look = {
      'payment': (Icons.account_balance_wallet_outlined, Color(0xFFD97706)),
      'verify': (Icons.fact_check_outlined, Color(0xFF2563EB)),
      'order': (Icons.receipt_long, C.green),
      'offer': (Icons.local_offer_outlined, Color(0xFF9333EA)),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Needs your attention',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
            child: Text('${list.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          )),
      SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final a = list[i] as Map;
            final l = look['${a['icon']}'] ?? look['order']!;
            return InkWell(
              onTap: () => _openAttention(a),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 250,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: l.$2, width: 4)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(children: [
                  CircleAvatar(backgroundColor: l.$2.withValues(alpha: 0.12), child: Icon(l.$1, color: l.$2, size: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('${a['title']}'),
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      const SizedBox(height: 2),
                      Text(tr('${a['sub']}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.grey)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: C.grey),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------ stat tiles
  Widget _stats(Map m, Map counts) {
    Widget tile(IconData i, Color c, String value, String label, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
              child: Column(children: [
                Icon(i, color: c, size: 22),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text(tr(label), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: C.grey)),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(children: [
        tile(Icons.grass, C.green, '${counts['crops'] ?? 0}', 'Crops', () => widget.goTab(1)),
        tile(Icons.agriculture, const Color(0xFFD97706), '${counts['bookings'] ?? 0}', 'Bookings', () => _open(const MyMachineBookingsScreen())),
        tile(Icons.warehouse_outlined, const Color(0xFF2563EB), '${toNum(m['storedTons'])} t', 'In storage', () => _open(const MyStorageScreen())),
        tile(Icons.local_offer_outlined, const Color(0xFF9333EA), '${counts['offers'] ?? 0}', 'Offers', () => _open(const OffersScreen(startReceived: true))),
      ]),
    );
  }

  // ------------------------------------------------------------ crops
  Widget _crops(Map m) {
    final list = (m['crops'] as List?) ?? const [];
    final health = toNum(m['cropHealth']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('My crops',
          trailing: list.isEmpty
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Ring(health, size: 26),
                  const SizedBox(width: 6),
                  Text(tr(health >= 80 ? 'Excellent' : (health >= 60 ? 'Good' : 'Needs care')),
                      style: const TextStyle(fontSize: 11, color: C.green, fontWeight: FontWeight.w700)),
                ])),
      SizedBox(
        height: 172,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            ...list.map((x) {
              final c = x as Map;
              final p = (toNum(c['progress']) / 100).clamp(0.0, 1.0).toDouble();
              return InkWell(
                onTap: () => _open(CropDetailScreen(cropId: '${c['id']}')),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    NetPhoto(url: photoUrl(c['photo']), kind: 'crop', height: 80, width: 150, radius: 16, thumb: true),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('${c['name']}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${tr('${c['stage']}')} · ${tr('Day')} ${c['dayNumber']}/${c['totalDays']}',
                            style: const TextStyle(fontSize: 10.5, color: C.grey)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: p),
                            duration: const Duration(milliseconds: 800),
                            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 7, backgroundColor: C.light, color: C.green),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${toNum(c['progress']).round()}% ${tr('grown')} · ${tr('Health')} ${toNum(c['health']).round()}%',
                            style: const TextStyle(fontSize: 10, color: C.grey)),
                      ]),
                    ),
                  ]),
                ),
              );
            }),
            InkWell(
              onTap: () => _open(const AddCropScreen()),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  color: C.light,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.green.withValues(alpha: 0.4)),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_circle_outline, color: C.green, size: 34),
                  const SizedBox(height: 6),
                  Text(tr(list.isEmpty ? 'Add your first crop' : 'Add crop'),
                      textAlign: TextAlign.center, style: const TextStyle(color: C.green, fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------ tasks
  bool get _rainSoon => _wx != null && _wx!.days.take(2).any((d) => d.rainChance >= 60);

  Widget _tasks(Map m) {
    final list = ((m['tasks'] as List?) ?? const []).cast<Map>();
    if (list.isEmpty) return const SizedBox.shrink();
    IconData icon(String t) => t.contains('irrig')
        ? Icons.water_drop_outlined
        : t.contains('fert')
            ? Icons.science_outlined
            : t.contains('spray') || t.contains('pest')
                ? Icons.bug_report_outlined
                : Icons.task_alt;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Upcoming farm tasks'),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: list.map((t) {
            final done = _doneTasks.contains('${t['cropId']}/${t['taskId']}');
            return CheckboxListTile(
              value: done,
              onChanged: done ? null : (_) => _toggleTask(t),
              activeColor: C.green,
              controlAffinity: ListTileControlAffinity.trailing,
              secondary: CircleAvatar(
                backgroundColor: C.light,
                child: Icon(icon('${t['type'] ?? t['title']}'.toLowerCase()), color: C.green, size: 20),
              ),
              title: Text(tr('${t['title']}'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? C.grey : C.text,
                  )),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${tr('${t['crop']}')} · ${tr('${t['when']}')}', style: const TextStyle(fontSize: 11)),
                if (_rainSoon && '${t['type']}' == 'irrigation' && ['Today', 'Tomorrow'].contains('${t['when']}'))
                  Text('🌧 ${tr('Rain expected: you may skip or delay this irrigation')}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
              ]),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------ quick actions
  Widget _quickActions() {
    final items = <(IconData, String, Color, VoidCallback)>[
      (Icons.smart_toy_outlined, 'AgriChatBot', const Color(0xFF059669), () => _open(const AgriChatBotScreen(role: 'farmer'))),
      (Icons.biotech_outlined, 'Crop Doctor', const Color(0xFFDC2626), () => _open(const CropDoctorScreen())),
      (Icons.add, 'Add crop', C.green, () => _open(const AddCropScreen())),
      (Icons.sell_outlined, 'Sell produce', const Color(0xFFD97706), () => _open(const SellProduceScreen())),
      (Icons.chat_bubble_outline, 'Ask expert', const Color(0xFF2563EB), () => _open(const AskExpertScreen())),
      (Icons.shopping_bag_outlined, 'Buy inputs', const Color(0xFF9333EA), () => widget.goTab(2)),
      (Icons.agriculture, 'Rent machine', const Color(0xFFB45309), () => _open(const MachineryBrowseScreen())),
      (Icons.warehouse_outlined, 'Store crop', const Color(0xFF0E7490), () => _open(const WarehouseBrowseScreen())),
      (Icons.local_offer_outlined, 'Offers', const Color(0xFFDB2777), () => _open(const OffersScreen())),
      (Icons.receipt_long_outlined, 'My orders', C.dark, () => widget.goTab(4)),
      (Icons.show_chart, 'Price trends', const Color(0xFF0E7490), () => _open(const MarketInsightScreen())),
      (Icons.favorite_border, 'Saved', Colors.red, () => _open(const SavedScreen())),
      (Icons.forum_outlined, 'Messages', const Color(0xFF059669), () => _open(const ChatListScreen())),
      (Icons.format_size, 'Text size', const Color(0xFF475569), () => showTextSizeSheet(context)),
      (Icons.tour_outlined, 'App tour', const Color(0xFF7C3AED), () => AppTour.show(context)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Quick actions'),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
        children: items
            .map((it) => _Pressable(
                  onTap: it.$4,
                  child: Column(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: it.$3.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
                      child: Icon(it.$1, color: it.$3, size: 28),
                    ),
                    const SizedBox(height: 6),
                    Text(tr(it.$2),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ))
            .toList(),
      ),
    ]);
  }

  // ------------------------------------------------------------ recent orders
  Widget _recentOrders(Map m) {
    final orders = (m['recentOrders'] as List?) ?? const [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Recent sales', trailing: TextButton(onPressed: () => widget.goTab(4), child: Text(tr('See all')))),
      if (orders.isEmpty)
        AppCard(
          onTap: () => _open(const SellProduceScreen()),
          child: Row(children: [
            const Icon(Icons.storefront_outlined, color: C.green),
            const SizedBox(width: 10),
            Expanded(child: Text(tr('No sales yet. List your produce to start selling.'), style: const TextStyle(color: C.grey))),
            const Icon(Icons.chevron_right, color: C.grey),
          ]),
        ),
      ...orders.map((x) {
        final o = x as Map;
        final s = '${o['status']}';
        return AppCard(
          onTap: () => _open(OrderTrackingScreen(orderId: '${o['id']}')),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: statusColor(s).withValues(alpha: 0.12),
              child: Icon(Icons.receipt_long, color: statusColor(s), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${o['buyer']} · ${o['summary']}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(children: [
                  Text('#${o['number']}  ', style: const TextStyle(fontSize: 11, color: C.grey)),
                  Pill(statusLabel(s), color: statusColor(s)),
                ]),
              ]),
            ),
            Text(rsShort(toNum(o['total'])), style: const TextStyle(fontWeight: FontWeight.w800, color: C.green)),
          ]),
        );
      }),
    ]);
  }
}

/// 7-day earnings bars; tap a bar to see that day's amount.
class _WeekBars extends StatefulWidget {
  final List week;
  const _WeekBars({required this.week});
  @override
  State<_WeekBars> createState() => _WeekBarsState();
}

class _WeekBarsState extends State<_WeekBars> {
  int _sel = 6;

  @override
  Widget build(BuildContext context) {
    final w = widget.week;
    if (w.isEmpty) return const SizedBox(width: double.infinity);
    final max = w.map((d) => toNum((d as Map)['amount'])).fold<num>(0, (a, b) => b > a ? b : a);
    final sel = w[_sel.clamp(0, w.length - 1)] as Map;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(children: [
        Text('${tr('${sel['day']}')}: ${rs(toNum(sel['amount']))}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(w.length, (i) {
              final d = w[i] as Map;
              final h = max == 0 ? 0.05 : (toNum(d['amount']) / max).clamp(0.05, 1.0).toDouble();
              final on = i == _sel;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _sel = i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: h),
                      duration: Duration(milliseconds: 400 + i * 60),
                      curve: Curves.easeOutBack,
                      builder: (_, v, _) => Container(
                        height: 64 * v,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: on ? Colors.white : Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(tr('${d['day']}'),
                        style: TextStyle(color: on ? Colors.white : Colors.white70, fontSize: 10, fontWeight: on ? FontWeight.w800 : FontWeight.w400)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }
}

/// Slides + fades a section in, one after another.
class _FadeIn extends StatelessWidget {
  final int delay;
  final Widget child;
  const _FadeIn({required this.delay, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 350 + delay * 90),
        curve: Curves.easeOut,
        builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c)),
        child: child,
      );
}

/// Shrinks slightly while pressed (nice tactile feel for big buttons).
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(scale: _down ? 0.92 : 1, duration: const Duration(milliseconds: 120), child: widget.child),
      );
}
