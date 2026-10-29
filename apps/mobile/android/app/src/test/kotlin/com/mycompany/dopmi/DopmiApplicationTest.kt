package com.mycompany.dopmi

import android.app.Application
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.content.pm.ProviderInfo
import android.database.Cursor
import android.net.Uri
import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements

// The probe reads real Android preferences without initializing Firebase. The
// shadow also blocks Firebase if test tooling supplies merged manifest providers.
@RunWith(RobolectricTestRunner::class)
@Config(
    manifest = Config.NONE, application = Application::class, sdk = [35],
    packageName = "com.mycompany.dopmi",
    shadows = [SuppressedFirebaseInitProvider::class],
)
class DopmiApplicationTest {
    @get:Rule
    val temporary = TemporaryFolder()

    @Test
    fun inheritedSdkOptInsAreOffBeforeProviderCreationWithoutErasingUserData() {
        val context = RuntimeEnvironment.getApplication()
        val analytics = context.getSharedPreferences(
            "com.google.android.gms.measurement.prefs", Context.MODE_PRIVATE,
        )
        val diagnostics = context.getSharedPreferences(
            "com.google.firebase.crashlytics", Context.MODE_PRIVATE,
        )
        analytics.edit().putBoolean("measurement_enabled", true)
            .putBoolean("measurement_enabled_from_api", true)
            .putString("other_sdk_metadata", "preserve").commit()
        diagnostics.edit().putBoolean("firebase_crashlytics_collection_enabled", true)
            .putString("other_sdk_metadata", "preserve").commit()
        val user = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        user.edit().putBoolean("flutter.dopmi.TEST.alice.analytics", true)
            .putString("flutter.user_preference", "preserve").commit()
        write(context, ".crashlytics.v3/process/open-sessions/legacy-test")
        write(context, ".com.google.firebase.crashlytics.files.v1/reports/legacy-test")

        val application = DopmiApplication()
        shadowOf(application).callAttach(context)
        // No Application.onCreate or Dart initialization has happened yet.
        val provider = CollectionProbeProvider()
        provider.attachInfo(application, ProviderInfo().apply { authority = "dopmi.test.probe" })

        assertTrue(provider.created)
        assertFalse(provider.analyticsEnabled)
        assertFalse(analytics.getBoolean("measurement_enabled_from_api", true))
        assertFalse(provider.diagnosticsEnabled)
        assertFalse(provider.oldDiagnosticRootsPresent)
        assertEquals("preserve", analytics.getString("other_sdk_metadata", null))
        assertEquals("preserve", diagnostics.getString("other_sdk_metadata", null))
        assertTrue(user.getBoolean("flutter.dopmi.TEST.alice.analytics", false))
        assertEquals("preserve", user.getString("flutter.user_preference", null))
    }

    @Test
    fun everyColdStartDisablesEveryPriorNativeConsentCombination() {
        val context = RuntimeEnvironment.getApplication()
        val analytics = context.getSharedPreferences(
            "com.google.android.gms.measurement.prefs", Context.MODE_PRIVATE,
        )
        val diagnostics = context.getSharedPreferences(
            "com.google.firebase.crashlytics", Context.MODE_PRIVATE,
        )
        for (analyticsConsent in listOf(false, true)) {
            for (diagnosticsConsent in listOf(false, true)) {
                analytics.edit().putBoolean("measurement_enabled", analyticsConsent)
                    .putBoolean("measurement_enabled_from_api", analyticsConsent).commit()
                diagnostics.edit()
                    .putBoolean("firebase_crashlytics_collection_enabled", diagnosticsConsent).commit()
                val application = DopmiApplication()
                shadowOf(application).callAttach(context)
                val provider = CollectionProbeProvider()
                provider.attachInfo(
                    application, ProviderInfo().apply { authority = "dopmi.test.probe" },
                )
                assertFalse(provider.analyticsEnabled)
                assertFalse(analytics.getBoolean("measurement_enabled_from_api", true))
                assertFalse(provider.diagnosticsEnabled)
            }
        }
    }

    @Test
    fun projectChangePurgesOnlyTheTwoConfirmedSdkRootsAndStampsAfterward() {
        val context = RuntimeEnvironment.getApplication()
        NativeMeasurementStartup.prepare(context) { TEST_ID }
        val currentReport = write(context, ".crashlytics.v3/process/reports/test-report")
        val legacyReport = write(context, ".com.google.firebase.crashlytics.files.v1/open-sessions/test")
        val userPhoto = write(context, "private-media/photo.jpg")
        val otherSdk = write(context, ".other-sdk/cache")
        val user = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        user.edit().putBoolean("flutter.dopmi.TEST.alice.diagnostics", true)
            .putString("flutter.user_preference", "preserve").commit()
        val auth = context.getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE)
        auth.edit().putString("auth_fixture", "preserve").commit()

        NativeMeasurementStartup.prepare(context) { PROD_ID }

        assertFalse(currentReport.exists())
        assertFalse(legacyReport.exists())
        assertFalse(File(context.filesDir, ".crashlytics.v3").exists())
        assertFalse(File(context.filesDir, ".com.google.firebase.crashlytics.files.v1").exists())
        assertEquals("fixture", userPhoto.readText())
        assertEquals("fixture", otherSdk.readText())
        assertTrue(user.getBoolean("flutter.dopmi.TEST.alice.diagnostics", false))
        assertEquals("preserve", user.getString("flutter.user_preference", null))
        assertEquals("preserve", auth.getString("auth_fixture", null))
        assertEquals(PROD_ID, marker(context).getString("google_app_id", null))
    }

    @Test
    fun sameProjectKeepsLegitimatePendingReportsButStillStartsCollectionOff() {
        val context = RuntimeEnvironment.getApplication()
        NativeMeasurementStartup.prepare(context) { PROD_ID }
        val report = write(context, ".crashlytics.v3/process/reports/legitimate-report")
        context.getSharedPreferences("com.google.firebase.crashlytics", Context.MODE_PRIVATE)
            .edit().putBoolean("firebase_crashlytics_collection_enabled", true).commit()

        NativeMeasurementStartup.prepare(context) { PROD_ID }

        assertEquals("fixture", report.readText())
        assertEquals(PROD_ID, marker(context).getString("google_app_id", null))
        assertCollectionOff(context)
    }

    @Test
    fun missingProjectIdDoesNotPurgeOrAdvanceTheMarker() {
        val context = RuntimeEnvironment.getApplication()
        NativeMeasurementStartup.prepare(context) { TEST_ID }
        val report = write(context, ".crashlytics.v3/process/reports/test-report")

        for (invalid in listOf("", "../private-media")) {
            assertThrows(IllegalStateException::class.java) {
                NativeMeasurementStartup.prepare(context) { invalid }
            }
        }

        assertEquals("fixture", report.readText())
        assertEquals(TEST_ID, marker(context).getString("google_app_id", null))
        assertCollectionOff(context)
    }

    @Test
    fun symbolicSdkRootCannotDeleteOutsideOrAdvanceTheMarker() {
        val context = RuntimeEnvironment.getApplication()
        NativeMeasurementStartup.prepare(context) { TEST_ID }
        val outside = temporary.newFolder("user-media")
        val inside = File(context.filesDir, "private-media").apply { mkdirs() }
        val link = File(context.filesDir, ".crashlytics.v3")
        for (target in listOf(outside, inside)) {
            val userPhoto = File(target, "photo.jpg").apply { writeText("preserve") }
            Files.createSymbolicLink(link.toPath(), target.toPath())
            assertThrows(IllegalStateException::class.java) {
                NativeMeasurementStartup.prepare(context) { PROD_ID }
            }
            assertEquals("preserve", userPhoto.readText())
            assertTrue(Files.isSymbolicLink(link.toPath()))
            assertEquals(TEST_ID, marker(context).getString("google_app_id", null))
            assertCollectionOff(context)
            // Removes only this test-created link, never its target.
            assertTrue(link.delete())
        }
    }

    @Test
    fun nestedDanglingLinkFailsClosedWithoutFollowingIt() {
        val context = RuntimeEnvironment.getApplication()
        NativeMeasurementStartup.prepare(context) { TEST_ID }
        val sdkRoot = File(context.filesDir, ".crashlytics.v3/process").apply { mkdirs() }
        val outside = File(temporary.root, "missing-user-file")
        val link = File(sdkRoot, "dangling")
        Files.createSymbolicLink(link.toPath(), outside.toPath())

        assertThrows(IllegalStateException::class.java) {
            NativeMeasurementStartup.prepare(context) { PROD_ID }
        }

        assertFalse(outside.exists())
        assertTrue(Files.isSymbolicLink(link.toPath()))
        assertEquals(TEST_ID, marker(context).getString("google_app_id", null))
        assertCollectionOff(context)
    }

    @Test
    fun failedMarkerCommitDoesNotClaimCompletionAndCanRetry() {
        val context = RuntimeEnvironment.getApplication()
        NativeMeasurementStartup.prepare(context) { TEST_ID }
        write(context, ".crashlytics.v3/process/reports/test-report")

        assertThrows(IllegalStateException::class.java) {
            NativeMeasurementStartup.prepare(FailingMarkerContext(context)) { PROD_ID }
        }

        assertEquals(TEST_ID, marker(context).getString("google_app_id", null))
        assertCollectionOff(context)
        NativeMeasurementStartup.prepare(context) { PROD_ID }
        assertEquals(PROD_ID, marker(context).getString("google_app_id", null))
    }

    private fun write(context: Context, path: String): File = File(context.filesDir, path).apply {
        parentFile!!.mkdirs()
        writeText("fixture")
    }

    private fun marker(context: Context): SharedPreferences = context.getSharedPreferences(
        "dopmi.native_measurement_context.v1", Context.MODE_PRIVATE,
    )

    private fun assertCollectionOff(context: Context) {
        assertFalse(context.getSharedPreferences(
            "com.google.android.gms.measurement.prefs", Context.MODE_PRIVATE,
        ).getBoolean("measurement_enabled", true))
        assertFalse(context.getSharedPreferences(
            "com.google.firebase.crashlytics", Context.MODE_PRIVATE,
        ).getBoolean("firebase_crashlytics_collection_enabled", true))
    }

    private companion object {
        const val TEST_ID = "1:111111111111:android:1111111111111111"
        const val PROD_ID = "1:222222222222:android:2222222222222222"
    }
}

private class FailingMarkerContext(base: Context) : ContextWrapper(base) {
    override fun getSharedPreferences(name: String, mode: Int): SharedPreferences {
        val original = super.getSharedPreferences(name, mode)
        if (name != "dopmi.native_measurement_context.v1") return original
        return object : SharedPreferences by original {
            override fun edit(): SharedPreferences.Editor {
                val originalEditor = original.edit()
                return object : SharedPreferences.Editor by originalEditor {
                    override fun putString(key: String, value: String?): SharedPreferences.Editor {
                        originalEditor.putString(key, value)
                        return this
                    }
                    override fun remove(key: String): SharedPreferences.Editor {
                        originalEditor.remove(key)
                        return this
                    }
                    override fun commit(): Boolean {
                        originalEditor.commit()
                        return false
                    }
                }
            }
        }
    }
}

@Implements(
    className = "com.google.firebase.provider.FirebaseInitProvider", isInAndroidSdk = false,
)
class SuppressedFirebaseInitProvider {
    @Implementation
    fun onCreate(): Boolean = false
}

private class CollectionProbeProvider : ContentProvider() {
    var created = false
    var analyticsEnabled = true
    var diagnosticsEnabled = true
    var oldDiagnosticRootsPresent = true

    override fun onCreate(): Boolean {
        val app = requireNotNull(context)
        analyticsEnabled = app.getSharedPreferences(
            "com.google.android.gms.measurement.prefs", Context.MODE_PRIVATE,
        ).getBoolean("measurement_enabled", true)
        diagnosticsEnabled = app.getSharedPreferences(
            "com.google.firebase.crashlytics", Context.MODE_PRIVATE,
        ).getBoolean("firebase_crashlytics_collection_enabled", true)
        oldDiagnosticRootsPresent = File(app.filesDir, ".crashlytics.v3").exists() ||
            File(app.filesDir, ".com.google.firebase.crashlytics.files.v1").exists()
        created = true
        return true
    }

    override fun query(
        uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?,
    ): Cursor? = null
    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(
        uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?,
    ): Int = 0
}
