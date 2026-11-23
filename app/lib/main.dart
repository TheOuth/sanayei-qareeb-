import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core.dart';
import 'push.dart';
import 'update_gate.dart';
import 'theme.dart';
import 'screens/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  await Meta.load();
  await AppVersion.load();
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
      builder: (context, child) => UpdateGate(child: child ?? const SizedBox.shrink()),
      home: const HomeScreen(),
    );
  }
}
