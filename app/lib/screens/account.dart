import 'package:flutter/material.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';
import 'login.dart';
import 'register.dart';

/// إنشاء حساب عادي (عميل). نفس الحساب يصلح لاحقًا ليكون صنايعيًا ولكل تطبيقاتنا.
class AccountRegisterScreen extends StatefulWidget {
  const AccountRegisterScreen({super.key});
  @override
  State<AccountRegisterScreen> createState() => _AccountRegisterScreenState();
}

class _AccountRegisterScreenState extends State<AccountRegisterScreen> {
  final _name = TextEditingController(), _ph = TextEditingController(), _em = TextEditingController(), _pw = TextEditingController();
  bool _busy = false, _ok = false;

  Future<void> _go() async {
    final name = _name.text.trim();
    final ph = _ph.text.trim().isEmpty ? '' : normalizePhone('0${_ph.text}');
    final em = _em.text.trim();
    if (name.length < 2) return toast(context, 'اكتب اسمك');
    if (_ph.text.trim().isEmpty && em.isEmpty) return toast(context, 'اكتب رقم هاتفك أو بريدك الإلكتروني');
    if (_ph.text.trim().isNotEmpty && ph.isEmpty) return toast(context, 'رقم الهاتف غير صحيح. اكتب 9 أرقام تبدأ بـ 9 أو 1');
    if (em.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$').hasMatch(em)) return toast(context, 'البريد الإلكتروني غير صحيح');
    if (_pw.text.length < 6) return toast(context, 'كلمة السر 6 أحرف على الأقل');
    if (!_ok) return toast(context, 'أقرّ بأن عمرك 18 سنة فأكثر ووافق على الشروط');
    setState(() => _busy = true);
    try {
      final r = await Api.rpc('account_register', {'p_name': name, 'p_phone': ph, 'p_email': em, 'p_password': _pw.text, 'p_anon': Store.anon});
      await Store.signInAccount(r);
      if (ph.isNotEmpty) await Store.setLastPhone(localPhone(ph));
      Store.refreshReqBadge();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      final c = navKey.currentContext;
      if (c != null) toast(c, 'تم إنشاء حسابك. طلباتك صارت محفوظة وتظهر في أي جهاز');
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: 'login'),
      appBar: bar('إنشاء حساب'),
      body: AutofillGroup(child: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFE3F0FD), borderRadius: BorderRadius.circular(12)),
          child: const Text('حساب واحد لكل خدمات صنايعي قريب. تحفظ طلباتك وتراها من أي جهاز، وتقدر لاحقًا تسجّل كصنايعي بنفس الحساب. الحساب اختياري ويمكنك طلب الخدمة بدونه.', style: TextStyle(height: 1.6, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 14),
        TextField(controller: _name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'الاسم')),
        const SizedBox(height: 10),
        PhoneField(controller: _ph, label: 'رقم الهاتف', autofill: const [AutofillHints.username, AutofillHints.telephoneNumber]),
        const SizedBox(height: 10),
        TextField(controller: _em, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'البريد الإلكتروني (اختياري)')),
        const SizedBox(height: 10),
        TextField(controller: _pw, obscureText: true, autofillHints: const [AutofillHints.newPassword], decoration: const InputDecoration(labelText: 'كلمة السر (6 أحرف على الأقل)')),
        const SizedBox(height: 6),
        CheckboxListTile(
          value: _ok,
          onChanged: (v) => setState(() => _ok = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('عمري 18 سنة فأكثر وأوافق على الشروط والأحكام', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: _busy ? null : _go, child: Text(_busy ? 'جارٍ الإنشاء…' : 'إنشاء الحساب')),
        const SizedBox(height: 10),
        TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())), child: const Text('عندي حساب؟ تسجيل الدخول')),
        TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text('أريد التسجيل كصنايعي مباشرة')),
      ])),
    );
  }
}
