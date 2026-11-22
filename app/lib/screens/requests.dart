import 'package:flutter/material.dart';
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
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  String _status(String s) => const {'new': 'بانتظار تأكيدك', 'done': 'تمت الخدمة', 'failed': 'لم تنجح', 'not_agreed': 'لم نتفق'}[s] ?? s;

  Future<void> _rate(Map r) async {
    String outcome = 'done';
    int stars = 5;
    final c = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('كيف كانت الخدمة مع ${r['provider_name']}؟'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, children: [
                for (final o in const [['done', 'تمت الخدمة'], ['failed', 'لم تنجح'], ['not_agreed', 'لم نتفق']])
                  ChoiceChip(label: Text(o[1]), selected: outcome == o[0], onSelected: (_) => set(() => outcome = o[0])),
              ]),
              if (outcome != 'not_agreed') ...[
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 1; i <= 5; i++) IconButton(onPressed: () => set(() => stars = i), icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_border_rounded, color: C.gold, size: 32)),
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
                  await Api.rpc('add_review', {'p_request': r['id'], 'p_anon': Store.anon, 'p_outcome': outcome, 'p_stars': outcome == 'not_agreed' ? null : stars, 'p_comment': c.text.trim()});
                  if (mounted) toast(context, 'شكرًا لتقييمك');
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
      appBar: AppBar(title: const Text('طلباتي')),
      body: _err != null
          ? ErrorRetry(_err!, _load)
          : _items == null
              ? const Center(child: CircularProgressIndicator())
              : _items!.isEmpty
                  ? const Empty('ما عندك طلبات بعد. اتصل بصنايعي وبتظهر هنا', icon: Icons.history_rounded)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = _items![i] as Map;
                          final d = DateTime.fromMillisecondsSinceEpoch(r['ts'] as int);
                          return Card(
                            child: ListTile(
                              title: Text(r['provider_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${Meta.serviceName((r['service'] ?? '').toString())} · ${r['channel'] == 'call' ? 'اتصال' : 'واتساب'} · ${d.day}/${d.month}\n${_status(r['status'])}'),
                              isThreeLine: true,
                              trailing: r['status'] == 'new' ? FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 36)), onPressed: () => _rate(r), child: const Text('قيّم')) : null,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderScreen(id: r['provider_id']))),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
