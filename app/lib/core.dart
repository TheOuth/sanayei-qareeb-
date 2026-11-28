import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// مفتاح الملاحة العام (للتنقل من الإشعارات)
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

/// يتتبّع الصفحات المفتوحة حتى لا تتكدّس نسخ مكرّرة من نفس الصفحة فوق بعضها
final List<Route> openRoutes = [];

class RouteTracker extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) => openRoutes.add(route);
  @override
  void didPop(Route route, Route? previousRoute) => openRoutes.remove(route);
  @override
  void didRemove(Route route, Route? previousRoute) => openRoutes.remove(route);
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (oldRoute != null) openRoutes.remove(oldRoute);
    if (newRoute != null) openRoutes.add(newRoute);
  }
}

/// يفتح صفحة؛ وإن كانت مفتوحة أصلًا في الخلف يرجع إليها بدل فتح نسخة جديدة فوقها.
/// بهذا يرجع زر «رجوع» خطوة واحدة منطقية ثم إلى الرئيسية.
Future<void> openPage(String name, Widget Function() build) async {
  final nav = navKey.currentState;
  if (nav == null) return;
  if (openRoutes.any((r) => r.settings.name == name)) {
    nav.popUntil((r) => r.settings.name == name);
    return;
  }
  await nav.push(MaterialPageRoute(settings: RouteSettings(name: name), builder: (_) => build()));
}

/// إعدادات الخادم: غيّر هذين السطرين (أو مرّرهما وقت البناء) لنقل التطبيق لخادم آخر.
/// flutter build apk --dart-define=API_URL=https://... --dart-define=API_KEY=...
class Config {
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://pwqtvixjkpvyajqmfqpa.supabase.co');
  static const apiKey = String.fromEnvironment('API_KEY', defaultValue: 'sb_publishable_sFHW2864oPilfQvjs3txaA__QjKY0sG');
  static const siteUrl = 'https://saqapp.net/sanayei';
  static const commissionNote = 5000;
}

class ApiError implements Exception {
  final String code;
  ApiError(this.code);
  @override
  String toString() => code;
}

/// حدود السعر التي تضعها الإدارة (من إعدادات التطبيق)
int get priceFloor => ((Meta.cfg['price_floor'] ?? 10000) as num).toInt();
int get priceCap => ((Meta.cfg['price_cap'] ?? 1000000) as num).toInt();
String _n(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
String priceRangeMsg() => 'السعر يجب أن يكون بين ${_n(priceFloor)} و${_n(priceCap)} جنيه';

String errMsg(Object e) {
  final c = e is ApiError ? e.code : e.toString();
  if (c.contains('price_range')) return priceRangeMsg();
  const m = {
    'forbidden': 'غير مسموح. سجّل الدخول من جديد',
    'invalid_phone': 'رقم الهاتف غير صحيح',
    'weak': 'كلمة السر قصيرة (6 أحرف على الأقل)',
    'phone_taken': 'هذا الرقم مسجّل من قبل. سجّل الدخول بدل إنشاء حساب جديد',
    'email_taken': 'هذا البريد مسجّل من قبل. سجّل الدخول',
    'already_provider': 'حسابك مسجّل كصنايعي من قبل',
    'birth_required': 'تاريخ الميلاد مطلوب',
    'invalid_birth': 'تاريخ الميلاد غير صحيح',
    'underage': 'التطبيق لمن هم 18 سنة فأكثر',
    'rate_limited': 'محاولات كثيرة في وقت قصير. حاول بعد قليل',
    'upload_failed': 'تعذّر رفع الصورة، حاول مرة أخرى',
    'too_big': 'الصورة كبيرة جدًا',
    'wait': 'انتظر دقيقة ثم أعد إرسال الرمز',
    'limit': 'وصلت للحد اليومي لإرسال الرموز، حاول غدًا',
    'not_configured': 'خدمة البريد غير مفعّلة بعد',
    'send_failed': 'تعذّر إرسال البريد، تأكد من العنوان وحاول لاحقًا',
    'no_email': 'احفظ بريدك أولًا',
    'unavailable': 'الصنايعي غير متاح الآن',
    'too_many_pending': 'لديك 5 طلبات بانتظار الرد. انتظر ردّ أحدهم',
    'daily_limit': 'وصلت للحد اليومي للطلبات، حاول غدًا',
    'already_today': 'اعتذر هذا الصنايعي عن طلبك اليوم',
    'not_accepted': 'لم يقبل الصنايعي هذا الطلب',
    'banned_contact': 'لا يمكن استخدام هذه البيانات لأن حسابًا مرتبطًا بها محظور. تواصل مع الدعم',
    'appeal_pending': 'لديك طعن قيد المراجعة',
    'appeal_wait': 'يمكنك تقديم طعن جديد بعد 3 أيام من الرد على طعنك السابق',
    'self_request': 'لا يمكنك طلب خدمتك من نفسك',
    'state_closed': 'الخدمة غير متاحة حاليًا في هذه الولاية',
    'invalid_price': 'أعلى سعر يجب ألا يقل عن أدنى سعر',
    'no_verified_email': 'وثّق بريدك أولًا من تعديل الملف',
    'invalid_email': 'البريد الإلكتروني غير صحيح',
    'invalid_username': 'اسم المستخدم: حروف إنجليزية وأرقام (3 إلى 20) ويبدأ بحرف',
    'taken': 'اسم المستخدم مستخدم، جرّب غيره',
    'reserved': 'هذا الاسم محجوز للإدارة، اختر اسمًا آخر',
    'already': 'تم هذا الإجراء من قبل',
    'duplicate': 'هذا الرقم مسجّل من قبل',
    'invalid': 'بيانات غير صحيحة',
    'not_found': 'غير موجود',
    'locked': 'تم إيقاف الدخول مؤقتًا. حاول بعد 15 دقيقة',
    'no_password': 'لا توجد كلمة سر لهذا الحساب',
  };
  if (c.startsWith('not_configured:')) {
    final parts = c.substring(15).split('|');
    return 'خدمة البريد غير مفعّلة. لم يُضبط في Supabase: ${parts[0]}${parts.length > 1 && parts[1].isNotEmpty ? ' (الموجود عندك: ${parts[1]})' : ''}';
  }
  if (c.startsWith('send_failed:')) {
    final st = c.substring(12);
    if (st == '401') return 'Brevo رفض المفتاح: تأكد من المفتاح وأن تقييد عناوين IP مغلق';
    if (st == '400') return 'Brevo رفض الإرسال: غالبًا عنوان المرسِل غير موثّق عندهم';
    return 'تعذّر إرسال البريد (رمز $st)';
  }
  if (m.containsKey(c)) return m[c]!;
  if (c.contains('SocketException') || c.contains('ClientException') || c.contains('Failed host')) return 'لا يوجد اتصال بالإنترنت';
  if (c.contains('TimeoutException')) return 'الاتصال بطيء، حاول مرة أخرى';
  return 'حدث خطأ، حاول مرة أخرى';
}

class Api {
  static Future<dynamic> rpc(String fn, [Map<String, dynamic>? args]) async {
    final r = await http
        .post(Uri.parse('${Config.apiUrl}/rest/v1/rpc/$fn'),
            headers: {'Content-Type': 'application/json', 'apikey': Config.apiKey},
            body: jsonEncode(args ?? {}))
        .timeout(const Duration(seconds: 25));
    dynamic data;
    try {
      data = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    if (r.statusCode >= 300) {
      var m = (data is Map ? (data['message'] ?? data['hint']) : null)?.toString() ?? 'HTTP ${r.statusCode}';
      if (m.contains('duplicate key')) m = 'duplicate';
      throw ApiError(m);
    }
    return data;
  }
}


Future<dynamic> callFunction(String name, Map<String, dynamic> body) async {
  final r = await http
      .post(Uri.parse('${Config.apiUrl}/functions/v1/$name'),
          headers: {'Content-Type': 'application/json', 'apikey': Config.apiKey}, body: jsonEncode(body))
      .timeout(const Duration(seconds: 30));
  dynamic data;
  try {
    data = jsonDecode(utf8.decode(r.bodyBytes));
  } catch (_) {}
  if (r.statusCode >= 300) {
    final e = (data is Map ? data['error'] : null)?.toString() ?? 'failed';
    if (e == 'not_configured' && data is Map) throw ApiError('not_configured:${(data['missing'] as List?)?.join(',') ?? ''}|${(data['seen'] as List?)?.join(',') ?? ''}');
    if (e == 'send_failed' && data is Map) throw ApiError('send_failed:${data['status'] ?? ''}');
    throw ApiError(e);
  }
  return data;
}

/// تخزين محلي بسيط (هوية الجهاز، جلسة الصنايعي، آخر موقع، كاش خفيف)
class Store {
  static late SharedPreferences p;
  static final ValueNotifier<int> tick = ValueNotifier(0);
  static final ValueNotifier<int> unread = ValueNotifier(0);

  static Future<void> refreshUnread() async {
    if (!loggedIn) {
      unread.value = 0;
      return;
    }
    try {
      final c = await Api.rpc('provider_notif_count', {'p_id': pid, 'p_token': token});
      unread.value = (c is num) ? c.toInt() : 0;
    } catch (_) {}
  }
  /// حالة «طلباتي» للزبون بلا حساب: [هل لديه طلبات؟ 1/0، عدد الردود الجديدة، عدد المعلّقة]
  static final ValueNotifier<List<int>> reqInfo = ValueNotifier([0, 0, 0]);

  static Map<String, dynamic> _seenReqs() {
    try {
      final s = p.getString('req_seen');
      if (s != null) return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {}
    return {};
  }

  /// يحدّث عدّاد ردود الصنايعية على طلبات هذا الجهاز (قبول/اعتذار لم يرها الزبون بعد)
  static Future<void> refreshReqBadge() async {
    try {
      final r = await Api.rpc('my_requests', {'p_anon': anon}) as List;
      final first = !p.containsKey('req_seen');
      final seen = _seenReqs();
      var badge = 0, pend = 0;
      final cutoff = DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch;
      for (final x in r) {
        final a = (x['accept'] ?? '').toString();
        if (a == 'pending') {
          pend++;
        } else if ((a == 'accepted' || a == 'declined') && (x['ts'] as int) > cutoff && seen[x['id'].toString()] != a) {
          badge++;
        }
      }
      if (first) {
        await markReqsSeen(r);
        badge = 0;
      }
      reqInfo.value = [r.isEmpty ? 0 : 1, badge, pend];
    } catch (_) {}
  }

  /// يُستدعى عند فتح «طلباتي»: كل ما فيها صار مقروءًا
  static Future<void> markReqsSeen(List r) async {
    final m = <String, String>{for (final x in r) x['id'].toString(): (x['accept'] ?? '').toString()};
    await p.setString('req_seen', jsonEncode(m));
    reqInfo.value = [r.isEmpty ? 0 : 1, 0, r.where((x) => x['accept'] == 'pending').length];
  }

  static Future<void> init() async => p = await SharedPreferences.getInstance();

  static String get anon {
    var a = p.getString('anon');
    if (a == null) {
      final r = Random.secure();
      a = 'a' + List.generate(24, (_) => r.nextInt(36).toRadixString(36)).join();
      p.setString('anon', a);
    }
    return a;
  }

  static String? get pid => p.getString('pid');
  static String? get token => p.getString('token');
  static bool get loggedIn => pid != null && token != null;
  // الحساب الموحّد (عميل أو صنايعي)
  static String? get aid => p.getString('aid');
  static String? get atoken => p.getString('atoken');
  static bool get hasAccount => (aid != null && atoken != null) || loggedIn;
  static String get aName => p.getString('a_name') ?? '';
  static String get aPhone => p.getString('a_phone') ?? '';
  static bool get accountNeedsPhone => aid != null && aPhone.isEmpty;

  /// نتيجة account_login / account_register
  static Future<void> signInAccount(Map r) async {
    await p.setString('aid', r['account_id'].toString());
    await p.setString('atoken', r['account_token'].toString());
    await p.setString('a_name', (r['name'] ?? '').toString());
    await p.setString('a_phone', (r['phone'] ?? '').toString());
    if (r['provider_id'] != null && r['provider_token'] != null) {
      await signIn(r['provider_id'].toString(), r['provider_token'].toString());
    } else {
      await p.remove('pid');
      await p.remove('token');
      tick.value++;
    }
  }
  /// آخر رقم دخل به الصنايعي (يبقى بعد تسجيل الخروج لتسهيل الدخول القادم)
  static String get lastPhone => p.getString('last_phone') ?? '';
  static Future<void> setLastPhone(String v) => p.setString('last_phone', v);

  static Future<void> signIn(String id, String t) async {
    await p.setString('pid', id);
    await p.setString('token', t);
    tick.value++;
    refreshUnread();
  }

  /// يُضبط من خدمة الإشعارات لإلغاء ربط الجهاز عند الخروج
  static Future<void> Function()? onSignOut;

  static Future<void> signOut() async {
    try {
      await onSignOut?.call();
    } catch (_) {}
    await p.remove('pid');
    await p.remove('token');
    await p.remove('aid');
    await p.remove('atoken');
    await p.remove('a_name');
    await p.remove('a_phone');
    await p.remove('me_photo');
    await p.remove('me_name');
    unread.value = 0;
    tick.value++;
  }

  static String get mePhoto => p.getString('me_photo') ?? '';
  static String get meName => p.getString('me_name') ?? '';
  static Future<void> setMe(String name, String photo) async {
    await p.setString('me_name', name);
    await p.setString('me_photo', photo);
    tick.value++;
  }

  static Future<void> refreshMe() async {
    try {
      final me = await Api.rpc('provider_self', {'p_id': pid, 'p_token': token});
      await setMe((me['name'] ?? '').toString(), (me['photo'] ?? '').toString());
    } catch (_) {}
  }

  static Map<String, dynamic>? get loc {
    final s = p.getString('loc');
    return s == null ? null : (jsonDecode(s) as Map<String, dynamic>);
  }

  static Future<void> setLoc(Map<String, dynamic>? l) async {
    if (l == null) {
      await p.remove('loc');
    } else {
      await p.setString('loc', jsonEncode(l));
    }
  }

  static Future<void> cachePut(String k, dynamic v) async => p.setString('c_$k', jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'v': v}));
  static dynamic cacheGet(String k, {int maxAgeMin = 1 << 30}) {
    final s = p.getString('c_$k');
    if (s == null) return null;
    final o = jsonDecode(s);
    if (DateTime.now().millisecondsSinceEpoch - (o['t'] as int) > maxAgeMin * 60000) return null;
    return o['v'];
  }
}

class City {
  final String id, name;
  final double lat, lng;
  City(this.id, this.name, this.lat, this.lng);
}

class StateG {
  final String id, name;
  final List<City> cities;
  StateG(this.id, this.name, this.cities);
}

class Category {
  final String id, name, icon;
  final int color;
  Category(this.id, this.name, this.icon, this.color);
}

class Service {
  final String id, name, icon, cat;
  Service(this.id, this.name, this.icon, this.cat);
}

class Meta {
  static List<StateG> states = [];
  static List<Category> cats = [];
  static List<Service> services = [];
  static Map<String, String> keywords = {};
  static Map<String, dynamic> cfg = {};
  static Map<String, dynamic> legal = {};

  static Future<void> load() async {
    final g = jsonDecode(await rootBundle.loadString('assets/geo.json')) as List;
    states = g
        .map((s) => StateG(s['id'], s['name'],
            (s['cities'] as List).map((c) => City(c['id'], c['name'], (c['lat'] as num).toDouble(), (c['lng'] as num).toDouble())).toList()))
        .toList();
    final m = jsonDecode(await rootBundle.loadString('assets/meta.json'));
    cats = (m['categories'] as List)
        .map((c) => Category(c['id'], c['name'], c['icon'], int.parse('FF${(c['color'] as String).substring(1)}', radix: 16)))
        .toList();
    keywords = Map<String, String>.from(m['keywords'] as Map);
    _setServices(m['services'] as List, fromAsset: true);
    // الخدمات المحدّثة من الخادم (كاش ثم تحديث في الخلفية)
    final c = Store.cacheGet('services');
    if (c != null) _setServices(c as List);
    final cc = Store.cacheGet('cfg');
    if (cc is Map) cfg = Map<String, dynamic>.from(cc);
  }

  /// الولايات التي أغلقتها الإدارة مؤقتًا
  static Set<String> get closedStates => (cfg['closed_states'] ?? '').toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  static bool stateClosed(String id) => closedStates.contains(id);

  static void _setServices(List l, {bool fromAsset = false}) {
    final out = <Service>[];
    for (final s in l) {
      if (!fromAsset && s['active'] == false) continue;
      var cat = (s['cat'] is String && (s['cat'] as String).isNotEmpty) ? s['cat'] as String : 'other';
      if (fromAsset && s['cat'] is Map) cat = (s['cat'] as Map)['id'] as String;
      out.add(Service(s['id'], s['name'], s['icon'] ?? '', cat));
    }
    if (out.isNotEmpty) services = out;
  }

  static Future<void> refresh() async {
    try {
      final r = await Api.rpc('list_services') as List;
      await Store.cachePut('services', r);
      _setServices(r);
    } catch (_) {}
    try {
      final c = await Api.rpc('app_config');
      if (c is Map) cfg = Map<String, dynamic>.from(c);
      await Store.cachePut('cfg', cfg);
    } catch (_) {
      final c = Store.cacheGet('cfg');
      if (c is Map) cfg = Map<String, dynamic>.from(c);
    }
    // نصوص الشروط والخصوصية التي يحررها المدير (تظهر بلا تحديث للتطبيق)
    try {
      final l = await Api.rpc('legal_texts');
      if (l is Map) {
        legal = Map<String, dynamic>.from(l);
        await Store.cachePut('legal', legal);
      }
    } catch (_) {
      final l = Store.cacheGet('legal');
      if (l is Map) legal = Map<String, dynamic>.from(l);
    }
  }

  static Service? service(String id) {
    for (final s in services) if (s.id == id) return s;
    return null;
  }

  static String serviceName(String id) => service(id)?.name ?? id;

  static Category cat(String id) => cats.firstWhere((c) => c.id == id, orElse: () => cats.last);

  static City? city(String id) {
    for (final s in states) for (final c in s.cities) if (c.id == id) return c;
    return null;
  }

  static String cityName(String id) => city(id)?.name ?? '';
  static StateG? stateOf(String cityId) {
    for (final s in states) for (final c in s.cities) if (c.id == cityId) return s;
    return null;
  }

  static String norm(String s) => s
      .replaceAll(RegExp('[ً-ٟـ]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .toLowerCase()
      .trim();

  static List<Service> search(String q) {
    final n = norm(q);
    if (n.isEmpty) return services;
    return services.where((s) => norm(s.name).contains(n) || norm(keywords[s.id] ?? '').contains(n)).toList();
  }

  /// الشارة بحسب الأعمال المؤكدة فقط (الرمادية تمنحها الإدارة، وتأتي من الخادم في الحقل tier)
  static String tierOf(int jobs) => jobs >= 100 ? 'gold' : (jobs >= 25 ? 'blue' : (jobs >= 5 ? 'green' : ''));
  static String tierName(String t) => const {'gold': 'ذهبية', 'blue': 'زرقاء', 'green': 'خضراء', 'gray': 'رمادية'}[t] ?? '';
  static String tierOfProvider(Map p) {
    final t = (p['tier'] ?? '').toString();
    return t.isNotEmpty ? t : tierOf((p['jobs'] ?? 0) as int);
  }
}

String normalizePhone(String raw) {
  var d = raw.replaceAllMapped(RegExp('[٠-٩]'), (m) => (m[0]!.codeUnitAt(0) - 1632).toString()).replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('00')) d = d.substring(2);
  if (d.startsWith('249')) d = d.substring(3);
  if (d.startsWith('0')) d = d.substring(1);
  return RegExp(r'^[19]\d{8}$').hasMatch(d) ? '+249$d' : '';
}

/// الأرقام التسعة بعد الصفر (للحقل ذي الصفر الثابت)
String phoneBody(String p) {
  final n = normalizePhone(p);
  return n.isEmpty ? '' : n.substring(4);
}

String localPhone(String p) {
  final n = normalizePhone(p);
  return n.isEmpty ? p : '0${n.substring(4)}';
}

/// يحوّل "HH:mm" (24 ساعة) إلى نظام 12 ساعة بصباحًا/مساءً
String t12(dynamic v) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch((v ?? '').toString());
  if (m == null) return (v ?? '').toString();
  final h = int.parse(m.group(1)!);
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.group(2)} ${h < 12 ? 'ص' : 'م'}';
}

/// "من X إلى Y جنيه" أو "X جنيه" عند تساوي السعرين
String priceText(Map p) {
  final a = (p['price'] ?? 0) as int, b = (p['price_max'] ?? 0) as int;
  if (a <= 0 && b <= 0) return '';
  if (b <= a) return '$a جنيه';
  return 'من $a إلى $b جنيه';
}
