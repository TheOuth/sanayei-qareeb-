import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core.dart';
import 'theme.dart';

/// رقم النسخة المثبّتة (build number) — يُحمَّل مرة واحدة
class AppVersion {
  static int build = 0;
  static String name = '';
  static Future<void> load() async {
    try {
      final i = await PackageInfo.fromPlatform();
      build = int.tryParse(i.buildNumber) ?? 0;
      name = i.version;
    } catch (_) {}
  }
}

/// يمنع استخدام التطبيق إذا كانت النسخة أقل من الحد الأدنى الذي يضعه المدير،
/// ويعرض تنبيهًا يمكن تجاوزه عند وجود نسخة أحدث.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  bool _softHidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Meta.refresh().then((_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) Meta.refresh().then((_) { if (mounted) setState(() {}); });
  }

  int _n(String k) => int.tryParse((Meta.cfg[k] ?? '0').toString()) ?? 0;
  String get _url {
    final u = (Meta.cfg['update_url'] ?? '').toString();
    return u.isNotEmpty ? u : 'https://github.com/TheOuth/sanayei-qareeb-/releases/latest/download/sanayei-qareeb-native.apk';
  }

  Future<void> _open() => launchUrl(Uri.parse(_url), mode: LaunchMode.externalApplication);

  bool get _forced => AppVersion.build > 0 && _n('min_build') > AppVersion.build;
  bool get _soft {
    if (AppVersion.build <= 0 || _softHidden) return false;
    final last = _n('latest_build');
    if (last <= AppVersion.build) return false;
    return Store.p.getInt('upd_seen') != last;
  }

  @override
  Widget build(BuildContext context) {
    // التحديث الإجباري والتنبيه للتطبيق فقط، والموقع يتحدث تلقائيًا
    if (kIsWeb) return widget.child;
    final msg = (Meta.cfg['update_msg'] ?? '').toString();
    return Stack(children: [
      widget.child,
      if (_forced)
        Positioned.fill(
          child: Material(
            color: Colors.white,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Image.asset('assets/icon.png', width: 96, height: 96),
                  const SizedBox(height: 20),
                  const Text('يلزم تحديث التطبيق', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.navy)),
                  const SizedBox(height: 10),
                  Text(msg.isNotEmpty ? msg : 'هذه النسخة قديمة ولم تعد مدعومة. حمّل النسخة الجديدة لتواصل استخدام التطبيق، وبياناتك محفوظة.', textAlign: TextAlign.center, style: const TextStyle(height: 1.7, color: C.mute)),
                  const SizedBox(height: 24),
                  FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), onPressed: _open, icon: const Icon(Icons.system_update_rounded), label: const Text('تحديث الآن')),
                ]),
              ),
            ),
          ),
        )
      else if (_soft)
        Positioned(
          left: 12, right: 12, bottom: 12,
          child: SafeArea(
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: C.navy,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('نسخة جديدة متوفرة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(msg.isNotEmpty ? msg : 'تحديث فيه تحسينات وإصلاحات.', style: const TextStyle(color: Colors.white70, height: 1.5)),
                  const SizedBox(height: 10),
                  Row(children: [
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.navy), onPressed: _open, child: const Text('تحديث')),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      onPressed: () async {
                        await Store.p.setInt('upd_seen', _n('latest_build'));
                        if (mounted) setState(() => _softHidden = true);
                      },
                      child: const Text('لاحقًا'),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}
