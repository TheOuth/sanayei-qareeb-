import 'package:flutter/material.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../widgets.dart';
import 'register.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ph = TextEditingController();
  final _pw = TextEditingController();
  final _id = TextEditingController();
  bool _busy = false, _show = false, _byPhone = true;

  @override
  void initState() {
    super.initState();
    final lp = Store.lastPhone;
    if (lp.isNotEmpty) _ph.text = phoneBody(lp);
  }

  Future<void> _go() async {
    String ph;
    if (_byPhone) {
      ph = normalizePhone('0${_ph.text}');
      if (ph.isEmpty) return toast(context, 'اكتب رقم هاتفك: 9 أرقام تبدأ بـ 9 أو 1 (بدون صفر)');
    } else {
      ph = _id.text.trim();
      if (ph.length < 3) return toast(context, 'اكتب اسم المستخدم أو البريد الإلكتروني');
    }
    if (_pw.text.isEmpty) return toast(context, 'اكتب كلمة السر');
    setState(() => _busy = true);
    try {
      final r = await Api.rpc('provider_login', {'p_phone': ph, 'p_password': _pw.text});
      if (r['ok'] == true) {
        if (_byPhone) await Store.setLastPhone(localPhone(ph));
        await Store.signIn(r['id'], r['token']);
        Store.refreshMe();
        if (!mounted) return;
        Navigator.of(context).popUntil((r) => r.isFirst);
        toast(context, 'تم تسجيل الدخول. لوحتك من القائمة الجانبية');
      } else {
        final e = (r['error'] ?? 'invalid').toString();
        toast(context, e == 'invalid' ? (_byPhone ? 'الرقم أو كلمة السر غير صحيحة' : 'البيانات أو كلمة السر غير صحيحة') : errMsg(e));
      }
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(current: 'login'),
      appBar: bar('تسجيل دخول الصنايعي'),
      body: AutofillGroup(child: ListView(padding: const EdgeInsets.all(20), children: [
        const RegistrationNote(),
        const SizedBox(height: 10),
        if (_byPhone)
          PhoneField(controller: _ph, label: 'رقم الهاتف', autofill: const [AutofillHints.username, AutofillHints.telephoneNumber], action: TextInputAction.next)
        else
          TextField(controller: _id, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, autofillHints: const [AutofillHints.username, AutofillHints.email], textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'اسم المستخدم أو البريد الإلكتروني', hintText: 'username أو name@mail.com')),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(onPressed: () => setState(() => _byPhone = !_byPhone), child: Text(_byPhone ? 'الدخول باسم المستخدم أو البريد الإلكتروني' : 'الدخول برقم الهاتف')),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _pw,
          obscureText: !_show,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _go(),
          decoration: InputDecoration(labelText: 'كلمة السر', suffixIcon: IconButton(icon: Icon(_show ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _show = !_show))),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: _busy ? null : _go, child: Text(_busy ? 'جارٍ الدخول…' : 'دخول')),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text('ما عندي حساب؟ سجّل كصنايعي')),
        const SizedBox(height: 10),
        const Text('نسيت كلمة السر؟ تواصل مع الدعم من قائمة "عن التطبيق".', style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
      ])),
    );
  }
}
