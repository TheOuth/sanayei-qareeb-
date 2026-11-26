import 'package:audioplayers/audioplayers.dart';

/// أصوات داخل التطبيق (عند وصول إشعار والتطبيق مفتوح). أي خطأ يُتجاهل.
class Sfx {
  static final AudioPlayer _p = AudioPlayer();
  static Future<void> _play(String f) async {
    try {
      await _p.stop();
      await _p.play(AssetSource('sounds/$f'), volume: 1.0);
    } catch (_) {}
  }

  static Future<void> chime() => _play('sq_chime.mp3');
  static Future<void> request() => _play('sq_request.mp3');

  /// حسب نوع الإشعار: طلب خدمة أو قبولها => الصوت الأعلى
  static Future<void> forKind(String kind) => (kind == 'request' || kind == 'client_accept') ? request() : chime();
}
