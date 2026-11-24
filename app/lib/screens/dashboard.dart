import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';
import 'profile_form.dart';
import 'delete_account.dart';

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

  void _delete() {
    final me = _me ?? {};
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeleteAccountScreen(emailVerified: me['email_verified'] == true && (me['email'] ?? '').toString().isNotEmpty, email: (me['email'] ?? '').toString())));
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return Scaffold(
      drawer: const AppDrawer(current: 'dash'),
      appBar: bar('لوحتي'),
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
    final tier = Meta.tierOfProvider(me);
    final next = jobs >= 100 ? null : (jobs >= 25 ? 100 : (jobs >= 5 ? 25 : 5));
    final gs = (me['gray_status'] ?? '').toString();
    final pending = _reqs.where((r) => r['confirm'] == null && r['client'] == 'done').toList();
    final waiting = _reqs.where((r) => r['accept'] == 'pending').length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Avatar(photo: me['photo'], name: me['name'] ?? '', size: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Flexible(child: Text(me['name'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))), const SizedBox(width: 6), TierBadge(p: me, size: 22)]),
                Text('اكتمال الملف ${me['pct']}%', style: const TextStyle(color: C.mute, fontSize: 12)),
                if ((me['pct'] ?? 0) < 100 && (me['missing'] as List?)?.isNotEmpty == true)
                  Padding(padding: const EdgeInsets.only(top: 3), child: Text('ينقصك: ${(me['missing'] as List).map((k) => const {'photo': 'الصورة', 'bio': 'الوصف (20 حرفًا)', 'hood': 'الحي', 'price': 'أدنى سعر', 'price_max': 'أعلى سعر', 'experience': 'سنوات الخبرة', 'password': 'كلمة السر'}[k] ?? k).join('، ')}', style: const TextStyle(color: Color(0xFFB45309), fontSize: 12, height: 1.4))),
              ]),
            ),
            if (me['reply_pct'] != null) Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: ReplyRing(p: me, size: 42)),
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
            subtitle: Text(me['available'] == true ? 'ملفك ظاهر للزبائن' : (me['flag'] == true ? 'خارج ساعات العمل (${t12(me['from'])} - ${t12(me['to'])})' : 'غير ظاهر في القوائم')),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: InkWell(
           borderRadius: BorderRadius.circular(16),
           onTap: () => trustSheet(context, me, own: true),
           child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (tier.isNotEmpty) Image.asset('assets/badges/badge-$tier.png', width: 34, height: 34),
                const SizedBox(width: 8),
                Expanded(child: Text(tier.isEmpty ? 'لم تحصل على شارة بعد' : 'شارة ${Meta.tierName(tier)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('$jobs معاملة ناجحة'),
                const Icon(Icons.info_outline_rounded, size: 18, color: C.blue),
              ]),
              if (gs == 'pending') const Padding(padding: EdgeInsets.only(top: 8), child: Text('ملفك مكتمل ✓ وينتظر موافقة الإدارة على الشارة الرمادية.', style: TextStyle(color: C.blue, fontSize: 12.5, height: 1.4))),
              if (gs == 'none' && (me['pct'] ?? 0) < 100) const Padding(padding: EdgeInsets.only(top: 8), child: Text('أكمل ملفك 100% (الصورة، الوصف، الحي، السعر، الخبرة) لتُراجَع للحصول على الشارة الرمادية.', style: TextStyle(color: C.mute, fontSize: 12.5, height: 1.4))),
              if (next != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: (jobs / next).clamp(0, 1).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(6)),
                const SizedBox(height: 4),
                Text('باقي ${next - jobs} للشارة التالية', style: const TextStyle(color: C.mute, fontSize: 12)),
              ],
              const SizedBox(height: 6),
              Text('اضغط لمعرفة كيف تحصل على كل شارة. يُحتسب العمل عندما يؤكد العميل ثم تؤكد أنت. تُحصَّل عمولة ثابتة ${Config.commissionNote} جنيه عن كل عمل مؤكد.', style: const TextStyle(color: C.mute, fontSize: 12, height: 1.4)),
            ]),
           ),
          ),
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 16),
        Text('الطلبات (آخر 60 يومًا) — ${me['requests_week']} هذا الأسبوع', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (waiting > 0) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('$waiting طلب جديد بانتظار ردك (تنتهي مهلة الطلب بعد ساعتين)', style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700))),
        if (pending.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${pending.length} طلب أكّد العميل إتمامه وينتظر تأكيدك', style: const TextStyle(color: C.blue, fontWeight: FontWeight.w600))),
        if (_reqs.isEmpty) const Text('لا توجد طلبات بعد', style: TextStyle(color: C.mute)),
        for (final r in _reqs) _reqCard(r),
      ],
      const SizedBox(height: 20),
      OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: C.red), onPressed: _delete, child: const Text('حذف حسابي')),
      const SizedBox(height: 30),
    ]);
  }

  Future<void> _respond(Map r, bool accept) async {
    try {
      final res = await Api.rpc('provider_respond_request', {'p_id': _id, 'p_token': _tk, 'p_request': r['id'], 'p_accept': accept});
      if (mounted && res is Map) {
        if (res['ok'] == true) {
          toast(context, accept ? 'تم القبول. ظهر رقمك للزبون وسيتصل بك' : 'تم الاعتذار');
        } else {
          toast(context, res['state'] == 'expired' ? 'انتهت مهلة هذا الطلب' : 'لم يعد الطلب متاحًا');
        }
      }
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
    _load();
  }

  Widget _reqCard(Map r) {
    final acc = (r['accept'] ?? 'accepted').toString();
    final title = Text(Meta.serviceName((r['service'] ?? '').toString()), style: const TextStyle(fontWeight: FontWeight.w700));
    Widget body;
    if (acc == 'pending') {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: title), Text(_ago(r['ts'] as int), style: const TextStyle(color: C.mute, fontSize: 12))]),
        const SizedBox(height: 4),
        const Text('عميل يطلب هذه الخدمة. اقبل ليظهر له رقمك.', style: TextStyle(color: C.mute, fontSize: 12.5)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: C.green), onPressed: () => _respond(r, true), child: const Text('قبول'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton(onPressed: () => _respond(r, false), child: const Text('اعتذار'))),
        ]),
      ]);
    } else if (acc == 'accepted') {
      body = Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            title,
            const SizedBox(height: 2),
            Text('${_ago(r['ts'] as int)}\nالعميل: ${_cs(r['client'])}${r['confirm'] == null ? '' : ' · أنت: ${r['confirm'] == 'done' ? 'تمت' : 'لم تتم'}'}', style: const TextStyle(color: C.mute, fontSize: 12.5, height: 1.4)),
          ]),
        ),
        if (r['confirm'] == null) FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 36)), onPressed: () => _confirm(r), child: const Text('أكّد')),
      ]);
    } else {
      final t = const {'declined': 'اعتذرت', 'expired': 'انتهت المهلة دون رد', 'taken': 'بدأ العميل مع صنايعي آخر'}[acc] ?? acc;
      body = Row(children: [Expanded(child: title), Text('$t · ${_ago(r['ts'] as int)}', style: const TextStyle(color: C.mute, fontSize: 12))]);
    }
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(color: acc == 'pending' ? const Color(0xFFFFF8E1) : null, child: Padding(padding: const EdgeInsets.all(12), child: body)));
  }

  String _cs(dynamic s) => const {'new': 'لم يؤكد', 'done': 'تمت الخدمة', 'failed': 'لم تنجح', 'not_agreed': 'لم نتفق'}[s] ?? '$s';
  String _ago(int ts) {
    final m = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts)).inMinutes;
    if (m < 60) return 'قبل ${m < 1 ? 1 : m} دقيقة';
    if (m < 1440) return 'قبل ${m ~/ 60} ساعة';
    return 'قبل ${m ~/ 1440} يوم';
  }
}

/// يفتح شاشة تعديل الملف مباشرة (تُستخدم من الإشعارات)
Future<void> openEditProfile(BuildContext context) async {
  try {
    final me = await Api.rpc('provider_self', {'p_id': Store.pid, 'p_token': Store.token});
    if (context.mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => _EditScreen(me: Map<String, dynamic>.from(me as Map))));
  } catch (e) {
    if (context.mounted) toast(context, errMsg(e));
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
        footer: _box(),
        onSubmit: (body) async {
          await Api.rpc('update_profile', {'p_id': Store.pid, 'p_token': Store.token, 'p': body});
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}
