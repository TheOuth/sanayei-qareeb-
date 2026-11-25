import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_drawer.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';

/// رسالة الإدارة: عمولة الخدمات المكتملة. تبقى ظاهرة حتى تؤكد الإدارة استلام المبلغ.
class CommissionScreen extends StatefulWidget {
  const CommissionScreen({super.key});
  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  Map? _d;
  Object? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      final r = await Api.rpc('provider_commissions', {'p_id': Store.pid, 'p_token': Store.token});
      if (mounted) setState(() => _d = r as Map);
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  String _n(num v) => v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  String _waNumber(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('0')) d = '249${d.substring(1)}';
    if (RegExp(r'^[19]\d{8}$').hasMatch(d)) d = '249$d';
    return d;
  }

  void _copy(String v, String what) {
    Clipboard.setData(ClipboardData(text: v));
    toast(context, 'تم نسخ $what');
  }

  Widget _field(String label, String value) {
    final empty = value.isEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.hair)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: C.mute, fontSize: 12)),
            const SizedBox(height: 2),
            Text(empty ? 'سيضيفه المدير قريبًا' : value, textDirection: empty ? null : TextDirection.ltr, style: TextStyle(fontSize: empty ? 14 : 18, fontWeight: FontWeight.w800, color: empty ? C.mute : C.ink, letterSpacing: empty ? 0 : .5)),
          ]),
        ),
        if (!empty) IconButton(tooltip: 'نسخ', icon: const Icon(Icons.copy_rounded, color: C.blue), onPressed: () => _copy(value, label)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      drawer: const AppDrawer(current: 'dash'),
      appBar: bar('رسالة من الإدارة'),
      body: _err != null
          ? ErrorRetry(_err!, _load)
          : d == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: _load, child: _body(d)),
    );
  }

  Widget _body(Map d) {
    final due = (d['due'] as List?) ?? [];
    final total = (d['total'] ?? 0) as num;
    final amt = (d['amount'] ?? 0) as num;
    final acct = (d['account_no'] ?? '').toString(), name = (d['account_name'] ?? '').toString(), wa = _waNumber((d['whatsapp'] ?? '').toString());
    final text = (d['text'] ?? '').toString().replaceAll('{amount}', _n(due.length > 1 ? total : amt));
    if (due.isEmpty) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(24), children: const [
        SizedBox(height: 60),
        Icon(Icons.verified_rounded, size: 72, color: C.green),
        SizedBox(height: 12),
        Text('لا توجد عمولة مستحقة', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        SizedBox(height: 6),
        Text('استلمت الإدارة عمولتك. شكرًا لالتزامك!', textAlign: TextAlign.center, style: TextStyle(color: C.mute)),
      ]);
    }
    return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2E86DE), Color(0xFF5BB0FF)]), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.celebration_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('تهانينا على إكمال الخدمة', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: Colors.white, height: 1.7, fontSize: 14.5)),
          if (due.length > 1) Padding(padding: const EdgeInsets.only(top: 8), child: Text('عدد الخدمات المستحقة: ${due.length} — الإجمالي ${_n(total)} جنيه', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
      ),
      const SizedBox(height: 16),
      _field('رقم الحساب', acct),
      _field('اسم الحساب', name),
      const SizedBox(height: 4),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FA463), minimumSize: const Size.fromHeight(52)),
        onPressed: wa.isEmpty
            ? null
            : () {
                final msg = 'السلام عليكم، أنا ${Store.meName.isEmpty ? 'صنايعي' : Store.meName}. أرسلت عمولة ${_n(total)} جنيه عن ${due.length} ${due.length == 1 ? 'خدمة مكتملة' : 'خدمات مكتملة'} في تطبيق صنايعي قريب، وهذا إشعار التحويل.';
                openUrl('https://wa.me/$wa?text=${Uri.encodeComponent(msg)}');
              },
        icon: const Icon(Icons.chat_rounded),
        label: const Text('إرسال الإشعار عبر واتساب'),
      ),
      if (wa.isEmpty) const Padding(padding: EdgeInsets.only(top: 6), child: Text('رقم واتساب الإدارة لم يُضف بعد.', textAlign: TextAlign.center, style: TextStyle(color: C.mute, fontSize: 12))),
      const SizedBox(height: 16),
      const Text('الخدمات المستحقة', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      for (final x in due)
        Card(
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.task_alt_rounded, color: C.green),
            title: Text((x['service'] ?? 'خدمة').toString()),
            subtitle: Text(() {
              final t = DateTime.fromMillisecondsSinceEpoch(x['ts'] as int);
              return '${t.day}/${t.month}/${t.year}';
            }()),
            trailing: Text('${_n(x['amount'] as num)} جنيه', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      const SizedBox(height: 10),
      const Text('تبقى هذه الرسالة ظاهرة حتى تؤكد الإدارة استلام المبلغ. العمولة على الصنايعي فقط، والزبون لا يدفع أي شيء للتطبيق.', style: TextStyle(color: C.mute, fontSize: 12, height: 1.6)),
      const SizedBox(height: 20),
    ]);
  }
}
