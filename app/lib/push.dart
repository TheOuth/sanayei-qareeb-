import 'package:app_settings/app_settings.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core.dart';
import 'screens/commission.dart';
import 'screens/dashboard.dart';
import 'screens/notifications.dart';
import 'screens/requests.dart';

/// الإشعارات الفورية (FCM). أي خطأ هنا لا يجب أن يوقف التطبيق.
class Push with WidgetsBindingObserver {
  /// هل إشعارات التطبيق مسموحة؟ (true افتراضيًا حتى نعرف الحالة فلا يومض التنبيه)
  static final ValueNotifier<bool> allowed = ValueNotifier(true);
  static final Push _obs = Push._();
  Push._();
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      refreshStatus();
      Store.refreshReqBadge();
    }
  }

  static Future<void> refreshStatus() async {
    try {
      final st = await FirebaseMessaging.instance.getNotificationSettings();
      allowed.value = st.authorizationStatus == AuthorizationStatus.authorized || st.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {}
  }

  /// يطلب الإذن؛ وإن كان مرفوضًا نهائيًا يفتح إعدادات الإشعارات للتطبيق
  static Future<void> enable() async {
    try {
      final r = await FirebaseMessaging.instance.requestPermission();
      await refreshStatus();
      if (r.authorizationStatus != AuthorizationStatus.authorized && !allowed.value) {
        await AppSettings.openAppSettings(type: AppSettingsType.notification);
      }
    } catch (_) {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    }
  }

  static bool _ready = false;
  static RemoteMessage? _initial;
  static String? _fcm;
  static String _registered = '';

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      WidgetsBinding.instance.addObserver(_obs);
      await refreshStatus();
      await m.subscribeToTopic('all');
      _fcm = await m.getToken();
      _ready = true;
      m.onTokenRefresh.listen((t) {
        _fcm = t;
        _registered = '';
        sync();
      });
      // التطبيق مفتوح: نحدّث عدّاد الجرس فقط (النظام يعرض الإشعار وقت الخلفية)
      FirebaseMessaging.onMessage.listen((_) {
        Store.refreshUnread();
        Store.refreshReqBadge();
      });
      // الضغط على إشعار والتطبيق في الخلفية
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _open((m.data['kind'] ?? '').toString()));
      _initial = await m.getInitialMessage(); // الضغط على إشعار والتطبيق مغلق
      Store.tick.addListener(sync);
      Store.onSignOut = _unregister;
      await sync();
      await syncClient();
    } catch (_) {
      _ready = false;
    }
  }

  /// تُستدعى بعد شاشة البداية لفتح الإشعار الذي بدأ التطبيق
  static void openInitial() {
    final m = _initial;
    _initial = null;
    if (m != null) _open((m.data['kind'] ?? '').toString());
  }

  /// طلب/تأكيد => لوحتي (الطلبات)، وغيرها => الرسائل
  static void _open(String kind) {
    final nav = navKey.currentState;
    if (nav == null) return;
    if (kind != 'client_accept' && !Store.loggedIn) return;
    Store.refreshUnread();
    final goCommission = kind == 'commission';
    final goDash = kind == 'completed' || kind == 'request' || kind == 'confirm' || kind.startsWith('badge');
    nav.push(MaterialPageRoute(builder: (_) => kind == 'client_accept' ? const RequestsScreen() : goCommission ? const CommissionScreen() : goDash ? const DashboardScreen() : const NotificationsScreen()));
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

  /// يربط هذا الجهاز بمعرّف الزبون المجهول ليصله إشعار «قبل طلبك»
  static String _regClient = '';
  static Future<void> syncClient() async {
    if (!_ready || _fcm == null) return;
    final key = '${Store.anon}|$_fcm';
    if (key == _regClient) return;
    try {
      await Api.rpc('register_client_device', {'p_anon': Store.anon, 'p_fcm': _fcm});
      _regClient = key;
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
