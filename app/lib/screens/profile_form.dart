import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../core.dart';
import 'legal.dart';
import '../theme.dart';
import '../widgets.dart';

class ProfileForm extends StatefulWidget {
  final bool isRegister;
  /// التسجيل من حساب موجود: لا نطلب كلمة سر، ولا الهاتف إن كان موجودًا بالحساب
  final bool fromAccount;
  final Map? initial;
  final Widget? header;
  final Widget? footer;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  const ProfileForm({super.key, required this.isRegister, this.fromAccount = false, this.initial, this.header, this.footer, required this.onSubmit});
  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _wa = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _hood = TextEditingController();
  final _exp = TextEditingController();
  final _price = TextEditingController();
  final _pmax = TextEditingController();
  final _bio = TextEditingController();
  int? _d, _m, _y;
  StateG? _st;
  City? _city;
  final Set<String> _services = {};
  String _radius = '10';
  String _from = '08:00', _to = '20:00';
  String _photo = '';
  bool _busy = false, _ok18 = false, _sending = false;
  String _customName = '', _customNote = '';
  List _customList = [];
  double? _lat, _lng;

  static const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

  @override
  void initState() {
    super.initState();
    if (!widget.isRegister) _loadCustom();
    final i = widget.initial;
    if (i != null) {
      _name.text = (i['name'] ?? '').toString();
      _wa.text = phoneBody((i['whatsapp'] ?? '').toString());
      _hood.text = (i['hood'] ?? '').toString();
      _email.text = (i['email'] ?? '').toString();
      _exp.text = (i['experience'] ?? '').toString();
      _price.text = (i['price'] ?? '').toString();
      _pmax.text = ((i['price_max'] ?? 0) == 0 ? (i['price'] ?? '') : i['price_max']).toString();
      _bio.text = (i['bio'] ?? '').toString();
      _services.addAll((i['services'] as List).map((e) => e.toString()));
      _radius = (i['radius'] ?? '10').toString();
      _from = (i['from'] ?? '08:00').toString();
      _to = (i['to'] ?? '20:00').toString();
      _photo = (i['photo'] ?? '').toString();
      final c = Meta.city((i['city_id'] ?? '').toString());
      if (c != null) {
        _city = c;
        _st = Meta.stateOf(c.id);
      }
      final bd = i['birth_date'];
      if (bd is String && bd.length >= 10) {
        _y = int.tryParse(bd.substring(0, 4));
        _m = int.tryParse(bd.substring(5, 7));
        _d = int.tryParse(bd.substring(8, 10));
      }
    }
  }

  Future<void> _loadCustom() async {
    try {
      final r = await Api.rpc('my_custom_services', {'p_id': Store.pid, 'p_token': Store.token});
      if (mounted && r is List) setState(() => _customList = r);
    } catch (_) {}
  }

  Future<void> _customDialog() async {
    final n = TextEditingController(text: _customName);
    final d = TextEditingController(text: _customNote);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اقتراح خدمة خاصة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('إن كانت خدمتك غير موجودة في القائمة اكتبها هنا. تراجعها الإدارة وقد تضيفها للجميع.', style: TextStyle(fontSize: 12.5, height: 1.5)),
          const SizedBox(height: 10),
          TextField(controller: n, maxLength: 40, decoration: const InputDecoration(labelText: 'اسم الخدمة')),
          TextField(controller: d, maxLength: 200, maxLines: 2, decoration: const InputDecoration(labelText: 'وصف قصير (اختياري)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال للإدارة')),
        ],
      ),
    );
    if (ok != true) return;
    final name = n.text.trim();
    if (name.length < 2) return toast(context, 'اكتب اسم الخدمة');
    if (widget.isRegister) {
      setState(() { _customName = name; _customNote = d.text.trim(); });
      return;
    }
    try {
      await Api.rpc('suggest_service', {'p_id': Store.pid, 'p_token': Store.token, 'p_name': name, 'p_note': d.text.trim()});
      if (mounted) toast(context, 'أرسلنا اقتراحك للإدارة وسنخبرك بالقرار في الرسائل');
      await _loadCustom();
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
  }

  Widget _customSection() {
    final st = const {'pending': ['بانتظار موافقة الإدارة', Color(0xFFB45309)], 'approved': ['تمت الموافقة', C.green], 'rejected': ['لم تُقبل', C.red]};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: _customDialog, icon: const Icon(Icons.add_circle_outline_rounded, size: 18), label: const Text('خدمتي غير موجودة؟ اقترح خدمة خاصة')),
      if (widget.isRegister && _customName.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [const Icon(Icons.check_circle_rounded, color: C.green, size: 18), const SizedBox(width: 6), Expanded(child: Text('خدمة مقترحة: $_customName (تراجعها الإدارة)')), IconButton(onPressed: () => setState(() { _customName = ''; _customNote = ''; }), icon: const Icon(Icons.close_rounded, size: 18))])),
      for (final c in _customList.where((x) => x['status'] != 'approved').take(5))
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('• ${c['name']} — ${(st[c['status']] ?? ['', C.mute])[0]}${(c['suggest'] ?? '').toString().isNotEmpty ? ' (اقتراح الإدارة: ${c['suggest']})' : ''}', style: TextStyle(fontSize: 12.5, color: (st[c['status']] ?? ['', C.mute])[1] as Color)),
        ),
    ]);
  }

  Future<void> _pickPhoto() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, imageQuality: 90);
      if (x == null) return;
      final dec = img.decodeImage(await x.readAsBytes());
      if (dec == null) return;
      if (!widget.isRegister) {
        // حساب موجود: نرفع الصورة إلى التخزين ونحفظ الرابط فقط
        setState(() => _busy = true);
        try {
          final jpg = img.encodeJpg(img.copyResizeCropSquare(dec, size: 320), quality: 80);
          final r = await callFunction('upload-photo', {'id': Store.pid, 'token': Store.token, 'image': base64Encode(jpg)});
          if (mounted) setState(() => _photo = (r['url'] ?? '').toString());
        } catch (e) {
          if (mounted) toast(context, errMsg(e));
        }
        if (mounted) setState(() => _busy = false);
        return;
      }
      // تسجيل جديد (لا يوجد حساب بعد): صورة مصغّرة صغيرة الحجم
      var size = 128;
      String out = '';
      while (size >= 64) {
        final sq = img.copyResizeCropSquare(dec, size: size);
        for (var q = 70; q >= 40; q -= 10) {
          final s = 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(sq, quality: q))}';
          if (s.length <= 50000) { out = s; break; }
        }
        if (out.isNotEmpty) break;
        size -= 32;
      }
      if (out.isNotEmpty && mounted) setState(() => _photo = out);
    } catch (_) {
      if (mounted) toast(context, 'تعذّر اختيار الصورة');
    }
  }

  bool get _emailSaved => _savedEmail.isNotEmpty && _email.text.trim().toLowerCase() == _savedEmail;
  bool _verified = false;
  late String _savedEmail = (widget.initial?['email'] ?? '').toString();
  bool _savingEmail = false;

  Future<void> _saveEmail() async {
    final em = _email.text.trim().toLowerCase();
    if (em.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$').hasMatch(em)) return toast(context, 'البريد الإلكتروني غير صحيح');
    setState(() => _savingEmail = true);
    try {
      await Api.rpc('update_profile', {'p_id': Store.pid, 'p_token': Store.token, 'p': {'email': em}});
      if (mounted) {
        setState(() { _savedEmail = em; _verified = false; _codeOpen = false; });
        toast(context, em.isEmpty ? 'تم حذف البريد' : 'تم حفظ البريد. اضغط "أرسل رمز التأكيد" لتوثيقه');
      }
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
    if (mounted) setState(() => _savingEmail = false);
  }

  final _code = TextEditingController();
  bool _codeOpen = false, _checking = false;
  int _cool = 0;
  Timer? _coolT;

  @override
  void dispose() {
    _coolT?.cancel();
    super.dispose();
  }

  void _startCool([int s = 60]) {
    _coolT?.cancel();
    setState(() => _cool = s);
    _coolT = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cool = _cool - 1);
      if (_cool <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    setState(() => _sending = true);
    try {
      await callFunction('send-email-code', {'id': Store.pid, 'token': Store.token});
      if (!mounted) return;
      _code.clear();
      setState(() => _codeOpen = true);
      _startCool();
      toast(context, 'أرسلنا رمزًا من 4 أرقام إلى بريدك (تفقد الرسائل غير المرغوبة أيضًا)');
    } catch (e) {
      if (mounted) {
        // إن كان هناك رمز أُرسل قبل قليل نُبقي خانة الإدخال ظاهرة
        if (e is ApiError && e.code == 'wait') setState(() => _codeOpen = true);
        toast(context, errMsg(e));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _checkCode() async {
    final c = _code.text.trim();
    if (c.length != 4) return toast(context, 'اكتب الرمز المكوّن من 4 أرقام');
    setState(() => _checking = true);
    try {
      final r = await Api.rpc('verify_email_code', {'p_id': Store.pid, 'p_token': Store.token, 'p_code': c});
      if (!mounted) return;
      if (r['ok'] == true) {
        setState(() { _verified = true; _codeOpen = false; });
        toast(context, 'تم توثيق بريدك ✓');
      } else {
        final e = r['error'];
        _code.clear();
        if (e == 'wrong') {
          toast(context, 'الرمز غير صحيح (متبقي ${r['left']} محاولات). أعد الكتابة');
        } else {
          toast(context, e == 'expired' ? 'انتهت صلاحية الرمز. اطلب رمزًا جديدًا' : e == 'too_many' ? 'محاولات كثيرة. اطلب رمزًا جديدًا' : 'اطلب رمزًا جديدًا');
        }
      }
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
    if (mounted) setState(() => _checking = false);
  }

  Widget _codeBox() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF3F8FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDCE8F5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('اكتب الرمز الذي وصل إلى بريدك', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 28, letterSpacing: 12),
          decoration: const InputDecoration(counterText: '', hintText: '••••'),
          onChanged: (v) { if (v.trim().length == 4 && !_checking) _checkCode(); },
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FilledButton(onPressed: _checking ? null : _checkCode, child: Text(_checking ? 'جارٍ التحقق…' : 'تأكيد الرمز'))),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: (_sending || _cool > 0) ? null : _sendCode, child: Text(_cool > 0 ? 'إعادة الإرسال ($_cool)' : 'إرسال رمز جديد')),
        ]),
      ]),
    );
  }

  Widget _emailStatus() {
    final verified = _verified || (widget.initial?['email_verified'] == true && _emailSaved && _email.text.trim().toLowerCase() == (widget.initial?['email'] ?? '').toString());
    final typed = _email.text.trim().toLowerCase();
    if (typed.isEmpty && _savedEmail.isEmpty) return const SizedBox.shrink();
    if (typed != _savedEmail) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: _savingEmail ? null : _saveEmail,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(_savingEmail ? 'جارٍ الحفظ…' : (typed.isEmpty ? 'حذف البريد' : 'حفظ البريد')),
          ),
        ),
      );
    }
    if (verified) return const Padding(padding: EdgeInsets.only(top: 6), child: Row(children: [Text('✅', style: TextStyle(fontSize: 15)), SizedBox(width: 6), Text('تم التحقق من البريد', style: TextStyle(color: C.green, fontWeight: FontWeight.w600))]));
    if (_codeOpen) return _codeBox();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        OutlinedButton.icon(onPressed: _sending ? null : _sendCode, icon: const Icon(Icons.mark_email_read_outlined, size: 18), label: Text(_sending ? 'جارٍ الإرسال…' : 'أرسل رمز التأكيد')),
        TextButton(onPressed: () => setState(() => _codeOpen = true), child: const Text('لدي رمز')),
      ]),
    );
  }

  Future<void> _gpsPoint() async {
    final l = await detectLocation(context);
    if (l != null && mounted) {
      setState(() { _lat = l['lat']; _lng = l['lng']; });
      toast(context, 'تم حفظ موقعك الدقيق');
    }
  }

  /// سبب نقص الملف يظهر أسفل الحقل الناقص (في وضع التعديل فقط)
  Widget _need(bool cond, String msg) => (widget.isRegister || !cond)
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [const Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFB45309)), const SizedBox(width: 4), Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFB45309), fontSize: 12)))]));

  Future<void> _time(bool from) async {
    final cur = (from ? _from : _to).split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(cur[0]) ?? 8, minute: int.tryParse(cur[1]) ?? 0),
      builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: false), child: w!),
    );
    if (t == null) return;
    final s = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => from ? _from = s : _to = s);
  }

  Future<void> _submit() async {
    final reg = widget.isRegister;
    if (_name.text.trim().length < 3) return toast(context, 'اكتب اسمك الكامل');
    String ph = '';
    final askPhone = reg && (!widget.fromAccount || Store.accountNeedsPhone);
    if (reg) {
      if (askPhone) {
        ph = normalizePhone('0${_phone.text}');
        if (ph.isEmpty) return toast(context, 'رقم الهاتف غير صحيح. اكتب 9 أرقام تبدأ بـ 9 أو 1');
      }
      if (!widget.fromAccount && _pw.text.length < 6) return toast(context, 'كلمة السر 6 أحرف على الأقل');
      if (!_ok18) return toast(context, 'أقرّ بأن عمرك 18 سنة فأكثر ووافق على الشروط والأحكام');
    }
    if (_d == null || _m == null || _y == null) return toast(context, 'اختر تاريخ ميلادك الحقيقي');
    if (_city == null) return toast(context, 'اختر مدينتك');
    if (_services.isEmpty && _customName.isEmpty) return toast(context, 'اختر خدمة واحدة على الأقل أو اقترح خدمة خاصة');
    final exp = int.tryParse(_exp.text.trim());
    if (exp == null) return toast(context, 'اكتب سنوات الخبرة');
    final wa = _wa.text.trim().isEmpty ? '' : normalizePhone('0${_wa.text}');
    if (_wa.text.trim().isNotEmpty && wa.isEmpty) return toast(context, 'رقم الواتساب غير صحيح');
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'whatsapp': wa,
      'state_id': _st!.id,
      'city_id': _city!.id,
      'hood': _hood.text.trim(),
      'lat': _lat ?? _city!.lat,
      'lng': _lng ?? _city!.lng,
      'radius': _radius,
      'services': _services.toList(),
      'experience': exp,
      'price': int.tryParse(_price.text.trim()) ?? 0,
      'price_max': int.tryParse(_pmax.text.trim()) ?? 0,
      'bio': _bio.text.trim(),
      'from': _from,
      'to': _to,
      'photo': _photo,
      'birth_date': '${_y!.toString().padLeft(4, '0')}-${_m!.toString().padLeft(2, '0')}-${_d!.toString().padLeft(2, '0')}',
    };
    if (reg) {
      if (ph.isNotEmpty) body['phone'] = ph;
      if (!widget.fromAccount) body['password'] = _pw.text;
      if (_customName.isNotEmpty) { body['custom_service'] = _customName; body['custom_note'] = _customNote; }
    } else {
      final em = _email.text.trim();
      if (em.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$').hasMatch(em)) return toast(context, 'البريد الإلكتروني غير صحيح');
      body['email'] = em;
      if (_lat == null) { body.remove('lat'); body.remove('lng'); }
    }
    final pmn = int.tryParse(_price.text.trim()) ?? 0, pmx = int.tryParse(_pmax.text.trim()) ?? 0;
    if (pmn > 0 && pmx > 0 && pmx < pmn) return toast(context, 'أعلى سعر يجب ألا يقل عن أدنى سعر');
    if (pmn > 0 && (pmn < priceFloor || pmn > priceCap)) return toast(context, priceRangeMsg());
    if (pmx > 0 && (pmx < priceFloor || pmx > priceCap)) return toast(context, priceRangeMsg());
    setState(() => _busy = true);
    try {
      await widget.onSubmit(body);
      if (widget.isRegister && ph.isNotEmpty) await Store.setLastPhone(localPhone(ph));
    } catch (e) {
      if (mounted) toast(context, errMsg(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final reg = widget.isRegister;
    final nowY = DateTime.now().year;
    Widget sec(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: C.navy)));
    return AutofillGroup(child: ListView(padding: const EdgeInsets.all(16), children: [
      if (widget.header != null) widget.header!,
      Center(
        child: GestureDetector(
          onTap: _pickPhoto,
          child: Stack(children: [
            Avatar(photo: _photo, name: _name.text, size: 96),
            Positioned(bottom: 0, left: 0, child: CircleAvatar(radius: 16, backgroundColor: C.blue, child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white))),
          ]),
        ),
      ),
      const SizedBox(height: 4),
      const Center(child: Text('صورة شخصية واضحة (تزيد ثقة الزبائن)', style: TextStyle(color: C.mute, fontSize: 12))),
      Center(child: _need(_photo.isEmpty, 'ناقص: أضف صورة شخصية (30% من اكتمال الملف)')),
      sec('بياناتك'),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
      if (reg && (!widget.fromAccount || Store.accountNeedsPhone)) ...[
        const SizedBox(height: 10),
        PhoneField(controller: _phone, label: 'رقم الهاتف', autofill: const [AutofillHints.username]),
      ],
      const SizedBox(height: 10),
      PhoneField(controller: _wa, label: 'رقم الواتساب', note: reg ? 'اتركه فارغًا لو هو نفس رقم الهاتف' : null),
      if (!reg) ...[
        const SizedBox(height: 10),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'البريد الإلكتروني (اختياري)', helperText: 'للرسائل المهمة مثل التهنئة والتوثيق'), onChanged: (_) => setState(() {})),
        _emailStatus(),
      ],
      if (reg && !widget.fromAccount) ...[
        const SizedBox(height: 10),
        TextField(controller: _pw, obscureText: true, autofillHints: const [AutofillHints.newPassword], decoration: const InputDecoration(labelText: 'كلمة السر (6 أحرف على الأقل)')),
      ],
      sec('تاريخ الميلاد (18 سنة فأكثر) — اكتب عمرك الحقيقي'),
      Row(children: [
        Expanded(child: _dd<int>('اليوم', _d, List.generate(31, (i) => i + 1), (v) => '$v', (v) => setState(() => _d = v))),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: _dd<int>('الشهر', _m, List.generate(12, (i) => i + 1), (v) => months[v - 1], (v) => setState(() => _m = v))),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: _dd<int>('السنة', _y, List.generate(nowY - 1950 + 1, (i) => nowY - i), (v) => '$v', (v) => setState(() => _y = v))),
      ]),
      sec('موقعك'),
      _dd<StateG>('الولاية', _st, Meta.states, (v) => v.name, (v) => setState(() { _st = v; _city = null; })),
      const SizedBox(height: 10),
      _dd<City>('المدينة / المنطقة', _city, _st?.cities ?? [], (v) => v.name, (v) => setState(() => _city = v)),
      if (!reg) Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF0C95A))),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF9A6B00)),
          SizedBox(width: 8),
          Expanded(child: Text('إذا انتقلت لمدينة أخرى قم بتحديث موقعك الحالي', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B4A00)))),
        ]),
      ),
      const SizedBox(height: 10),
      TextField(controller: _hood, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'الحي')),
      _need(_hood.text.trim().isEmpty, 'ناقص: اكتب اسم حيّك (15% من اكتمال الملف)'),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: _gpsPoint, icon: Icon(_lat == null ? Icons.my_location_rounded : Icons.check_circle_rounded), label: Text(_lat == null ? 'حدّد موقعي الدقيق بالـ GPS (موصى به)' : 'تم حفظ موقعك الدقيق')),
      sec('خدماتك'),
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final s in Meta.services)
          FilterChip(
            label: Text('${s.icon} ${s.name}'),
            selected: _services.contains(s.id),
            onSelected: (v) => setState(() => v ? _services.add(s.id) : _services.remove(s.id)),
          ),
      ]),
      _customSection(),
      sec('نطاق التغطية'),
      Wrap(spacing: 6, children: [
        for (final r in const [['5', '5 كم'], ['10', '10 كم'], ['20', '20 كم'], ['all', 'كل المدينة']])
          ChoiceChip(label: Text(r[1]), selected: _radius == r[0], onSelected: (_) => setState(() => _radius = r[0])),
      ]),
      sec('العمل'),
      TextField(controller: _exp, onChanged: (_) => setState(() {}), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سنوات الخبرة')),
      _need((int.tryParse(_exp.text.trim()) ?? 0) <= 0, 'ناقص: اكتب سنوات خبرتك (سنة على الأقل) (10%)'),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(controller: _price, onChanged: (_) => setState(() {}), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أدنى سعر (جنيه)'))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _pmax, onChanged: (_) => setState(() {}), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أعلى سعر (جنيه)'))),
      ]),
      const Padding(padding: EdgeInsets.only(top: 6), child: Text('السعر النهائي يُحدَّد بالاتفاق مع الزبون بعد أن تعرف حجم الخدمة، ويقع بين الأدنى والأعلى. يظهر هذا للزبون في ملفك.', style: TextStyle(color: C.mute, fontSize: 12, height: 1.5))),
      _need((int.tryParse(_price.text.trim()) ?? 0) <= 0, 'ناقص: اكتب أدنى سعر لخدمتك (10%). ${priceRangeMsg()}'),
      _need((int.tryParse(_price.text.trim()) ?? 0) > 0 && (int.tryParse(_pmax.text.trim()) ?? 0) < (int.tryParse(_price.text.trim()) ?? 0), 'اكتب أعلى سعر (لا يقل عن الأدنى)'),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => _time(true), child: Text('من ${t12(_from)}'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: () => _time(false), child: Text('إلى ${t12(_to)}'))),
      ]),
      const SizedBox(height: 10),
      TextField(controller: _bio, onChanged: (_) => setState(() {}), maxLength: 200, maxLines: 3, decoration: const InputDecoration(labelText: 'نبذة عنك وعن شغلك')),
      _need(_bio.text.trim().length < 20, 'ناقص: اكتب وصفًا لا يقل عن 20 حرفًا (25% من اكتمال الملف)، متبقي ${20 - _bio.text.trim().length} حرفًا'),
      if (reg) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: _ok18, onChanged: (v) => setState(() => _ok18 = v ?? false)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text.rich(
                TextSpan(style: const TextStyle(fontSize: 13, height: 1.6, color: C.ink), children: [
                  const TextSpan(text: 'أقرّ أن عمري 18 سنة فأكثر وأن بياناتي صحيحة، وأوافق على '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => LegalScreen.showSheet(context),
                      child: const Text('الشروط والأحكام', style: TextStyle(fontSize: 13, height: 1.6, color: C.blue, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                    ),
                  ),
                  const TextSpan(text: '، والتواصل معي للتحقق من هويتي.'),
                ]),
              ),
            ),
          ),
        ]),
      ],
      if (widget.footer != null) ...[const SizedBox(height: 16), widget.footer!],
      const SizedBox(height: 10),
      FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'جارٍ الحفظ…' : (reg ? 'إنشاء الحساب' : 'حفظ التعديلات'))),
      const SizedBox(height: 30),
    ]));
  }

  Widget _dd<T>(String label, T? v, List<T> items, String Function(T) text, void Function(T?) on) {
    return DropdownButtonFormField<T>(
      value: items.contains(v) ? v : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      items: [for (final i in items) DropdownMenuItem<T>(value: i, child: Text(text(i), overflow: TextOverflow.ellipsis))],
      onChanged: on,
    );
  }
}
