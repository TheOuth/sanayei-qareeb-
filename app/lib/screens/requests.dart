import 'dart:async';
import 'package:flutter/material.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';
import 'provider.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  List? _items;
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
      if (mounted) setState(() => _items = r as List);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: 'requests'),
      appBar: bar('طلباتي'),
      body: _err != null
          ? ErrorRetry(_err!, _load)
          : _items == null
              ? const Center(child: CircularProgressIndicator())
              : _items!.isEmpty
                  ? const Empty('ما عندك طلبات بعد. افتح صنايعي واضغط "طلب الخدمة"', icon: Icons.history_rounded)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _items!.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => i == 0 ? const SafetyNote() : _card(_items![i - 1] as Map),
                      ),
                    ),
    );
  }
}
