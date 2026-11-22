import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core.dart';
import 'theme.dart';

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
            : Text(name.isEmpty ? '?' : name.characters.first, style: TextStyle(fontSize: size * .42, color: C.blue, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class TierBadge extends StatelessWidget {
  final int jobs;
  final double size;
  const TierBadge({super.key, required this.jobs, this.size = 20});
  @override
  Widget build(BuildContext context) {
    final t = Meta.tierOf(jobs);
    if (t.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => tierSheet(context, jobs),
      child: Image.asset('assets/badges/badge-$t.png', width: size, height: size),
    );
  }
}

void tierSheet(BuildContext context, int jobs) {
  final t = Meta.tierOf(jobs);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (t.isNotEmpty) Image.asset('assets/badges/badge-$t.png', width: 44, height: 44),
          const SizedBox(width: 10),
          const Text('صنايعي موثوق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        Text('أنجز $jobs أعمال مؤكدة من عملاء مختلفين.'),
        const SizedBox(height: 12),
        Table(border: TableBorder.all(color: C.hair, borderRadius: BorderRadius.circular(8)), children: [
          for (final r in [
            ['الشارة', 'الأعمال المؤكدة'],
            ['منجز (رمادية)', '3 أعمال'],
            ['متميز (زرقاء)', '10 أعمال'],
            ['ذهبي', '25 عملًا'],
          ])
            TableRow(children: [for (final x in r) Padding(padding: const EdgeInsets.all(8), child: Text(x))]),
        ]),
        const SizedBox(height: 10),
        const Text('يُحسب العمل عندما يقول العميل "تمت الخدمة" ولا يعترض الصنايعي.', style: TextStyle(color: C.mute, fontSize: 12)),
      ]),
    ),
  );
}

class Stars extends StatelessWidget {
  final num? rating;
  final int n;
  const Stars({super.key, this.rating, this.n = 0});
  @override
  Widget build(BuildContext context) {
    if (rating == null) return Text(n == 0 ? 'جديد' : 'تقييم قيد التجميع', style: const TextStyle(color: C.mute, fontSize: 12));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, color: C.gold, size: 18),
      Text(' $rating ', style: const TextStyle(fontWeight: FontWeight.w700)),
      Text('($n)', style: const TextStyle(color: C.mute, fontSize: 12)),
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
            Avatar(photo: p['photo'], name: p['name'] ?? '', size: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 6),
                  TierBadge(jobs: (p['jobs'] ?? 0) as int),
                  if (p['verified'] == true) const Padding(padding: EdgeInsetsDirectional.only(start: 4), child: Icon(Icons.verified_rounded, color: C.blue, size: 18)),
                ]),
                const SizedBox(height: 2),
                Text(services, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.mute, fontSize: 13)),
                const SizedBox(height: 4),
                Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Stars(rating: p['rating'] as num?, n: (p['rating_n'] ?? 0) as int),
                  if (d != null) Text('$d كم', style: const TextStyle(fontSize: 12, color: C.mute)),
                  if (p['age'] != null) Text('${p['age']} سنة', style: const TextStyle(fontSize: 12, color: C.mute)),
                ]),
              ]),
            ),
            Column(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: avail ? C.green : Colors.grey, shape: BoxShape.circle)),
              const SizedBox(height: 4),
              Text(avail ? 'متاح' : 'غير متاح', style: TextStyle(fontSize: 11, color: avail ? C.green : C.mute)),
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
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              const SizedBox(width: 4),
              TierBadge(jobs: (p['jobs'] ?? 0) as int, size: 18),
              if (p['verified'] == true) const Padding(padding: EdgeInsetsDirectional.only(start: 2), child: Icon(Icons.verified_rounded, color: C.blue, size: 16)),
            ]),
            const SizedBox(height: 2),
            Text(services, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: C.mute, fontSize: 12)),
            const SizedBox(height: 6),
            Stars(rating: p['rating'] as num?, n: (p['rating_n'] ?? 0) as int),
            const SizedBox(height: 2),
            Text(avail ? (d != null ? 'متاح · $d كم' : 'متاح') : 'غير متاح', style: TextStyle(fontSize: 11, color: avail ? C.green : C.mute)),
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
