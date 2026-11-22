import 'package:flutter/material.dart';
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
import 'about.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _q = TextEditingController();
  String _query = '';
  List? _featured;
  Object? _err;
  Map<String, dynamic>? _loc = Store.loc;
  final _key = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    Meta.refresh().then((_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  Future<void> _load() async {
    final cached = Store.cacheGet('featured', maxAgeMin: 30);
    if (cached != null && _featured == null) setState(() => _featured = cached as List);
    try {
      final r = await Api.rpc('featured_providers', {'p_lat': _loc?['lat'], 'p_lng': _loc?['lng'], 'p_limit': 12, 'p_offset': 0});
      final items = (r['items'] as List);
      await Store.cachePut('featured', items);
      if (mounted) setState(() { _featured = items; _err = null; });
    } catch (e) {
      if (mounted && _featured == null) setState(() => _err = e);
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
    return Scaffold(
      key: _key,
      drawer: _drawer(),
      body: RefreshIndicator(
        onRefresh: () async { await _load(); await Meta.refresh(); setState(() {}); },
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _hero()),
          if (_query.isNotEmpty) ...[
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
          ] else ...[
            for (final c in Meta.cats) ..._catSection(c),
            SliverToBoxAdapter(child: _featuredSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ]),
      ),
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
        Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/icon.png')),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('صنايعي قريب', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
          IconButton(onPressed: () => _key.currentState?.openDrawer(), icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28)),
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
            hintText: 'ابحث: سباك، كهربائي، تكييف…',
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

  Widget _featuredSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('صنايعية مميزون', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (_featured == null && _err != null) ErrorRetry(_err!, _load)
        else if (_featured == null) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_featured!.isEmpty) const Empty('لا يوجد صنايعية بعد')
        else for (final p in _featured!) Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ProviderCard(p: p as Map, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderScreen(id: p['id'])))),
        ),
      ]),
    );
  }

  Widget _drawer() {
    void go(Widget w) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    }
    return Drawer(
      child: SafeArea(
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/icon.png', width: 44, height: 44)),
              const SizedBox(width: 10),
              const Text('صنايعي قريب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.home_rounded), title: const Text('الرئيسية'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.history_rounded), title: const Text('طلباتي'), onTap: () => go(const RequestsScreen())),
          ListTile(leading: const Icon(Icons.place_rounded), title: const Text('تغيير موقعي'), onTap: () { Navigator.pop(context); _pickLoc(); }),
          const Divider(),
          const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 4), child: Text('أنا صنايعي', style: TextStyle(color: C.mute, fontWeight: FontWeight.w600))),
          if (Store.loggedIn)
            ListTile(leading: const Icon(Icons.dashboard_rounded), title: const Text('لوحتي'), onTap: () => go(const DashboardScreen()))
          else ...[
            ListTile(leading: const Icon(Icons.login_rounded), title: const Text('تسجيل الدخول'), onTap: () => go(const LoginScreen())),
            ListTile(leading: const Icon(Icons.app_registration_rounded), title: const Text('سجّل كصنايعي'), subtitle: const Text('اعرض خدمتك حسب المهارات العندك'), onTap: () => go(const RegisterScreen())),
          ],
          const Divider(),
          ListTile(leading: const Icon(Icons.info_outline_rounded), title: const Text('عن التطبيق والدعم'), onTap: () => go(const AboutScreen())),
        ]),
      ),
    );
  }
}
