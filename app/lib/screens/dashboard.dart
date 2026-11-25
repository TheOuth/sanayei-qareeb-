import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';
import 'profile_form.dart';
import 'delete_account.dart';
import 'commission.dart';
import 'banned.dart';

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

  Future<void> _remind(Map r) async {
    try {
      final res = await Api.rpc('provider_remind_client', {'p_id': _id, 'p_token': _tk, 'p_request': r['id']});
      final st = res is Map ? (res['state'] ?? '').toString() : '';
      if (!mounted) return;
      toast(context, res is Map && res['ok'] == true ? 'أرسلنا تذكيرًا للزبون' : (st == 'too_soon' ? 'ذكّرته مؤخرًا. جرّب بعد عدة ساعات' : 'الطلب مغلق'));
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
      appBar: bar('لوحة الخدمات'),
      body: _err != null
          ? ErrorRetry(_err!, _load)
          : me == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: _load, child: _body(me)),
    );
  }

  bool _finished(Map r) {
    final cl = (r['client'] ?? 'new').toString();
    final pc = r['confirm']?.toString();
    return (cl == 'done' && pc == 'done') || cl == 'failed' || cl == 'not_agreed' || pc == 'not_done';
  }

  Widget _tip(IconData i, String t, {Color c = C.mute}) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 15, color: c),
          const SizedBox(width: 6),
          Expanded(child: Text(t, style: TextStyle(color: c, fontSize: 12.5, height: 1.5))),
        ]),
      );

  Widget _stat(IconData i, Color c, String n, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(color: c.withOpacity(.09), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Icon(i, color: c, size: 22),
            const SizedBox(height: 4),
            Text(n, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c)),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: C.mute, height: 1.3)),
          ]),
        ),
      );

  Widget _section(IconData i, Color c, String title, int count) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Row(children: [
          Icon(i, size: 19, color: c),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          ],
        ]),
      );

  /// لوحة الخدمات: الطلبات والعمولة فقط. الهوية والشارة والإعدادات في «ملفي».
  Widget _body(Map me) {
    final status = (me['status'] ?? '').toString();
    if (status == 'banned') return const BannedView();
    final jobs = (me['jobs'] ?? 0) as int;
    final fresh = _reqs.where((r) => r['accept'] == 'pending').toList();
    final active = _reqs.where((r) => r['accept'] == 'accepted' && !_finished(r)).toList();
    final history = _reqs.where((r) => r['accept'] != 'pending' && !(r['accept'] == 'accepted' && !_finished(r))).toList();
    final waitingMe = active.where((r) => r['confirm'] == null && r['client'] == 'done').length;
    final visible = me['available'] == true;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Avatar(photo: me['photo'], name: me['name'] ?? '', size: 46),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('أهلًا ${shortName((me['name'] ?? '').toString())} 👋', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            if (status == 'approved')
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen())).then((_) => _load()),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    Icon(Icons.circle, size: 9, color: visible ? C.green : C.mute),
                    const SizedBox(width: 5),
                    Text(visible ? 'ملفك ظاهر للزبائن' : 'ملفك غير ظاهر — غيّر حالتك من «ملفي»', style: TextStyle(color: visible ? C.green : const Color(0xFFB45309), fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
        ),
        if (me['reply_pct'] != null) ReplyRing(p: me, size: 42),
      ]),
      const SizedBox(height: 14),
      if (status == 'pending')
        Card(color: const Color(0xFFE3F0FD), child: const Padding(padding: EdgeInsets.all(14), child: Text('حسابك قيد المراجعة. سنتواصل معك على الواتساب للتحقق ثم يظهر ملفك للزبائن.', style: TextStyle(height: 1.5))))
      else if (status != 'approved')
        Card(color: const Color(0xFFFFE3E3), child: const Padding(padding: EdgeInsets.all(14), child: Text('حسابك غير مفعّل حاليًا. تواصل مع الدعم.'))),
      if (status == 'approved' && ((me['commission_due'] ?? 0) as num) > 0) ...[
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const CommissionScreen()));
            _load();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFFF1E0), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF2B36B))),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFE67E22)),
              const SizedBox(width: 10),
              Expanded(child: Text('عمولة مستحقة ${((me['commission_due'] as num).round())} جنيه — اضغط لعرض رسالة الإدارة وإرسال الإشعار', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5, color: Color(0xFF7A4300)))),
              const Icon(Icons.chevron_left_rounded, color: Color(0xFFE67E22)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (status == 'approved') ...[
        Row(children: [
          _stat(Icons.notifications_active_rounded, const Color(0xFFE67E22), '${fresh.length}', 'طلبات جديدة'),
          const SizedBox(width: 8),
          _stat(Icons.handyman_rounded, C.blue, '${active.length}', 'قيد التنفيذ'),
          const SizedBox(width: 8),
          _stat(Icons.verified_rounded, C.green, '$jobs', 'خدمات مكتملة'),
        ]),
        const SizedBox(height: 8),
        const SafetyNote(provider: true),
        _section(Icons.notifications_active_rounded, const Color(0xFFE67E22), 'طلبات جديدة', fresh.length),
        _tip(Icons.lightbulb_outline_rounded, 'اقبل أو اعتذر بسرعة. تنتهي مهلة الطلب بعد ساعتين، وسرعة ردك تظهر للزبائن وتزيد ظهورك.'),
        if (fresh.isEmpty) const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('لا توجد طلبات جديدة الآن. تأكد أن حالتك «متاح الآن» من «ملفي».', style: TextStyle(color: C.mute, height: 1.5))),
        for (final r in fresh) _reqCard(r),
        _section(Icons.handyman_rounded, C.blue, 'قيد التنفيذ', active.length),
        _tip(Icons.lightbulb_outline_rounded, waitingMe > 0 ? '$waitingMe خدمة أكّد الزبون إنجازها وتنتظر تأكيدك لتُضاف إلى ملفك.' : 'بعد إنهاء الخدمة أكّدها هنا. لا تُحتسب لك ولشارتك إلا بتأكيد الطرفين.', c: waitingMe > 0 ? C.blue : C.mute),
        if (active.isEmpty) const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('لا توجد خدمات جارية.', style: TextStyle(color: C.mute))),
        for (final r in active) _reqCard(r),
        if (history.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('السجل (${history.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              subtitle: const Text('آخر 60 يومًا: المكتملة والمعتذَر عنها والمنتهية', style: TextStyle(fontSize: 12)),
              children: [for (final r in history) _reqCard(r)],
            ),
          ),
      ],
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
      final cl = (r['client'] ?? 'new').toString();
      final pc = r['confirm']?.toString();
      final complete = cl == 'done' && pc == 'done';
      final closed = cl == 'failed' || cl == 'not_agreed' || pc == 'not_done';
      String help;
      Color hc = C.mute;
      if (complete) {
        help = 'خدمة مكتملة ✓ أُضيفت إلى ملفك وتُحتسب في شارتك.';
        hc = C.green;
      } else if (closed) {
        help = cl == 'not_agreed' ? 'أغلق الزبون الطلب (لم تتفقا).' : 'لم تُحتسب هذه الخدمة.';
      } else if (pc == null) {
        help = cl == 'done' ? 'الزبون أكّد إنجاز الخدمة. أكّدها أنت الآن لتُضاف إلى ملفك.' : 'أنجزت الخدمة؟ أكّدها الآن. لا تُحتسب لك إلا بتأكيد الطرفين.';
        hc = C.blue;
      } else {
        help = 'بانتظار تأكيد الزبون. الخدمة لا تُضاف إلى ملفك وشارتك حتى يؤكد.';
        hc = const Color(0xFFB45309);
      }
      Widget step(String who, bool ok, bool no) => Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ok ? Icons.check_circle_rounded : (no ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded), size: 18, color: ok ? C.green : (no ? C.red : C.mute)),
            const SizedBox(width: 4),
            Text(who, style: TextStyle(fontSize: 12.5, color: ok ? C.green : C.mute, fontWeight: FontWeight.w600)),
          ]);
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: title), Text(_ago(r['ts'] as int), style: const TextStyle(color: C.mute, fontSize: 12))]),
        const SizedBox(height: 6),
        Wrap(spacing: 14, runSpacing: 4, children: [
          step('الزبون: ${cl == 'done' ? 'أكّد' : (cl == 'new' ? 'لم يؤكد' : _cs(cl))}', cl == 'done', cl == 'failed' || cl == 'not_agreed'),
          step('أنت: ${pc == 'done' ? 'أكّدت' : (pc == 'not_done' ? 'لم تتم' : 'لم تؤكد')}', pc == 'done', pc == 'not_done'),
        ]),
        const SizedBox(height: 6),
        Text(help, style: TextStyle(color: hc, fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w600)),
        if (!complete && !closed) ...[
          const SizedBox(height: 8),
          Row(children: [
            if (pc == null) Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => _confirm(r), child: const Text('أكّدت إنجاز الخدمة'))),
            if (pc == 'done' && cl == 'new') Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => _remind(r), icon: const Icon(Icons.notifications_active_outlined, size: 18), label: const Text('ذكّر الزبون بالتأكيد'))),
          ]),
        ],
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
