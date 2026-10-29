import base64
import contextlib
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("firebase_config", Path(__file__).with_name("write-firebase-config.py"))
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class FirebaseConfigTests(unittest.TestCase):
    def info(self):
        return {
            "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
            "CFBundleDisplayName": "Dopmi",
            "FirebaseCrashlyticsCollectionEnabled": False,
            "CFBundleURLTypes": [{"CFBundleURLSchemes": ["io.dopmi.app", "another-preserved-callback"]}],
        }

    def google_env(self, production=False):
        number = self.files(production)[1]["GCM_SENDER_ID"]
        return {**self.env(production), "ENABLE_GOOGLE_AUTH": "true",
                "GOOGLE_SERVER_CLIENT_ID": f"{number}-web.apps.googleusercontent.com",
                "GOOGLE_IOS_CLIENT_ID": f"{number}-ios.apps.googleusercontent.com"}

    def files(self, production=False):
        project = "dopmi-production" if production else config.TEST_PROJECT
        number = "934560123456" if production else config.TEST_PROJECT_NUMBER
        android_app = f"1:{number}:android:abcdef0123456789abcdef" if production else config.TEST_ANDROID_APP
        ios_app = f"1:{number}:ios:0123456789abcdef012345"
        android = {"project_info": {"project_id": project, "project_number": number},
                   "client": [{"client_info": {"mobilesdk_app_id": android_app,
                                               "android_client_info": {"package_name": config.PACKAGE}},
                               "api_key": [{"current_key": "synthetic-client-value"}]}]}
        ios = {"PROJECT_ID": project, "BUNDLE_ID": config.PACKAGE, "GOOGLE_APP_ID": ios_app,
               "GCM_SENDER_ID": number, "API_KEY": "synthetic-client-value",
               "IS_SIGNIN_ENABLED": True, "IS_GCM_ENABLED": True, "IS_APPINVITE_ENABLED": True}
        return android, ios

    def env(self, production=False, android=None, ios=None):
        source_android, source_ios = self.files(production)
        android = source_android if android is None else android
        ios = source_ios if ios is None else ios
        prefix = "FIREBASE_PRODUCTION_" if production else "FIREBASE_"
        env = {f"{prefix}ANDROID_CONFIG_BASE64": base64.b64encode(json.dumps(android).encode()).decode(),
               f"{prefix}IOS_CONFIG_BASE64": base64.b64encode(plistlib.dumps(ios)).decode()}
        if production:
            env.update(DOPMI_ENVIRONMENT="production", FIREBASE_PRODUCTION_PROJECT_ID=source_android["project_info"]["project_id"],
                       FIREBASE_PRODUCTION_ANDROID_APP_ID=source_android["client"][0]["client_info"]["mobilesdk_app_id"],
                       FIREBASE_PRODUCTION_IOS_APP_ID=source_ios["GOOGLE_APP_ID"])
        return env

    def test_existing_test_registration_is_preserved_without_rewriting_files(self):
        env = self.env()
        android, ios = config.build_config(env)
        self.assertEqual(android, base64.b64decode(env["FIREBASE_ANDROID_CONFIG_BASE64"]))
        self.assertEqual(ios, base64.b64decode(env["FIREBASE_IOS_CONFIG_BASE64"]))
        self.assertEqual(config.build_config({**env, "DOPMI_ENVIRONMENT": "test"}), (android, ios))

    def test_production_pins_both_platforms_and_preserves_downloaded_defaults(self):
        env = self.env(True)
        android, ios = config.build_config(env, production_beta=True)
        self.assertEqual(android, base64.b64decode(env["FIREBASE_PRODUCTION_ANDROID_CONFIG_BASE64"]))
        self.assertEqual(ios, base64.b64decode(env["FIREBASE_PRODUCTION_IOS_CONFIG_BASE64"]))
        self.assertTrue(plistlib.loads(ios)["IS_GCM_ENABLED"])
        self.assertTrue(plistlib.loads(ios)["IS_SIGNIN_ENABLED"])

    def test_environment_and_flag_must_select_the_same_profile(self):
        for env, flag in ((self.env(True), False), (self.env(), True),
                          ({**self.env(True), "DOPMI_ENVIRONMENT": "test"}, True),
                          ({**self.env(True), "DOPMI_ENVIRONMENT": "staging"}, True),
                          ({**self.env(), "DOPMI_ENVIRONMENT": ""}, False)):
            with self.subTest(environment=env.get("DOPMI_ENVIRONMENT"), flag=flag), self.assertRaises(ValueError):
                config.build_config(env, flag)

    def test_production_never_falls_back_to_test_variables(self):
        production = self.env(True)
        mixed = {**self.env(), **production}
        self.assertEqual(config.build_config(mixed, True), config.build_config(production, True))
        for name in ("FIREBASE_PRODUCTION_ANDROID_CONFIG_BASE64", "FIREBASE_PRODUCTION_IOS_CONFIG_BASE64"):
            env = {**mixed}
            del env[name]
            with self.subTest(name=name), self.assertRaises(ValueError):
                config.build_config(env, True)
        for name in ("FIREBASE_ANDROID_CONFIG_BASE64", "FIREBASE_IOS_CONFIG_BASE64"):
            env = {**self.env(), **production, "DOPMI_ENVIRONMENT": "test"}
            del env[name]
            with self.subTest(name=name), self.assertRaises(ValueError):
                config.build_config(env)

    def test_missing_or_invalid_pins_reject_before_accepting_production_configs(self):
        bad = {
            "FIREBASE_PRODUCTION_PROJECT_ID": ["", config.TEST_PROJECT, "dopmi-ci-placeholder", "dopmi-dummy", "dopmi-fixture", "https://example.test", "invalid-"],
            "FIREBASE_PRODUCTION_ANDROID_APP_ID": ["", config.TEST_ANDROID_APP, "1:000000000000:android:0000000000000000", "1:934560123456:ios:abcdef0123456789abcdef", "not-an-app-id"],
            "FIREBASE_PRODUCTION_IOS_APP_ID": ["", "1:623928073757:ios:0123456789abcdef012345", "1:934560123456:web:0123456789abcdef012345", "1:934560123456:ios:0000000000000000"],
        }
        for name, values in bad.items():
            for value in values:
                with self.subTest(name=name, value=value), self.assertRaises(ValueError):
                    config.build_config({**self.env(True), name: value}, True)

    def test_platform_pins_and_downloaded_project_numbers_must_agree(self):
        android, ios = self.files(True)
        alternate_ios = "1:834560123456:ios:0123456789abcdef012345"
        with self.assertRaises(ValueError):
            config.build_config({**self.env(True), "FIREBASE_PRODUCTION_IOS_APP_ID": alternate_ios}, True)
        for target in ("android_number", "ios_number", "android_app", "ios_app"):
            changed_android, changed_ios = copy.deepcopy(android), copy.deepcopy(ios)
            if target == "android_number":
                changed_android["project_info"]["project_number"] = "834560123456"
            elif target == "ios_number":
                changed_ios["GCM_SENDER_ID"] = "834560123456"
            elif target == "android_app":
                changed_android["client"][0]["client_info"]["mobilesdk_app_id"] = "1:934560123456:android:1234567890abcdef123456"
            else:
                changed_ios["GOOGLE_APP_ID"] = alternate_ios
            with self.subTest(target=target), self.assertRaises(ValueError):
                config.build_config(self.env(True, changed_android, changed_ios), True)

    def test_crossed_project_or_package_is_rejected_on_either_platform(self):
        for production in (False, True):
            for target in ("android_project", "ios_project", "android_package", "ios_bundle", "duplicate_android"):
                android, ios = self.files(production)
                if target == "android_project":
                    android["project_info"]["project_id"] = "another-project"
                elif target == "ios_project":
                    ios["PROJECT_ID"] = "another-project"
                elif target == "android_package":
                    android["client"][0]["client_info"]["android_client_info"]["package_name"] = "com.example.other"
                elif target == "ios_bundle":
                    ios["BUNDLE_ID"] = "com.example.other"
                else:
                    android["client"].append(copy.deepcopy(android["client"][0]))
                with self.subTest(production=production, target=target), self.assertRaises(ValueError):
                    config.build_config(self.env(production, android, ios), production)

    def test_registered_test_android_app_cannot_be_replaced(self):
        android, ios = self.files()
        android["client"][0]["client_info"]["mobilesdk_app_id"] = "1:623928073757:android:1234567890abcdef123456"
        with self.assertRaises(ValueError):
            config.build_config(self.env(False, android, ios))

    def test_explicit_emulator_configurations_are_rejected_in_production(self):
        for target, value in (("android", "http://localhost:9099"), ("ios", "http://10.0.2.2:9099"),
                              ("ios", "https://127.0.0.1:9099"), ("android", "http://[::1]:9099")):
            android, ios = self.files(True)
            (android if target == "android" else ios)["auth_endpoint"] = value
            with self.subTest(target=target, value=value), self.assertRaises(ValueError):
                config.build_config(self.env(True, android, ios), True)
        android, ios = self.files(True)
        android["services"] = {"auth_emulator_host": "emulator.example.test:9099"}
        with self.assertRaises(ValueError):
            config.build_config(self.env(True, android, ios), True)

    def test_invalid_encoding_and_payload_errors_never_echo_config_contents(self):
        private_marker = "private-marker-do-not-echo"
        for variable in ("FIREBASE_PRODUCTION_ANDROID_CONFIG_BASE64", "FIREBASE_PRODUCTION_IOS_CONFIG_BASE64"):
            for value in (private_marker, base64.b64encode(private_marker.encode()).decode(), ""):
                with self.subTest(variable=variable, value=value), self.assertRaises(ValueError) as caught:
                    config.build_config({**self.env(True), variable: value}, True)
                self.assertNotIn(private_marker, str(caught.exception))
                if value:
                    self.assertNotIn(value, str(caught.exception))

    def test_main_writes_only_both_validated_files_without_printing_contents(self):
        for production in (False, True):
            env = self.env(production)
            expected = config.build_config(env, production)
            with self.subTest(production=production), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                info = root / "ios/Runner/Info.plist"
                info.parent.mkdir(parents=True)
                info.write_bytes(plistlib.dumps(self.info()))
                output = io.StringIO()
                with patch.object(config, "ROOT", root), patch.dict(os.environ, env, clear=True), contextlib.redirect_stdout(output):
                    config.main(["--production-beta"] if production else [])
                self.assertEqual((root / "android/app/google-services.json").read_bytes(), expected[0])
                self.assertEqual((root / "ios/Runner/GoogleService-Info.plist").read_bytes(), expected[1])
                self.assertEqual(plistlib.loads(info.read_bytes()), self.info())
                self.assertNotIn("synthetic-client-value", output.getvalue())
                for value in env.values():
                    if len(value) > 50:
                        self.assertNotIn(value, output.getvalue())

    def test_invalid_main_removes_stale_connected_files_without_partial_write(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = (root / "android/app/google-services.json", root / "ios/Runner/GoogleService-Info.plist")
            for path in paths:
                path.parent.mkdir(parents=True)
                path.write_text("stale")
            env = {**self.env(True), "FIREBASE_PRODUCTION_IOS_CONFIG_BASE64": "invalid"}
            with patch.object(config, "ROOT", root), patch.dict(os.environ, env, clear=True), self.assertRaises(SystemExit):
                config.main(["--production-beta"])
            self.assertTrue(all(not path.exists() for path in paths))

    def test_google_scheme_is_derived_from_each_profile_preserving_other_identity(self):
        for production in (False, True):
            env = self.google_env(production)
            _, ios = config.build_config(env, production)
            original = self.info()
            original["CFBundleURLTypes"].append({"CFBundleURLSchemes": [
                "com.googleusercontent.apps.623928073757-old", "unrelated-preserved-callback"]})
            result = plistlib.loads(config.build_ios_info(env, plistlib.dumps(original), ios, production))
            expected = self.info()
            expected["CFBundleURLTypes"].append({"CFBundleURLSchemes": ["unrelated-preserved-callback"]})
            number = self.files(production)[1]["GCM_SENDER_ID"]
            expected["CFBundleURLTypes"].append({"CFBundleURLSchemes": [f"com.googleusercontent.apps.{number}-ios"]})
            self.assertEqual(result, expected)
            self.assertEqual(config.build_ios_info(env, plistlib.dumps(result), ios, production), plistlib.dumps(result, sort_keys=False))

    def test_enabled_google_rejects_missing_malformed_or_crossed_profile_clients(self):
        for production in (False, True):
            for name in ("GOOGLE_IOS_CLIENT_ID", "GOOGLE_SERVER_CLIENT_ID"):
                other = self.google_env(not production)[name]
                for value in ("", "not-a-client-id", other):
                    with self.subTest(production=production, name=name, value=value), self.assertRaises(ValueError):
                        config.build_config({**self.google_env(production), name: value}, production)

    def test_declared_firebase_ios_client_and_reversed_scheme_must_match_profile(self):
        for key in ("CLIENT_ID", "REVERSED_CLIENT_ID"):
            android, ios = self.files(True)
            ios[key] = ("623928073757-foreign.apps.googleusercontent.com" if key == "CLIENT_ID"
                        else "com.googleusercontent.apps.623928073757-foreign")
            env = {**self.google_env(True), **self.env(True, android, ios)}
            with self.subTest(key=key), self.assertRaises(ValueError):
                config.build_config(env, True)
        for production in (False, True):
            android, ios = self.files(production)
            env = self.google_env(production)
            ios["CLIENT_ID"] = env["GOOGLE_IOS_CLIENT_ID"]
            ios["REVERSED_CLIENT_ID"] = "com.googleusercontent.apps." + ios["CLIENT_ID"].removesuffix(".apps.googleusercontent.com")
            env.update(self.env(production, android, ios))
            self.assertEqual(config.build_config(env, production)[1], plistlib.dumps(ios))

    def test_disabled_google_needs_no_client_and_removes_only_its_old_schemes(self):
        env = self.env(True)
        _, ios = config.build_config(env, True)
        original = self.info()
        original["CFBundleURLTypes"].append({"CFBundleURLSchemes": ["com.googleusercontent.apps.623928073757-old"]})
        result = plistlib.loads(config.build_ios_info(env, plistlib.dumps(original), ios, True))
        self.assertEqual(result, self.info())
        self.assertEqual(config.build_config(env, True)[1], ios)
        self.assertNotIn("CLIENT_ID", plistlib.loads(ios))

    def test_android_google_accepts_web_only_without_ios_identity_changes(self):
        for production in (False, True):
            env = {**self.google_env(production), "GOOGLE_IOS_CLIENT_ID": ""}
            with self.subTest(production=production):
                configs = config.build_config(env, production, platform="android")
                with self.assertRaises(ValueError):
                    config.build_config(env, production, platform="ios")
                with tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    info = root / "ios/Runner/Info.plist"
                    info.parent.mkdir(parents=True)
                    original = plistlib.dumps(self.info())
                    info.write_bytes(original)
                    with patch.object(config, "ROOT", root), patch.dict(os.environ, env, clear=True), contextlib.redirect_stdout(io.StringIO()):
                        config.main((["--production-beta"] if production else []) + ["--platform", "android"])
                    self.assertEqual(info.read_bytes(), original)
                    self.assertEqual((root / "android/app/google-services.json").read_bytes(), configs[0])
                    self.assertEqual((root / "ios/Runner/GoogleService-Info.plist").read_bytes(), configs[1])

    def test_google_test_profile_rejects_coordinated_foreign_project_metadata(self):
        android, ios = self.files()
        foreign_number = self.files(True)[1]["GCM_SENDER_ID"]
        android["project_info"]["project_number"] = foreign_number
        ios["GCM_SENDER_ID"] = foreign_number
        ios["GOOGLE_APP_ID"] = f"1:{foreign_number}:ios:0123456789abcdef012345"
        env = {**self.env(False, android, ios), "ENABLE_GOOGLE_AUTH": "true",
               "GOOGLE_SERVER_CLIENT_ID": f"{foreign_number}-web.apps.googleusercontent.com",
               "GOOGLE_IOS_CLIENT_ID": f"{foreign_number}-ios.apps.googleusercontent.com"}
        # PROJECT_ID and BUNDLE_ID still say TEST; coordinated metadata cannot
        # redefine the authoritative registered TEST project number.
        bad_environments = {"coordinated": env}
        for target in ("android_number", "ios_app_id"):
            android, ios = self.files()
            if target == "android_number":
                android["project_info"]["project_number"] = foreign_number
            else:
                ios["GOOGLE_APP_ID"] = f"1:{foreign_number}:ios:0123456789abcdef012345"
            bad_environments[target] = {**self.google_env(), **self.env(False, android, ios)}
        for target, bad in bad_environments.items():
            for platform in ("android", "ios", "both"):
                with self.subTest(target=target, platform=platform), self.assertRaises(ValueError):
                    config.build_config(bad, platform=platform)

    def test_main_validates_google_before_writing_any_connected_configuration(self):
        for invalid in (False, True):
            with self.subTest(invalid=invalid), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                info = root / "ios/Runner/Info.plist"
                info.parent.mkdir(parents=True)
                original = plistlib.dumps(self.info())
                info.write_bytes(original)
                env = self.google_env(True)
                if invalid:
                    env["GOOGLE_IOS_CLIENT_ID"] = self.google_env()["GOOGLE_IOS_CLIENT_ID"]
                with patch.object(config, "ROOT", root), patch.dict(os.environ, env, clear=True), contextlib.redirect_stdout(io.StringIO()):
                    if invalid:
                        with self.assertRaises(SystemExit):
                            config.main(["--production-beta"])
                    else:
                        config.main(["--production-beta"])
                firebase_paths = (root / "android/app/google-services.json", root / "ios/Runner/GoogleService-Info.plist")
                if invalid:
                    self.assertTrue(all(not path.exists() for path in firebase_paths))
                    self.assertEqual(info.read_bytes(), original)
                else:
                    self.assertEqual(tuple(path.read_bytes() for path in firebase_paths), config.build_config(env, True))
                    self.assertEqual(plistlib.loads(info.read_bytes())["CFBundleURLTypes"][-1],
                                     {"CFBundleURLSchemes": ["com.googleusercontent.apps.934560123456-ios"]})


if __name__ == "__main__":
    unittest.main()
