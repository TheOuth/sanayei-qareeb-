import 'package:flutter/material.dart';
import '../core.dart';
import '../theme.dart';
import 'requests.dart';
import 'login.dart';
import 'register.dart';
import 'dashboard.dart';
import 'about.dart';
import 'location.dart';

/// زر القائمة (ثلاث خطوط) يفتح القائمة الجانبية للصفحة الحالية
class MenuBtn extends StatelessWidget {
  const MenuBtn({super.key});
  @override
  Widget build(BuildContext context) => Builder(
        builder: (c) => IconButton(icon: const Icon(Icons.menu_rounded, size: 28), onPressed: () => Scaffold.of(c).openDrawer()),
      );
}

class AppDrawer extends StatelessWidget {
  /// home | requests | dash | login | register | about
  final String current;
  final Future<void> Function()? onLocation;
  const AppDrawer({super.key, required this.current, this.onLocation});

  void _go(BuildContext context, String key, Widget Function() build) {
    Navigator.pop(context); // يغلق القائمة
    if (key == current) return;
    if (key == 'home') {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    final route = MaterialPageRoute(builder: (_) => build());
    if (current == 'home') {
      Navigator.push(context, route);
    } else {
      Navigator.pushReplacement(context, route);
    }
  }

  Widget _item(BuildContext context, String key, IconData icon, String title, {Widget Function()? build, VoidCallback? onTap, String? subtitle}) {
    final on = key == current;
    return Container(
      decoration: BoxDecoration(
        color: on ? const Color(0xFFE3F0FD) : Colors.transparent,
        border: BorderDirectional(end: BorderSide(color: on ? C.blue : Colors.transparent, width: 5)),
      ),
      child: ListTile(
        leading: Icon(icon, color: on ? C.blue : C.mute),
        title: Text(title, style: TextStyle(fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? C.blue : C.ink)),
        subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 11)),
        onTap: onTap ?? () => _go(context, key, build ?? () => const SizedBox()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(padding: EdgeInsets.zero, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/icon.png', width: 44, height: 44)),
              const SizedBox(width: 10),
              const Text('صنايعي قريب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Divider(height: 1),
          _item(context, 'home', Icons.home_rounded, 'الرئيسية'),
          _item(context, 'requests', Icons.history_rounded, 'طلباتي', build: () => const RequestsScreen()),
          _item(context, 'location', Icons.place_rounded, 'تغيير موقعي', onTap: () async {
            Navigator.pop(context);
            if (onLocation != null) {
              await onLocation!();
            } else {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationScreen()));
            }
          }),
          const Divider(),
          const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 4), child: Text('أنا صنايعي', style: TextStyle(color: C.mute, fontWeight: FontWeight.w600))),
          if (Store.loggedIn)
            _item(context, 'dash', Icons.dashboard_rounded, 'لوحتي', build: () => const DashboardScreen())
          else ...[
            _item(context, 'login', Icons.login_rounded, 'تسجيل الدخول', build: () => const LoginScreen()),
            _item(context, 'register', Icons.app_registration_rounded, 'سجّل كصنايعي', subtitle: 'اعرض خدمتك حسب المهارات العندك', build: () => const RegisterScreen()),
          ],
          const Divider(),
          _item(context, 'about', Icons.info_outline_rounded, 'عن التطبيق والدعم', build: () => const AboutScreen()),
        ]),
      ),
    );
  }
}
