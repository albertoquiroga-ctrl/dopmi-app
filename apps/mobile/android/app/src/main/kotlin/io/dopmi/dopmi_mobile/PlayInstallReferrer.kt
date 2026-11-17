package com.mycompany.dopmi

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

internal fun registerPlayInstallReferrer(engine: FlutterEngine, context: Context) {
    MethodChannel(
        engine.dartExecutor.binaryMessenger,
        "io.dopmi.app/play_install_referrer",
    ).setMethodCallHandler { call, result ->
        if (call.method == "read") {
            readPlayInstallReferrer(context, result)
        } else {
            result.notImplemented()
        }
    }
}

private fun readPlayInstallReferrer(context: Context, result: MethodChannel.Result) {
    val client = InstallReferrerClient.newBuilder(context).build()
    val main = Handler(Looper.getMainLooper())
    var finished = false
    lateinit var timeout: Runnable

    fun finish(details: Map<String, Any>? = null, retryable: Boolean = false) {
        if (finished) return
        finished = true
        main.removeCallbacks(timeout)
        runCatching { client.endConnection() }
        if (retryable) {
            result.error("play_referrer_unavailable", null, null)
        } else {
            result.success(details)
        }
    }

    timeout = Runnable { finish(retryable = true) }
    main.postDelayed(timeout, 5000)
    try {
        client.startConnection(object : InstallReferrerStateListener {
            override fun onInstallReferrerSetupFinished(responseCode: Int) {
                main.post {
                    if (finished) return@post
                    when (responseCode) {
                        InstallReferrerClient.InstallReferrerResponse.OK -> {
                            try {
                                val details = client.installReferrer
                                val serverClick = details.referrerClickTimestampServerSeconds
                                val serverInstall = details.installBeginTimestampServerSeconds
                                // Compare both timestamps from the same clock.
                                val useServerTime = serverClick > 0 && serverInstall > 0
                                finish(
                                    mapOf(
                                        "referrer" to details.installReferrer,
                                        "clickedAtSeconds" to if (useServerTime) {
                                            serverClick
                                        } else {
                                            details.referrerClickTimestampSeconds
                                        },
                                        "installedAtSeconds" to if (useServerTime) {
                                            serverInstall
                                        } else {
                                            details.installBeginTimestampSeconds
                                        },
                                    ),
                                )
                            } catch (_: Exception) {
                                finish(retryable = true)
                            }
                        }
                        InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED,
                        InstallReferrerClient.InstallReferrerResponse.DEVELOPER_ERROR -> finish()
                        else -> finish(retryable = true)
                    }
                }
            }

            override fun onInstallReferrerServiceDisconnected() {
                main.post { finish(retryable = true) }
            }
        })
    } catch (_: Exception) {
        finish(retryable = true)
    }
}
