import base64
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("mobile_config", Path(__file__).with_name("write-mobile-config.py"))
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class MobileConfigTests(unittest.TestCase):
    def setUp(self):
        example = Path(__file__).resolve().parents[1] / "apps/mobile/config.example.json"
        self.env = {"SUPABASE_URL": json.loads(example.read_text())["SUPABASE_URL"],
                    "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_unit_test_placeholder"}

    def test_guardian_requires_explicit_build_option(self):
        self.env["ENABLE_GUARDIAN_TEST"] = "true"
        self.assertEqual(config.build_config(self.env)["ENABLE_GUARDIAN_TEST"], "false")
        self.assertEqual(config.build_config(self.env, True)["ENABLE_GUARDIAN_TEST"], "true")

    def test_measurement_diagnostic_requires_explicit_build_option(self):
        self.env["ENABLE_MEASUREMENT_TEST"] = "true"
        self.assertEqual(config.build_config(self.env)["ENABLE_MEASUREMENT_TEST"], "false")
        self.assertEqual(config.build_config(self.env, measurement_test=True)["ENABLE_MEASUREMENT_TEST"], "true")

    def test_guardian_rejects_another_project(self):
        self.env["SUPABASE_URL"] = "https://another-project.supabase.co"
        with self.assertRaises(ValueError):
            config.build_config(self.env, True)

    def test_rejects_server_credentials_without_echoing_them(self):
        for key in ("sb_secret_placeholder", "sk_test_placeholder", "rk_test_placeholder", self.jwt("service_role")):
            self.env["SUPABASE_PUBLISHABLE_KEY"] = key
            with self.assertRaises(ValueError) as caught:
                config.build_config(self.env)
            self.assertNotIn(key, str(caught.exception))

    def test_preserves_existing_anon_client_and_social_options(self):
        self.env.update(SUPABASE_PUBLISHABLE_KEY=self.jwt("anon"), ENABLE_GOOGLE_AUTH=" true ", ENABLE_APPLE_AUTH="false",
                        GOOGLE_SERVER_CLIENT_ID="123-unit-test.apps.googleusercontent.com")
        result = config.build_config(self.env, True)
        self.assertEqual(result["ENABLE_GOOGLE_AUTH"], "true")
        self.assertEqual(result["ENABLE_APPLE_AUTH"], "false")
        self.assertEqual(result["AUTH_REDIRECT_URL"], "io.dopmi.app://auth/callback")

    def test_google_requires_public_client_configuration(self):
        with self.assertRaises(ValueError):
            config.build_config({**self.env, "ENABLE_GOOGLE_AUTH": "true"})
        with self.assertRaises(ValueError):
            config.build_config({**self.env, "GOOGLE_SERVER_CLIENT_ID": "not-an-oauth-client"})

    def test_invalid_or_missing_options_fail_early(self):
        for name, value in (("SUPABASE_URL", ""), ("SUPABASE_PUBLISHABLE_KEY", ""),
                            ("ENABLE_APPLE_AUTH", "yes"), ("SUPABASE_URL", "https://example.com")):
            with self.subTest(name=name, value=value), self.assertRaises(ValueError):
                config.build_config({**self.env, name: value})

    def test_normalizes_pasted_whitespace(self):
        self.env["SUPABASE_URL"] += "/\n"
        self.env["SUPABASE_PUBLISHABLE_KEY"] += "\n"
        result = config.build_config(self.env, True)
        self.assertFalse(result["SUPABASE_URL"].endswith("/"))
        self.assertNotIn("\n", result["SUPABASE_PUBLISHABLE_KEY"])

    def test_all_workflows_reject_unregistered_projects(self):
        for guardian in (False, True):
            with self.subTest(guardian=guardian), self.assertRaises(ValueError):
                config.build_config({**self.env, "SUPABASE_URL": "https://another-project.supabase.co"}, guardian)

    def test_production_stays_closed_until_commissioned(self):
        for environment in ("production", "staging", ""):
            with self.subTest(environment=environment), self.assertRaises(ValueError):
                config.build_config({**self.env, "DOPMI_ENVIRONMENT": environment})
        self.assertEqual(config.build_config(self.env)["DOPMI_ENVIRONMENT"], "test")

    def test_rejects_anon_key_from_another_project(self):
        payload = base64.urlsafe_b64encode(json.dumps({"role": "anon", "ref": "another-project"}).encode()).decode().rstrip("=")
        with self.assertRaises(ValueError):
            config.build_config({**self.env, "SUPABASE_PUBLISHABLE_KEY": f"e30.{payload}.signature"})

    def test_firebase_is_limited_to_measurement_sdks(self):
        pubspec = (Path(__file__).resolve().parents[1] / "apps/mobile/pubspec.yaml").read_text()
        declared = {
            line.split(":", 1)[0].strip()
            for line in pubspec.splitlines()
            if line.startswith("  firebase_") or line.startswith("  cloud_")
        }
        self.assertEqual(
            declared,
            {"firebase_core", "firebase_analytics", "firebase_crashlytics"},
            "Firebase must remain limited to optional Analytics and Crashlytics; Supabase is the product backend.",
        )

    def test_native_wallets_require_guardian_workflow_and_explicit_flag(self):
        self.env.update(ENABLE_NATIVE_WALLETS_TEST="true", STRIPE_PUBLISHABLE_KEY_TEST="pk_test_fixture")
        normal = config.build_config(self.env)
        self.assertEqual(normal["ENABLE_NATIVE_WALLETS_TEST"], "false")
        self.assertEqual(normal["STRIPE_PUBLISHABLE_KEY_TEST"], "")
        enabled = config.build_config(self.env, True)
        self.assertEqual(enabled["ENABLE_NATIVE_WALLETS_TEST"], "true")
        self.assertEqual(enabled["STRIPE_PUBLISHABLE_KEY_TEST"], "pk_test_fixture")
        self.assertEqual(enabled["APPLE_PAY_MERCHANT_ID"], "")

    def test_native_wallets_reject_secret_live_missing_keys_without_echo(self):
        for value in ("", "pk_live_fixture", "sk_test_fixture", "rk_test_fixture", "sb_secret_fixture"):
            with self.subTest(value=value), self.assertRaises(ValueError) as caught:
                config.build_config({**self.env, "ENABLE_NATIVE_WALLETS_TEST": "true", "STRIPE_PUBLISHABLE_KEY_TEST": value}, True)
            if value:
                self.assertNotIn(value, str(caught.exception))

    def test_native_wallets_preserve_valid_merchant_and_reject_invalid_metadata(self):
        wallet = {**self.env, "ENABLE_NATIVE_WALLETS_TEST": " true ", "STRIPE_PUBLISHABLE_KEY_TEST": " pk_test_fixture ",
                  "APPLE_PAY_MERCHANT_ID": " merchant.com.example.fixture "}
        self.assertEqual(config.build_config(wallet, True)["APPLE_PAY_MERCHANT_ID"], "merchant.com.example.fixture")
        for value in ("secret-fixture", "https://example.com", "merchant. invalid"):
            with self.assertRaises(ValueError) as caught:
                config.build_config({**wallet, "APPLE_PAY_MERCHANT_ID": value}, True)
            self.assertNotIn(value, str(caught.exception))
        with self.assertRaises(ValueError):
            config.build_config({**wallet, "ENABLE_NATIVE_WALLETS_TEST": "yes"}, True)

    def test_disabled_native_wallets_do_not_copy_unrelated_credentials(self):
        result = config.build_config({**self.env, "STRIPE_PUBLISHABLE_KEY_TEST": "sk_test_fixture", "APPLE_PAY_MERCHANT_ID": "private"}, True)
        self.assertEqual(result["STRIPE_PUBLISHABLE_KEY_TEST"], "")
        self.assertEqual(result["APPLE_PAY_MERCHANT_ID"], "")
        self.assertEqual(result["ENABLE_NATIVE_WALLETS_TEST"], "false")

    @staticmethod
    def jwt(role):
        payload = base64.urlsafe_b64encode(json.dumps({"role": role}).encode()).decode().rstrip("=")
        return f"e30.{payload}.test_signature"


if __name__ == "__main__":
    unittest.main()
