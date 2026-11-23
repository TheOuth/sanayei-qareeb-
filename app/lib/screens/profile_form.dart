import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../core.dart';
import '../theme.dart';
import '../widgets.dart';

class ProfileForm extends StatefulWidget {
  final bool isRegister;
  final Map? initial;
  final Widget? header;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  const ProfileForm({super.key, required this.isRegister, this.initial, this.header, required this.onSubmit});
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
  final _bio = TextEditingController();
  int? _d, _m, _y;
  StateG? _st;
  City? _city;
  final Set<String> _services = {};
  String _radius = '10';
  String _from = '08:00', _to = '20:00';
  String _photo = '';
  bool _busy = false, _ok18 = false, _sending = false;
  double? _lat, _lng;

  static const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _name.text = (i['name'] ?? '').toString();
      _wa.text = localPhone((i['whatsapp'] ?? '').toString());
      _hood.text = (i['hood'] ?? '').toString();
      _email.text = (i['email'] ?? '').toString();
      _exp.text = (i['experience'] ?? '').toString();
      _price.text = (i['price'] ?? '').toString();
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

  Future<void> _pickPhoto() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
      if (x == null) return;
      final dec = img.decodeImage(await x.readAsBytes());
      if (dec == null) return;
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
    if (verified) return const Padding(padding: EdgeInsets.only(top: 6), child: Row(children: [Icon(Icons.verified_rounded, color: C.green, size: 18), SizedBox(width: 6), Text('بريد موثّق', style: TextStyle(color: C.green, fontWeight: FontWeight.w600))]));
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

  Future<void> _time(bool from) async {
    final cur = (from ? _from : _to).split(':');
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(cur[0]) ?? 8, minute: int.tryParse(cur[1]) ?? 0));
    if (t == null) return;
    final s = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => from ? _from = s : _to = s);
  }

  Future<void> _submit() async {
    final reg = widget.isRegister;
    if (_name.text.trim().length < 3) return toast(context, 'اكتب اسمك الكامل');
    String ph = '';
    if (reg) {
      ph = normalizePhone(_phone.text);
      if (ph.isEmpty) return toast(context, 'رقم الهاتف غير صحيح (09xxxxxxxx)');
      if (_pw.text.length < 6) return toast(context, 'كلمة السر 6 أحرف على الأقل');
      if (!_ok18) return toast(context, 'أقرّ بأن عمرك 18 سنة فأكثر وأن البيانات صحيحة');
    }
    if (_d == null || _m == null || _y == null) return toast(context, 'اختر تاريخ ميلادك الحقيقي');
    if (_city == null) return toast(context, 'اختر مدينتك');
    if (_services.isEmpty) return toast(context, 'اختر خدمة واحدة على الأقل');
    final exp = int.tryParse(_exp.text.trim());
    if (exp == null) return toast(context, 'اكتب سنوات الخبرة');
    final wa = _wa.text.trim().isEmpty ? '' : normalizePhone(_wa.text);
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
      'bio': _bio.text.trim(),
      'from': _from,
      'to': _to,
      'photo': _photo,
      'birth_date': '${_y!.toString().padLeft(4, '0')}-${_m!.toString().padLeft(2, '0')}-${_d!.toString().padLeft(2, '0')}',
    };
    if (reg) {
      body['phone'] = ph;
      body['password'] = _pw.text;
    } else {
      final em = _email.text.trim();
      if (em.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$').hasMatch(em)) return toast(context, 'البريد الإلكتروني غير صحيح');
      body['email'] = em;
      if (_lat == null) { body.remove('lat'); body.remove('lng'); }
    }
    setState(() => _busy = true);
    try {
      await widget.onSubmit(body);
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
    return ListView(padding: const EdgeInsets.all(16), children: [
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
      sec('بياناتك'),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
      if (reg) ...[
        const SizedBox(height: 10),
        TextField(controller: _phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'رقم الهاتف', hintText: '09xxxxxxxx')),
      ],
      const SizedBox(height: 10),
      TextField(controller: _wa, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: InputDecoration(labelText: 'رقم الواتساب', helperText: reg ? 'اتركه فارغًا لو هو نفس رقم الهاتف' : null)),
      if (!reg) ...[
        const SizedBox(height: 10),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'البريد الإلكتروني (اختياري)', helperText: 'للرسائل المهمة مثل التهنئة والتوثيق'), onChanged: (_) => setState(() {})),
        _emailStatus(),
      ],
      if (reg) ...[
        const SizedBox(height: 10),
        TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة السر (6 أحرف على الأقل)')),
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
      TextField(controller: _hood, decoration: const InputDecoration(labelText: 'الحي (اختياري)')),
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
      sec('نطاق التغطية'),
      Wrap(spacing: 6, children: [
        for (final r in const [['5', '5 كم'], ['10', '10 كم'], ['20', '20 كم'], ['all', 'كل المدينة']])
          ChoiceChip(label: Text(r[1]), selected: _radius == r[0], onSelected: (_) => setState(() => _radius = r[0])),
      ]),
      sec('العمل'),
      Row(children: [
        Expanded(child: TextField(controller: _exp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سنوات الخبرة'))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الكشف (جنيه)'))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => _time(true), child: Text('من $_from'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: () => _time(false), child: Text('إلى $_to'))),
      ]),
      const SizedBox(height: 10),
      TextField(controller: _bio, maxLength: 200, maxLines: 3, decoration: const InputDecoration(labelText: 'نبذة عنك وعن شغلك')),
      if (reg) ...[
        CheckboxListTile(
          value: _ok18,
          onChanged: (v) => setState(() => _ok18 = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('أقرّ أن عمري 18 سنة فأكثر وأن بياناتي صحيحة، وأوافق على التواصل معي للتحقق من هويتي.', style: TextStyle(fontSize: 13)),
        ),
      ],
      const SizedBox(height: 10),
      FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'جارٍ الحفظ…' : (reg ? 'إنشاء الحساب' : 'حفظ التعديلات'))),
      const SizedBox(height: 30),
    ]);
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
