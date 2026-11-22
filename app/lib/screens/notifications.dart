import 'package:flutter/material.dart';
import '../core.dart';
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
        _ => Icons.mail_rounded,
      };

  Color _color(String k) => switch (k) {
        'request' => C.blue,
        'confirm' => C.green,
        'review' => C.gold,
        'badge' => C.gold,
        'verify' => C.blue,
        'account' => C.navy,
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
      body: _err != null
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
                    ),
    );
  }
}
