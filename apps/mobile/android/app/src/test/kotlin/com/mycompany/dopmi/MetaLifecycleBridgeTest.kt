package com.mycompany.dopmi

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MetaLifecycleBridgeTest {
    @Test
    fun backgroundBlocksNewReadsAndResumingNeverRestoresAnOldRead() {
        val session = MetaLifecycleSession()
        assertFalse(session.current(session.snapshot()))
        session.setForeground(true)
        val original = session.snapshot()
        assertTrue(session.current(original))
        session.setForeground(false)
        assertFalse(session.current(original))
        assertFalse(session.current(session.snapshot()))
        session.setForeground(true)
        assertFalse(session.current(original))
        val resumed = session.snapshot()
        assertTrue(session.current(resumed))
        session.cancel()
        assertFalse(session.current(resumed))
    }

    private fun context(
        id: String? = "81000000-0000-4000-8000-000000000001",
        limited: Boolean = false,
        first: Long = 1000,
        updated: Long = 1000,
        packageName: String = "com.mycompany.dopmi",
        appBuild: Long = 444,
    ) = metaLifecycleAndroidContext(
        packageName, "2.3.13", appBuild, "16", id, limited, first, updated,
    )

    @Test
    fun aFreshPackageHasOnlyTheApprovedContextAndInstallProof() {
        val result = requireNotNull(context())
        assertEquals(
            setOf("platform", "package_name", "advertising_id", "tracking_authorized",
                "app_version", "app_build", "os_version", "install_eligible"),
            result.keys,
        )
        assertEquals("android", result["platform"])
        assertTrue(result["tracking_authorized"] == true)
        assertTrue(result["install_eligible"] == true)
    }

    @Test
    fun anUpdateOrUncertainTimestampsCannotBecomeAnInstall() {
        assertFalse(context(first = 1000, updated = 2000)!!["install_eligible"] == true)
        assertFalse(context(first = 0, updated = 0)!!["install_eligible"] == true)
        assertFalse(context(first = 2000, updated = 1000)!!["install_eligible"] == true)
    }

    @Test
    fun deletedLimitedMalformedOrMissingIdentifiersNeverCrossTheBridge() {
        assertNull(context(id = null))
        assertNull(context(id = "00000000-0000-0000-0000-000000000000"))
        assertNull(context(id = "not-an-advertising-id"))
        assertNull(context(limited = true))
    }

    @Test
    fun contextRejectsAnotherPackageAndInvalidBuild() {
        assertNull(context(packageName = "com.other.application"))
        assertNull(context(appBuild = 0))
        assertNull(context(appBuild = 2_100_000_001))
    }
}
