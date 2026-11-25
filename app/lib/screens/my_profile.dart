import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';
import 'dashboard.dart';
import 'delete_account.dart';
import 'banned.dart';
import 'provider.dart';

/// ملفي: الهوية والإعدادات (الحالة، الشارة، تعديل الملف، الرابط). أما الخدمات والطلبات ففي «لوحة الخدمات».
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});
  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  Map? _me;
  Object? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await Api.rpc('provider_self', {'p_id': Store.pid, 'p_token': Store.token});
      Store.setMe((me['name'] ?? '').toString(), (me['photo'] ?? '').toString());
      if (mounted) setState(() { _me = me as Map; _err = null; });
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
      await Api.rpc('set_available', {'p_id': Store.pid, 'p_token': Store.token, 'p_value': v});
      _load();
    } catch (e) {
      toast(context, errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return Scaffold(
      drawer: const AppDrawer(current: 'me'),
      appBar: bar('ملفي'),
      body: _err != null
          ? ErrorRetry(_err!, _load)
          : me == null
              ? const Center(child: CircularProgressIndicator())
              : (me['status'] == 'banned' ? const BannedView() : RefreshIndicator(onRefresh: _load, child: _body(me))),
    );
  }

  Widget _tip(IconData i, String t, {Color c = C.mute}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 15, color: c),
          const SizedBox(width: 6),
          Expanded(child: Text(t, style: TextStyle(color: c, fontSize: 12.5, height: 1.5))),
        ]),
      );

  Widget _body(Map me) {
    final status = (me['status'] ?? '').toString();
    final jobs = (me['jobs'] ?? 0) as int;
    final tier = Meta.tierOfProvider(me);
    final next = jobs >= 100 ? null : (jobs >= 25 ? 100 : (jobs >= 5 ? 25 : 5));
    final gs = (me['gray_status'] ?? '').toString();
    final pct = (me['pct'] ?? 0) as int;
    final missing = (me['missing'] as List?) ?? [];
    final user = (me['username'] ?? '').toString();
    final link = '${Config.siteUrl}/#/u/$user';
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Avatar(photo: me['photo'], name: me['name'] ?? '', size: 84),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(me['name'] ?? '', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              const SizedBox(width: 6),
              TierBadge(p: me, size: 24),
            ]),
            if (user.isNotEmpty) Text('@$user', textDirection: TextDirection.ltr, style: const TextStyle(color: C.blue, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: () async {
                await openEditProfile(context);
                _load();
              },
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('تعديل الملف'),
            ),
            if (status == 'approved') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderScreen(id: Store.pid!))),
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('شاهد ملفك كما يراه الزبون'),
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 10),
      if (status == 'pending')
        Card(color: const Color(0xFFE3F0FD), child: const Padding(padding: EdgeInsets.all(14), child: Text('حسابك قيد المراجعة. سنتواصل معك على الواتساب للتحقق ثم يظهر ملفك للزبائن.', style: TextStyle(height: 1.5)))),
      if (status != 'pending' && status != 'approved')
        Card(color: const Color(0xFFFFE3E3), child: Padding(padding: const EdgeInsets.all(14), child: Text('حسابك غير مفعّل حاليًا. تواصل مع الدعم.'))),
      if (me['birth_date'] == null)
        Card(color: const Color(0xFFFFF4D6), child: const Padding(padding: EdgeInsets.all(12), child: Text('أضف تاريخ ميلادك الحقيقي من "تعديل الملف" (مطلوب 18+).'))),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('اكتمال الملف', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('$pct%', style: TextStyle(fontWeight: FontWeight.w800, color: pct >= 100 ? C.green : C.blue)),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (pct / 100).clamp(0, 1).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(6), color: pct >= 100 ? C.green : C.blue),
            if (pct < 100 && missing.isNotEmpty)
              _tip(Icons.lightbulb_outline_rounded, 'ينقصك: ${missing.map((k) => const {'photo': 'الصورة', 'bio': 'الوصف (20 حرفًا)', 'hood': 'الحي', 'price': 'أدنى سعر', 'price_max': 'أعلى سعر', 'experience': 'سنوات الخبرة', 'password': 'كلمة السر'}[k] ?? k).join('، ')}', c: const Color(0xFFB45309))
            else
              _tip(Icons.check_circle_outline_rounded, 'ملفك مكتمل. الملفات المكتملة تظهر أعلى في القوائم.', c: C.green),
          ]),
        ),
      ),
      if (status == 'approved') ...[
        const SizedBox(height: 4),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Column(children: [
              SwitchListTile(
                value: me['flag'] == true,
                onChanged: _toggle,
                title: const Text('أنا متاح الآن', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(me['available'] == true ? 'ملفك ظاهر للزبائن' : (me['flag'] == true ? 'خارج ساعات العمل (${t12(me['from'])} - ${t12(me['to'])})' : 'غير ظاهر في القوائم')),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _tip(Icons.lightbulb_outline_rounded, 'أوقفه عندما تكون مشغولًا حتى لا تصلك طلبات لا تستطيع تلبيتها. ساعات العمل تُعدَّل من «تعديل الملف».')),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => trustSheet(context, me, own: true),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (tier.isNotEmpty) Image.asset('assets/badges/badge-$tier.png', width: 36, height: 36),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tier.isEmpty ? 'لم تحصل على شارة بعد' : 'شارة ${Meta.tierName(tier)}', style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text('$jobs خدمة مكتملة'),
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline_rounded, size: 18, color: C.blue),
                ]),
                if (gs == 'pending') _tip(Icons.hourglass_top_rounded, 'ملفك مكتمل ✓ وينتظر موافقة الإدارة على الشارة الرمادية.', c: C.blue),
                if (gs == 'none' && pct < 100) _tip(Icons.lightbulb_outline_rounded, 'أكمل ملفك 100% لتُراجَع للحصول على الشارة الرمادية.'),
                if (next != null) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: (jobs / next).clamp(0, 1).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(6)),
                  const SizedBox(height: 4),
                  Text('باقي ${next - jobs} خدمة للشارة التالية', style: const TextStyle(color: C.mute, fontSize: 12)),
                ],
                _tip(Icons.touch_app_rounded, 'اضغط لمعرفة كيف تحصل على كل شارة. تُحتسب الخدمة عندما يؤكدها الزبون وتؤكدها أنت.'),
              ]),
            ),
          ),
        ),
      ],
      const SizedBox(height: 4),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('رابط ملفك', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF3F8FF), borderRadius: BorderRadius.circular(12)),
              child: Text(link, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12.5, color: C.mute)),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (mounted) toast(context, 'تم نسخ الرابط');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('نسخ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(onPressed: () => Share.share('${me['name']} على صنايعي قريب\n$link'), icon: const Icon(Icons.share_rounded, size: 18), label: const Text('مشاركة'))),
            ]),
            _tip(Icons.lightbulb_outline_rounded, 'شارك رابطك مع زبائنك ليطلبوك مباشرة.'),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        style: OutlinedButton.styleFrom(foregroundColor: C.red),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeleteAccountScreen(emailVerified: me['email_verified'] == true && (me['email'] ?? '').toString().isNotEmpty, email: (me['email'] ?? '').toString()))),
        child: const Text('حذف حسابي'),
      ),
      const SizedBox(height: 30),
    ]);
  }
}
