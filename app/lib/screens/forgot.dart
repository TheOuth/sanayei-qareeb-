import 'dart:async';
import 'package:flutter/material.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';
import 'app_drawer.dart' show bar;

/// استعادة كلمة السر برمز من 6 أرقام يصل إلى البريد الموثّق، ثم دخول مباشر بكلمة السر الجديدة.
class ForgotPasswordScreen extends StatefulWidget {
  final String initial;
  const ForgotPasswordScreen({super.key, this.initial = ''});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _id = TextEditingController(text: widget.initial);
  final _code = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false, _sent = false, _show = false, _noEmail = false;
  String _masked = '';
  int _cool = 0;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  /// يحوّل ما كتبه الصنايعي إلى صيغة يفهمها الخادم (هاتف / اسم مستخدم / بريد)
  String _login() {
    final t = _id.text.trim();
    final d = t.replaceAll(RegExp(r'[\s\-]'), '');
    if (RegExp(r'^[+٠-٩0-9]+$').hasMatch(d)) {
      final n = normalizePhone(d.startsWith('0') || d.startsWith('+') || d.startsWith('٠') ? d : '0$d');
      if (n.isNotEmpty) return n;
    }
    return t;
  }

  void _startCool() {
    _t?.cancel();
    setState(() => _cool = 60);
    _t = Timer.periodic(const Duration(seconds: 1), (k) {
      if (!mounted) return k.cancel();
      setState(() => _cool--);
      if (_cool <= 0) k.cancel();
    });
  }

  Future<void> _send() async {
    final l = _login();
    if (l.length < 3) return toast(context, 'اكتب رقم هاتفك أو اسم المستخدم أو بريدك');
    setState(() { _busy = true; _noEmail = false; });
    try {
      final r = await callFunction('send-reset-code', {'login': l});
      if (!mounted) return;
      if (r is Map && r['hint'] == 'no_email') {
        setState(() => _noEmail = true);
      } else {
        setState(() { _sent = true; _masked = (r is Map ? (r['masked'] ?? '') : '').toString(); });
        _startCool();
        toast(context, 'إن كان الحساب موجودًا وبريده موثّقًا فقد أرسلنا الرمز (تفقد الرسائل غير المرغوبة)');
      }
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reset() async {
    if (_code.text.trim().length != 6) return toast(context, 'اكتب الرمز المكوّن من 6 أرقام');
    if (_pw.text.length < 6) return toast(context, 'كلمة السر الجديدة 6 أحرف على الأقل');
    if (_pw.text != _pw2.text) return toast(context, 'كلمتا السر غير متطابقتين');
    setState(() => _busy = true);
    try {
      final r = await Api.rpc('reset_password_with_code', {'p_login': _login(), 'p_code': _code.text.trim(), 'p_new': _pw.text});
      if (!mounted) return;
      if (r['ok'] == true) {
        await Store.signIn(r['id'], r['token']);
        Store.refreshMe();
        if (!mounted) return;
        Navigator.of(context).popUntil((x) => x.isFirst);
        final c = navKey.currentContext;
        if (c != null) toast(c, 'تم تغيير كلمة السر وتسجيل دخولك');
        return;
      }
      final e = (r['error'] ?? '').toString();
      toast(
        context,
        e == 'wrong' ? 'الرمز غير صحيح (متبقي ${r['left']} محاولات)' : e == 'expired' ? 'انتهت صلاحية الرمز، اطلب رمزًا جديدًا' : e == 'too_many' ? 'محاولات كثيرة، اطلب رمزًا جديدًا' : e == 'weak' ? 'كلمة السر قصيرة (6 أحرف على الأقل)' : 'اطلب رمزًا جديدًا',
      );
      if (e == 'expired' || e == 'too_many' || e == 'no_code') _code.clear();
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _support() {
    final wa = (Meta.cfg['support_whatsapp'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('حسابك لا يملك بريدًا موثّقًا، لذلك لا نستطيع إرسال رمز إليه.', style: TextStyle(fontWeight: FontWeight.w700, height: 1.6)),
        const SizedBox(height: 6),
        const Text('تواصل مع الدعم ليعيدوا لك كلمة السر بعد التحقق من هويتك. وبعد دخولك وثّق بريدك من تعديل الملف حتى تستعيد حسابك بنفسك مستقبلًا.', style: TextStyle(height: 1.7, fontSize: 13)),
        if (wa.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => openUrl('https://wa.me/$wa'), icon: const Icon(Icons.chat_rounded, color: C.green), label: const Text('تواصل مع الدعم')),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar('استعادة كلمة السر', menu: false, bell: false),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('اكتب رقم هاتفك أو اسم المستخدم أو بريدك، وسنرسل رمزًا من 6 أرقام إلى بريدك الموثّق.', style: TextStyle(height: 1.7, color: C.mute)),
        const SizedBox(height: 14),
        TextField(
          controller: _id,
          enabled: !_sent,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy || _sent ? null : _send(),
          decoration: const InputDecoration(labelText: 'رقم الهاتف أو اسم المستخدم أو البريد', hintText: '9XXXXXXXX أو username'),
        ),
        if (!_sent) ...[
          const SizedBox(height: 14),
          FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? 'جارٍ الإرسال…' : 'أرسل الرمز')),
          if (_noEmail) _support(),
        ] else ...[
          const SizedBox(height: 14),
          if (_masked.isNotEmpty) Text('أرسلنا الرمز إلى $_masked', textDirection: TextDirection.rtl, style: const TextStyle(color: C.green, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(labelText: 'الرمز (6 أرقام)', counterText: ''),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pw,
            obscureText: !_show,
            decoration: InputDecoration(labelText: 'كلمة السر الجديدة', suffixIcon: IconButton(icon: Icon(_show ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _show = !_show))),
          ),
          const SizedBox(height: 10),
          TextField(controller: _pw2, obscureText: !_show, decoration: const InputDecoration(labelText: 'أعد كتابة كلمة السر')),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _reset, child: Text(_busy ? 'جارٍ الحفظ…' : 'تغيير كلمة السر ودخول')),
          const SizedBox(height: 6),
          TextButton(onPressed: (_cool > 0 || _busy) ? null : _send, child: Text(_cool > 0 ? 'إعادة الإرسال بعد $_cool ث' : 'لم يصلك الرمز؟ أعد الإرسال')),
        ],
      ]),
    );
  }
}
