import 'package:flutter/material.dart';
import '../core.dart';
import '../push.dart';
import '../theme.dart';
import 'requests.dart';
import 'login.dart';
import 'register.dart';
import 'dashboard.dart';
import 'about.dart';
import 'location.dart';
import 'notifications.dart';

/// زر القائمة (ثلاث خطوط) يفتح القائمة الجانبية للصفحة الحالية
class MenuBtn extends StatelessWidget {
  const MenuBtn({super.key});
  @override
  Widget build(BuildContext context) => Builder(
        builder: (c) => IconButton(icon: const Icon(Icons.menu_rounded, size: 28), onPressed: () => Scaffold.of(c).openDrawer()),
      );
}

/// شريط علوي موحّد: سهم رجوع + عنوان + زر القائمة
AppBar bar(String title, {List<Widget> actions = const [], bool menu = true, bool bell = true}) => AppBar(
      automaticallyImplyLeading: false,
      leading: const BackButton(),
      title: Text(title),
      actions: [...actions, if (bell) const BellBtn(), if (menu) const MenuBtn()],
    );

/// جرس الرسائل للصنايعي المسجّل، وعليه عدّاد أحمر للرسائل غير المقروءة
class BellBtn extends StatelessWidget {
  final bool light;
  const BellBtn({super.key, this.light = false});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) {
        if (!Store.loggedIn) return const SizedBox.shrink();
        return ValueListenableBuilder<int>(
          valueListenable: Store.unread,
          builder: (ctx, n, ___) => IconButton(
            tooltip: 'الرسائل',
            onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            icon: Stack(clipBehavior: Clip.none, children: [
              Icon(n > 0 ? Icons.mark_email_unread_rounded : Icons.mail_outline_rounded, size: 27, color: light ? Colors.white : null),
              if (n == 0)
                ValueListenableBuilder<bool>(
                  valueListenable: Push.allowed,
                  builder: (_, ok, __) => ok ? const SizedBox.shrink() : Positioned(top: -1, right: -1, child: Container(width: 11, height: 11, decoration: BoxDecoration(color: const Color(0xFFF59E0B), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
                ),
              if (n > 0)
                Positioned(
                  top: -5, right: -5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white, width: 1.5)),
                    alignment: Alignment.center,
                    child: Text(n > 99 ? '99+' : '$n', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.1)),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
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
        child: Column(children: [
          Expanded(child: ListView(padding: EdgeInsets.zero, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/icon.png', width: 44, height: 44)),
              const SizedBox(width: 10),
              const Expanded(child: Text('صنايعي قريب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'إغلاق', onPressed: () => Navigator.pop(context)),
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
        ])),
          if (Store.loggedIn) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: C.red),
              title: const Text('تسجيل الخروج', style: TextStyle(color: C.red, fontWeight: FontWeight.w600)),
              onTap: () async {
                final nav = Navigator.of(context);
                final root = navKey.currentContext ?? context;
                nav.pop();
                final ok = await showDialog<bool>(
                  context: root,
                  builder: (dctx) => AlertDialog(
                    title: const Text('تسجيل الخروج'),
                    content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('إلغاء')),
                      FilledButton(style: FilledButton.styleFrom(backgroundColor: C.red), onPressed: () => Navigator.pop(dctx, true), child: const Text('خروج')),
                    ],
                  ),
                );
                if (ok != true) return;
                await Store.signOut();
                nav.popUntil((r) => r.isFirst);
              },
            ),
          ],
        ]),
      ),
    );
  }
}
