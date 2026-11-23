import 'dart:async';
import 'package:flutter/material.dart';
import '../push.dart';
import '../theme.dart';
import 'home.dart';

/// شاشة البداية: الشعار ثم الاسم ثم العبارة، ثم تنتقل للرئيسية بتلاشٍ هادئ.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300))..forward();
  Timer? _t;

  Animation<double> _iv(double a, double b, [Curve k = Curves.easeOutCubic]) => CurvedAnimation(parent: _c, curve: Interval(a, b, curve: k));

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 2600), _go);
  }

  void _go() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => const HomeScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
    Push.openInitial();
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = _iv(0, .35, Curves.easeOutBack);
    final name = _iv(.25, .55);
    final tag1 = _iv(.5, .75);
    final tag2 = _iv(.65, .9);
    Widget rise(Animation<double> a, Widget child) => AnimatedBuilder(
          animation: a,
          builder: (_, __) => Opacity(opacity: a.value.clamp(0, 1), child: Transform.translate(offset: Offset(0, 14 * (1 - a.value)), child: child)),
        );
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0F3A68), Color(0xFF1F6FD0), Color(0xFF2B8CF0)])),
        child: SafeArea(
          child: Column(children: [
            const Spacer(flex: 5),
            AnimatedBuilder(
              animation: logo,
              builder: (_, __) => Opacity(
                opacity: logo.value.clamp(0, 1),
                child: Transform.scale(
                  scale: .7 + .3 * logo.value,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(34), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 30, offset: const Offset(0, 12))]),
                    child: ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.asset('assets/icon.png', width: 104, height: 104)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            rise(name, const Text('صنايعي قريب', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: .3))),
            const SizedBox(height: 18),
            rise(tag1, Text('داير صنايعي؟   انت صنايعي؟', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(.92), fontSize: 17, height: 1.6))),
            rise(tag2, const Text('انت في المكان المناسب', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFD66B), fontSize: 19, fontWeight: FontWeight.w800, height: 1.8))),
            const Spacer(flex: 6),
            rise(tag2, SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white.withOpacity(.7)))),
            const SizedBox(height: 36),
          ]),
        ),
      ),
    );
  }
}
