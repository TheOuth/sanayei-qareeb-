import 'package:flutter/material.dart';
import '../core.dart';
import '../push.dart';
import '../theme.dart';
import '../widgets.dart';
import 'app_drawer.dart';
import 'dashboard.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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
      final r = await Api.rpc('provider_notifications', {'p_id': Store.pid, 'p_token': Store.token, 'p_mark': true});
      Store.unread.value = 0;
      if (mounted) setState(() => _items = (r['items'] as List));
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  IconData _icon(String k) => switch (k) {
        'request' => Icons.call_received_rounded,
        'confirm' => Icons.task_alt_rounded,
        'review' => Icons.star_rounded,
        'badge' => Icons.workspace_premium_rounded,
        'verify' => Icons.verified_rounded,
        'account' => Icons.manage_accounts_rounded,
        'broadcast' => Icons.campaign_rounded,
        'service' => Icons.handyman_rounded,
        _ => Icons.mail_rounded,
      };

  Color _color(String k) => switch (k) {
        'request' => C.blue,
        'confirm' => C.green,
        'review' => C.gold,
        'badge' => C.gold,
        'verify' => C.blue,
        'account' => C.navy,
        'service' => C.blue,
        _ => const Color(0xFF6D5BEF),
      };

  String _ago(int ts) {
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (d.inMinutes < 1) return 'الآن';
    if (d.inMinutes < 60) return 'قبل ${d.inMinutes} دقيقة';
    if (d.inHours < 24) return 'قبل ${d.inHours} ساعة';
    return 'قبل ${d.inDays} يوم';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: 'home'),
      appBar: bar('الرسائل', bell: false),
      body: Column(children: [
        ValueListenableBuilder<bool>(
          valueListenable: Push.allowed,
          builder: (_, ok, __) => ok
              ? const SizedBox.shrink()
              : Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFFFF4DC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3D08A))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [Icon(Icons.notifications_off_rounded, color: Color(0xFFB45309)), SizedBox(width: 8), Expanded(child: Text('الإشعارات متوقفة', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7A3E00))))]),
                    const SizedBox(height: 6),
                    const Text('فعّل الإشعارات لتصلك طلبات الزبائن ورسائل الإدارة فور وصولها، وإلا قد تفوتك أعمال.', style: TextStyle(height: 1.6, color: Color(0xFF7A3E00))),
                    const SizedBox(height: 10),
                    FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB45309)), onPressed: Push.enable, icon: const Icon(Icons.notifications_active_rounded, size: 18), label: const Text('تفعيل الإشعارات')),
                  ]),
                ),
        ),
        Expanded(child: _content()),
      ]),
    );
  }

  Widget _content() {
    return Builder(builder: (context) {
      return _err != null
          ? ErrorRetry(_err!, _load)
          : _items == null
              ? const Center(child: CircularProgressIndicator())
              : _items!.isEmpty
                  ? const Empty('لا توجد رسائل حتى الآن. ستصلك هنا الطلبات والتقييمات ورسائل الإدارة', icon: Icons.notifications_none_rounded)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final n = _items![i] as Map;
                          final k = (n['kind'] ?? '').toString();
                          final unread = n['unread'] == true;
                          return Container(
                            decoration: BoxDecoration(
                              color: unread ? const Color(0xFFE3F0FD) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: unread ? C.blue.withOpacity(.4) : C.hair),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: _color(k).withOpacity(.12), child: Icon(_icon(k), color: _color(k))),
                              title: Text((n['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text((n['body'] ?? '').toString(), style: const TextStyle(height: 1.45)),
                                  const SizedBox(height: 4),
                                  Text(_ago(n['ts'] as int), style: const TextStyle(fontSize: 11, color: C.mute)),
                                ]),
                              ),
                              onTap: (k == 'request' || k == 'confirm' || k == 'account')
                                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()))
                                  : null,
                            ),
                          );
                        },
                      ),
                    );
    });
  }
}
