import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core.dart';
import 'push.dart';
import 'presence.dart';
import 'update_gate.dart';
import 'theme.dart';
import 'screens/splash.dart';
import 'screens/onboarding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? fatal;
  Future<void> step(String name, Future<void> Function() f, {bool critical = false}) async {
    try {
      await f().timeout(const Duration(seconds: 12));
    } catch (e, st) {
      debugPrint('startup $name failed: $e\n$st');
      if (critical) fatal ??= '$name: $e';
    }
  }

  await step('store', Store.init, critical: true);
  await step('onboarding', Onboarding.init);
  await step('meta', Meta.load, critical: true);
  await step('version', AppVersion.load);
  if (fatal != null) {
    // بدل الشاشة الفارغة نعرض سبب العطل ليسهل إصلاحه
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('تعذّر تشغيل التطبيق', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText(fatal!, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      ),
    ));
    return;
  }
  Presence.start();
  Push.init(); // لا ننتظرها حتى لا تؤخر فتح التطبيق
  runApp(const SanayeiApp());
}

class SanayeiApp extends StatelessWidget {
  const SanayeiApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'صنايعي قريب',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [_UnfocusObserver(), RouteTracker()],
      // لمس أي مكان خارج حقل الكتابة يخفي الكيبورد ويُنهي التركيز
      builder: (context, child) {
        // أندرويد 15 يرسم التطبيق تحت شريط التنقل؛ نترك مساحة للأسفل فقط (والأعلى تتولاه كل شاشة)
        final v = MediaQueryData.fromView(View.of(context));
        final bottom = (v.viewPadding.bottom - v.viewInsets.bottom).clamp(0.0, 200.0);
        final mq = MediaQuery.of(context);
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: MediaQuery(
            data: mq.copyWith(padding: mq.padding.copyWith(bottom: 0), viewPadding: mq.viewPadding.copyWith(bottom: 0)),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: UpdateGate(child: child ?? const SizedBox.shrink()),
            ),
          ),
        );
      },
      navigatorKey: navKey,
      // على الويب قد يكون المسار /username؛ نبدأ دائمًا من الشاشة الأولى ثم نفتح الصنايعي منها
      home: const SplashScreen(),
      onGenerateInitialRoutes: (_) => [MaterialPageRoute(builder: (_) => const SplashScreen())],
    );
  }
}

/// عند الانتقال بين الشاشات نُنهي التركيز حتى لا يعود الكيبورد وحده عند الرجوع
class _UnfocusObserver extends NavigatorObserver {
  void _clear() => FocusManager.instance.primaryFocus?.unfocus();
  @override
  void didPush(Route route, Route? previousRoute) => _clear();
  @override
  void didPop(Route route, Route? previousRoute) => _clear();
}
