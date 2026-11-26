import 'package:flutter/material.dart';
import '../core.dart';
import '../theme.dart';
import 'home.dart';
import 'register.dart';

/// تظهر مرة واحدة فقط بعد أول تثبيت: تعرّف الزبون والصنايعي بما يفعله كلٌّ منهما
class Onboarding {
  static const _k = 'onboarded_v1';
  /// من ثبّت التطبيق سابقًا (له معرّف محفوظ) لا يرى الترحيب عند التحديث؛ يُستدعى قبل أي شيء يُنشئ المعرّف
  static Future<void> init() async {
    if (!Store.p.containsKey(_k) && (Store.p.containsKey('anon') || Store.p.containsKey('pid'))) await done();
  }

  static bool get needed => !(Store.p.getBool(_k) ?? false) && !Store.loggedIn;
  static Future<void> done() => Store.p.setBool(_k, true);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _i = 0;

  Future<void> _finish({bool register = false}) async {
    await Onboarding.done();
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    if (register) nav.push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  Widget _page({required IconData icon, required String title, required String text, Widget? extra}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(color: Colors.white.withOpacity(.16), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 26),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(.92), fontSize: 16, height: 1.8)),
          if (extra != null) ...[const SizedBox(height: 22), extra],
        ]),
      );

  /// نموذج مصغّر يوضح مكان الزر: القائمة ثم «إنشاء حساب صنايعي»
  Widget _menuHint() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: C.blue.withOpacity(.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.blue, width: 1.6)),
              child: const Icon(Icons.menu_rounded, color: C.blue),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('1. اضغط على زر القائمة في أعلى الصفحة الرئيسية', style: TextStyle(color: C.ink, fontSize: 13.5, fontWeight: FontWeight.w700))),
          ]),
          const Divider(height: 22),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.app_registration_rounded, color: Colors.white, size: 18), SizedBox(width: 4), Text('إنشاء حساب صنايعي', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))]),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('2. اختر «إنشاء حساب صنايعي» ثم أكمل بياناتك', style: TextStyle(color: C.ink, fontSize: 13.5, fontWeight: FontWeight.w700))),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final last = _i == 2;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0F3A68), Color(0xFF1F6FD0), Color(0xFF2B8CF0)])),
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(onPressed: () => _finish(), child: const Text('تخطي', style: TextStyle(color: Colors.white70, fontSize: 15))),
            ),
            Expanded(
              child: PageView(controller: _pc, onPageChanged: (v) => setState(() => _i = v), children: [
                _page(icon: Icons.search_rounded, title: 'ابحث عن صنايعي قريب', text: 'اختر الخدمة التي تحتاجها وسنعرض لك أقرب الصنايعية إليك، وتتواصل معهم مباشرة بالاتصال أو الواتساب، بدون تسجيل ومجانًا.'),
                _page(icon: Icons.handshake_rounded, title: 'اطلب الخدمة بسهولة', text: 'اضغط «طلب الخدمة» ليصل طلبك للصنايعي، وعندما يقبله يظهر لك رقمه فورًا مع إشعار على هاتفك.'),
                _page(icon: Icons.engineering_rounded, title: 'هل أنت صنايعي؟', text: 'اعرض خدمتك لآلاف الباحثين عنها في منطقتك. أنشئ حسابك من القائمة الجانبية:', extra: _menuHint()),
              ]),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var k = 0; k < 3; k++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _i == k ? 24 : 8, height: 8,
                  decoration: BoxDecoration(color: _i == k ? Colors.white : Colors.white38, borderRadius: BorderRadius.circular(8)),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
              child: last
                  ? Column(children: [
                      SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.blue, minimumSize: const Size(0, 50)), onPressed: () => _finish(register: true), child: const Text('إنشاء حساب صنايعي الآن', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)))),
                      const SizedBox(height: 8),
                      TextButton(onPressed: () => _finish(), child: const Text('أنا زبون، ابدأ التصفح', style: TextStyle(color: Colors.white, fontSize: 15))),
                    ])
                  : SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.blue, minimumSize: const Size(0, 50)), onPressed: () => _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut), child: const Text('التالي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)))),
            ),
          ]),
        ),
      ),
    );
  }
}
