import 'package:flutter/material.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';

/// صفحة الحساب المحظور: السبب، حالة الطعن، ونموذج تقديم طعن
class BannedView extends StatefulWidget {
  const BannedView({super.key});
  @override
  State<BannedView> createState() => _BannedViewState();
}

class _BannedViewState extends State<BannedView> {
  Map? _d;
  Object? _err;
  bool _form = false, _busy = false, _pledge = false;
  String _kind = 'mistake';
  final _body = TextEditingController();

  static const _kinds = {
    'mistake': 'أرى أن الحظر تم عن طريق الخطأ',
    'regret': 'أقرّ بالمخالفة وألتزم بعدم تكرارها',
    'pay': 'سأسدّد العمولة المستحقة',
    'other': 'سبب آخر',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.rpc('provider_ban_info', {'p_id': Store.pid, 'p_token': Store.token});
      if (mounted) setState(() { _d = r as Map; _err = null; });
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  Future<void> _send() async {
    if (_body.text.trim().length < 15) return toast(context, 'اكتب توضيحًا لا يقل عن 15 حرفًا');
    if (!_pledge) return toast(context, 'أكّد التعهد أولًا');
    setState(() => _busy = true);
    try {
      await Api.rpc('submit_appeal', {'p_id': Store.pid, 'p_token': Store.token, 'p_kind': _kind, 'p_body': _body.text.trim()});
      if (mounted) {
        toast(context, 'وصلنا طعنك وسنراجعه قريبًا');
        _form = false;
        _body.clear();
      }
      await _load();
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_err != null) return ErrorRetry(_err!, _load);
    final d = _d;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final ap = d['appeal'] as Map?;
    final reason = (d['reason'] ?? '').toString();
    final due = (d['due'] ?? 0) as num;
    final wa = (Meta.cfg['support_whatsapp'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(18), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFFFFEDED), borderRadius: BorderRadius.circular(18), border: Border.all(color: C.red.withOpacity(.3))),
          child: Column(children: [
            const Icon(Icons.gpp_bad_rounded, size: 56, color: C.red),
            const SizedBox(height: 8),
            const Text('حسابك محظور', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.red)),
            const SizedBox(height: 8),
            const Text('تم حظر حسابك لمخالفة قوانين التطبيق. لن يظهر ملفك للزبائن ولن تصلك طلبات.', textAlign: TextAlign.center, style: TextStyle(height: 1.7)),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('السبب: $reason', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.6)),
            ],
            if (due > 0) ...[
              const SizedBox(height: 6),
              Text('عمولة غير مسدّدة: ${due.round()} جنيه', style: const TextStyle(color: Color(0xFF7A4300), fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        if (ap != null && ap['status'] == 'pending')
          _note(Icons.hourglass_top_rounded, C.blue, 'طعنك قيد المراجعة', 'سنراجع طلبك ونبلغك بالنتيجة هنا. لا حاجة لإرسال طعن آخر.', body: (ap['body'] ?? '').toString())
        else ...[
          if (ap != null && ap['status'] == 'rejected')
            _note(Icons.info_outline_rounded, const Color(0xFFB45309), 'لم يُقبل طعنك السابق', (ap['note'] ?? '').toString().isEmpty ? 'راجعنا طلبك ولم نجد ما يستدعي استعادة الحساب حاليًا.' : 'ملاحظة الإدارة: ${ap['note']}'),
          if (d['can_appeal'] == true && !_form)
            FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), onPressed: () => setState(() => _form = true), icon: const Icon(Icons.gavel_rounded), label: const Text('تقديم طعن')),
          if (ap != null && ap['status'] == 'rejected' && d['can_appeal'] != true)
            const Text('يمكنك تقديم طعن جديد بعد 3 أيام من الرد على طعنك السابق.', textAlign: TextAlign.center, style: TextStyle(color: C.mute, fontSize: 13)),
        ],
        if (_form) _formCard(),
        const SizedBox(height: 14),
        if (wa.isNotEmpty)
          OutlinedButton.icon(onPressed: () => openUrl('https://wa.me/$wa'), icon: const Icon(Icons.support_agent_rounded), label: const Text('تواصل مع الدعم')),
      ]),
    );
  }

  Widget _note(IconData i, Color c, String t, String b, {String body = ''}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.withOpacity(.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(i, color: c), const SizedBox(width: 8), Text(t, style: TextStyle(fontWeight: FontWeight.w800, color: c))]),
          const SizedBox(height: 6),
          Text(b, style: const TextStyle(height: 1.6)),
          if (body.isNotEmpty) ...[
            const Divider(height: 18),
            Text('طعنك: $body', style: const TextStyle(color: C.mute, fontSize: 13, height: 1.6)),
          ],
        ]),
      );

  Widget _formCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('فرصة لمراجعة حسابك', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'قد تُستعاد حسابك إذا التزمت بقواعد التطبيق: إكمال الخدمة وتأكيدها من داخل التطبيق، وعدم إنهاء أي خدمة خارجه دون إعلامنا، وسداد أي عمولة مستحقة.',
              style: TextStyle(height: 1.7, color: C.mute),
            ),
            const SizedBox(height: 14),
            const Text('سبب الطعن', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final e in _kinds.entries) ChoiceChip(label: Text(e.value), selected: _kind == e.key, onSelected: (_) => setState(() => _kind = e.key)),
            ]),
            const SizedBox(height: 14),
            TextField(controller: _body, maxLines: 5, maxLength: 800, decoration: const InputDecoration(labelText: 'اكتب توضيحك', hintText: 'اشرح ما حدث ولماذا ترى أنه يجب استعادة حسابك', alignLabelWithHint: true)),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _pledge,
              onChanged: (v) => setState(() => _pledge = v == true),
              title: const Text('أتعهد بإكمال الخدمات من داخل التطبيق وسداد العمولة المستحقة', style: TextStyle(fontSize: 13.5, height: 1.5)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? 'جارٍ الإرسال…' : 'إرسال الطعن'))),
              const SizedBox(width: 10),
              TextButton(onPressed: () => setState(() => _form = false), child: const Text('إلغاء')),
            ]),
          ]),
        ),
      );
}
