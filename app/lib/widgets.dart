import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core.dart';
import 'theme.dart';

/// الاسم الأول والثاني فقط (الكامل يظهر في ملف الصنايعي)
String shortName(String n) {
  final parts = n.trim().split(RegExp(r'\s+'));
  return parts.take(2).join(' ');
}

/// الاسم الرباعي: أربع كلمات على الأقل
bool isFullName(String n) {
  final parts = n.trim().split(RegExp(r'\s+'));
  return parts.length >= 4 && parts.every((x) => x.length >= 2);
}

void toast(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
}

Future<void> openUrl(String u) async {
  try {
    await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// يفتح تطبيق المنصة مباشرة إن كان مثبتًا، وإلا المتصفح الخارجي (وليس داخل تطبيقنا)
Future<void> openSocial(String web, String? app) async {
  if (app != null) {
    try {
      if (await launchUrl(Uri.parse(app), mode: LaunchMode.externalNonBrowserApplication)) return;
    } catch (_) {}
  }
  await openUrl(web);
}

double haversine(double a, double b, double c, double d) {
  const r = 6371.0;
  double rad(double x) => x * pi / 180;
  final dl = rad(c - a), dn = rad(d - b);
  final h = pow(sin(dl / 2), 2) + cos(rad(a)) * cos(rad(c)) * pow(sin(dn / 2), 2);
  return 2 * r * asin(sqrt(h));
}

City nearestCity(double lat, double lng) {
  City? best;
  var bd = 1e9;
  for (final s in Meta.states) {
    for (final c in s.cities) {
      if (c.id.endsWith('_other')) continue;
      final d = haversine(lat, lng, c.lat, c.lng);
      if (d < bd) {
        bd = d;
        best = c;
      }
    }
  }
  return best!;
}

/// يحدد الموقع بالـ GPS ويحفظه. يرجع null عند الفشل.
Future<Map<String, dynamic>?> detectLocation(BuildContext ctx) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      toast(ctx, 'فعّل خدمة الموقع (GPS) في الهاتف');
      return null;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      toast(ctx, 'لم يُسمح بالموقع. اختر مدينتك يدويًا');
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium)).timeout(const Duration(seconds: 20));
    final c = nearestCity(pos.latitude, pos.longitude);
    final l = {'lat': pos.latitude, 'lng': pos.longitude, 'city_id': c.id, 'label': c.name, 'gps': true};
    await Store.setLoc(l);
    return l;
  } catch (_) {
    toast(ctx, 'تعذّر تحديد الموقع. اختر مدينتك يدويًا');
    return null;
  }
}

Uint8List? photoBytes(String? p) {
  if (p == null || !p.startsWith('data:image')) return null;
  try {
    return base64Decode(p.substring(p.indexOf(',') + 1));
  } catch (_) {
    return null;
  }
}

class Avatar extends StatelessWidget {
  final String? photo;
  final String name;
  final double size;
  const Avatar({super.key, this.photo, required this.name, this.size = 56});
  @override
  Widget build(BuildContext context) {
    final b = photoBytes(photo);
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFE3F0FD),
        alignment: Alignment.center,
        child: b != null
            ? Image.memory(b, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true)
            : (photo != null && photo!.startsWith('http'))
                ? Image.network(photo!, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: (size * 3).round(), errorBuilder: (_, __, ___) => _initial(), loadingBuilder: (c, w, p) => p == null ? w : _initial())
                : _initial(),
      ),
    );
  }

  Widget _initial() => Text(name.isEmpty ? '?' : name.characters.first, style: TextStyle(fontSize: size * .42, color: C.blue, fontWeight: FontWeight.w700));
}

class TierBadge extends StatelessWidget {
  final Map p;
  final double size;
  const TierBadge({super.key, required this.p, this.size = 20});
  @override
  Widget build(BuildContext context) {
    final t = Meta.tierOfProvider(p);
    if (t.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => trustSheet(context, p),
      child: Image.asset('assets/badges/badge-$t.png', width: size, height: size),
    );
  }
}

/// نافذة «موثّق»: سبب التوثيق ومتطلبات كل شارة. [own] لملف الصنايعي نفسه.
void trustSheet(BuildContext context, Map p, {bool own = false}) {
  final jobs = (p['jobs'] ?? 0) as int;
  final t = Meta.tierOfProvider(p);
  final gs = (p['gray_status'] ?? '').toString();
  final next = jobs >= 100 ? null : (jobs >= 25 ? 100 : (jobs >= 5 ? 25 : 5));
  TableRow tr(Widget a, Widget b) => TableRow(children: [Padding(padding: const EdgeInsets.all(10), child: a), Padding(padding: const EdgeInsets.all(10), child: b)]);
  Widget chip(String badge, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/badges/badge-$badge.png', width: 22, height: 22),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      maxChildSize: .95,
      builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 18, 20, 28), children: [
        Row(children: [
          if (t.isNotEmpty) Image.asset('assets/badges/badge-$t.png', width: 46, height: 46),
          const SizedBox(width: 12),
          Expanded(child: Text(own ? 'شاراتك وكيف تحصل عليها' : 'لماذا ${shortName((p['name'] ?? '').toString())} موثوق؟', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 14),
        Table(border: TableBorder.all(color: C.hair, borderRadius: BorderRadius.circular(10)), columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(2)}, children: [
          tr(const Text('الأعمال المؤكدة'), Text('$jobs${next == null ? '' : '  (باقي ${next - jobs} للشارة التالية)'}')),
          tr(const Text('الشارة الحالية'), t.isEmpty ? const Text('لا توجد بعد', style: TextStyle(color: C.mute)) : chip(t, 'شارة ${Meta.tierName(t)}')),
          if (own && gs == 'pending') tr(const Text('ملفك'), const Text('مكتمل وبانتظار موافقة الإدارة على الشارة الرمادية', style: TextStyle(color: C.blue))),
          if (own && gs == 'rejected') tr(const Text('ملفك'), const Text('لم تُمنح الشارة الرمادية. راجع بياناتك وتواصل مع الدعم', style: TextStyle(color: C.red))),
          if (own && (p['badge_reason'] ?? '').toString().isNotEmpty) tr(const Text('سبب المنح'), Text(p['badge_reason'].toString())),
        ]),
        const SizedBox(height: 18),
        const Text('كيف تحصل على الشارات؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Table(border: TableBorder.all(color: C.hair, borderRadius: BorderRadius.circular(10)), columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(2)}, children: [
          tr(chip('gray', 'رمادية'), const Text('أكمل بيانات ملفك بالكامل (الصورة، الوصف، الحي، السعر، الخبرة). تراجعها الإدارة وتمنحك الشارة إن كانت البيانات صحيحة.', style: TextStyle(height: 1.5))),
          tr(chip('green', 'خضراء'), const Text('أكمل 5 معاملات ناجحة', style: TextStyle(height: 1.5))),
          tr(chip('blue', 'زرقاء'), const Text('أكمل 25 معاملة ناجحة', style: TextStyle(height: 1.5))),
          tr(chip('gold', 'ذهبية'), const Text('أكمل 100 معاملة ناجحة', style: TextStyle(height: 1.5))),
        ]),
        const SizedBox(height: 10),
        const Text('تُحسب المعاملة الناجحة عندما يقول العميل «تمت الخدمة» ويؤكدها الصنايعي، ومن عملاء مختلفين.', style: TextStyle(color: C.mute, fontSize: 12, height: 1.5)),
        const SizedBox(height: 14),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسنًا')),
      ]),
    ),
  );
}

class Stars extends StatelessWidget {
  final num? rating;
  final int n;
  final bool isNew;
  const Stars({super.key, this.rating, this.n = 0, this.isNew = false});
  @override
  Widget build(BuildContext context) {
    if (rating == null) {
      if (isNew) return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: C.green.withOpacity(.12), borderRadius: BorderRadius.circular(10)), child: const Text('مستخدم جديد', style: TextStyle(color: C.green, fontSize: 12, fontWeight: FontWeight.w700)));
      return Text(n == 0 ? 'لا تقييمات بعد' : 'تقييم قيد التجميع', style: const TextStyle(color: C.mute, fontSize: 12));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, color: C.gold, size: 18),
      Text(' $rating ', style: const TextStyle(fontWeight: FontWeight.w700)),
      Text('($n)', style: const TextStyle(color: C.mute, fontSize: 12)),
    ]);
  }
}

/// "نشط الآن" أو "آخر ظهور قبل X" تحت أيقونة الصنايعي.
class SeenLabel extends StatelessWidget {
  final Map p;
  final double size;
  const SeenLabel({super.key, required this.p, this.size = 10.5});
  static String? text(Map p) {
    final v = p['seen_s'];
    if (v == null) return null;
    final s = (v as num).toInt();
    if (s < 300) return 'نشط الآن';
    final m = s ~/ 60;
    if (m < 60) return 'آخر ظهور قبل $m د';
    final h = m ~/ 60;
    if (h < 24) return h == 1 ? 'آخر ظهور قبل ساعة' : (h == 2 ? 'آخر ظهور قبل ساعتين' : (h <= 10 ? 'آخر ظهور قبل $h ساعات' : 'آخر ظهور قبل $h ساعة'));
    if (h < 36) return 'آخر ظهور أمس';
    final d = (h / 24).round();
    if (d == 2) return 'آخر ظهور قبل يومين';
    if (d <= 10) return 'آخر ظهور قبل $d أيام';
    if (d < 30) return 'آخر ظهور قبل $d يوم';
    return 'آخر ظهور منذ مدة';
  }
  @override
  Widget build(BuildContext context) {
    final t = text(p);
    if (t == null) return const SizedBox.shrink();
    final on = t == 'نشط الآن';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (on) Container(width: 7, height: 7, margin: const EdgeInsetsDirectional.only(end: 4), decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle)),
      Flexible(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: size, color: on ? C.green : C.mute, fontWeight: on ? FontWeight.w700 : FontWeight.w500))),
    ]);
  }
}

class ProviderCard extends StatelessWidget {
  final Map p;
  final VoidCallback onTap;
  const ProviderCard({super.key, required this.p, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final services = (p['services'] as List).map((e) => Meta.serviceName(e.toString())).take(3).join('، ');
    final d = p['distance_km'];
    final avail = p['available'] == true;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            SizedBox(width: 74, child: Column(mainAxisSize: MainAxisSize.min, children: [
              Avatar(photo: p['photo'], name: p['name'] ?? '', size: 60),
              const SizedBox(height: 4),
              SeenLabel(p: p, size: 10),
            ])),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(shortName((p['name'] ?? '').toString()), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 6),
                  TierBadge(p: p),
                ]),
                const SizedBox(height: 2),
                Text(services, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.mute, fontSize: 13)),
                const SizedBox(height: 4),
                Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Stars(rating: p['rating'] as num?, n: (p['rating_n'] ?? 0) as int, isNew: p['is_new'] == true),
                  if (d != null) Text('$d كم', style: const TextStyle(fontSize: 12, color: C.mute)),
                  if (p['age'] != null) Text('${p['age']} سنة', style: const TextStyle(fontSize: 12, color: C.mute)),
                  ReplyRing(p: p, size: 30),
                ]),
              ]),
            ),
            Column(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: avail ? C.green : Colors.grey, shape: BoxShape.circle)),
              const SizedBox(height: 4),
              Text(avail ? 'متاح' : (p['off'] == 'hours' ? 'خارج وقت العمل' : 'غير متاح الآن'), style: TextStyle(fontSize: 11, color: avail ? C.green : C.mute)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class ProviderGridCard extends StatelessWidget {
  final Map p;
  final VoidCallback onTap;
  const ProviderGridCard({super.key, required this.p, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final services = (p['services'] as List).map((e) => Meta.serviceName(e.toString())).take(2).join('، ');
    final d = p['distance_km'];
    final avail = p['available'] == true;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              Avatar(photo: p['photo'], name: p['name'] ?? '', size: 64),
              Positioned(
                bottom: 0, left: 0,
                child: Container(width: 14, height: 14, decoration: BoxDecoration(color: avail ? C.green : Colors.grey, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
              ),
            ]),
            const SizedBox(height: 3),
            SeenLabel(p: p),
            const SizedBox(height: 5),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(shortName((p['name'] ?? '').toString()), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              const SizedBox(width: 4),
              TierBadge(p: p, size: 18),
            ]),
            const SizedBox(height: 2),
            Text(services, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: C.mute, fontSize: 12)),
            const SizedBox(height: 6),
            Stars(rating: p['rating'] as num?, n: (p['rating_n'] ?? 0) as int, isNew: p['is_new'] == true),
            if (p['reply_pct'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: ReplyRing(p: p, size: 30)),
            const SizedBox(height: 2),
            Text(avail ? (d != null ? 'متاح · $d كم' : 'متاح') : (p['off'] == 'hours' ? 'خارج وقت العمل' : 'غير متاح الآن'), style: TextStyle(fontSize: 11, color: avail ? C.green : C.mute)),
          ]),
        ),
      ),
    );
  }
}

class Empty extends StatelessWidget {
  final String text;
  final IconData icon;
  const Empty(this.text, {super.key, this.icon = Icons.search_off_rounded});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: C.hair),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: C.mute)),
          ]),
        ),
      );
}

class ErrorRetry extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorRetry(this.error, this.onRetry, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: C.mute),
            const SizedBox(height: 10),
            Text(errMsg(error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ]),
        ),
      );
}


/// سرعة الرد: نسبة الطلبات التي ردّ عليها الصنايعي خلال 15 دقيقة، داخل دائرة
class ReplyRing extends StatelessWidget {
  final Map p;
  final double size;
  final bool label;
  const ReplyRing({super.key, required this.p, this.size = 36, this.label = false});
  @override
  Widget build(BuildContext context) {
    final v = p['reply_pct'];
    if (v == null) return const SizedBox.shrink();
    final pct = (v as num).toInt().clamp(0, 100);
    final col = pct >= 80 ? const Color(0xFF1A7F4B) : (pct >= 50 ? const Color(0xFFB45309) : const Color(0xFFB42318));
    final ring = SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(width: size, height: size, child: CircularProgressIndicator(value: pct / 100, strokeWidth: size / 9, backgroundColor: col.withOpacity(.15), valueColor: AlwaysStoppedAnimation(col))),
        Text('$pct%', style: TextStyle(fontSize: size * .30, fontWeight: FontWeight.w800, color: col)),
      ]),
    );
    if (!label) return Tooltip(message: 'سرعة الرد', child: ring);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ring,
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('سرعة الرد', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text('ردّ خلال 15 دقيقة على $pct% من الطلبات', style: const TextStyle(fontSize: 11.5, color: C.mute)),
      ]),
    ]);
  }
}

/// تنبيه أعلى شاشتي الدخول والتسجيل: هذا القسم لمقدمي الخدمات فقط
class RegistrationNote extends StatelessWidget {
  const RegistrationNote({super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF0C95A))),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF9A6B00)),
          SizedBox(width: 8),
          Expanded(child: Text('التسجيل خاص بمقدمي الخدمات. إذا كنت تبحث عن خدمة فلا تحتاج إلى تسجيل.', style: TextStyle(color: Color(0xFF6B4A00), height: 1.5, fontWeight: FontWeight.w600))),
        ]),
      );
}


/// حقل رقم الهاتف: صفر ثابت لا يُعدَّل، ويقبل تسعة أرقام تبدأ بـ 9 أو 1 فقط.
/// القيمة في controller.text هي الأرقام التسعة فقط (أضف '0' أمامها عند الاستخدام).
class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? note;
  final Iterable<String>? autofill;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  const PhoneField({super.key, required this.controller, required this.label, this.note, this.autofill, this.action, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textInputAction: action,
        onSubmitted: onSubmitted,
        autofillHints: autofill,
        inputFormatters: [_PhoneBodyFormatter()],
        style: const TextStyle(fontSize: 17, letterSpacing: 1),
        decoration: InputDecoration(
          labelText: label,
          hintText: '9xxxxxxxx',
          helperText: note ?? 'لا تكتب الصفر وابدأ بالرقم الذي يليه',
          helperMaxLines: 2,
          prefixIcon: Container(
            width: 48,
            alignment: Alignment.center,
            child: const Text('0', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.mute)),
          ),
        ),
      ),
    );
  }
}

class _PhoneBodyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue v) {
    var d = v.text.replaceAllMapped(RegExp('[٠-٩]'), (m) => (m[0]!.codeUnitAt(0) - 1632).toString()).replaceAll(RegExp(r'\D'), '');
    final pasted = v.text.length - old.text.length > 1;
    if (pasted) {
      if (d.startsWith('00249')) {
        d = d.substring(5);
      } else if (d.startsWith('249') && d.length > 9) {
        d = d.substring(3);
      } else if (d.startsWith('0')) {
        d = d.substring(1);
      }
    }
    if (d.isNotEmpty && d[0] != '9' && d[0] != '1') d = ''; // الصفر وأي رقم غير 9/1 غير مقبول
    if (d.length > 9) d = d.substring(0, 9);
    return TextEditingValue(text: d, selection: TextSelection.collapsed(offset: d.length));
  }
}

/// تنبيه السلامة المالية في قسم الطلبات
class SafetyNote extends StatefulWidget {
  final bool provider;
  const SafetyNote({super.key, this.provider = false});
  @override
  State<SafetyNote> createState() => _SafetyNoteState();
}

class _SafetyNoteState extends State<SafetyNote> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: const Color(0xFFFFF4D6), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF0C95A))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(children: [
                const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF9A6B00)),
                const SizedBox(width: 8),
                const Expanded(child: Text('حافظ على حقك', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6B4A00), fontSize: 13.5))),
                Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: const Color(0xFF9A6B00)),
              ]),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                widget.provider
                    ? '• لا تطلب أي مبلغ مقدّمًا.\n• لا تشترِ مواد أو أدوات للخدمة على حسابك قبل الاتفاق مع الزبون وسداد ثمنها.\n• التسليم والدفع يتمّان وجهًا لوجه بعد إنهاء الخدمة.\n• التطبيق غير مسؤول عن أي مشتريات أو تحويلات تتم خارج ذلك.'
                    : '• لا تحوّل أي مبلغ ولا تدفع قبل أن تنتهي الخدمة وتستلمها.\n• تسليم الخدمة ودفع المال يتمّان وجهًا لوجه.\n• التطبيق غير مسؤول عن أي تعامل مالي يتم خارج ذلك.',
                style: const TextStyle(color: Color(0xFF6B4A00), height: 1.6, fontSize: 13),
              ),
            ),
        ]),
      );
}


/// اسم المستخدم: إنجليزي فقط، يتحول تلقائيًا إلى حروف صغيرة، ولا يقبل النقطة أو المسافة أو الحروف العربية
class UsernameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    final t = n.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final cut = t.length > 20 ? t.substring(0, 20) : t;
    final off = n.selection.baseOffset.clamp(0, cut.length);
    return TextEditingValue(text: cut, selection: TextSelection.collapsed(offset: off));
  }
}
