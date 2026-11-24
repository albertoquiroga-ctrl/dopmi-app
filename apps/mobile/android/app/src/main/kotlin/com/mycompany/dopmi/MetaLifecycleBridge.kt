package com.mycompany.dopmi

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.pm.PackageInfoCompat
import com.google.android.gms.ads.identifier.AdvertisingIdClient
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/** Called only by the consented lifecycle controller, separately from account CAPI. */
internal class MetaLifecycleBridge(engine: FlutterEngine, context: Context) {
    private val applicationContext = context.applicationContext
    private val session = MetaLifecycleSession()
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(
        engine.dartExecutor.binaryMessenger,
        "io.dopmi.app/meta_lifecycle_measurement",
    )

    init {
        // Keep cancellation on the main thread; a slow Play Services call must
        // not queue withdrawal behind the identifier lookup.
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "cancel" -> {
                    cancel()
                    result.success(null)
                }
                "readContext" -> {
                    val revision = session.snapshot()
                    if (!session.current(revision)) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        val fields = if (session.current(revision)) readContext(revision) else null
                        main.post {
                            result.success(if (session.current(revision)) fields else null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun cancel() {
        session.cancel()
    }

    fun setForeground(value: Boolean) {
        session.setForeground(value)
    }

    fun dispose() {
        cancel()
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
    }

    @Suppress("DEPRECATION")
    private fun readContext(revision: Int): Map<String, Any>? {
        return try {
            val app = applicationContext.packageManager.getPackageInfo(applicationContext.packageName, 0)
            if (!session.current(revision)) return null
            val info = AdvertisingIdClient.getAdvertisingIdInfo(applicationContext)
            if (!session.current(revision)) return null
            metaLifecycleAndroidContext(
                applicationContext.packageName,
                app.versionName ?: "",
                PackageInfoCompat.getLongVersionCode(app),
                Build.VERSION.RELEASE,
                info.id,
                info.isLimitAdTrackingEnabled,
                app.firstInstallTime,
                app.lastUpdateTime,
            )
        } catch (_: Exception) {
            null
        }
    }
}

internal class MetaLifecycleSession {
    private val generation = AtomicInteger()
    private val foreground = AtomicBoolean(false)

    fun snapshot(): Int = generation.get()
    fun current(revision: Int): Boolean = foreground.get() && revision == generation.get()
    fun cancel() { generation.incrementAndGet() }
    fun setForeground(value: Boolean) {
        foreground.set(value)
        if (!value) cancel()
    }
}

/** Pure whitelist/proof policy; no identifier or device context is persisted. */
internal fun metaLifecycleAndroidContext(
    packageName: String,
    appVersion: String,
    appBuild: Long,
    osVersion: String,
    advertisingId: String?,
    limited: Boolean,
    firstInstallTime: Long,
    lastUpdateTime: Long,
): Map<String, Any>? {
    val id = advertisingId?.lowercase(Locale.ROOT) ?: return null
    if (limited || packageName != "com.mycompany.dopmi" ||
        !Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$").matches(id) ||
        id == "00000000-0000-0000-0000-000000000000" || appBuild !in 1..2_100_000_000L ||
        appVersion.length > 24 ||
        !Regex("^[0-9]+(\\.[0-9]+){1,3}([+-][0-9A-Za-z.-]+)?$").matches(appVersion) ||
        !Regex("^[0-9][0-9A-Za-z._+-]{0,23}$").matches(osVersion)
    ) return null
    return mapOf(
        "platform" to "android",
        "package_name" to packageName,
        "advertising_id" to id,
        "tracking_authorized" to true,
        "app_version" to appVersion,
        "app_build" to appBuild,
        "os_version" to osVersion,
        "install_eligible" to (firstInstallTime > 0 && firstInstallTime == lastUpdateTime),
    )
}
