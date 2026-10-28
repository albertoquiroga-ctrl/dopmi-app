"""Create Codemagic's temporary Flutter config without logging credentials."""
import argparse
import base64
import json
import os
from pathlib import Path
import re


PRODUCTION_URL = "https://ysaoeuidcvgtlmphmeyb.supabase.co"


def client_key(value, project_ref=None, require_project_ref=False):
    if re.fullmatch(r"sb_publishable_[A-Za-z0-9_-]+", value):
        return True
    try:
        parts = value.split(".")
        if len(parts) != 3:
            return False
        payload = parts[1] + "=" * (-len(parts[1]) % 4)
        claims = json.loads(base64.urlsafe_b64decode(payload))
        if claims["role"] != "anon":
            return False
        ref = claims.get("ref")
        if require_project_ref:
            return ref == project_ref
        return ref is None or project_ref is None or ref == project_ref
    except (ValueError, KeyError, IndexError, TypeError):
        return False


def build_config(env, guardian_test=False, measurement_test=False, production_beta=False):
    endpoint = "".join(env.get("SUPABASE_URL", "").split()).rstrip("/")
    key = "".join(env.get("SUPABASE_PUBLISHABLE_KEY", "").split())
    if not re.fullmatch(r"https://[a-z0-9-]+\.supabase\.co", endpoint):
        raise ValueError("SUPABASE_URL is missing or invalid in dopmi_supabase.")
    expected = json.loads((Path(__file__).resolve().parents[1] / "apps/mobile/config.example.json").read_text())
    environment = env.get("DOPMI_ENVIRONMENT", "test").strip().lower()
    if environment not in ("test", "production"):
        raise ValueError("DOPMI_ENVIRONMENT must be test or production.")
    if production_beta and (guardian_test or measurement_test):
        raise ValueError("Production beta cannot be combined with test build options.")
    if (environment == "production") != production_beta:
        raise ValueError("Production requires DOPMI_ENVIRONMENT=production and --production-beta together.")
    registered_url = PRODUCTION_URL if production_beta else expected["SUPABASE_URL"].rstrip("/")
    if endpoint != registered_url:
        raise ValueError("The endpoint does not match the registered environment.")
    project_ref = endpoint.split("//")[1].split(".")[0]
    if not client_key(key, project_ref, require_project_ref=production_beta):
        raise ValueError("A publishable or anon client key for the configured project is required.")
    if not production_beta and env.get("STRIPE_PUBLISHABLE_KEY", "").strip():
        raise ValueError("STRIPE_PUBLISHABLE_KEY is reserved for the production beta profile.")
    result = {
        "DOPMI_ENVIRONMENT": environment,
        "SUPABASE_URL": endpoint,
        "SUPABASE_PUBLISHABLE_KEY": key,
        "AUTH_REDIRECT_URL": "io.dopmi.app://auth/callback",
        "ENABLE_GUARDIAN_TEST": str(guardian_test).lower(),
        "ENABLE_MEASUREMENT_TEST": str(measurement_test).lower(),
        "ENABLE_GUARDIAN": str(production_beta).lower(),
        "STRIPE_PUBLISHABLE_KEY": "",
    }
    for name in ("ENABLE_GOOGLE_AUTH", "ENABLE_APPLE_AUTH"):
        value = env.get(name, "false").strip().lower() or "false"
        if value not in ("true", "false"):
            raise ValueError(f"{name} must be true or false.")
        result[name] = value
    for name in ("GOOGLE_SERVER_CLIENT_ID", "GOOGLE_IOS_CLIENT_ID"):
        value = env.get(name, "").strip()
        if value and not re.fullmatch(r"[A-Za-z0-9-]+\.apps\.googleusercontent\.com", value):
            raise ValueError(f"{name} must be a Google OAuth client identifier.")
        result[name] = value
    if result["ENABLE_GOOGLE_AUTH"] == "true" and not result["GOOGLE_SERVER_CLIENT_ID"]:
        raise ValueError("Google authentication requires GOOGLE_SERVER_CLIENT_ID.")
    native = env.get("ENABLE_NATIVE_WALLETS_TEST", "false").strip().lower() or "false"
    if native not in ("true", "false"):
        raise ValueError("ENABLE_NATIVE_WALLETS_TEST must be true or false.")
    enabled = guardian_test and native == "true"
    result["ENABLE_NATIVE_WALLETS_TEST"] = str(enabled).lower()
    result["STRIPE_PUBLISHABLE_KEY_TEST"] = ""
    result["APPLE_PAY_MERCHANT_ID"] = ""
    # Guardian acceptance uses native card PaymentSheet even when the optional
    # Apple Pay / Google Pay paths stay closed. Never couple its client key to
    # the wallet flag or publish a Guardian build with an unusable card flow.
    if guardian_test:
        stripe_key = env.get("STRIPE_PUBLISHABLE_KEY_TEST", "").strip()
        if not re.fullmatch(r"pk_test_[A-Za-z0-9]+", stripe_key):
            raise ValueError("Guardian native cards require a Stripe test publishable key.")
        result["STRIPE_PUBLISHABLE_KEY_TEST"] = stripe_key
    if enabled:
        merchant = env.get("APPLE_PAY_MERCHANT_ID", "").strip()
        if merchant and not re.fullmatch(r"merchant\.[A-Za-z0-9.-]+", merchant):
            raise ValueError("APPLE_PAY_MERCHANT_ID must be an Apple merchant identifier.")
        result["APPLE_PAY_MERCHANT_ID"] = merchant
    if production_beta:
        stripe_key = env.get("STRIPE_PUBLISHABLE_KEY", "").strip()
        if not re.fullmatch(r"pk_live_[A-Za-z0-9]+", stripe_key):
            raise ValueError("Production beta requires a Stripe live publishable key.")
        result["STRIPE_PUBLISHABLE_KEY"] = stripe_key
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--guardian-test", action="store_true")
    parser.add_argument("--measurement-test", action="store_true")
    parser.add_argument("--production-beta", action="store_true")
    args = parser.parse_args()
    target = Path("config.json")
    # A failed validation must not leave an older connected configuration behind.
    target.unlink(missing_ok=True)
    try:
        config = build_config(os.environ, args.guardian_test, args.measurement_test, args.production_beta)
    except ValueError as error:
        raise SystemExit(str(error)) from None
    target.write_text(json.dumps(config, indent=2) + "\n")
    target.chmod(0o600)
    print(
        "Flutter configuration ready. "
        f"Production beta: {args.production_beta}. "
        f"Guardian test: {config['ENABLE_GUARDIAN_TEST']}. "
        f"Measurement test: {config['ENABLE_MEASUREMENT_TEST']}."
    )


if __name__ == "__main__":
    main()
