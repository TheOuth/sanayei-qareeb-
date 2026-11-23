import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';

class ProviderScreen extends StatefulWidget {
  final String id;
  final String? service;
  const ProviderScreen({super.key, required this.id, this.service});
  @override
  State<ProviderScreen> createState() => _ProviderScreenState();
}

class _ProviderScreenState extends State<ProviderScreen> {
  Map? _p;
  Object? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      final l = Store.loc;
      final r = await Api.rpc('get_provider', {'p_id': widget.id, 'p_lat': l?['lat'], 'p_lng': l?['lng']});
      if (mounted) setState(() => _p = (r is Map) ? r : {});
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  Future<void> _contact(String channel) async {
    final p = _p!;
    final sid = widget.service ?? ((p['services'] as List).isNotEmpty ? p['services'][0].toString() : '');
    try {
      final l = Store.loc;
      await Api.rpc('create_request', {'p': {'provider_id': p['id'], 'anon_id': Store.anon, 'service': sid, 'city_id': l?['city_id'] ?? p['city_id'], 'channel': channel}});
    } catch (_) {}
    if (channel == 'call') {
      await openUrl('tel:${p['phone']}');
    } else {
      final d = (p['whatsapp'] ?? p['phone']).toString().replaceAll(RegExp(r'\D'), '');
      final msg = Uri.encodeComponent('السلام عليكم، وجدتك في تطبيق صنايعي قريب وأريد خدمة ${Meta.serviceName(sid)}');
      await openUrl('https://wa.me/$d?text=$msg');
    }
    if (mounted) toast(context, 'بعد انتهاء الخدمة ادخل "طلباتي" وقيّم الصنايعي');
  }

  void _report() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إبلاغ عن مشكلة'),
        content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'اكتب المشكلة باختصار')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Api.rpc('report_provider', {'p_id': widget.id, 'p_anon': Store.anon, 'p_reason': c.text.trim()});
                if (mounted) toast(context, 'وصلنا بلاغك، شكرًا');
              } catch (e) {
                if (mounted) toast(context, errMsg(e));
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      drawer: const AppDrawer(current: 'home'),
      appBar: bar(
        'الصنايعي',
        actions: [
          if (p != null && p.isNotEmpty && p['username'] != null)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: () => Share.share('${p['name']} على صنايعي قريب\n${Config.siteUrl}/#/u/${p['username']}'),
            ),
          if (p != null && p.isNotEmpty) IconButton(icon: const Icon(Icons.flag_outlined), onPressed: _report),
        ],
      ),
      body: _err != null
          ? ErrorRetry(_err!, _load)
          : p == null
              ? const Center(child: CircularProgressIndicator())
              : p.isEmpty
                  ? const Empty('هذا الصنايعي غير متاح')
                  : _body(p),
      bottomNavigationBar: (p == null || p.isEmpty)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: FilledButton.icon(onPressed: () => _contact('call'), icon: const Icon(Icons.call_rounded), label: const Text('اتصال'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FA463)),
                      onPressed: () => _contact('whatsapp'),
                      icon: const Icon(Icons.chat_rounded),
                      label: const Text('واتساب'),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _body(Map p) {
    final reviews = (p['reviews'] as List?) ?? [];
    final jobs = (p['jobs'] ?? 0) as int;
    final tier = Meta.tierOfProvider(p);
    final history = (p['history'] as List?) ?? [];
    return RefreshIndicator(onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Avatar(photo: p['photo'], name: p['name'] ?? '', size: 88),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(p['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              const SizedBox(width: 6),
              TierBadge(p: p, size: 26),
              if (p['verified'] == true && tier.isNotEmpty) Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: GestureDetector(onTap: () => trustSheet(context, p), child: const Icon(Icons.verified_rounded, color: C.blue, size: 22))),
            ]),
            if (tier.isNotEmpty || p['verified'] == true)
              GestureDetector(
                onTap: () => trustSheet(context, p),
                child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('موثّق${tier.isNotEmpty ? ' · شارة ${Meta.tierName(tier)}' : ''} · $jobs معاملة ناجحة  ›', style: const TextStyle(color: C.blue, fontSize: 12, fontWeight: FontWeight.w600))),
              ),
            const SizedBox(height: 8),
            Stars(rating: p['rating'] as num?, n: (p['rating_n'] ?? 0) as int),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
              for (final s in (p['services'] as List)) Chip(label: Text(Meta.serviceName(s.toString())), backgroundColor: const Color(0xFFE3F0FD), side: BorderSide.none),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            _kv('الحالة', p['available'] == true ? 'متاح الآن' : 'غير متاح الآن'),
            if (p['distance_km'] != null) _kv('المسافة', '${p['distance_km']} كم'),
            _kv('المنطقة', '${Meta.cityName((p['city_id'] ?? '').toString())}${(p['hood'] ?? '').toString().isEmpty ? '' : ' - ${p['hood']}'}'),
            _kv('ساعات العمل', '${p['from']} - ${p['to']}'),
            _kv('الخبرة', '${p['experience']} سنة'),
            if ((p['price'] ?? 0) != 0) _kv('سعر الكشف', '${p['price']} جنيه'),
            if (p['age'] != null) _kv('العمر', '${p['age']} سنة'),
          ]),
        ),
      ),
      if ((p['bio'] ?? '').toString().isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(p['bio']))),
      ],
      const SizedBox(height: 16),
      const Text('آخر أعمال الصنايعي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 8),
      if (history.isEmpty) const Text('لا توجد أعمال بعد', style: TextStyle(color: C.mute)) else _historyGrid(history),
      const SizedBox(height: 16),
      const Text('آراء العملاء', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 8),
      if (reviews.isEmpty) const Text('لا توجد تقييمات بعد', style: TextStyle(color: C.mute)),
      for (final r in reviews)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: Icon(r['success'] == true ? Icons.check_circle_rounded : Icons.cancel_rounded, color: r['success'] == true ? C.green : C.red),
              title: Row(children: [if (r['stars'] != null) Stars(rating: r['stars'] as num, n: 0)]),
              subtitle: (r['comment'] ?? '').toString().isEmpty ? null : Text(r['comment']),
            ),
          ),
        ),
      const SizedBox(height: 70),
    ]));
  }

  Widget _historyGrid(List h) {
    const meta = {
      'done': ['مكتمل', C.green, Icons.check_circle_rounded],
      'open': ['جارٍ', C.blue, Icons.autorenew_rounded],
      'failed': ['لم تتم', C.red, Icons.cancel_rounded],
      'not_agreed': ['لم يُتفق', C.mute, Icons.handshake_outlined],
      'disputed': ['قيد المراجعة', Color(0xFFB45309), Icons.hourglass_bottom_rounded],
    };
    String date(int ts) {
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: .92,
      children: [
        for (final x in h)
          Builder(builder: (_) {
            final m = meta[x['state']] ?? meta['open']!;
            final col = m[1] as Color;
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: col.withOpacity(.35))),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text((x['icon'] ?? '🔧').toString(), style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 2),
                Text((x['service'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: col.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(m[2] as IconData, size: 12, color: col), const SizedBox(width: 3), Text(m[0] as String, style: TextStyle(fontSize: 10.5, color: col, fontWeight: FontWeight.w700))]),
                ),
                const SizedBox(height: 3),
                Text(date(x['ts'] as int), style: const TextStyle(fontSize: 10, color: C.mute)),
              ]),
            );
          }),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [Text(k, style: const TextStyle(color: C.mute)), const Spacer(), Text(v, style: const TextStyle(fontWeight: FontWeight.w600))]),
      );
}
