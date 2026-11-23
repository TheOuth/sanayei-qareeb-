import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core.dart';

/// الإشعارات الفورية (FCM). أي خطأ هنا لا يجب أن يوقف التطبيق.
class Push {
  static bool _ready = false;
  static String? _fcm;
  static String _registered = '';

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      await m.subscribeToTopic('all');
      _fcm = await m.getToken();
      _ready = true;
      m.onTokenRefresh.listen((t) {
        _fcm = t;
        _registered = '';
        sync();
      });
      // التطبيق مفتوح: نحدّث عدّاد الجرس فقط (النظام يعرض الإشعار وقت الخلفية)
      FirebaseMessaging.onMessage.listen((_) => Store.refreshUnread());
      Store.tick.addListener(sync);
      Store.onSignOut = _unregister;
      await sync();
    } catch (_) {
      _ready = false;
    }
  }

  /// يربط هذا الجهاز بحساب الصنايعي الحالي
  static Future<void> sync() async {
    if (!_ready || _fcm == null || !Store.loggedIn) return;
    final key = '${Store.pid}|$_fcm';
    if (key == _registered) return;
    try {
      await Api.rpc('register_device', {'p_id': Store.pid, 'p_token': Store.token, 'p_fcm': _fcm});
      _registered = key;
    } catch (_) {}
  }

  static Future<void> _unregister() async {
    if (!_ready || _fcm == null) return;
    try {
      await Api.rpc('unregister_device', {'p_fcm': _fcm});
    } catch (_) {}
    _registered = '';
  }
}
