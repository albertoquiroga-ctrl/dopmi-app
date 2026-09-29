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

    @staticmethod
    def jwt(role):
        payload = base64.urlsafe_b64encode(json.dumps({"role": role}).encode()).decode().rstrip("=")
        return f"e30.{payload}.test_signature"


if __name__ == "__main__":
    unittest.main()
