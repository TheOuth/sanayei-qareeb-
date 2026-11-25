import 'package:flutter/material.dart';
import '../core.dart';
import '../push.dart';
import '../theme.dart';
import '../widgets.dart';
import 'app_drawer.dart';
import 'dashboard.dart';
import 'commission.dart';
import 'my_profile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List? _items;
  Object? _err;
  final Set<String> _sel = {};
  bool _selecting = false;

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

  void _exitSel() => setState(() { _selecting = false; _sel.clear(); });

  Future<void> _delete() async {
    if (_sel.isEmpty) return;
    final all = _items != null && _sel.length == _items!.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('حذف الرسائل'),
        content: Text(all ? 'سيتم حذف كل الرسائل المعروضة (${_sel.length}). لا يمكن التراجع.' : 'سيتم حذف ${_sel.length} رسالة. لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: C.red), onPressed: () => Navigator.pop(dctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.rpc('delete_notifications', {'p_id': Store.pid, 'p_token': Store.token, 'p_ids': _sel.toList()});
      _exitSel();
      await _load();
      Store.refreshUnread();
      if (mounted) toast(context, 'تم الحذف');
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  PreferredSizeWidget _appBar() {
    if (!_selecting) {
      return bar('الرسائل', bell: false, actions: [
        if (_items != null && _items!.isNotEmpty) IconButton(tooltip: 'تحديد', icon: const Icon(Icons.checklist_rounded), onPressed: () => setState(() => _selecting = true)),
      ]);
    }
    final total = _items?.length ?? 0;
    final allOn = total > 0 && _sel.length == total;
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'إلغاء التحديد', onPressed: _exitSel),
      title: Text(_sel.isEmpty ? 'حدد الرسائل' : 'تم تحديد ${_sel.length}'),
      actions: [
        IconButton(
          tooltip: allOn ? 'إلغاء تحديد الكل' : 'تحديد الكل',
          icon: Icon(allOn ? Icons.deselect_rounded : Icons.select_all_rounded),
          onPressed: () => setState(() {
            if (allOn) {
              _sel.clear();
            } else {
              _sel..clear()..addAll(_items!.map((e) => (e as Map)['id'].toString()));
            }
          }),
        ),
        IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete_outline_rounded), onPressed: _sel.isEmpty ? null : _delete),
      ],
    );
  }

  /// أيقونة الرسالة: صورة الشارة نفسها لإشعارات الشارات
  Widget _leading(String k) {
    final parts = k.split(':');
    final base = parts[0];
    final tier = parts.length > 1 ? parts[1] : '';
    if ((base == 'badge' || base == 'badge_down') && ['gray', 'green', 'blue', 'gold'].contains(tier)) {
      final img = Image.asset('assets/badges/badge-$tier.png', width: 40, height: 40);
      if (base == 'badge') return img;
      return SizedBox(width: 44, height: 44, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        img,
        const Positioned(bottom: -3, left: -3, child: CircleAvatar(radius: 10, backgroundColor: C.red, child: Icon(Icons.arrow_downward_rounded, size: 13, color: Colors.white))),
      ]));
    }
    if (base == 'badge_down') return CircleAvatar(backgroundColor: C.red.withOpacity(.12), child: const Icon(Icons.trending_down_rounded, color: C.red));
    return CircleAvatar(backgroundColor: _color(base).withOpacity(.12), child: Icon(_icon(base), color: _color(base)));
  }

  /// الضغط على رسالة مرتبطة بقسم ينقلك إليه؛ التنبيهات العامة لا تنقل إلى مكان
  VoidCallback? _target(String k) {
    final base = k.split(':')[0];
    switch (base) {
      case 'commission':
        return () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommissionScreen()));
      case 'completed':
      case 'request':
      case 'confirm':
      case 'review':
        return () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      case 'badge':
      case 'badge_down':
      case 'account':
        return () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen()));
      case 'service':
      case 'verify':
        return () => openEditProfile(context);
      default:
        return null;
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
        'commission' => Icons.account_balance_wallet_rounded,
        'completed' => Icons.celebration_rounded,
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
        'commission' => const Color(0xFFE67E22),
        'completed' => C.green,
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
      appBar: _appBar(),
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
                          final down = k.startsWith('badge_down');
                          final id = n['id'].toString();
                          final picked = _sel.contains(id);
                          void toggle() => setState(() { _selecting = true; picked ? _sel.remove(id) : _sel.add(id); });
                          return Container(
                            decoration: BoxDecoration(
                              color: picked ? const Color(0xFFFDE8E8) : (unread ? (down ? const Color(0xFFFFEDED) : const Color(0xFFE3F0FD)) : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: picked ? C.red.withOpacity(.5) : (unread ? (down ? C.red.withOpacity(.35) : C.blue.withOpacity(.4)) : C.hair)),
                            ),
                            child: ListTile(
                              leading: _selecting
                                  ? Checkbox(value: picked, onChanged: (_) => toggle())
                                  : _leading(k),
                              onLongPress: toggle,
                              title: Text((n['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text((n['body'] ?? '').toString(), style: const TextStyle(height: 1.45)),
                                  const SizedBox(height: 4),
                                  Text(_ago(n['ts'] as int), style: const TextStyle(fontSize: 11, color: C.mute)),
                                ]),
                              ),
                              onTap: _selecting ? toggle : _target(k),
                              trailing: (!_selecting && _target(k) != null) ? const Icon(Icons.chevron_left_rounded, color: C.mute) : null,
                            ),
                          );
                        },
                      ),
                    );
    });
  }
}
