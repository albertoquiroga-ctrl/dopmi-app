package com.mycompany.dopmi

import android.app.Application
import android.content.Context
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructStat
import java.io.File

/** Keeps optional collection off until Dart restores the current owner's consent. */
class DopmiApplication : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        NativeMeasurementStartup.prepare(base)
    }
}

/** SDK-specific startup boundary; review these bindings when upgrading Firebase. */
internal object NativeMeasurementStartup {
    private const val CONTEXT_PREFERENCES = "dopmi.native_measurement_context.v1"
    private const val CONTEXT_KEY = "google_app_id"
    // FileStore in Crashlytics 20.1.1. Never delete a prefix or filesDir itself.
    private val diagnosticRoots = listOf(".crashlytics.v3", ".com.google.firebase.crashlytics.files.v1")
    private val androidAppId = Regex("1:[0-9]{5,20}:android:[0-9a-fA-F]{16,64}")

    fun prepare(context: Context, applicationId: () -> String = { googleApplicationId(context) }) {
        // attachBaseContext precedes all providers, including FirebaseInitProvider.
        // Manifest defaults lose to the persisted overrides in measurement 23.2.0
        // and Crashlytics 20.1.1. Disable before even reading the project resource.
        // apply updates the in-process preference object immediately. Repeating this
        // before providers in every process also covers an unfinished disk write.
        context.getSharedPreferences("com.google.android.gms.measurement.prefs", Context.MODE_PRIVATE)
            .edit().putBoolean("measurement_enabled", false)
            .putBoolean("measurement_enabled_from_api", false).apply()
        context.getSharedPreferences("com.google.firebase.crashlytics", Context.MODE_PRIVATE)
            .edit().putBoolean("firebase_crashlytics_collection_enabled", false).apply()

        val current = applicationId()
        check(androidAppId.matches(current)) { "Firebase application ID is missing or invalid" }
        val marker = context.getSharedPreferences(CONTEXT_PREFERENCES, Context.MODE_PRIVATE)
        val previous = marker.getString(CONTEXT_KEY, null)
        if (previous == current) return

        // Existing reports have no project namespace. Purge synchronously while no
        // Firebase provider exists; a queued deleteUnsentReports call is not a barrier.
        val files = context.filesDir
        val canonicalFiles = files.canonicalFile
        check(canonicalFiles.isDirectory) { "Application files directory is unavailable" }
        for (name in diagnosticRoots) {
            val root = File(files, name)
            purgeSdkEntry(root, File(canonicalFiles, name))
        }
        check(diagnosticRoots.all { stat(File(files, it)) == null }) { "Old diagnostics remain" }

        // A failed or interrupted purge must never advance this marker. Restore
        // the in-memory old value too if the preference disk commit reports failure.
        if (!marker.edit().putString(CONTEXT_KEY, current).commit()) {
            marker.edit().also { editor ->
                if (previous == null) editor.remove(CONTEXT_KEY)
                else editor.putString(CONTEXT_KEY, previous)
            }.apply()
            error("Measurement context could not be saved")
        }
    }

    private fun googleApplicationId(context: Context): String {
        val id = context.resources.getIdentifier("google_app_id", "string", context.packageName)
        check(id != 0) { "Firebase application ID resource is missing" }
        return context.getString(id)
    }

    private fun purgeSdkEntry(entry: File, expectedCanonical: File) {
        val metadata = stat(entry) ?: return
        check(!OsConstants.S_ISLNK(metadata.st_mode)) { "Diagnostics path is a symbolic link" }
        // expectedCanonical is built from the trusted canonical filesDir plus
        // literal SDK roots/child names, never by following a candidate link.
        check(entry.canonicalFile == expectedCanonical) { "Diagnostics path escaped its SDK root" }
        if (OsConstants.S_ISDIR(metadata.st_mode)) {
            val children = checkNotNull(entry.listFiles()) { "Diagnostics directory cannot be read" }
            for (child in children) purgeSdkEntry(child, File(expectedCanonical, child.name))
        }
        check(entry.canonicalFile == expectedCanonical) { "Diagnostics path changed during cleanup" }
        check(entry.delete()) { "Old diagnostics could not be deleted" }
        check(stat(entry) == null) { "Old diagnostics remain" }
    }

    private fun stat(entry: File): StructStat? = try {
        Os.lstat(entry.absolutePath)
    } catch (cause: ErrnoException) {
        if (cause.errno == OsConstants.ENOENT) null
        else throw IllegalStateException("Diagnostics path cannot be inspected", cause)
    }
}
