import 'package:flutter/material.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';
import 'location.dart';
import 'provider.dart';

class ListScreen extends StatefulWidget {
  final Service service;
  const ListScreen({super.key, required this.service});
  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  Map<String, dynamic>? _loc = Store.loc;
  Map? _res;
  Object? _err;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loc == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() { _loading = true; _err = null; });
    try {
      final r = await Api.rpc('nearby_providers', {'p_lat': _loc!['lat'], 'p_lng': _loc!['lng'], 'p_service': widget.service.id, 'p_city': _loc!['city_id']});
      if (mounted) setState(() { _res = r as Map; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _err = e; _loading = false; });
    }
  }

  Future<void> _pick() async {
    final r = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LocationScreen()));
    if (r == true) {
      _loc = Store.loc;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    return Scaffold(
      drawer: const AppDrawer(current: 'home'),
      appBar: bar('${s.icon} ${s.name}'),
      body: Builder(builder: (_) {
        if (_loc == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.place_rounded, size: 56, color: C.blue),
                const SizedBox(height: 10),
                const Text('نحتاج موقعك لنعرض لك الأقرب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                FilledButton(onPressed: _pick, child: const Text('حدّد موقعي')),
              ]),
            ),
          );
        }
        if (_loading) return const Center(child: CircularProgressIndicator());
        if (_err != null) return ErrorRetry(_err!, _load);
        final tier = _res?['tier'] ?? 'none';
        final items = (_res?['items'] as List?) ?? [];
        String note = '';
        if (tier == 'nearest_city') note = 'لا يوجد صنايعي ضمن نطاقك الآن، هذه أقرب النتائج في مدينتك.';
        if (tier == 'other_city') note = 'لا يوجد في مدينتك الآن، هؤلاء أقرب المتاحين في مدن أخرى.';
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            InkWell(
              onTap: _pick,
              child: Row(children: [
                const Icon(Icons.place_rounded, size: 18, color: C.blue),
                const SizedBox(width: 4),
                Text(_loc!['label'] ?? '', style: const TextStyle(color: C.blue, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Text('تغيير', style: TextStyle(color: C.mute, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const SizedBox(height: 300, child: Empty('لا يوجد صنايعي متاح لهذه الخدمة الآن. جرّب لاحقًا أو غيّر المدينة'))
            else ...[
              if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(note, style: const TextStyle(color: C.mute, fontSize: 13))),
              for (final p in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ProviderCard(p: p as Map, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderScreen(id: p['id'], service: s.id)))),
                ),
            ],
          ]),
        );
      }),
    );
  }
}
