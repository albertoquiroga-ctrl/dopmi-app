import base64
import contextlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("mobile_config", Path(__file__).with_name("write-mobile-config.py"))
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)

maps_spec = importlib.util.spec_from_file_location("maps_config", Path(__file__).with_name("write-maps-config.py"))
maps_config = importlib.util.module_from_spec(maps_spec)
maps_spec.loader.exec_module(maps_config)


def codemagic_workflow(source, workflow_id):
    heading = rf"^  {re.escape(workflow_id)}:(?: +&[\w-]+)? *\n"
    body = re.split(heading, source, maxsplit=1, flags=re.MULTILINE)[1]
    return re.split(r"^  [\w-]+:", body, maxsplit=1, flags=re.MULTILINE)[0]


class MobileConfigTests(unittest.TestCase):
    def setUp(self):
        example = Path(__file__).resolve().parents[1] / "apps/mobile/config.example.json"
        self.env = {"SUPABASE_URL": json.loads(example.read_text())["SUPABASE_URL"],
                    "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_unit_test_placeholder",
                    "STRIPE_PUBLISHABLE_KEY_TEST": "pk_test_fixture"}

    def test_guardian_requires_explicit_build_option(self):
        self.env["ENABLE_GUARDIAN_TEST"] = "true"
        self.assertEqual(config.build_config(self.env)["ENABLE_GUARDIAN_TEST"], "false")
        self.assertEqual(config.build_config(self.env, True)["ENABLE_GUARDIAN_TEST"], "true")

    def test_measurement_diagnostic_requires_explicit_build_option(self):
        self.env["ENABLE_MEASUREMENT_TEST"] = "true"
        self.assertEqual(config.build_config(self.env)["ENABLE_MEASUREMENT_TEST"], "false")
        self.assertEqual(config.build_config(self.env, measurement_test=True)["ENABLE_MEASUREMENT_TEST"], "true")

    def test_meta_ads_measurement_requires_explicit_build_option(self):
        self.env["ENABLE_META_ADS_MEASUREMENT"] = "true"
        self.assertEqual(config.build_config(self.env)["ENABLE_META_ADS_MEASUREMENT"], "false")
        enabled = config.build_config(self.env, meta_ads_measurement=True)
        self.assertEqual(enabled["ENABLE_META_ADS_MEASUREMENT"], "true")
        self.assertEqual(enabled["ENABLE_MEASUREMENT_TEST"], "false")

    def test_meta_lifecycle_default_off_does_not_copy_injected_credentials(self):
        generated = config.build_config({**self.env,
            "DOPMI_META_LIFECYCLE_ENABLED": "true", "META_LIFECYCLE_ENABLED": "true",
            "DOPMI_META_APP_ID": "1156849688851390",
            "DOPMI_META_APP_CLIENT_TOKEN": "0123456789abcdef0123456789abcdef"})
        self.assertEqual(generated.get("META_LIFECYCLE_ENABLED"), "false")
        self.assertEqual(generated.get("META_APP_ID"), "")
        self.assertEqual(generated.get("META_APP_CLIENT_TOKEN"), "")

    def test_meta_lifecycle_cli_is_explicit_and_preserves_selected_profile(self):
        script = Path(__file__).with_name("write-mobile-config.py")
        token = "0123456789abcdef0123456789abcdef"
        for production in (False, True):
            with self.subTest(production=production), tempfile.TemporaryDirectory() as directory:
                env = {name: value for name, value in os.environ.items()
                       if name.upper() in {"PATH", "SYSTEMROOT", "WINDIR", "TEMP", "TMP"}}
                env.update(self.production_env() if production else self.env)
                env.update(DOPMI_META_APP_ID="1156849688851390", DOPMI_META_APP_CLIENT_TOKEN=token)
                args = ["--production-beta", "--adoption-only", "--store-amazon-public"] if production else []
                result = subprocess.run([sys.executable, str(script), *args, "--meta-lifecycle"],
                    cwd=directory, env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                generated = json.loads(Path(directory, "config.json").read_text())
                self.assertEqual(generated["META_LIFECYCLE_ENABLED"], "true")
                self.assertEqual(generated["META_APP_ID"], "1156849688851390")
                self.assertEqual(generated["META_APP_CLIENT_TOKEN"], token)
                self.assertEqual(generated["ENABLE_META_ADS_MEASUREMENT"], "false")
                self.assertEqual(generated["DOPMI_ENVIRONMENT"], "production" if production else "test")
                self.assertEqual(generated["DOPMI_STORE_AMAZON_PUBLIC"], str(production).lower())
                self.assertEqual(generated["ENABLE_GUARDIAN"], "false")
                self.assertEqual(generated["STRIPE_PUBLISHABLE_KEY"], "")
                self.assertNotIn(token, result.stdout + result.stderr)

    def test_meta_lifecycle_cli_rejects_wrong_app_or_non_client_token_without_echo(self):
        script = Path(__file__).with_name("write-mobile-config.py")
        valid_token = "0123456789abcdef0123456789abcdef"
        invalid = [("", valid_token), ("1156849688851391", valid_token),
                   ("1156849688851390", ""), ("1156849688851390", "EAA_capi_fixture_token"),
                   ("1156849688851390", "sb_secret_fixture"),
                   ("1156849688851390", "a" * 31), ("1156849688851390", "a" * 33),
                   ("1156849688851390", "g" * 32)]
        for app_id, token in invalid:
            with self.subTest(app_id=app_id, token_length=len(token)), tempfile.TemporaryDirectory() as directory:
                env = {name: value for name, value in os.environ.items()
                       if name.upper() in {"PATH", "SYSTEMROOT", "WINDIR", "TEMP", "TMP"}}
                env.update(self.env, DOPMI_META_APP_ID=app_id, DOPMI_META_APP_CLIENT_TOKEN=token)
                Path(directory, "config.json").write_text("stale connected configuration")
                result = subprocess.run([sys.executable, str(script), "--meta-lifecycle"],
                    cwd=directory, env=env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(Path(directory, "config.json").exists())
                if token:
                    self.assertNotIn(token, result.stdout + result.stderr)

    def test_production_meta_preserves_public_adoption_profile_and_closed_finance(self):
        enabled = config.build_config(
            self.production_env(), production_beta=True, adoption_only=True,
            store_amazon_public=True, meta_ads_measurement=True,
        )
        self.assertEqual(enabled["ENABLE_META_ADS_MEASUREMENT"], "true")
        self.assertEqual(enabled["DOPMI_ENVIRONMENT"], "production")
        self.assertEqual(enabled["DOPMI_STORE_AMAZON_PUBLIC"], "true")
        self.assertEqual(enabled["ENABLE_GUARDIAN"], "false")
        self.assertEqual(enabled["ENABLE_MEASUREMENT_TEST"], "false")
        self.assertEqual(enabled["STRIPE_PUBLISHABLE_KEY"], "")

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

    def test_posthog_passes_only_explicit_ingestion_configuration(self):
        token = "phc_UnitTestFixture"
        self.assertNotIn("DOPMI_POSTHOG_PROJECT_TOKEN", config.build_config(self.env))
        for region in ("us", "eu"):
            configured = config.build_config({**self.env, "DOPMI_POSTHOG_PROJECT_TOKEN": token,
                                               "DOPMI_POSTHOG_REGION": region})
            self.assertEqual(configured["DOPMI_POSTHOG_PROJECT_TOKEN"], token)
            self.assertEqual(configured["DOPMI_POSTHOG_REGION"], region)
        for invalid_token, invalid_region in ((token, ""), ("", "us"),
                                               (token, "example.com"), ("phx_UnitTestFixture", "us")):
            with self.assertRaises(ValueError) as caught:
                config.build_config({**self.env, "DOPMI_POSTHOG_PROJECT_TOKEN": invalid_token,
                                     "DOPMI_POSTHOG_REGION": invalid_region})
            self.assertNotIn("UnitTestFixture", str(caught.exception))

    def test_invalid_or_missing_options_fail_early(self):
        for name, value in (("SUPABASE_URL", ""), ("SUPABASE_PUBLISHABLE_KEY", ""),
                            ("ENABLE_APPLE_AUTH", "yes"), ("ENABLE_GOOGLE_MAPS", "yes"), ("SUPABASE_URL", "https://example.com")):
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

    def test_production_requires_its_explicit_build_option(self):
        for environment in ("production", "staging", ""):
            with self.subTest(environment=environment), self.assertRaises(ValueError):
                config.build_config({**self.env, "DOPMI_ENVIRONMENT": environment})
        self.assertEqual(config.build_config(self.env)["DOPMI_ENVIRONMENT"], "test")

    def production_env(self):
        return {**self.env, "DOPMI_ENVIRONMENT": "production",
                "SUPABASE_URL": "https://ysaoeuidcvgtlmphmeyb.supabase.co",
                "STRIPE_PUBLISHABLE_KEY": "pk_live_fixture"}

    def test_production_beta_uses_registered_project_and_live_public_key(self):
        result = config.build_config(self.production_env(), production_beta=True)
        self.assertEqual(result["DOPMI_ENVIRONMENT"], "production")
        self.assertEqual(result["DOPMI_ADOPTION_ONLY"], "false")
        self.assertEqual(result["SUPABASE_URL"], "https://ysaoeuidcvgtlmphmeyb.supabase.co")
        self.assertEqual(result["ENABLE_GUARDIAN"], "true")
        self.assertEqual(result["STRIPE_PUBLISHABLE_KEY"], "pk_live_fixture")
        self.assertEqual(result["AUTH_REDIRECT_URL"], "io.dopmi.app://auth/callback")
        self.assertEqual(result["ENABLE_GUARDIAN_TEST"], "false")
        self.assertEqual(result["ENABLE_MEASUREMENT_TEST"], "false")
        self.assertEqual(result["ENABLE_NATIVE_WALLETS_TEST"], "false")
        self.assertEqual(result["STRIPE_PUBLISHABLE_KEY_TEST"], "")
        self.assertEqual(result["APPLE_PAY_MERCHANT_ID"], "")

    def test_adoption_only_uses_production_without_stripe_or_guardian(self):
        env = {
            **self.production_env(),
            "DOPMI_ADOPTION_ONLY": "true",
            "ENABLE_NATIVE_WALLETS_TEST": "true",
            "APPLE_PAY_MERCHANT_ID": "merchant.test.fixture",
        }
        result = config.build_config(env, production_beta=True, adoption_only=True)
        self.assertEqual(result["SUPABASE_URL"], self.production_env()["SUPABASE_URL"])
        self.assertEqual(result["DOPMI_ADOPTION_ONLY"], "true")
        self.assertEqual(result["DOPMI_STORE_REVIEW"], "false")
        for name in ("ENABLE_GUARDIAN", "ENABLE_GUARDIAN_TEST", "ENABLE_NATIVE_WALLETS_TEST"):
            self.assertEqual(result[name], "false")
        for name in ("STRIPE_PUBLISHABLE_KEY", "STRIPE_PUBLISHABLE_KEY_TEST", "APPLE_PAY_MERCHANT_ID"):
            self.assertEqual(result[name], "")
        env.pop("STRIPE_PUBLISHABLE_KEY")
        self.assertEqual(config.build_config(env, production_beta=True, adoption_only=True), result)

    def test_store_review_only_adds_its_own_flag_to_production_adoption(self):
        env = {**self.production_env(), "DOPMI_ADOPTION_ONLY": "true"}
        env.pop("STRIPE_PUBLISHABLE_KEY")
        adoption = config.build_config(env, production_beta=True, adoption_only=True)
        review = config.build_config(
            {**env, "DOPMI_STORE_REVIEW": "true"},
            production_beta=True, adoption_only=True, store_review=True,
        )
        self.assertEqual(review, {**adoption, "DOPMI_STORE_REVIEW": "true"})
        self.assertEqual(config.build_config(self.env)["DOPMI_STORE_REVIEW"], "false")

    def test_store_review_rejects_incompatible_or_implicit_selection(self):
        production = self.production_env()
        cases = (
            (self.env, False, False, True),
            (production, True, False, True),
            ({**production, "DOPMI_STORE_REVIEW": "true"}, True, True, False),
            ({**production, "DOPMI_STORE_REVIEW": "false"}, True, True, True),
            ({**production, "DOPMI_STORE_REVIEW": "yes"}, True, True, False),
        )
        for env, beta, adoption, review in cases:
            with self.subTest(beta=beta, adoption=adoption, review=review), self.assertRaises(ValueError):
                config.build_config(env, production_beta=beta, adoption_only=adoption, store_review=review)

    def test_public_amazon_store_is_an_explicit_production_adoption_option(self):
        production = self.production_env()
        adoption = config.build_config(production, production_beta=True, adoption_only=True)
        public = config.build_config(
            {**production, "DOPMI_STORE_AMAZON_PUBLIC": "true"},
            production_beta=True, adoption_only=True, store_amazon_public=True,
        )
        self.assertEqual(public, {**adoption, "DOPMI_STORE_AMAZON_PUBLIC": "true"})
        self.assertEqual(config.build_config(self.env)["DOPMI_STORE_AMAZON_PUBLIC"], "false")
        invalid = (
            (self.env, False, False, False, True),
            (production, True, False, False, True),
            (production, True, True, True, True),
            ({**production, "DOPMI_STORE_AMAZON_PUBLIC": "true"}, True, True, False, False),
            ({**production, "DOPMI_STORE_AMAZON_PUBLIC": "false"}, True, True, False, True),
            ({**production, "DOPMI_STORE_AMAZON_PUBLIC": "yes"}, True, True, False, False),
        )
        for env, beta, adoption_only, review, public in invalid:
            with self.subTest(beta=beta, adoption=adoption_only, review=review, public=public), self.assertRaises(ValueError):
                config.build_config(env, production_beta=beta, adoption_only=adoption_only,
                                    store_review=review, store_amazon_public=public)

    def test_adoption_only_rejects_wrong_environment_or_conflicting_request(self):
        cases = (
            (self.env, False, True),
            ({**self.production_env(), "SUPABASE_URL": self.env["SUPABASE_URL"]}, True, True),
            ({**self.production_env(), "DOPMI_ADOPTION_ONLY": "false"}, True, True),
            ({**self.production_env(), "DOPMI_ADOPTION_ONLY": "true"}, True, False),
            ({**self.production_env(), "DOPMI_ADOPTION_ONLY": "yes"}, True, False),
        )
        for env, production, adoption_only in cases:
            with self.subTest(production=production, adoption_only=adoption_only, requested=env.get("DOPMI_ADOPTION_ONLY")):
                with self.assertRaises(ValueError):
                    config.build_config(env, production_beta=production, adoption_only=adoption_only)

    def test_production_beta_cannot_be_combined_with_test_build_options(self):
        for guardian, measurement in ((True, False), (False, True), (True, True)):
            with self.subTest(guardian=guardian, measurement=measurement), self.assertRaises(ValueError):
                config.build_config(self.production_env(), guardian, measurement, production_beta=True)

    def test_production_beta_does_not_copy_test_flags_or_merchant(self):
        env = {**self.production_env(), "ENABLE_GUARDIAN_TEST": "true",
               "ENABLE_MEASUREMENT_TEST": "true", "ENABLE_NATIVE_WALLETS_TEST": "true",
               "APPLE_PAY_MERCHANT_ID": "merchant.test.fixture"}
        result = config.build_config(env, production_beta=True)
        for name in ("ENABLE_GUARDIAN_TEST", "ENABLE_MEASUREMENT_TEST", "ENABLE_NATIVE_WALLETS_TEST"):
            self.assertEqual(result[name], "false")
        self.assertEqual(result["STRIPE_PUBLISHABLE_KEY_TEST"], "")
        self.assertEqual(result["APPLE_PAY_MERCHANT_ID"], "")

    def test_test_profile_cannot_copy_live_configuration(self):
        result = config.build_config(self.env, True, True)
        self.assertEqual(result["ENABLE_GUARDIAN"], "false")
        self.assertEqual(result["STRIPE_PUBLISHABLE_KEY"], "")
        with self.assertRaises(ValueError):
            config.build_config({**self.env, "STRIPE_PUBLISHABLE_KEY": "pk_live_fixture"}, True)

    def test_environment_and_endpoint_crosses_fail_closed(self):
        for env, production in (
            (self.production_env(), False),
            (self.env, True),
            ({**self.production_env(), "SUPABASE_URL": self.env["SUPABASE_URL"]}, True),
            ({**self.env, "SUPABASE_URL": self.production_env()["SUPABASE_URL"]}, False),
            ({**self.production_env(), "SUPABASE_URL": "https://another-project.supabase.co"}, True),
            ({**self.production_env(), "DOPMI_ENVIRONMENT": "staging"}, True),
        ):
            with self.subTest(environment=env.get("DOPMI_ENVIRONMENT"), production=production), self.assertRaises(ValueError):
                config.build_config(env, production_beta=production)

    def test_production_beta_rejects_non_live_or_server_stripe_keys_without_echo(self):
        for value in ("", "pk_test_fixture", "sk_live_fixture", "rk_live_fixture", "sb_secret_fixture"):
            with self.subTest(value=value), self.assertRaises(ValueError) as caught:
                config.build_config({**self.production_env(), "STRIPE_PUBLISHABLE_KEY": value}, production_beta=True)
            if value:
                self.assertNotIn(value, str(caught.exception))

    def test_production_beta_requires_the_exact_anon_project_reference(self):
        for project in (None, "", "another-project", "ohqxranynackjignryep", "ysaoeuidcvgtlmphmeyb"):
            env = {**self.production_env(), "SUPABASE_PUBLISHABLE_KEY": self.jwt("anon", project)}
            with self.subTest(project=project):
                if project == "ysaoeuidcvgtlmphmeyb":
                    self.assertEqual(config.build_config(env, production_beta=True)["SUPABASE_PUBLISHABLE_KEY"], env["SUPABASE_PUBLISHABLE_KEY"])
                else:
                    with self.assertRaises(ValueError):
                        config.build_config(env, production_beta=True)

    def test_production_beta_rejects_server_supabase_keys_without_echo(self):
        for value in ("sb_secret_fixture", self.jwt("service_role", "ysaoeuidcvgtlmphmeyb")):
            with self.subTest(value=value), self.assertRaises(ValueError) as caught:
                config.build_config({**self.production_env(), "SUPABASE_PUBLISHABLE_KEY": value}, production_beta=True)
            self.assertNotIn(value, str(caught.exception))

    def test_cli_production_beta_and_failure_remove_stale_config(self):
        script = Path(__file__).with_name("write-mobile-config.py").resolve()
        for options, env, expected_guardian in (
            (["--production-beta"], self.production_env(), "true"),
            (["--production-beta", "--adoption-only"],
             {**self.production_env(), "DOPMI_ADOPTION_ONLY": "true"}, "false"),
            (["--production-beta", "--adoption-only", "--store-review"],
             {**self.production_env(), "DOPMI_ADOPTION_ONLY": "true", "DOPMI_STORE_REVIEW": "true"}, "false"),
            (["--production-beta", "--adoption-only", "--store-amazon-public"],
             {**self.production_env(), "DOPMI_ADOPTION_ONLY": "true", "DOPMI_STORE_AMAZON_PUBLIC": "true"}, "false"),
            (["--production-beta", "--adoption-only"],
             {**self.production_env(), "DOPMI_ADOPTION_ONLY": "true", "DOPMI_STORE_REVIEW": "true"}, None),
            (["--production-beta", "--adoption-only", "--store-review", "--store-amazon-public"],
             self.production_env(), None),
            ([], self.production_env(), None),
            (["--production-beta"], self.env, None),
            (["--production-beta", "--guardian-test"], self.production_env(), None),
            (["--production-beta", "--measurement-test"], self.production_env(), None),
            (["--production-beta"], {**self.production_env(), "STRIPE_PUBLISHABLE_KEY": "sk_live_fixture"}, None),
        ):
            with self.subTest(options=options, environment=env.get("DOPMI_ENVIRONMENT")), tempfile.TemporaryDirectory() as directory:
                target = Path(directory) / "config.json"
                target.write_text('{"stale": true}')
                # Keep host runtime variables while isolating the fixture's supported options.
                child_env = {name: value for name, value in os.environ.items()
                             if name not in set(self.production_env()) | {
                                 "ENABLE_GOOGLE_AUTH", "ENABLE_APPLE_AUTH", "GOOGLE_SERVER_CLIENT_ID",
                                 "GOOGLE_IOS_CLIENT_ID", "ENABLE_NATIVE_WALLETS_TEST", "APPLE_PAY_MERCHANT_ID",
                                 "DOPMI_ADOPTION_ONLY", "DOPMI_STORE_REVIEW", "DOPMI_STORE_AMAZON_PUBLIC"}}
                process = subprocess.run([sys.executable, str(script), *options], cwd=directory,
                                         env={**child_env, **env}, capture_output=True, text=True)
                if expected_guardian is not None:
                    self.assertEqual(process.returncode, 0, process.stderr)
                    result = json.loads(target.read_text())
                    adoption = "--adoption-only" in options
                    self.assertEqual(result["DOPMI_ADOPTION_ONLY"], str(adoption).lower())
                    self.assertEqual(result["DOPMI_STORE_REVIEW"], str("--store-review" in options).lower())
                    self.assertEqual(result["DOPMI_STORE_AMAZON_PUBLIC"], str("--store-amazon-public" in options).lower())
                    self.assertEqual(result["ENABLE_GUARDIAN"], expected_guardian)
                else:
                    self.assertNotEqual(process.returncode, 0)
                    self.assertFalse(target.exists())
                for value in (env["SUPABASE_PUBLISHABLE_KEY"], env.get("STRIPE_PUBLISHABLE_KEY", "")):
                    if value:
                        self.assertNotIn(value, process.stdout + process.stderr)

    def test_production_example_contains_only_empty_public_credentials(self):
        example = Path(__file__).resolve().parents[1] / "apps/mobile/config.production.example.json"
        values = json.loads(example.read_text())
        self.assertEqual(values["DOPMI_ENVIRONMENT"], "production")
        self.assertEqual(values["SUPABASE_URL"], self.production_env()["SUPABASE_URL"])
        self.assertEqual(values["SUPABASE_PUBLISHABLE_KEY"], "")
        self.assertEqual(values["STRIPE_PUBLISHABLE_KEY"], "")
        self.assertEqual(values["STRIPE_PUBLISHABLE_KEY_TEST"], "")

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

    def test_guardian_native_card_does_not_enable_optional_wallets(self):
        for wallet_flag in (None, "false", " false "):
            with self.subTest(wallet_flag=wallet_flag):
                env = {**self.env, "STRIPE_PUBLISHABLE_KEY_TEST": " pk_test_fixture ",
                       "APPLE_PAY_MERCHANT_ID": "private-metadata-not-for-card-flow"}
                if wallet_flag is not None:
                    env["ENABLE_NATIVE_WALLETS_TEST"] = wallet_flag
                result = config.build_config(env, True)
                self.assertEqual(result["STRIPE_PUBLISHABLE_KEY_TEST"], "pk_test_fixture")
                self.assertEqual(result["ENABLE_NATIVE_WALLETS_TEST"], "false")
                self.assertEqual(result["APPLE_PAY_MERCHANT_ID"], "")

    def test_guardian_cards_reject_secret_live_missing_keys_without_echo(self):
        for value in ("", "pk_live_fixture", "sk_test_fixture", "rk_test_fixture", "sb_secret_fixture"):
            for wallet_flag in ("false", "true"):
                with self.subTest(value=value, wallet_flag=wallet_flag), self.assertRaises(ValueError) as caught:
                    config.build_config({**self.env, "ENABLE_NATIVE_WALLETS_TEST": wallet_flag,
                                         "STRIPE_PUBLISHABLE_KEY_TEST": value}, True)
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

    def test_standard_workflow_does_not_copy_unrelated_credentials(self):
        result = config.build_config({**self.env, "STRIPE_PUBLISHABLE_KEY_TEST": "sk_test_fixture", "APPLE_PAY_MERCHANT_ID": "private"})
        self.assertEqual(result["STRIPE_PUBLISHABLE_KEY_TEST"], "")
        self.assertEqual(result["APPLE_PAY_MERCHANT_ID"], "")
        self.assertEqual(result["ENABLE_NATIVE_WALLETS_TEST"], "false")

    def test_beta_workflows_route_both_configs_to_the_selected_environment(self):
        git = shutil.which("git")
        git_bash = Path(git).resolve().parents[1] / "bin/bash.exe" if git else None
        bash = (str(git_bash) if os.name == "nt" and git_bash and git_bash.exists()
                else shutil.which("bash") if os.name != "nt" else None)
        if not bash:
            self.skipTest("Bash is needed to execute the Codemagic configuration steps")
        codemagic = (Path(__file__).resolve().parents[1] / "codemagic.yaml").read_text(encoding="utf-8")

        def configuration_script(workflow, name):
            step = workflow.split(f"      - name: {name}\n", 1)[1].split("      - name:", 1)[0]
            lines = step.split("        script:", 1)[1].splitlines()
            if lines[0].strip().endswith("|"):
                return "\n".join(line[10:] for line in lines[1:] if line.startswith("          "))
            return lines[0].strip()

        for workflow_id, source_id, platform, steps in (
            ("android-guardian-internal", "android-guardian-internal", "android",
             ("Create explicit Guardian environment configuration", "Create matching Guardian Firebase configuration")),
            ("android-play-production", "android-play-production", "android",
             ("Require the public Amazon adoption profile", "Create matching Guardian Firebase configuration")),
            ("ios-testflight", "ios-testflight", "ios", ("Create runtime configuration", "Create Firebase configuration")),
            ("ios-app-store", "ios-app-store", "ios", ("Require the App Store adoption profile", "Create Firebase configuration")),
        ):
            workflow = codemagic_workflow(codemagic, source_id)
            firebase_workflow = workflow
            if workflow_id == "android-play-production":
                self.assertIn("script: *android-signed-firebase", workflow)
                firebase_workflow = codemagic_workflow(codemagic, "android-guardian-internal")
            if workflow_id == "ios-app-store":
                self.assertIn("script: *ios-signed-firebase", workflow)
                firebase_workflow = codemagic_workflow(codemagic, "ios-testflight")
            script = 'export PATH="$PWD/bin:$PATH"\n' + "\n".join([
                configuration_script(workflow, steps[0]),
                configuration_script(firebase_workflow, steps[1]),
            ])
            test_calls = ["../../scripts/write-mobile-config.py --guardian-test --measurement-test",
                          f"../../scripts/write-firebase-config.py --platform {platform}"]
            production_calls = ["../../scripts/write-mobile-config.py --production-beta",
                                f"../../scripts/write-firebase-config.py --production-beta --platform {platform}"]
            adoption_calls = [production_calls[0] + " --adoption-only", production_calls[1]]
            review_calls = [adoption_calls[0] + " --store-review", adoption_calls[1]]
            public_calls = [adoption_calls[0] + " --store-amazon-public", adoption_calls[1]]
            profiles = (
                (None, None, None, None, test_calls),
                ("test", None, None, None, test_calls),
                ("production", None, None, None, production_calls),
                ("production", "true", "false", None, adoption_calls),
                ("production", "true", "false", "false", adoption_calls),
                ("production", "true", "false", "true", public_calls),
                ("production", "true", "true", "true", None),
                ("production", "false", "false", "true", None),
                ("production", "true", "false", "yes", None),
                ("production", "true", "false", "", None),
                ("test", "true", "false", "true", None),
                ("production", "true", "true", None, review_calls if platform == "android" else None),
                ("production", None, "true", None, None),
                ("production", "true", "yes", None, None),
                ("production", "true", "", None, None),
                ("test", None, "true", None, None),
                ("test", "true", None, None, None),
                ("production", "yes", None, None, None),
                ("production", "", None, None, None),
                ("staging", None, None, None, None),
            )
            cases = [(*profile, {}) for profile in profiles]
            for lifecycle_setting, expected in (
                ("true", [public_calls[0] + " --meta-lifecycle", public_calls[1]]),
                ("false", public_calls), ("", None), ("yes", None),
            ):
                cases.append(("production", "true", "false", "true", expected,
                              {"DOPMI_META_LIFECYCLE_ENABLED": lifecycle_setting}))
            if platform == "android":
                for meta_ads_setting, expected in (
                    ("true", [public_calls[0] + " --meta-ads-measurement", public_calls[1]]),
                    ("false", public_calls),
                    ("", None),
                    ("yes", None),
                ):
                    cases.append(("production", "true", "false", "true", expected,
                                  {"DOPMI_ANDROID_META_ADS_MEASUREMENT": meta_ads_setting}))
                cases.append(("production", "true", "false", "true",
                    [public_calls[0] + " --meta-ads-measurement --meta-lifecycle", public_calls[1]],
                    {"DOPMI_ANDROID_META_ADS_MEASUREMENT": "true", "DOPMI_META_LIFECYCLE_ENABLED": "true"}))
            if workflow_id == "android-play-production":
                cases += [
                    ("production", "true", "false", "true", public_calls, {"GOOGLE_PLAY_TRACK": "production"}),
                    ("production", "true", "false", "true", None, {"GOOGLE_PLAY_TRACK": "internal"}),
                    ("production", "true", "false", "true", None, {"DOPMI_PLAY_PRODUCTION_SUBMISSION": "false"}),
                ]
            if workflow_id == "ios-app-store":
                cases += [
                    ("production", "true", "false", "true", None, {"DOPMI_APP_STORE_SUBMISSION": "false"}),
                    ("test", "false", "false", "false", None, {"DOPMI_APP_STORE_SUBMISSION": "false"}),
                ]
            for selected, adoption, review, public, expected, overrides in cases:
                with self.subTest(workflow=workflow_id, environment=selected, adoption=adoption, review=review, public=public, overrides=overrides), \
                        tempfile.TemporaryDirectory() as directory:
                    binary = Path(directory) / "bin/python3"
                    binary.parent.mkdir()
                    binary.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> calls.txt\n')
                    binary.chmod(0o755)
                    env = {name: value for name, value in os.environ.items()
                           if name.upper() in {"PATH", "SYSTEMROOT", "WINDIR", "TEMP", "TMP"}}
                    if workflow_id == "ios-app-store":
                        env["DOPMI_APP_STORE_SUBMISSION"] = "true"
                        if (selected, adoption, review) != ("production", "true", "false"):
                            expected = None
                    if workflow_id == "android-play-production":
                        env["DOPMI_PLAY_PRODUCTION_SUBMISSION"] = "true"
                        if (selected, adoption, review, public) != ("production", "true", "false", "true"):
                            expected = None
                    if selected is not None:
                        env["DOPMI_ENVIRONMENT"] = selected
                    if adoption is not None:
                        env["DOPMI_ADOPTION_ONLY"] = adoption
                    if review is not None:
                        env["DOPMI_STORE_REVIEW"] = review
                    if public is not None:
                        env["DOPMI_STORE_AMAZON_PUBLIC"] = public
                    env.update(overrides)
                    process = subprocess.run([bash, "-c", script], cwd=directory, env=env,
                                             capture_output=True, text=True)
                    calls = Path(directory) / "calls.txt"
                    if expected is None:
                        self.assertNotEqual(process.returncode, 0)
                        self.assertFalse(calls.exists(), "Invalid profiles must not invoke either writer")
                    else:
                        self.assertEqual(process.returncode, 0, process.stderr)
                        self.assertEqual(calls.read_text().splitlines(), expected)

    def test_public_play_publication_uses_existing_identity_and_signed_build(self):
        codemagic = (Path(__file__).resolve().parents[1] / "codemagic.yaml").read_text(encoding="utf-8")
        workflow = codemagic_workflow(codemagic, "android-play-production")
        self.assertIn("<<: *android-signed-release", workflow)
        self.assertIn("<<: *android-signed-environment", workflow)
        self.assertIn("<<: *android-signed-vars", workflow)
        self.assertIn("DOPMI_PLAY_PRODUCTION_SUBMISSION: 'true'", workflow)
        self.assertIn("DOPMI_STORE_AMAZON_PUBLIC: 'true'", workflow)
        self.assertIn("script: *android-signed-bundle", workflow)
        self.assertIn("track: production", workflow)
        self.assertIn("submit_as_draft: false", workflow)
        self.assertNotIn("track: internal", workflow)

    def test_app_store_publication_reuses_signed_ipa_after_its_required_guard(self):
        codemagic = (Path(__file__).resolve().parents[1] / "codemagic.yaml").read_text(encoding="utf-8")
        workflow = codemagic_workflow(codemagic, "ios-app-store")
        scripts = workflow.split("    scripts:\n", 1)[1]
        self.assertTrue(scripts.startswith("      - name: Require the App Store adoption profile\n"))
        self.assertIn("script: *ios-signed-ipa", scripts)
        self.assertIn("DOPMI_APP_STORE_SUBMISSION: 'true'", workflow)
        self.assertIn("submit_to_app_store: true", workflow)
        self.assertIn("release_type: AFTER_APPROVAL", workflow)

    def test_testflight_build_info_describes_the_generated_profile(self):
        workflow = (Path(__file__).resolve().parents[1] / "codemagic.yaml").read_text(encoding="utf-8")
        workflow = codemagic_workflow(workflow, "ios-testflight")
        embedded = workflow.split("<<'PYINFO'\n", 1)[1].split("          PYINFO", 1)[0]
        program = "\n".join(line[10:] for line in embedded.splitlines())
        for production, adoption, public in ((False, False, False), (True, False, False),
                                             (True, True, False), (True, True, True)):
            with self.subTest(production=production, adoption=adoption, public=public), tempfile.TemporaryDirectory() as directory:
                generated = (config.build_config(self.production_env(), production_beta=True,
                    adoption_only=adoption, store_amazon_public=public) if production
                             else config.build_config(self.env, guardian_test=True, measurement_test=True))
                Path(directory, "config.json").write_text(json.dumps(generated))
                Path(directory, "build").mkdir()
                release_env = {"RELEASE_NAME": "2.3.3", "DOPMI_APP_STORE_SUBMISSION": str(public).lower()}
                with contextlib.chdir(directory), patch.dict(os.environ, release_env), \
                        patch.object(sys, "argv", ["-", "999"]), \
                        patch.object(subprocess, "check_output", return_value="fixture-source\n"):
                    exec(compile(program, "codemagic.yaml:ios-testflight-build-info", "exec"), {})
                artifact = Path(directory, "build/guardian-build-info.txt").read_text()
                self.assertIn("Environment: production\n" if production else "Environment: test\n", artifact)
                self.assertIn(f"Adoption only: {str(adoption).lower()}\n", artifact)
                self.assertIn("Store review: false\n", artifact)
                self.assertIn(f"Amazon Store public: {str(public).lower()}\n", artifact)
                self.assertIn(f"Distribution: {'App Store submission' if public else 'TestFlight (external eligible)'}\n", artifact)
                self.assertIn(f"Stripe live client: {str(production and not adoption).lower()}\n", artifact)
                self.assertIn("Guardian test: false\n" if production else "Guardian test: true\n", artifact)
                self.assertIn("Commit: fixture-source\nVersion: 2.3.3 (999)\n", artifact)

    def test_signed_receipts_report_lifecycle_state_and_app_without_client_token(self):
        codemagic = (Path(__file__).resolve().parents[1] / "codemagic.yaml").read_text(encoding="utf-8")
        token = "0123456789abcdef0123456789abcdef"
        for workflow_id in ("android-guardian-internal", "ios-testflight"):
            workflow = codemagic_workflow(codemagic, workflow_id)
            embedded = workflow.split("<<'PYINFO'\n", 1)[1].split("          PYINFO", 1)[0]
            program = "\n".join(line[10:] for line in embedded.splitlines())
            for enabled in (False, True):
                with self.subTest(workflow=workflow_id, enabled=enabled), tempfile.TemporaryDirectory() as directory:
                    generated = config.build_config(self.production_env(), production_beta=True,
                        adoption_only=True, store_amazon_public=True)
                    generated.update(META_LIFECYCLE_ENABLED=str(enabled).lower(),
                        META_APP_ID="1156849688851390" if enabled else "", META_APP_CLIENT_TOKEN=token)
                    Path(directory, "config.json").write_text(json.dumps(generated))
                    Path(directory, "build").mkdir()
                    android = Path(directory, "android/app/google-services.json")
                    android.parent.mkdir(parents=True)
                    android.write_text(json.dumps({"project_info": {"project_id": "dopmi-production"},
                        "client": [{"client_info": {"android_client_info": {"package_name": "com.mycompany.dopmi"},
                                                     "mobilesdk_app_id": "fixture-firebase-app"}}]}))
                    ios = Path(directory, "ios/Runner/GoogleService-Info.plist")
                    ios.parent.mkdir(parents=True)
                    ios.write_text("fixture-ios-config")
                    with contextlib.chdir(directory), patch.dict(os.environ, {"RELEASE_NAME": "2.3.11"}), \
                            patch.object(sys, "argv", ["-", "999"]), \
                            patch.object(subprocess, "check_output", return_value="fixture-source\n"):
                        exec(compile(program, f"codemagic.yaml:{workflow_id}-build-info", "exec"), {})
                    receipt = Path(directory, "build/guardian-build-info.txt").read_text()
                    self.assertIn(f"Meta lifecycle: {str(enabled).lower()}\n", receipt)
                    self.assertIn("Meta app: 1156849688851390\n" if enabled else "Meta app: \n", receipt)
                    self.assertNotIn(token, receipt)
                    self.assertNotIn("META_APP_CLIENT_TOKEN", receipt)

    def test_ios_builds_enforce_foreground_only_location_before_publication(self):
        root = Path(__file__).resolve().parents[1]
        codemagic = (root / "codemagic.yaml").read_text(encoding="utf-8")
        for name, argument in (("ios-verify", '--app "$CM_BUILD_DIR/apps/mobile/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"'),
                               ("ios-testflight", '--ipa "$IPA_PATH"')):
            with self.subTest(workflow=name):
                workflow = codemagic_workflow(codemagic, name)
                environment, scripts = workflow.split("    scripts:\n", 1)
                self.assertIn("BYPASS_PERMISSION_LOCATION_ALWAYS: '1'", environment)
                guard = f"python3 ../../scripts/verify-ios-foreground-location.py {argument}"
                self.assertLess(scripts.index('if [ -z "$IPA_PATH" ]'), scripts.index(guard))
                self.assertLess(scripts.index(guard), scripts.index('echo "IPA ready for publishing:'))
                self.assertIn("set -euo pipefail", scripts.split("      - name: Build signed IPA\n", 1)[1])
        ci = (root / ".github/workflows/milestone-1.yml").read_text(encoding="utf-8")
        ios = ci.split("\n  ios:\n", 1)[1].split("\n  identity-and-adoption-backend:", 1)[0]
        self.assertIn("BYPASS_PERMISSION_LOCATION_ALWAYS: '1'", ios.split("    steps:\n", 1)[0])
        self.assertLess(ios.index("flutter build ios --simulator"),
                        ios.index("python3 scripts/verify-ios-foreground-location.py --app apps/mobile/build/ios/iphonesimulator/Runner.app"))
        self.assertIn("\n  geolocator_apple: 2.3.15\n", (root / "apps/mobile/pubspec.yaml").read_text(encoding="utf-8"))

    @staticmethod
    def jwt(role, project=None):
        claims = {"role": role}
        if project is not None:
            claims["ref"] = project
        payload = base64.urlsafe_b64encode(json.dumps(claims).encode()).decode().rstrip("=")
        return f"e30.{payload}.test_signature"


class MapsConfigTests(unittest.TestCase):
    def test_disabled_maps_does_not_reuse_old_ios_key(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "ios/Flutter/DopmiMaps.local.xcconfig"
            target.parent.mkdir(parents=True)
            target.write_text("DOPMI_MAPS_IOS_KEY=stale", encoding="utf-8")
            self.assertFalse(maps_config.write_config({}, "ios", root))
            self.assertEqual(target.read_text(encoding="utf-8"), "DOPMI_MAPS_IOS_KEY=\n")

    def test_failed_maps_validation_removes_stale_native_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "ios/Flutter/DopmiMaps.local.xcconfig"
            target.parent.mkdir(parents=True)
            target.write_text("stale", encoding="utf-8")
            with self.assertRaises(ValueError):
                maps_config.write_config({"ENABLE_GOOGLE_MAPS": "true"}, "ios", root)
            self.assertFalse(target.exists())

    def test_maps_keys_are_platform_specific(self):
        key = "AIza" + "A" * 35
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = {"ENABLE_GOOGLE_MAPS": "true", "GOOGLE_MAPS_ANDROID_API_KEY": key}
            self.assertTrue(maps_config.write_config(env, "android", root))
            with self.assertRaises(ValueError):
                maps_config.write_config(env, "ios", root)
            env = {"ENABLE_GOOGLE_MAPS": "true", "GOOGLE_MAPS_IOS_API_KEY": key}
            self.assertTrue(maps_config.write_config(env, "ios", root))
            with self.assertRaises(ValueError):
                maps_config.write_config(env, "android", root)

    def test_maps_cli_never_prints_native_key(self):
        key = "AIza" + "A" * 35
        script = Path(__file__).with_name("write-maps-config.py")
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([sys.executable, str(script), "--platform", "ios"],
                cwd=directory, env={**os.environ, "ENABLE_GOOGLE_MAPS": "true",
                    "GOOGLE_MAPS_IOS_API_KEY": key}, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn(key, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
