import 'dart:async';
import 'package:flutter/material.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../sound.dart';
import '../theme.dart';
import '../widgets.dart';
import 'provider.dart';
import 'dashboard.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  List? _items;
  List _recv = [];
  int _tab = 0; // 0 طلبتها أنا، 1 وصلتني
  Object? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      final r = await Api.rpc('my_requests', {'p_anon': Store.anon});
      if (Store.loggedIn) {
        try {
          _recv = await Api.rpc('provider_requests', {'p_id': Store.pid, 'p_token': Store.token}) as List;
        } catch (_) {}
      }
      final before = _items;
      if (before != null) {
        final pend = {for (final x in before) if ((x as Map)['accept'] == 'pending') x['id']};
        if ((r as List).any((x) => pend.contains((x as Map)['id']) && x['accept'] == 'accepted')) Sfx.request();
      }
      if (mounted) setState(() => _items = r as List);
      Store.markReqsSeen(r as List);
      _timer?.cancel();
      if ((r as List).any((x) => x['accept'] == 'pending')) _timer = Timer(const Duration(seconds: 20), _load);
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _status(String s) => const {'new': 'بانتظار تأكيدك', 'done': 'تمت الخدمة', 'failed': 'لم تنجح', 'not_agreed': 'لم نتفق'}[s] ?? s;

  Future<void> _cancel(Map r) async {
    try {
      await Api.rpc('cancel_request', {'p_request': r['id'], 'p_anon': Store.anon});
      _load();
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  Future<void> _call(Map r) => openUrl('tel:${r['phone']}');

  Future<void> _wa(Map r) {
    final d = (r['whatsapp'] ?? r['phone']).toString().replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent('السلام عليكم، قبلت طلبي في تطبيق صنايعي قريب لخدمة ${Meta.serviceName((r['service'] ?? '').toString())}');
    return openUrl('https://wa.me/$d?text=$msg');
  }

  Widget _tag(String t, Color c, IconData i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 14, color: c), const SizedBox(width: 4), Text(t, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700))]),
      );

  Widget _card(Map r) {
    final d = DateTime.fromMillisecondsSinceEpoch(r['ts'] as int);
    final acc = (r['accept'] ?? 'accepted').toString();
    final st = (r['status'] ?? 'new').toString();
    Widget tag;
    List<Widget> actions = [];
    switch (acc) {
      case 'pending':
        tag = _tag('بانتظار رد الصنايعي', C.blue, Icons.hourglass_top_rounded);
        actions = [TextButton(onPressed: () => _cancel(r), child: const Text('إلغاء الطلب'))];
        break;
      case 'accepted':
        if (st == 'new') {
          tag = _tag('قبل طلبك', C.green, Icons.check_circle_rounded);
          if ((r['phone'] ?? '').toString().isNotEmpty) {
            actions = [
              FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: () => _call(r), icon: const Icon(Icons.call_rounded, size: 18), label: const Text('اتصال')),
              FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(0, 38), backgroundColor: const Color(0xFF1FA463)), onPressed: () => _wa(r), icon: const Icon(Icons.chat_rounded, size: 18), label: const Text('واتساب')),
              OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)), onPressed: () => _rate(r), child: const Text('تمت الخدمة؟ أكّد')),
            ];
          } else {
            actions = [OutlinedButton(onPressed: () => _rate(r), child: const Text('قيّم'))];
          }
        } else {
          tag = _tag(_status(st), st == 'done' ? C.green : C.mute, st == 'done' ? Icons.verified_rounded : Icons.info_outline_rounded);
        }
        break;
      case 'declined':
        tag = _tag('اعتذر الصنايعي', C.red, Icons.cancel_rounded);
        break;
      case 'expired':
        tag = _tag('انتهت المهلة دون رد', C.mute, Icons.timer_off_rounded);
        break;
      case 'taken':
        tag = _tag('بدأت مع صنايعي آخر', C.mute, Icons.swap_horiz_rounded);
        break;
      default:
        tag = _tag('ألغيت الطلب', C.mute, Icons.block_rounded);
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFF59E0B), width: 1.4)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderScreen(id: r['provider_id']))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(shortName((r['provider_name'] ?? '').toString()), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              tag,
            ]),
            const SizedBox(height: 4),
            Text('${Meta.serviceName((r['service'] ?? '').toString())} · ${d.day}/${d.month}', style: const TextStyle(color: C.mute, fontSize: 13)),
            if (actions.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: actions)],
          ]),
        ),
      ),
    );
  }

  Future<void> _rate(Map r) async {
    String outcome = 'done';
    int stars = 0;
    final c = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('كيف كانت الخدمة مع ${shortName((r['provider_name'] ?? '').toString())}؟'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, children: [
                for (final o in const [['done', 'تمت الخدمة'], ['failed', 'لم تنجح'], ['not_agreed', 'لم نتفق']])
                  ChoiceChip(label: Text(o[1]), selected: outcome == o[0], onSelected: (_) => set(() => outcome = o[0])),
              ]),
              if (outcome != 'not_agreed') ...[
                const SizedBox(height: 12),
                const Text('التقييم اختياري', style: TextStyle(color: C.mute, fontSize: 12)),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 1; i <= 5; i++) IconButton(onPressed: () => set(() => stars = stars == i ? 0 : i), icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_border_rounded, color: C.gold, size: 32)),
                ]),
                TextField(controller: c, maxLines: 2, decoration: const InputDecoration(hintText: 'تعليق (اختياري)')),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await Api.rpc('add_review', {'p_request': r['id'], 'p_anon': Store.anon, 'p_outcome': outcome, 'p_stars': (outcome == 'not_agreed' || stars == 0) ? null : stars, 'p_comment': c.text.trim()});
                  if (mounted) toast(context, 'شكرًا لك');
                  _load();
                } catch (e) {
                  if (mounted) toast(context, errMsg(e));
                }
              },
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recvCard(Map r) {
    final d = DateTime.fromMillisecondsSinceEpoch(r['ts'] as int);
    final acc = (r['accept'] ?? 'accepted').toString();
    final cl = (r['client'] ?? 'new').toString();
    final pc = r['confirm']?.toString();
    Widget tag;
    if (acc == 'pending') {
      tag = _tag('بانتظار ردك', C.blue, Icons.hourglass_top_rounded);
    } else if (acc == 'accepted') {
      if (cl == 'done' && pc == 'done') {
        tag = _tag('خدمة مكتملة', C.green, Icons.verified_rounded);
      } else if (cl == 'failed' || cl == 'not_agreed' || pc == 'not_done') {
        tag = _tag('لم تُحتسب', C.mute, Icons.info_outline_rounded);
      } else {
        tag = _tag('قبلتَه، بانتظار التأكيد', C.green, Icons.check_circle_rounded);
      }
    } else if (acc == 'declined') {
      tag = _tag('اعتذرت', C.red, Icons.cancel_rounded);
    } else {
      tag = _tag('انتهى', C.mute, Icons.timer_off_rounded);
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.green, width: 1.4)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openPage('dashboard', () => const DashboardScreen()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Meta.serviceName((r['service'] ?? '').toString()), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text('طلب وصلك · ${d.day}/${d.month}', style: const TextStyle(color: C.mute, fontSize: 13)),
            ])),
            tag,
          ]),
        ),
      ),
    );
  }

  Widget _seg(int i, String t, int n, Color c) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: _tab == i ? c.withOpacity(.14) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: _tab == i ? c : C.hair)),
            child: Text('$t ($n)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: _tab == i ? c : C.mute)),
          ),
        ),
      );

  Widget _list(List items, Widget Function(Map) card, String empty) {
    if (items.isEmpty) return Empty(empty, icon: Icons.history_rounded);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => card(items[i] as Map),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: 'requests'),
      appBar: bar('طلباتي'),
      body: _err != null
          ? ErrorRetry(_err!, _load)
          : _items == null
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 8), child: SafetyNote()),
                  if (Store.loggedIn)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(children: [
                        _seg(0, 'طلبتها أنا', _items!.length, const Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        _seg(1, 'وصلتني', _recv.length, C.green),
                      ]),
                    ),
                  Expanded(
                    child: (Store.loggedIn && _tab == 1)
                        ? _list(_recv, _recvCard, 'لا توجد طلبات وصلتك بعد')
                        : _list(_items!, _card, 'ما عندك طلبات بعد. افتح صنايعي واضغط "طلب الخدمة"'),
                  ),
                ]),
    );
  }
}
