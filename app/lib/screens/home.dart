import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';
import 'list.dart';
import 'provider.dart';
import 'location.dart';
import 'requests.dart';
import 'login.dart';
import 'register.dart';
import 'dashboard.dart';
import 'dart:async';
import 'about.dart';
import 'app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _poll;
  final _q = TextEditingController();
  String _query = '';
  List? _featured;
  bool _more = false, _loadingMore = false;
  int _tab = 0;
  Object? _err;
  Map<String, dynamic>? _loc = Store.loc;
  final _key = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    Store.tick.addListener(_onTick);
    WidgetsBinding.instance.addObserver(this);
    Store.refreshUnread();
    _poll = Timer.periodic(const Duration(seconds: 90), (_) => Store.refreshUnread());
    if (Store.loggedIn && Store.meName.isEmpty) Store.refreshMe();
    Meta.refresh().then((_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Store.refreshUnread();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Store.tick.removeListener(_onTick);
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    } else {
      final cached = Store.cacheGet('featured', maxAgeMin: 30);
      if (cached != null && _featured == null) setState(() => _featured = cached as List);
    }
    try {
      final off = more ? (_featured?.length ?? 0) : 0;
      final r = await Api.rpc('featured_providers', {'p_lat': _loc?['lat'], 'p_lng': _loc?['lng'], 'p_limit': 12, 'p_offset': off});
      final items = (r['items'] as List);
      if (!more) await Store.cachePut('featured', items);
      if (mounted) {
        setState(() {
          _featured = more ? [...?_featured, ...items] : items;
          _more = r['more'] == true;
          _err = null;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadingMore = false; if (_featured == null) _err = e; });
    }
  }

  Future<void> _pickLoc() async {
    final r = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LocationScreen()));
    if (r == true) {
      setState(() { _loc = Store.loc; _featured = null; });
      _load();
    }
  }

  void _openService(Service s) => Navigator.push(context, MaterialPageRoute(builder: (_) => ListScreen(service: s)));

  @override
  Widget build(BuildContext context) {
    final found = Meta.search(_query);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_key.currentState?.isDrawerOpen ?? false) {
          Navigator.pop(context);
          return;
        }
        if (_tab == 1) {
          setState(() => _tab = 0);
          return;
        }
        final exit = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('الخروج من التطبيق'),
            content: const Text('هل تريد الخروج من صنايعي قريب؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('البقاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('خروج')),
            ],
          ),
        );
        if (exit == true) SystemNavigator.pop();
      },
      child: Scaffold(
      key: _key,
      drawer: AppDrawer(current: 'home', onLocation: _pickLoc),
      onDrawerChanged: (open) { if (open) setState(() {}); },
      body: RefreshIndicator(
        onRefresh: () async { await _load(); await Meta.refresh(); setState(() {}); },
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _hero()),
          SliverToBoxAdapter(child: _tabs()),
          if (_tab == 1) ...[
            SliverToBoxAdapter(child: _providersTab()),
          ] else if (_query.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: found.isEmpty
                  ? const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Empty('ما لقينا خدمة بهذا الاسم. جرّب كلمة ثانية')))
                  : SliverList.separated(
                      itemCount: found.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _serviceTile(found[i]),
                    ),
            ),
          ] else
            for (final c in Meta.cats) ..._catSection(c),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ]),
      ),
    ));
  }

  Widget _tabs() {
    Widget t(int i, String label, IconData ic) {
      final on = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(color: on ? C.blue : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(ic, size: 18, color: on ? Colors.white : C.mute),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: on ? Colors.white : C.mute)),
            ]),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.hair)),
        child: Row(children: [t(0, 'الخدمات', Icons.handyman_rounded), t(1, 'مقدمو الخدمات', Icons.groups_rounded)]),
      ),
    );
  }

  Widget _providersTab() {
    final n = Meta.norm(_query);
    var list = _featured;
    if (list != null && n.isNotEmpty) {
      list = list.where((p) => Meta.norm((p['name'] ?? '').toString()).contains(n) || (p['services'] as List).any((s) => Meta.norm(Meta.serviceName(s.toString())).contains(n))).toList();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (list == null && _err != null) ErrorRetry(_err!, _load)
        else if (list == null) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (list.isEmpty) const Empty('لا يوجد مقدمو خدمات بهذا الاسم')
        else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 214),
            itemBuilder: (_, i) {
              final p = list![i] as Map;
              return ProviderGridCard(p: p, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderScreen(id: p['id']))));
            },
          ),
          const SizedBox(height: 8),
          if (_more && n.isEmpty) Center(child: OutlinedButton(onPressed: _loadingMore ? null : () => _load(more: true), child: Text(_loadingMore ? 'جارٍ التحميل…' : 'عرض المزيد'))),
        ],
      ]),
    );
  }

  Widget _hero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [C.navy, C.blue], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))]),
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/icon.png', width: 46, height: 46)),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _key.currentState?.openDrawer(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 46, height: 40,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          const Expanded(child: Padding(padding: EdgeInsets.only(top: 10), child: Text('صنايعي قريب', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)))),
          if (Store.loggedIn) const BellBtn(light: true),
          if (Store.loggedIn)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen())).then((_) { if (mounted) setState(() {}); }),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Colors.white, Color(0xFFBFE0FF)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: Avatar(photo: Store.mePhoto, name: Store.meName, size: 50),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white70, width: 1)),
                  child: const Text('الملف الشخصي', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
        ]),
        const SizedBox(height: 14),
        const Text('خدمتك لحدّ بيتك', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('أقرب صنايعي ليك، اتصل بيه مباشرة', style: TextStyle(color: Color(0xFFD6E9FF))),
        const SizedBox(height: 14),
        InkWell(
          onTap: _pickLoc,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.place_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(_loc == null ? 'حدّد موقعك' : '${_loc!['label']}${_loc!['gps'] == true ? ' (GPS)' : ''}', style: const TextStyle(color: Colors.white)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _q,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: _tab == 0 ? 'ابحث: سباك، كهربائي، تكييف…' : 'ابحث باسم الصنايعي أو خدمته',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () { _q.clear(); setState(() => _query = ''); }),
          ),
        ),
      ]),
    );
  }

  Widget _serviceTile(Service s) {
    final c = Color(Meta.cat(s.cat).color);
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: c.withOpacity(.12), child: Text(s.icon, style: const TextStyle(fontSize: 20))),
        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => _openService(s),
      ),
    );
  }

  List<Widget> _catSection(Category c) {
    final items = Meta.services.where((s) => s.cat == c.id).toList();
    if (items.isEmpty) return [];
    final col = Color(c.color);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        sliver: SliverToBoxAdapter(child: Row(children: [
          Text(c.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(c.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: col)),
        ])),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .95),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final s = items[i];
            return InkWell(
              onTap: () => _openService(s),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.hair)),
                padding: const EdgeInsets.all(6),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 44, height: 44, alignment: Alignment.center,
                    decoration: BoxDecoration(color: col.withOpacity(.12), shape: BoxShape.circle),
                    child: Text(s.icon, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(height: 6),
                  Text(s.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          },
        ),
      ),
    ];
  }
}
