import 'dart:async';
import 'package:flutter/material.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';

/// صفحة حذف الحساب: كلمة السر + رمز يصل للبريد الموثّق (لحماية الحساب إن سُرق الهاتف).
class DeleteAccountScreen extends StatefulWidget {
  final bool emailVerified;
  final String email;
  const DeleteAccountScreen({super.key, required this.emailVerified, required this.email});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _pw = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false, _sending = false, _busy = false, _agree = false;
  int _cool = 0;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _startCool() {
    _t?.cancel();
    setState(() => _cool = 60);
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cool--);
      if (_cool <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    setState(() => _sending = true);
    try {
      await callFunction('send-email-code', {'id': Store.pid, 'token': Store.token, 'purpose': 'delete'});
      if (!mounted) return;
      setState(() => _sent = true);
      _startCool();
      toast(context, 'أرسلنا رمز الحذف إلى بريدك');
    } catch (e) {
      if (mounted) {
        if (e is ApiError && e.code == 'wait') setState(() => _sent = true);
        toast(context, errMsg(e));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _delete() async {
    if (_pw.text.isEmpty) return toast(context, 'اكتب كلمة السر');
    if (widget.emailVerified && _code.text.trim().length != 4) return toast(context, 'اكتب رمز الحذف الذي وصل لبريدك');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد أخير'),
        content: const Text('سيُحذف حسابك وكل بياناتك نهائيًا ولا يمكن استرجاعه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: C.red), onPressed: () => Navigator.pop(context, true), child: const Text('احذف نهائيًا')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final r = await Api.rpc('delete_account', {'p_id': Store.pid, 'p_token': Store.token, 'p_password': _pw.text, 'p_code': widget.emailVerified ? _code.text.trim() : null});
      if (!mounted) return;
      if (r['ok'] == true) {
        await Store.signOut();
        if (!mounted) return;
        toast(context, 'تم حذف حسابك');
        Navigator.of(context).popUntil((r) => r.isFirst);
        return;
      }
      final e = r['error'];
      toast(
        context,
        e == 'wrong_password' ? 'كلمة السر غير صحيحة' : e == 'wrong_code' ? 'الرمز غير صحيح (متبقي ${r['left']} محاولات)' : e == 'expired' ? 'انتهت صلاحية الرمز، اطلب رمزًا جديدًا' : e == 'too_many' ? 'محاولات كثيرة، اطلب رمزًا جديدًا' : e == 'locked' ? 'محاولات كثيرة، حاول بعد 15 دقيقة' : 'اطلب رمز حذف جديدًا',
      );
      if (e == 'wrong_code' || e == 'expired' || e == 'too_many') _code.clear();
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: bar('حذف الحساب', menu: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3C6C6))),
          child: const Text('تنبيه: حذف الحساب نهائي. سيختفي ملفك من البحث وتُحذف تقييماتك وطلباتك ولا يمكن استرجاعها.', style: TextStyle(color: C.red, fontWeight: FontWeight.w600, height: 1.6)),
        ),
        const SizedBox(height: 16),
        const Text('الخطوة 1: كلمة السر', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(hintText: 'كلمة سر حسابك')),
        const SizedBox(height: 18),
        if (widget.emailVerified) ...[
          Text('الخطوة 2: رمز يصل إلى بريدك (${widget.email})', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: (_sending || _cool > 0) ? null : _sendCode,
            icon: const Icon(Icons.mark_email_read_outlined, size: 18),
            label: Text(_sending ? 'جارٍ الإرسال…' : _cool > 0 ? 'إعادة الإرسال ($_cool)' : (_sent ? 'إرسال رمز جديد' : 'أرسل رمز الحذف')),
          ),
          if (_sent) ...[
            const SizedBox(height: 8),
            TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 28, letterSpacing: 12), decoration: const InputDecoration(counterText: '', hintText: '••••')),
          ],
          const SizedBox(height: 10),
        ] else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E6), borderRadius: BorderRadius.circular(12)),
            child: const Text('لم توثّق بريدًا إلكترونيًا، لذلك الحذف يتطلب كلمة السر فقط. لحماية أقوى وثّق بريدك من «تعديل الملف» فيُطلب رمز إضافي عند الحذف.', style: TextStyle(height: 1.6)),
          ),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: _agree, onChanged: (v) => setState(() => _agree = v ?? false), title: const Text('أفهم أن الحذف نهائي ولا رجعة فيه'), controlAffinity: ListTileControlAffinity.leading),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.red, minimumSize: const Size.fromHeight(50)),
          onPressed: (_busy || !_agree) ? null : _delete,
          child: Text(_busy ? 'جارٍ الحذف…' : 'حذف حسابي نهائيًا'),
        ),
      ]),
    );
  }
}
