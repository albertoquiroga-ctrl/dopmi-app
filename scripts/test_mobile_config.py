import base64
import contextlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("mobile_config", Path(__file__).with_name("write-mobile-config.py"))
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


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
        self.assertEqual(result["SUPABASE_URL"], "https://ysaoeuidcvgtlmphmeyb.supabase.co")
        self.assertEqual(result["ENABLE_GUARDIAN"], "true")
        self.assertEqual(result["STRIPE_PUBLISHABLE_KEY"], "pk_live_fixture")
        self.assertEqual(result["AUTH_REDIRECT_URL"], "io.dopmi.app://auth/callback")
        self.assertEqual(result["ENABLE_GUARDIAN_TEST"], "false")
        self.assertEqual(result["ENABLE_MEASUREMENT_TEST"], "false")
        self.assertEqual(result["ENABLE_NATIVE_WALLETS_TEST"], "false")
        self.assertEqual(result["STRIPE_PUBLISHABLE_KEY_TEST"], "")
        self.assertEqual(result["APPLE_PAY_MERCHANT_ID"], "")

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
        for options, env in (
            (["--production-beta"], self.production_env()),
            ([], self.production_env()),
            (["--production-beta"], self.env),
            (["--production-beta", "--guardian-test"], self.production_env()),
            (["--production-beta", "--measurement-test"], self.production_env()),
            (["--production-beta"], {**self.production_env(), "STRIPE_PUBLISHABLE_KEY": "sk_live_fixture"}),
        ):
            with self.subTest(options=options, environment=env.get("DOPMI_ENVIRONMENT")), tempfile.TemporaryDirectory() as directory:
                target = Path(directory) / "config.json"
                target.write_text('{"stale": true}')
                # Keep host runtime variables while isolating the fixture's supported options.
                child_env = {name: value for name, value in os.environ.items()
                             if name not in set(self.production_env()) | {
                                 "ENABLE_GOOGLE_AUTH", "ENABLE_APPLE_AUTH", "GOOGLE_SERVER_CLIENT_ID",
                                 "GOOGLE_IOS_CLIENT_ID", "ENABLE_NATIVE_WALLETS_TEST", "APPLE_PAY_MERCHANT_ID"}}
                process = subprocess.run([sys.executable, str(script), *options], cwd=directory,
                                         env={**child_env, **env}, capture_output=True, text=True)
                if options == ["--production-beta"] and env == self.production_env():
                    self.assertEqual(process.returncode, 0, process.stderr)
                    self.assertEqual(json.loads(target.read_text())["ENABLE_GUARDIAN"], "true")
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

    def test_testflight_routes_both_configs_to_the_selected_environment(self):
        git = shutil.which("git")
        git_bash = Path(git).resolve().parents[1] / "bin/bash.exe" if git else None
        bash = (str(git_bash) if os.name == "nt" and git_bash and git_bash.exists()
                else shutil.which("bash") if os.name != "nt" else None)
        if not bash:
            self.skipTest("Bash is needed to execute the Codemagic configuration steps")
        workflow = (Path(__file__).resolve().parents[1] / "codemagic.yaml").read_text()
        workflow = workflow.split("\n  ios-testflight:\n", 1)[1]

        def configuration_script(name):
            step = workflow.split(f"      - name: {name}\n", 1)[1].split("      - name:", 1)[0]
            lines = step.split("        script:", 1)[1].splitlines()
            if lines[0].strip() == "|":
                return "\n".join(line[10:] for line in lines[1:] if line.startswith("          "))
            return lines[0].strip()

        script = 'export PATH="$PWD/bin:$PATH"\n' + "\n".join(
            configuration_script(name) for name in ("Create runtime configuration", "Create Firebase configuration")
        )
        test_calls = ["../../scripts/write-mobile-config.py --guardian-test --measurement-test",
                      "../../scripts/write-firebase-config.py --platform ios"]
        production_calls = ["../../scripts/write-mobile-config.py --production-beta",
                            "../../scripts/write-firebase-config.py --production-beta --platform ios"]
        for selected, expected in ((None, test_calls), ("test", test_calls),
                                   ("production", production_calls), ("staging", None)):
            with self.subTest(environment=selected), tempfile.TemporaryDirectory() as directory:
                binary = Path(directory) / "bin/python3"
                binary.parent.mkdir()
                binary.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> calls.txt\n')
                binary.chmod(0o755)
                env = {name: value for name, value in os.environ.items()
                       if name.upper() in {"PATH", "SYSTEMROOT", "WINDIR", "TEMP", "TMP"}}
                if selected is not None:
                    env["DOPMI_ENVIRONMENT"] = selected
                process = subprocess.run([bash, "-c", script], cwd=directory, env=env,
                                         capture_output=True, text=True)
                calls = Path(directory) / "calls.txt"
                if expected is None:
                    self.assertNotEqual(process.returncode, 0)
                    self.assertFalse(calls.exists(), "Unknown environments must not invoke either writer")
                else:
                    self.assertEqual(process.returncode, 0, process.stderr)
                    self.assertEqual(calls.read_text().splitlines(), expected)

    def test_testflight_build_info_describes_the_generated_profile(self):
        workflow = (Path(__file__).resolve().parents[1] / "codemagic.yaml").read_text()
        workflow = workflow.split("\n  ios-testflight:\n", 1)[1]
        embedded = workflow.split("<<'PYINFO'\n", 1)[1].split("          PYINFO", 1)[0]
        program = "\n".join(line[10:] for line in embedded.splitlines())
        for production in (False, True):
            with self.subTest(production=production), tempfile.TemporaryDirectory() as directory:
                generated = (config.build_config(self.production_env(), production_beta=True) if production
                             else config.build_config(self.env, guardian_test=True, measurement_test=True))
                Path(directory, "config.json").write_text(json.dumps(generated))
                Path(directory, "build").mkdir()
                with contextlib.chdir(directory), patch.dict(os.environ, {"RELEASE_NAME": "2.3.3"}), \
                        patch.object(sys, "argv", ["-", "999"]), \
                        patch.object(subprocess, "check_output", return_value="fixture-source\n"):
                    exec(compile(program, "codemagic.yaml:ios-testflight-build-info", "exec"), {})
                artifact = Path(directory, "build/guardian-build-info.txt").read_text()
                self.assertIn("Environment: production\n" if production else "Environment: test\n", artifact)
                self.assertIn("Guardian test: false\n" if production else "Guardian test: true\n", artifact)
                self.assertIn("Commit: fixture-source\nVersion: 2.3.3 (999)\n", artifact)

    @staticmethod
    def jwt(role, project=None):
        claims = {"role": role}
        if project is not None:
            claims["ref"] = project
        payload = base64.urlsafe_b64encode(json.dumps(claims).encode()).decode().rstrip("=")
        return f"e30.{payload}.test_signature"


if __name__ == "__main__":
    unittest.main()
