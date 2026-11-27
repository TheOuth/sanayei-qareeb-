import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';
import '../push.dart';
import 'requests.dart';

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

  bool _sending = false;

  Future<String?> _pickService(Map p) async {
    final list = (p['services'] as List).map((e) => e.toString()).toList();
    if (widget.service != null && list.contains(widget.service)) return widget.service;
    if (list.length == 1) return list[0];
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('ما الخدمة التي تحتاجها؟', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          for (final s in list) ListTile(title: Text(Meta.serviceName(s)), onTap: () => Navigator.pop(ctx, s)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  String _offTitle(Map p) => switch (p['off']) {
        'hours' => 'الصنايعي خارج وقت عمله',
        'busy' => 'الصنايعي غير متاح حاليًا',
        _ => 'الصنايعي غير متصل الآن',
      };

  String _offMsg(Map p) {
    final tail = 'يمكنك إرسال الطلب إذا كنت تريد الاتفاق على الخدمة وتنفيذها في وقت آخر، أو اختيار صنايعي آخر متاح للعمل الآن.';
    switch (p['off']) {
      case 'hours':
        return 'ساعات عمله من ${t12(p['from'])} إلى ${t12(p['to'])}.\n\n$tail';
      case 'busy':
        return 'حدّد الصنايعي نفسه «غير متاح» في الوقت الحالي، وقد يتأخر في الرد.\n\n$tail';
      default:
        return 'لم يفتح الصنايعي التطبيق منذ فترة، وقد يتأخر في رؤية طلبك.\n\n$tail';
    }
  }

  Future<void> _request() async {
    final p = _p!;
    final sid = await _pickService(p);
    if (sid == null || !mounted) return;
    if (p['off'] != null) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.schedule_rounded, color: Color(0xFFB45309), size: 34),
          title: Text(_offTitle(p), textAlign: TextAlign.center),
          content: Text(_offMsg(p), style: const TextStyle(height: 1.7)),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowAlignment: OverflowBarAlignment.center,
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('أرسل الطلب لوقت آخر')),
            OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('اختيار صنايعي آخر متاح الآن')),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    setState(() => _sending = true);
    try {
      final l = Store.loc;
      final r = await Api.rpc('create_request', {'p': {'provider_id': p['id'], 'anon_id': Store.anon, 'client_pid': Store.pid, 'service': sid, 'city_id': l?['city_id'] ?? p['city_id']}});
      final existing = r is Map && r['existing'] == true;
      Push.syncClient();
      Store.refreshReqBadge();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(existing ? 'لديك طلب قائم عند هذا الصنايعي' : 'تم إرسال طلبك'),
          content: Text(existing ? 'طلبك السابق ما زال قائمًا (قيد الانتظار أو مقبول)، تجده في "طلباتي". يمكنك إرسال طلب جديد بعد إنهائه أو انتهاء مدته.' : 'سيظهر لك رقم الصنايعي وواتساب في "طلباتي" بمجرد أن يضغط "قبول". يمكنك طلب الخدمة من أكثر من صنايعي، ومن يرد أولًا تبدأ معه.\n\nتنبيه: لا تحوّل أي مبلغ ولا تدفع قبل انتهاء الخدمة وتسلّمها؛ الدفع وجهًا لوجه.', style: TextStyle(height: 1.6)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('البقاء هنا')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                openPage('RequestsScreen', () => const RequestsScreen());
              },
              child: const Text('طلباتي'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
              onPressed: () => Share.share('${p['name']} على صنايعي قريب\n${Config.siteUrl}/${p['username']}'),
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
      bottomNavigationBar: (p == null || p.isEmpty || widget.id == Store.pid)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: (p['state_closed'] != true && !_sending) ? _request : null,
                  icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.handyman_rounded),
                  label: Text(p['state_closed'] == true ? 'غير متاحة حاليًا في هذه الولاية' : 'طلب الخدمة'),
                ),
              ),
            ),
    );
  }

  int _tab = 0;

  String _date(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  Widget _ring(int? pct, Color col, {double size = 54}) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: size, height: size, child: CircularProgressIndicator(value: pct == null ? 0 : pct / 100, strokeWidth: size / 9, backgroundColor: col.withOpacity(.15), valueColor: AlwaysStoppedAnimation(col))),
          Text(pct == null ? '—' : '$pct%', style: TextStyle(fontSize: size * .30, fontWeight: FontWeight.w800, color: pct == null ? C.mute : col)),
        ]),
      );

  Widget _statTile(Widget top, String label, String sub) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.hair)),
          child: Column(children: [
            SizedBox(height: 54, child: Center(child: top)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            Text(sub, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: C.mute, fontSize: 11, height: 1.3)),
          ]),
        ),
      );

  Widget _chip(IconData i, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: c.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 14, color: c), const SizedBox(width: 4), Text(t, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700))]),
      );

  Widget _tabs(int reviewsN) {
    Widget b(int i, String t) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: _tab == i ? C.blue : Colors.transparent, borderRadius: BorderRadius.circular(12)),
              child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _tab == i ? Colors.white : C.mute)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE9F2FD), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [b(0, 'الأعمال'), b(1, reviewsN > 0 ? 'التقييمات ($reviewsN)' : 'التقييمات'), b(2, 'معلومات')]),
    );
  }

  Widget _body(Map p) {
    final jobs = (p['jobs'] ?? 0) as int;
    final tier = Meta.tierOfProvider(p);
    final rn = (p['rating_n'] ?? 0) as int;
    final rating = p['rating'] as num?;
    final ratePct = rating == null ? null : (rating / 5 * 100).round();
    final replyPct = p['reply_pct'] == null ? null : (p['reply_pct'] as num).toInt().clamp(0, 100);
    final avail = p['available'] == true;
    final place = '${Meta.cityName((p['city_id'] ?? '').toString())}${(p['hood'] ?? '').toString().isEmpty ? '' : ' - ${p['hood']}'}';
    Color rc(int? v) => v == null ? C.mute : (v >= 80 ? const Color(0xFF1A7F4B) : (v >= 50 ? const Color(0xFFB45309) : const Color(0xFFB42318)));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Avatar(photo: p['photo'], name: p['name'] ?? '', size: 92),
              const SizedBox(height: 4),
              SeenLabel(p: p, size: 12),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: Text(p['name'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                const SizedBox(width: 6),
                TierBadge(p: p, size: 26),
              ]),
              if (tier.isNotEmpty)
                GestureDetector(
                  onTap: () => trustSheet(context, p),
                  child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('شارة ${Meta.tierName(tier)}  ›', style: const TextStyle(color: C.blue, fontSize: 12.5, fontWeight: FontWeight.w700))),
                ),
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                _chip(Icons.circle, avail ? 'متاح الآن' : (p['off'] == 'hours' ? 'خارج وقت العمل' : 'غير متاح الآن'), avail ? C.green : C.mute),
                if (p['is_new'] == true) _chip(Icons.fiber_new_rounded, 'مستخدم جديد', C.green),
                _chip(Icons.place_rounded, place, C.blue),
                if (p['distance_km'] != null) _chip(Icons.near_me_rounded, '${p['distance_km']} كم', C.blue),
              ]),
              if ((p['bio'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(p['bio'].toString(), textAlign: TextAlign.center, style: const TextStyle(height: 1.7, color: Color(0xFF3B4A5A))),
              ],
            ]),
          ),
        ),
        if (p['state_closed'] == true) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFE9E9), borderRadius: BorderRadius.circular(14)),
            child: const Row(children: [
              Icon(Icons.block_rounded, color: C.red),
              SizedBox(width: 8),
              Expanded(child: Text('الخدمة غير متاحة حاليًا في هذه الولاية.', style: TextStyle(color: C.red, fontWeight: FontWeight.w700))),
            ]),
          ),
        ],
        if (p['off'] != null && p['state_closed'] != true) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF4DC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3D08A))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.schedule_rounded, color: Color(0xFFB45309)),
              const SizedBox(width: 8),
              Expanded(child: Text('${_offTitle(p)}. ما زال بإمكانك طلب الخدمة والاتفاق على وقت آخر، أو اختيار صنايعي متاح الآن.', style: const TextStyle(color: Color(0xFF7A3E00), height: 1.5, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _statTile(Text('$jobs', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: C.green)), 'خدمات مكتملة', jobs == 0 ? 'لم يكمل بعد' : 'مؤكدة من الطرفين'),
          const SizedBox(width: 8),
          _statTile(_ring(ratePct, rc(ratePct)), 'التقييم', rating != null ? 'من $rn تقييم' : (rn > 0 ? '$rn من 3 تقييمات لعرض النسبة' : 'بلا تقييمات بعد')),
          const SizedBox(width: 8),
          _statTile(_ring(replyPct, rc(replyPct)), 'سرعة الرد', replyPct != null ? 'يردّ خلال 15 دقيقة' : 'تظهر بعد 3 طلبات'),
        ]),
        const SizedBox(height: 14),
        _tabs(rn),
        const SizedBox(height: 12),
        if (_tab == 0) _worksTab(p),
        if (_tab == 1) _reviewsTab(p, ratePct, rc(ratePct)),
        if (_tab == 2) _infoTab(p),
        const SizedBox(height: 70),
      ]),
    );
  }

  /// تبويب الأعمال: الخدمات المنجزة لكل مهارة ثم آخر الأعمال
  Widget _worksTab(Map p) {
    final sj = (p['svc_jobs'] as Map?) ?? {};
    final list = (p['services'] as List).map((e) => e.toString()).toList();
    list.sort((a, b) => ((sj[b] ?? 0) as int).compareTo((sj[a] ?? 0) as int));
    final maxN = list.fold<int>(1, (m, id) => ((sj[id] ?? 0) as int) > m ? (sj[id] as int) : m);
    final history = (p['history'] as List?) ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('المهارات والخدمات المنجزة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 8),
      for (final id in list)
        Builder(builder: (_) {
          final s = Meta.service(id);
          final n = (sj[id] ?? 0) as int;
          final col = Color(Meta.cat(s?.cat ?? 'other').color);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: n > 0 ? col.withOpacity(.35) : C.hair)),
            child: Row(children: [
              CircleAvatar(radius: 22, backgroundColor: col.withOpacity(.12), child: Text(s?.icon ?? '🔧', style: const TextStyle(fontSize: 22))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Meta.serviceName(id), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: n == 0 ? 0 : (n / maxN).clamp(.08, 1).toDouble(), minHeight: 6, borderRadius: BorderRadius.circular(6), color: col, backgroundColor: col.withOpacity(.12)),
                ]),
              ),
              const SizedBox(width: 12),
              Column(children: [
                Text('$n', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: n > 0 ? C.green : C.mute)),
                Text(n > 0 ? 'مكتملة' : 'لم تُسجَّل', style: const TextStyle(fontSize: 11, color: C.mute)),
              ]),
            ]),
          );
        }),
      const SizedBox(height: 10),
      const Text('آخر الأعمال', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 8),
      if (history.isEmpty) const Text('لا توجد أعمال بعد', style: TextStyle(color: C.mute)) else _historyGrid(history),
    ]);
  }

  /// تبويب التقييمات: ملخص ثم آخر الآراء
  Widget _reviewsTab(Map p, int? pct, Color col) {
    final reviews = (p['reviews'] as List?) ?? [];
    final ok = (p['ok'] ?? 0) as int, fail = (p['fail'] ?? 0) as int;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            _ring(pct, col, size: 62),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pct != null ? 'رضا العملاء $pct%' : 'لا توجد نسبة بعد', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text(pct != null ? 'محسوبة من متوسط تقييمات العملاء (من 5 نجوم).' : 'تظهر النسبة بعد 3 تقييمات على الأقل، حتى تكون عادلة.', style: const TextStyle(color: C.mute, fontSize: 12, height: 1.5)),
                const SizedBox(height: 6),
                Text('خدمات نجحت: $ok · لم تنجح: $fail', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      if (reviews.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('لا توجد آراء بعد. التقييم اختياري ويضيفه الزبون بعد الخدمة.', style: TextStyle(color: C.mute, height: 1.6))),
      for (final r in reviews)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.hair)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (r['stars'] != null) ...List.generate(5, (i) => Icon(i < (r['stars'] as num) ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: const Color(0xFFF5A623))),
              if (r['stars'] == null) const Text('بلا تقييم بالنجوم', style: TextStyle(color: C.mute, fontSize: 12)),
              const Spacer(),
              Icon(r['success'] == true ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: r['success'] == true ? C.green : C.red),
              const SizedBox(width: 4),
              Text(r['success'] == true ? 'خدمة ناجحة' : 'لم تنجح', style: TextStyle(fontSize: 12, color: r['success'] == true ? C.green : C.red, fontWeight: FontWeight.w700)),
            ]),
            if ((r['comment'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(r['comment'].toString(), style: const TextStyle(height: 1.6))),
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(_date(r['ts'] as int), style: const TextStyle(fontSize: 11, color: C.mute))),
          ]),
        ),
      if (reviews.isNotEmpty) const Text('تُعرض آخر 5 آراء.', textAlign: TextAlign.center, style: TextStyle(color: C.mute, fontSize: 11.5)),
    ]);
  }

  Widget _infoTab(Map p) => Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            _kv('الحالة', p['available'] == true ? 'متاح الآن' : (p['off'] == 'hours' ? 'خارج وقت العمل' : 'غير متاح الآن')),
            _kv('المنطقة', '${Meta.cityName((p['city_id'] ?? '').toString())}${(p['hood'] ?? '').toString().isEmpty ? '' : ' - ${p['hood']}'}'),
            if (p['distance_km'] != null) _kv('المسافة', '${p['distance_km']} كم'),
            _kv('ساعات العمل', 'من ${t12(p['from'])} إلى ${t12(p['to'])}'),
            _kv('الخبرة', '${p['experience']} سنة'),
            if (priceText(p).isNotEmpty) _kv('السعر', priceText(p)),
            if (priceText(p).isNotEmpty) const Padding(padding: EdgeInsets.only(top: 2, bottom: 4, left: 8, right: 8), child: Text('السعر النهائي يُتفق عليه مع الصنايعي بعد معرفة حجم الخدمة، ويكون ضمن هذا النطاق.', style: TextStyle(color: C.mute, fontSize: 12, height: 1.5))),
            if (p['age'] != null) _kv('العمر', '${p['age']} سنة'),
          ]),
        ),
      );

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
