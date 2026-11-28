import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// شريط «المنصة الأم» أسفل صفحات موقع الخدمة (للويب فقط، لا يظهر في التطبيق).
/// مكوّن موحّد: كل خدمة جديدة تضعه كما هو أسفل صفحتها الرئيسية (انظر SERVICE_GUIDE.md).
/// عند الضغط يفتح بوابة سبيل في نفس التبويب.
class ParentPlatformBar extends StatelessWidget {
  const ParentPlatformBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => launchUrl(Uri.base.resolve('/'), webOnlyWindowName: '_self'),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF0C3076), Color(0xFF123F95)]),
              boxShadow: [BoxShadow(color: const Color(0xFF0C3076).withOpacity(.25), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Row(children: [
              Image.asset('assets/sabil-logo.png', height: 46),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('أحد خدمات منصة سبيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  SizedBox(height: 2),
                  Text('طرق أكثر لحياة أسهل', style: TextStyle(color: Color(0xFFFFA733), fontWeight: FontWeight.w600, fontSize: 12.5)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFFF8A00), borderRadius: BorderRadius.circular(999)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('زيارة سبيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
