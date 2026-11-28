import 'package:flutter/material.dart';
import '../theme.dart';

/// يظهر عند فتح رابط ملف صنايعي غير موجود. يبقى داخل صنايعي قريب ويعيد للرئيسية.
class UserNotFoundScreen extends StatelessWidget {
  final String name;
  const UserNotFoundScreen({super.key, required this.name});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 88, height: 88,
                decoration: const BoxDecoration(color: Color(0xFFE3F0FD), shape: BoxShape.circle),
                child: const Icon(Icons.person_search_rounded, size: 44, color: C.blue),
              ),
              const SizedBox(height: 18),
              const Text('المستخدم غير موجود', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('لا يوجد صنايعي باسم @$name في صنايعي قريب. تأكد من كتابة الاسم صحيحًا، أو ابحث عن صنايعي من الصفحة الرئيسية.',
                  textAlign: TextAlign.center, style: const TextStyle(color: C.mute, height: 1.7)),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                icon: const Icon(Icons.home_rounded),
                label: const Text('الصفحة الرئيسية'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
