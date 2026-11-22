import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';
import 'profile_form.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map? _me;
  List _reqs = [];
  Object? _err;

  String get _id => Store.pid!;
  String get _tk => Store.token!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await Api.rpc('provider_self', {'p_id': _id, 'p_token': _tk});
      List rq = [];
      try {
        if (me['status'] == 'approved') rq = await Api.rpc('provider_requests', {'p_id': _id, 'p_token': _tk}) as List;
      } catch (_) {}
      Store.setMe((me['name'] ?? '').toString(), (me['photo'] ?? '').toString());
      if (mounted) setState(() { _me = me as Map; _reqs = rq; _err = null; });
    } catch (e) {
      if (e is ApiError && e.code == 'forbidden') {
        await Store.signOut();
        if (mounted) Navigator.pop(context);
        return;
      }
      if (mounted) setState(() => _err = e);
    }
  }

  Future<void> _toggle(bool v) async {
    try {
      await Api.rpc('set_available', {'p_id': _id, 'p_token': _tk, 'p_value': v});
      _load();
    } catch (e) {
      toast(context, errMsg(e));
    }
  }

  Future<void> _confirm(Map r) async {
    final amount = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('هل تمت الخدمة؟'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${Meta.serviceName((r['service'] ?? '').toString())} — ${r['channel'] == 'call' ? 'اتصال' : 'واتساب'}'),
          const SizedBox(height: 10),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المتفق عليه (جنيه)')),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _send(r, false, null);
            },
            child: const Text('لم تتم'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _send(r, true, num.tryParse(amount.text.trim()));
            },
            child: const Text('تمت'),
          ),
        ],
      ),
    );
  }

  Future<void> _send(Map r, bool done, num? amt) async {
    try {
      await Api.rpc('provider_confirm_request', {'p_id': _id, 'p_token': _tk, 'p_request': r['id'], 'p_done': done, 'p_amount': amt});
      _load();
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  Future<void> _logout() async {
    await Store.signOut();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الحساب نهائيًا؟'),
        content: const Text('سيُحذف ملفك وكل بياناتك ولا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: C.red), onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.rpc('delete_provider', {'p_id': _id, 'p_token': _tk});
      await Store.signOut();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return Scaffold(
      drawer: const AppDrawer(current: 'dash'),
      appBar: bar('لوحتي', actions: [IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _logout)]),
      body: _err != null
          ? ErrorRetry(_err!, _load)
          : me == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: _load, child: _body(me)),
    );
  }

  Widget _body(Map me) {
    final status = (me['status'] ?? '').toString();
    final jobs = (me['jobs'] ?? 0) as int;
    final tier = Meta.tierOf(jobs);
    final next = jobs >= 25 ? null : (jobs >= 10 ? 25 : (jobs >= 3 ? 10 : 3));
    final pending = _reqs.where((r) => r['confirm'] == null && r['client'] == 'done').toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Avatar(photo: me['photo'], name: me['name'] ?? '', size: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Flexible(child: Text(me['name'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))), const SizedBox(width: 6), TierBadge(jobs: jobs, size: 22)]),
                Text('اكتمال الملف ${me['pct']}%', style: const TextStyle(color: C.mute, fontSize: 12)),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => _EditScreen(me: me)));
                _load();
              },
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      if (me['birth_date'] == null)
        Card(color: const Color(0xFFFFF4D6), child: const Padding(padding: EdgeInsets.all(12), child: Text('أضف تاريخ ميلادك الحقيقي من "تعديل" (مطلوب 18+).'))),
      if (status == 'pending')
        Card(color: const Color(0xFFE3F0FD), child: const Padding(padding: EdgeInsets.all(14), child: Text('حسابك قيد المراجعة. سنتواصل معك على الواتساب للتحقق ثم يظهر ملفك للزبائن.', style: TextStyle(height: 1.5))))
      else if (status != 'approved')
        Card(color: const Color(0xFFFFE3E3), child: Padding(padding: const EdgeInsets.all(14), child: Text('حسابك غير مفعّل حاليًا ($status). تواصل مع الدعم.'))),
      if (status == 'approved') ...[
        Card(
          child: SwitchListTile(
            value: me['flag'] == true,
            onChanged: _toggle,
            title: const Text('أنا متاح الآن', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(me['available'] == true ? 'ملفك ظاهر للزبائن' : (me['flag'] == true ? 'خارج ساعات العمل (${me['from']} - ${me['to']})' : 'غير ظاهر في القوائم')),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (tier.isNotEmpty) Image.asset('assets/badges/badge-$tier.png', width: 34, height: 34),
                const SizedBox(width: 8),
                Expanded(child: Text(tier.isEmpty ? 'لم تحصل على شارة بعد' : 'شارة ${Meta.tierName(tier)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('$jobs عمل مؤكد'),
              ]),
              if (next != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: (jobs / next).clamp(0, 1).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(6)),
                const SizedBox(height: 4),
                Text('باقي ${next - jobs} للشارة التالية', style: const TextStyle(color: C.mute, fontSize: 12)),
              ],
              const SizedBox(height: 6),
              Text('يُحتسب العمل عندما يؤكد العميل ثم تؤكد أنت. تُحصَّل عمولة ثابتة ${Config.commissionNote} جنيه عن كل عمل مؤكد.', style: const TextStyle(color: C.mute, fontSize: 12, height: 1.4)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 16),
        Text('الطلبات (آخر 60 يومًا) — ${me['requests_week']} هذا الأسبوع', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (pending.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${pending.length} طلب أكّد العميل إتمامه وينتظر تأكيدك', style: const TextStyle(color: C.blue, fontWeight: FontWeight.w600))),
        if (_reqs.isEmpty) const Text('لا توجد طلبات بعد', style: TextStyle(color: C.mute)),
        for (final r in _reqs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                title: Text(Meta.serviceName((r['service'] ?? '').toString())),
                subtitle: Text('${r['channel'] == 'call' ? 'اتصال' : 'واتساب'} · ${_ago(r['ts'] as int)}\nالعميل: ${_cs(r['client'])}${r['confirm'] == null ? '' : ' · أنت: ${r['confirm'] == 'done' ? 'تمت' : 'لم تتم'}'}'),
                isThreeLine: true,
                trailing: r['confirm'] == null ? FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 36)), onPressed: () => _confirm(r), child: const Text('أكّد')) : null,
              ),
            ),
          ),
      ],
      const SizedBox(height: 20),
      OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: C.red), onPressed: _delete, child: const Text('حذف حسابي')),
      const SizedBox(height: 30),
    ]);
  }

  String _cs(dynamic s) => const {'new': 'لم يؤكد', 'done': 'تمت الخدمة', 'failed': 'لم تنجح', 'not_agreed': 'لم نتفق'}[s] ?? '$s';
  String _ago(int ts) {
    final m = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts)).inMinutes;
    if (m < 60) return 'قبل ${m < 1 ? 1 : m} دقيقة';
    if (m < 1440) return 'قبل ${m ~/ 60} ساعة';
    return 'قبل ${m ~/ 1440} يوم';
  }
}

class _EditScreen extends StatefulWidget {
  final Map me;
  const _EditScreen({required this.me});
  @override
  State<_EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<_EditScreen> {
  late String _user = (widget.me['username'] ?? '').toString();
  late bool _changed = widget.me['username_changed'] == true;

  String get _link => '${Config.siteUrl}/#/u/$_user';

  Future<void> _rename() async {
    final c = TextEditingController(text: _user);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير اسم المستخدم'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('يمكن تغييره مرة واحدة فقط. حروف إنجليزية وأرقام، يبدأ بحرف.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          TextField(controller: c, textDirection: TextDirection.ltr),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final r = await Api.rpc('set_username', {'p_id': Store.pid, 'p_token': Store.token, 'p_username': c.text.trim()});
                if (mounted) setState(() { _user = r.toString(); _changed = true; });
              } catch (e) {
                if (mounted) toast(context, errMsg(e));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Widget _box() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFE3F0FD), borderRadius: BorderRadius.circular(16), border: Border.all(color: C.blue.withOpacity(.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('رابط ملفك واسم المستخدم', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('@$_user', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.blue)),
            const SizedBox(height: 4),
            Text(_link, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12, color: C.mute)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _link));
                if (mounted) toast(context, 'تم نسخ الرابط');
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('نسخ'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => Share.share('${widget.me['name']} على صنايعي قريب\n$_link'),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('مشاركة'),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _changed
              ? const Text('تم استخدام تغيير الاسم. للتعديل تواصل مع الدعم.', style: TextStyle(fontSize: 12, color: C.mute))
              : TextButton.icon(onPressed: _rename, icon: const Icon(Icons.edit_rounded, size: 16), label: const Text('تغيير اسم المستخدم (مرة واحدة)')),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar('تعديل الملف', menu: false),
      body: ProfileForm(
        isRegister: false,
        initial: widget.me,
        header: _box(),
        onSubmit: (body) async {
          await Api.rpc('update_profile', {'p_id': Store.pid, 'p_token': Store.token, 'p': body});
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}
