"""Check the app-owned Meta lifecycle declaration and Runner resource chain.

Uses only the standard library; does not inspect or replace plugin manifests.
Run from any directory: python scripts/test_ios_privacy.py
"""

from pathlib import Path
import plistlib
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "apps/mobile/ios"
MANIFEST = IOS / "Runner/PrivacyInfo.xcprivacy"
PROJECT = IOS / "Runner.xcodeproj/project.pbxproj"


def project_objects(text):
    """Read top-level PBX objects, ignoring braces in comments/quoted scripts."""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    objects = {}
    for match in re.finditer(r"(?m)^\t\t([A-F0-9]{24})\s*=\s*\{", text):
        start = match.end()
        depth, quoted, escaped = 1, False, False
        for at in range(start, len(text)):
            char = text[at]
            if quoted:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    quoted = False
            elif char == '"':
                quoted = True
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    objects[match[1]] = text[start:at]
                    break
        else:
            raise ValueError(f"Unterminated PBX object {match[1]}")
    return objects


def property_value(body, name):
    match = re.search(rf"\b{re.escape(name)}\s*=\s*([^;]+);", body)
    return match[1].strip().strip('"') if match else None


def references(body, name):
    value = property_value(body, name) or ""
    return re.findall(r"\b[A-F0-9]{24}\b", value)


class IosPrivacyTests(unittest.TestCase):
    def manifest(self):
        self.assertTrue(MANIFEST.is_file(), "Runner privacy manifest is missing")
        with MANIFEST.open("rb") as stream:
            return plistlib.load(stream)

    def test_direct_lifecycle_tracking_domain_is_declared(self):
        manifest = self.manifest()
        self.assertIs(manifest.get("NSPrivacyTracking"), True)
        self.assertEqual(
            manifest.get("NSPrivacyTrackingDomains"), ["graph.facebook.com"]
        )

    def test_app_owned_types_keep_product_data_separate_from_meta_tracking(self):
        entries = self.manifest().get("NSPrivacyCollectedDataTypes", [])
        # Active public identity, profile, adoption, chat and support payloads.
        # Disabled payment routes and SDK-owned collection are not inferred here.
        purposes = {
            kind: ["AppFunctionality"] for kind in (
                "Name", "EmailAddress", "PhoneNumber", "PhysicalAddress",
                "OtherUserContactInfo", "EmailsOrTextMessages", "PhotosorVideos",
                "OtherUserContent", "CustomerSupport",
            )
        }
        purposes.update({
            "UserID": ["AppFunctionality", "Analytics", "DeveloperAdvertising"],
            "PreciseLocation": ["AppFunctionality", "ProductPersonalization"],
            "CoarseLocation": ["AppFunctionality", "ProductPersonalization"],
            "DeviceID": ["DeveloperAdvertising", "Analytics"],
            "ProductInteraction": ["DeveloperAdvertising", "Analytics", "AppFunctionality", "ProductPersonalization"],
            "OtherDataTypes": ["DeveloperAdvertising", "Analytics"],
        })
        expected = {"NSPrivacyCollectedDataType" + kind for kind in purposes}
        meta = {"DeviceID", "ProductInteraction", "OtherDataTypes"}
        self.assertEqual(len(entries), len(expected))
        self.assertEqual({e.get("NSPrivacyCollectedDataType") for e in entries}, expected)
        for entry in entries:
            with self.subTest(data_type=entry.get("NSPrivacyCollectedDataType")):
                kind = entry["NSPrivacyCollectedDataType"].removeprefix("NSPrivacyCollectedDataType")
                self.assertEqual(set(entry), {
                    "NSPrivacyCollectedDataType", "NSPrivacyCollectedDataTypeLinked",
                    "NSPrivacyCollectedDataTypeTracking", "NSPrivacyCollectedDataTypePurposes",
                })
                self.assertIs(entry["NSPrivacyCollectedDataTypeLinked"], True)
                self.assertIs(entry["NSPrivacyCollectedDataTypeTracking"], kind in meta)
                self.assertCountEqual(entry["NSPrivacyCollectedDataTypePurposes"], [
                    "NSPrivacyCollectedDataTypePurpose" + purpose for purpose in purposes[kind]
                ])

    def test_no_required_reason_api_is_fabricated_for_the_native_bridge(self):
        bridge = (IOS / "Runner/MetaLifecycleBridge.swift").read_text(encoding="utf-8")
        self.assertNotRegex(bridge, r"\bUserDefaults\b")
        self.assertNotIn("NSPrivacyAccessedAPITypes", self.manifest())

    def test_manifest_is_a_resource_of_runner_not_only_a_file_reference(self):
        objects = project_objects(PROJECT.read_text(encoding="utf-8"))
        def find(isa, field, value):
            found = [key for key, body in objects.items()
                     if property_value(body, "isa") == isa
                     and property_value(body, field) == value]
            self.assertEqual(len(found), 1, f"Expected one {isa} {field}={value}")
            return found[0]

        file_id = find("PBXFileReference", "path", "PrivacyInfo.xcprivacy")
        group_id = find("PBXGroup", "path", "Runner")
        self.assertIn(file_id, references(objects[group_id], "children"))
        build_id = find("PBXBuildFile", "fileRef", file_id)
        target_id = find("PBXNativeTarget", "name", "Runner")
        phases = references(objects[target_id], "buildPhases")
        resources = [objects[key] for key in phases
                     if property_value(objects[key], "isa") == "PBXResourcesBuildPhase"]
        self.assertEqual(len(resources), 1)
        self.assertEqual(references(resources[0], "files").count(build_id), 1)


if __name__ == "__main__":
    unittest.main()
