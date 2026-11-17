package com.mycompany.dopmi

import android.os.Build
import androidx.core.content.pm.PackageInfoCompat
import com.google.android.gms.ads.identifier.AdvertisingIdClient
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.util.Locale

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(
            messenger,
            "io.dopmi.app/meta_ads_measurement",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler { call, result ->
            if (call.method == "getAdvertisingContext") {
                result.success(advertisingContext())
            } else {
                result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun advertisingContext(): Map<String, Any>? {
        return try {
            val info = AdvertisingIdClient.getAdvertisingIdInfo(applicationContext)
            val id = info.id?.lowercase(Locale.ROOT)
            if (info.isLimitAdTrackingEnabled || id == null ||
                id == "00000000-0000-0000-0000-000000000000" || !advertisingIdPattern.matches(id)
            ) return null
            val app = packageManager.getPackageInfo(packageName, 0)
            val version = app.versionName ?: return null
            val build = PackageInfoCompat.getLongVersionCode(app)
            if (version.isBlank() || build <= 0 || Build.VERSION.RELEASE.isBlank()) return null
            mapOf(
                "advertising_id" to id,
                "os_version" to Build.VERSION.RELEASE,
                "app_version" to version,
                "app_build" to build,
            )
        } catch (_: Exception) {
            null
        }
    }

    private companion object {
        val advertisingIdPattern =
            Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
    }
}
