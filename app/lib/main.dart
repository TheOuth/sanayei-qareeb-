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
  await Store.init();
  await Onboarding.init();
  await Meta.load();
  await AppVersion.load();
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
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: UpdateGate(child: child ?? const SizedBox.shrink()),
      ),
      navigatorKey: navKey,
      home: const SplashScreen(),
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
