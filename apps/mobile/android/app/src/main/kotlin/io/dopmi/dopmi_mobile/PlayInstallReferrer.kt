package com.mycompany.dopmi

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
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
            readPlayInstallReferrer(context, result, call.argument<Boolean>("diagnostics") == true)
        } else {
            result.notImplemented()
        }
    }
}

private enum class PlayReferrerDiagnostic {
    OK, FEATURE_NOT_SUPPORTED, DEVELOPER_ERROR, TRANSIENT, TIMEOUT,
    READ_ERROR, DISCONNECTED, CONNECT_ERROR,
}

private fun readPlayInstallReferrer(
    context: Context,
    result: MethodChannel.Result,
    diagnostics: Boolean,
) {
    val client = InstallReferrerClient.newBuilder(context).build()
    val main = Handler(Looper.getMainLooper())
    var finished = false
    lateinit var timeout: Runnable

    fun diagnose(state: PlayReferrerDiagnostic) {
        if (diagnostics) runCatching { Log.i("DopmiAcquisition", "native=${state.name}") }
    }

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

    timeout = Runnable {
        diagnose(PlayReferrerDiagnostic.TIMEOUT)
        finish(retryable = true)
    }
    main.postDelayed(timeout, 5000)
    try {
        client.startConnection(object : InstallReferrerStateListener {
            override fun onInstallReferrerSetupFinished(responseCode: Int) {
                main.post {
                    if (finished) return@post
                    when (responseCode) {
                        InstallReferrerClient.InstallReferrerResponse.OK -> {
                            diagnose(PlayReferrerDiagnostic.OK)
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
                                diagnose(PlayReferrerDiagnostic.READ_ERROR)
                                finish(retryable = true)
                            }
                        }
                        InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED -> {
                            diagnose(PlayReferrerDiagnostic.FEATURE_NOT_SUPPORTED)
                            finish()
                        }
                        InstallReferrerClient.InstallReferrerResponse.DEVELOPER_ERROR -> {
                            diagnose(PlayReferrerDiagnostic.DEVELOPER_ERROR)
                            finish()
                        }
                        else -> {
                            diagnose(PlayReferrerDiagnostic.TRANSIENT)
                            finish(retryable = true)
                        }
                    }
                }
            }

            override fun onInstallReferrerServiceDisconnected() {
                main.post {
                    if (!finished) {
                        diagnose(PlayReferrerDiagnostic.DISCONNECTED)
                        finish(retryable = true)
                    }
                }
            }
        })
    } catch (_: Exception) {
        diagnose(PlayReferrerDiagnostic.CONNECT_ERROR)
        finish(retryable = true)
    }
}
