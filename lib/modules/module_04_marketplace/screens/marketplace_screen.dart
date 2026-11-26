import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agrisphere/core/i18n/app_lang.dart';
import 'package:agrisphere/core/services/agri_api.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/ux.dart';
import 'package:agrisphere/core/widgets/voice.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/offers_screen.dart';
import 'package:agrisphere/modules/module_04_marketplace/screens/sell_produce_screen.dart';
import 'package:agrisphere/modules/module_04_marketplace/widgets/product_card.dart';
import 'package:agrisphere/modules/module_05_orders/screens/checkout_screen.dart' show pkCities;
import 'package:agrisphere/modules/module_09_machinery/screens/machinery_browse_screen.dart';
import 'package:agrisphere/modules/module_10_warehouse/screens/warehouse_browse_screen.dart';
import 'package:agrisphere/modules/module_11_social/favorites.dart';

/// Marketplace home: search, banners, categories, curated sections and the full product grid.
/// Typing a search, choosing a category or applying a filter switches to the results view.
class MarketplaceScreen extends StatefulWidget {
  final void Function(int) goTab;
  const MarketplaceScreen({super.key, required this.goTab});
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _q = TextEditingController();
  final _scroll = ScrollController();
  late Future<dynamic> _home;
  late Future<dynamic> _grid;
  String _cat = 'All';
  String _sort = 'Newest';
  String _kind = 'All'; // All | produce | input
  RangeValues _price = const RangeValues(0, 1000);
  double _maxKm = 0;
  String? _city;
  bool _verified = false;
  String _searched = '';
  final List _extra = []; // pages after the first
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;

  static const _sorts = ['Newest', 'Near me', 'Lowest price', 'Top rated'];

  bool get _results => _searched.isNotEmpty || _cat != 'All' || _filterCount > 0 || _kind != 'All';
  int get _filterCount =>
      (_price.start > 0 || _price.end < 1000 ? 1 : 0) + (_maxKm > 0 ? 1 : 0) + (_city != null ? 1 : 0) + (_verified ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _home = _fetchHome();
    _grid = _fetchGrid();
    CartBadge.refresh();
    Favs.load();
    if (MyLocation.last == null) {
      MyLocation.get(quiet: true).then((p) {
        if (p != null && mounted) setState(() => _home = _fetchHome());
      });
    }
  }

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<dynamic> _fetchHome() => AgriApi.get('/market-home?x=1${MyLocation.query(sortNear: false)}');

  Future<dynamic> _fetchGrid() {
    final p = <String>[];
    if (_cat != 'All') p.add('category=${Uri.encodeQueryComponent(_cat)}');
    if (_kind != 'All') p.add('kind=$_kind');
    if (_searched.isNotEmpty) p.add('q=${Uri.encodeQueryComponent(_searched)}');
    if (_sort == 'Lowest price') p.add('sort=price');
    if (_sort == 'Top rated') p.add('sort=rating');
    if (_price.start > 0) p.add('minPrice=${_price.start.round()}');
    if (_price.end < 1000) p.add('maxPrice=${_price.end.round()}');
    if (_maxKm > 0) p.add('maxKm=${_maxKm.round()}');
    if (_city != null) p.add('city=${Uri.encodeQueryComponent(_city!)}');
    if (_verified) p.add('verified=1');
    final loc = _sort == 'Near me' || _maxKm > 0 || MyLocation.last != null ? MyLocation.query(sortNear: _sort == 'Near me') : '';
    _gridQuery = '/listings?${p.join('&')}$loc';
    _extra.clear();
    _page = 1;
    return AgriApi.get('$_gridQuery&page=1').then((d) {
      _hasMore = d is Map && d['hasMore'] == true;
      return d;
    });
  }

  String _gridQuery = '/listings?';

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final d = await AgriApi.get('$_gridQuery&page=${_page + 1}') as Map;
      _page++;
      _extra.addAll((d['items'] as List?) ?? const []);
      _hasMore = d['hasMore'] == true;
    } catch (e) {
      if (mounted) snack(context, cleanErr(e), error: true);
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  void _reloadGrid() => setState(() => _grid = _fetchGrid());
  Future<void> _refreshAll() async {
    setState(() {
      _home = _fetchHome();
      _grid = _fetchGrid();
    });
    CartBadge.refresh();
    await Future.wait([_home, _grid].map((f) => f.catchError((_) => null)));
  }

  void _search(String v) {
    _searched = v.trim();
    _reloadGrid();
  }

  void _clearAll() {
    _q.clear();
    setState(() {
      _searched = '';
      _cat = 'All';
      _kind = 'All';
      _price = const RangeValues(0, 1000);
      _maxKm = 0;
      _city = null;
      _verified = false;
      _sort = 'Newest';
    });
    _reloadGrid();
  }

  Future<void> _setSort(String v) async {
    if (v == 'Near me' && MyLocation.last == null && await MyLocation.get(context: context) == null) return;
    setState(() => _sort = v);
    _reloadGrid();
  }

  // ------------------------------------------------------------ filter sheet
  Future<void> _filters() async {
    var price = _price;
    var km = _maxKm;
    var city = _city;
    var verified = _verified;
    var kind = _kind;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(tr('Filters'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                  onPressed: () => set(() {
                    price = const RangeValues(0, 1000);
                    km = 0;
                    city = null;
                    verified = false;
                    kind = 'All';
                  }),
                  child: Text(tr('Clear all')),
                ),
              ]),
              const SizedBox(height: 6),
              Text(tr('Show'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ChipRow(
                items: const ['All', 'Produce', 'Farm inputs'],
                selected: kind == 'produce' ? 'Produce' : (kind == 'input' ? 'Farm inputs' : 'All'),
                onSelect: (v) => set(() => kind = v == 'Produce' ? 'produce' : (v == 'Farm inputs' ? 'input' : 'All')),
              ),
              const SizedBox(height: 10),
              Text('${tr('Price per kg')}: ${rs(price.start)} - ${price.end >= 1000 ? '${rs(1000)}+' : rs(price.end)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              RangeSlider(
                values: price,
                min: 0,
                max: 1000,
                divisions: 40,
                activeColor: C.green,
                labels: RangeLabels(rs(price.start), rs(price.end)),
                onChanged: (v) => set(() => price = v),
              ),
              Text('${tr('Distance')}: ${km == 0 ? tr('Any distance') : '${tr('within')} ${km.round()} km'}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                value: km,
                min: 0,
                max: 200,
                divisions: 20,
                activeColor: C.green,
                label: km == 0 ? tr('Any') : '${km.round()} km',
                onChanged: (v) => set(() => km = v),
              ),
              DropdownButtonFormField<String?>(
                initialValue: city,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('City'),
                  prefixIcon: const Icon(Icons.location_city_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(tr('All cities'))),
                  ...pkCities.map((c) => DropdownMenuItem<String?>(value: c, child: Text(tr(c)))),
                ],
                onChanged: (v) => set(() => city = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: verified,
                activeThumbColor: C.green,
                onChanged: (v) => set(() => verified = v),
                title: Text(tr('Verified sellers only')),
                secondary: const Icon(Icons.verified, color: C.green),
              ),
              PrimaryButton(label: tr('Show results'), icon: Icons.check, onPressed: () => Navigator.pop(ctx, true)),
            ]),
          ),
        ),
      ),
    );
    if (apply != true || !mounted) return;
    if (km > 0 && MyLocation.last == null && await MyLocation.get(context: context) == null) km = 0;
    setState(() {
      _price = price;
      _maxKm = km;
      _city = city;
      _verified = verified;
      _kind = kind;
    });
    _reloadGrid();
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sell',
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        onPressed: () async {
          final ok = await Navigator.push(context, MaterialPageRoute(builder: (_) => const SellProduceScreen()));
          if (ok == true) _refreshAll();
        },
        icon: const Icon(Icons.add),
        label: Text(tr('Sell')),
      ),
      body: RefreshIndicator(
        color: C.green,
        onRefresh: _refreshAll,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(child: _header()),
            if (_results) ...[
              SliverToBoxAdapter(child: _resultsBar()),
              _gridSliver(),
            ] else ...[
              SliverToBoxAdapter(child: _homeSections()),
              SliverToBoxAdapter(child: _allHeader()),
              _gridSliver(),
            ],
            SliverToBoxAdapter(child: _loadMoreButton()),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1BA94C), C.dark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Marketplace'), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                InkWell(
                  onTap: () async {
                    await MyLocation.get(context: context);
                    _refreshAll();
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_on, color: Colors.white70, size: 14),
                    const SizedBox(width: 2),
                    Text(MyLocation.last == null ? tr('Tap to use my location') : tr('Showing produce near you'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
            IconButton(
              tooltip: tr('Offers'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OffersScreen())),
              icon: const Icon(Icons.local_offer_outlined, color: Colors.white),
            ),
            IconButton(
              tooltip: tr('Saved items'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedScreen())),
              icon: const Icon(Icons.favorite_border, color: Colors.white),
            ),
            ValueListenableBuilder<int>(
              valueListenable: CartBadge.count,
              builder: (_, n, _) => IconButton(
                tooltip: tr('Cart'),
                onPressed: () => widget.goTab(3),
                icon: Badge(
                  isLabelVisible: n > 0,
                  label: Text('$n'),
                  backgroundColor: C.amber,
                  child: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _q,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            onChanged: (v) {
              if (v.isEmpty && _searched.isNotEmpty) _search('');
            },
            decoration: InputDecoration(
              hintText: tr('Search wheat, tomato, seeds...'),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                VoiceSearchButton(onResult: (t) {
                  _q.text = t;
                  _search(t);
                }),
                IconButton(
                  tooltip: tr('Filters'),
                  icon: Badge(
                    isLabelVisible: _filterCount > 0,
                    label: Text('$_filterCount'),
                    backgroundColor: C.amber,
                    child: const Icon(Icons.tune, size: 20),
                  ),
                  onPressed: _filters,
                ),
              ]),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ]),
      );

  // ------------------------------------------------------------ home (no search / filter)
  Widget _homeSections() => FutureBuilder<dynamic>(
        future: _home,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const SkeletonList(rows: 3);
          final m = s.data is Map ? s.data as Map : const {};
          final cats = ((m['categories'] as List?) ?? const []).cast<Map>();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 14),
            _PromoCarousel(onTap: (i) {
              if (i == 0) {
                setState(() => _sort = 'Lowest price');
                _reloadGrid();
                _scroll.animateTo(_scroll.position.maxScrollExtent * 0.6, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
              } else if (i == 1) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MachineryBrowseScreen()));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseBrowseScreen()));
              }
            }),
            if (cats.isNotEmpty) _categories(cats),
            if (s.hasError)
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppCard(
                  onTap: _refreshAll,
                  child: Row(children: [
                    const Icon(Icons.cloud_off, color: C.grey),
                    const SizedBox(width: 10),
                    Expanded(child: Text(cleanErr(s.error!), style: const TextStyle(color: C.grey))),
                    Text(tr('Retry'), style: const TextStyle(color: C.green, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ProductStrip(title: 'Best deals today', icon: Icons.local_fire_department, color: const Color(0xFFDC2626), items: (m['deals'] as List?) ?? const [], onChanged: _refreshAll),
            if (MyLocation.last == null && !s.hasError)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: AppCard(
                  onTap: () async {
                    if (await MyLocation.get(context: context) != null) _refreshAll();
                  },
                  child: Row(children: [
                    const CircleAvatar(backgroundColor: C.light, child: Icon(Icons.near_me, color: C.green)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('See produce near you'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(tr('Turn on location to see distance and nearest sellers'), style: const TextStyle(fontSize: 11.5, color: C.grey)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: C.grey),
                  ]),
                ),
              ),
            ProductStrip(title: 'Near you', icon: Icons.near_me, items: (m['near'] as List?) ?? const [], onSeeAll: () => _setSort('Near me'), onChanged: _refreshAll),
            ProductStrip(title: 'Top rated', icon: Icons.star_rounded, color: const Color(0xFFF5A524), items: (m['topRated'] as List?) ?? const [], onSeeAll: () => _setSort('Top rated'), onChanged: _refreshAll),
            ProductStrip(title: 'Fresh this week', icon: Icons.eco, color: const Color(0xFF059669), items: (m['fresh'] as List?) ?? const [], onChanged: _refreshAll),
            ProductStrip(
              title: 'Seeds, fertilizer & tools',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF7C3AED),
              items: (m['inputs'] as List?) ?? const [],
              onSeeAll: () {
                setState(() => _kind = 'input');
                _reloadGrid();
              },
              onChanged: _refreshAll,
            ),
          ]);
        },
      );

  Widget _categories(List<Map> cats) => SizedBox(
        height: 104,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
          scrollDirection: Axis.horizontal,
          children: [
            for (final c in cats)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() => _cat = '${c['name']}');
                  _reloadGrid();
                },
                child: SizedBox(
                  width: 78,
                  child: Column(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: catColor(c['name']).withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                        border: Border.all(color: catColor(c['name']).withValues(alpha: 0.3)),
                      ),
                      child: Icon(catIcon(c['name']), color: catColor(c['name']), size: 26),
                    ),
                    const SizedBox(height: 4),
                    Text(tr('${c['name']}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    Text('${c['count']} ${tr('items')}', style: const TextStyle(fontSize: 10, color: C.grey)),
                  ]),
                ),
              ),
          ],
        ),
      );

  Widget _allHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.grid_view_rounded, color: C.green, size: 20),
            const SizedBox(width: 6),
            Text(tr('All products'), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          ChipRow(items: _sorts, selected: _sort, onSelect: _setSort),
        ]),
      );

  // ------------------------------------------------------------ results view
  Widget _resultsBar() {
    final chips = <(String, VoidCallback)>[
      if (_searched.isNotEmpty) ('"$_searched"', () {
        _q.clear();
        _search('');
      }),
      if (_cat != 'All') (tr(_cat), () {
        setState(() => _cat = 'All');
        _reloadGrid();
      }),
      if (_kind != 'All') (tr(_kind == 'input' ? 'Farm inputs' : 'Produce'), () {
        setState(() => _kind = 'All');
        _reloadGrid();
      }),
      if (_price.start > 0 || _price.end < 1000) ('${rs(_price.start)} - ${rs(_price.end)}', () {
        setState(() => _price = const RangeValues(0, 1000));
        _reloadGrid();
      }),
      if (_maxKm > 0) ('≤ ${_maxKm.round()} km', () {
        setState(() => _maxKm = 0);
        _reloadGrid();
      }),
      if (_city != null) (tr(_city!), () {
        setState(() => _city = null);
        _reloadGrid();
      }),
      if (_verified) (tr('Verified'), () {
        setState(() => _verified = false);
        _reloadGrid();
      }),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(onPressed: _clearAll, icon: const Icon(Icons.arrow_back), tooltip: tr('Back to marketplace')),
          Expanded(
            child: FutureBuilder<dynamic>(
              future: _grid,
              builder: (_, s) {
                final n = s.data is Map ? (((s.data as Map)['items'] as List?)?.length ?? 0) : null;
                return Text(n == null ? tr('Searching...') : '$n ${tr('results')}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800));
              },
            ),
          ),
          TextButton(onPressed: _clearAll, child: Text(tr('Clear all'))),
        ]),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: chips
              .map((c) => InputChip(
                    label: Text(c.$1, style: const TextStyle(fontSize: 12)),
                    onDeleted: c.$2,
                    deleteIconColor: C.grey,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: C.line),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        ChipRow(items: _sorts, selected: _sort, onSelect: _setSort),
      ]),
    );
  }

  Widget _gridSliver() => FutureBuilder<dynamic>(
        future: _grid,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const SliverToBoxAdapter(child: SkeletonList(rows: 4));
          }
          if (s.hasError) {
            return SliverToBoxAdapter(
              child: SizedBox(height: 260, child: EmptyState(icon: Icons.cloud_off, text: cleanErr(s.error!), action: EmptyAction('Retry', () async => _reloadGrid(), icon: Icons.refresh))),
            );
          }
          final items = [...(((s.data as Map)['items'] as List?) ?? const []), ..._extra];
          if (items.isEmpty) {
            return SliverToBoxAdapter(
              child: SizedBox(
                height: 300,
                child: EmptyState(
                  icon: Icons.search_off,
                  text: _results ? 'No products match.\nTry fewer filters or another word.' : 'No products yet.\nBe the first to sell!',
                  action: _results
                      ? EmptyAction('Clear filters', () async => _clearAll(), icon: Icons.filter_alt_off)
                      : EmptyAction('Sell produce', () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const SellProduceScreen()));
                          _refreshAll();
                        }),
                ),
              ),
            );
          }
          final w = MediaQuery.of(context).size.width;
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: w > 900 ? 4 : (w > 600 ? 3 : 2),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 252,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => ProductCard(p: items[i] as Map, onChanged: _refreshAll),
                childCount: items.length,
              ),
            ),
          );
        },
      );

  Widget _loadMoreButton() => FutureBuilder<dynamic>(
        future: _grid,
        builder: (_, s) {
          if (s.connectionState != ConnectionState.done || !_hasMore) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: OutlinedButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: C.green))
                  : const Icon(Icons.expand_more),
              label: Text(tr('Load more')),
              style: OutlinedButton.styleFrom(foregroundColor: C.green, minimumSize: const Size.fromHeight(46)),
            ),
          );
        },
      );
}

/// Auto-sliding promo banners.
class _PromoCarousel extends StatefulWidget {
  final ValueChanged<int> onTap;
  const _PromoCarousel({required this.onTap});
  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _pc = PageController(viewportFraction: 0.9);
  int _i = 0;
  Timer? _t;

  static const _slides = [
    ('assets/img/hero_market.png', 'Fresh harvest deals', 'Buy direct from farmers, no middlemen', 'Shop deals'),
    ('assets/img/hero_tractor.png', 'Need a tractor?', 'Rent machinery near your field by the hour', 'Rent now'),
    ('assets/img/hero_warehouse.png', 'Store your harvest', 'Safe warehouse space with temperature checks', 'Find space'),
  ];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pc.hasClients) return;
      _pc.animateToPage((_i + 1) % _slides.length, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pc,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) {
              final s = _slides[i];
              return GestureDetector(
                onTap: () => widget.onTap(i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(fit: StackFit.expand, children: [
                    Image.asset(s.$1, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: C.green)),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(tr(s.$2), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        SizedBox(width: 190, child: Text(tr(s.$3), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: C.amber, borderRadius: BorderRadius.circular(20)),
                          child: Text(tr(s.$4), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _slides.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _i ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(color: i == _i ? C.green : C.line, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ]);
}
