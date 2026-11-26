package sd.sanayei.qareeb

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            fun mk(id: String, name: String, res: String) {
                val uri = Uri.parse(ContentResolver.SCHEME_ANDROID_RESOURCE + "://" + packageName + "/raw/" + res)
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                val ch = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH)
                ch.setSound(uri, attrs)
                ch.enableVibration(true)
                nm.createNotificationChannel(ch)
            }
            mk("sq_alerts", "إشعارات عامة", "sq_chime")
            mk("sq_request", "الطلبات والقبول", "sq_request")
        }
    }
}
