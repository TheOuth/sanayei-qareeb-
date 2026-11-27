import 'dart:async';
import 'package:flutter/widgets.dart';
import 'core.dart';

/// نبضة حضور: طالما التطبيق مفتوح على الشاشة يُحدَّث «آخر ظهور» للصنايعي المسجّل كل دقيقتين،
/// فيظهر «نشط الآن» للجميع، وعند إغلاق التطبيق يتحول إلى «آخر ظهور قبل X».
class Presence with WidgetsBindingObserver {
  static final Presence _i = Presence._();
  Presence._();
  static Timer? _t;

  static void start() {
    WidgetsBinding.instance.addObserver(_i);
    Store.tick.addListener(ping);
    _run();
  }

  static void _run() {
    _t?.cancel();
    ping();
    _t = Timer.periodic(const Duration(minutes: 2), (_) => ping());
  }

  static Future<void> ping() async {
    if (!Store.loggedIn) return;
    try {
      await Api.rpc('provider_ping', {'p_id': Store.pid, 'p_token': Store.token});
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _run();
    } else if (s == AppLifecycleState.paused || s == AppLifecycleState.detached) {
      _t?.cancel();
    }
  }
}
