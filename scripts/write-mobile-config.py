"""Create Codemagic's temporary Flutter config without logging credentials."""
import argparse
import base64
import json
import os
from pathlib import Path
import re


def client_key(value):
    if re.fullmatch(r"sb_publishable_[A-Za-z0-9_-]+", value):
        return True
    try:
        parts = value.split(".")
        payload = parts[1] + "=" * (-len(parts[1]) % 4)
        return len(parts) == 3 and json.loads(base64.urlsafe_b64decode(payload))["role"] == "anon"
    except (ValueError, KeyError, IndexError, TypeError):
        return False


def build_config(env, guardian_test=False):
    endpoint = "".join(env.get("SUPABASE_URL", "").split()).rstrip("/")
    key = "".join(env.get("SUPABASE_PUBLISHABLE_KEY", "").split())
    if not re.fullmatch(r"https://[a-z0-9-]+\.supabase\.co", endpoint):
        raise ValueError("SUPABASE_URL is missing or invalid in dopmi_supabase.")
    if not client_key(key):
        raise ValueError("A publishable or anon client key is required in dopmi_supabase.")
    expected = json.loads((Path(__file__).resolve().parents[1] / "apps/mobile/config.example.json").read_text())
    if guardian_test and endpoint != expected["SUPABASE_URL"].rstrip("/"):
        raise ValueError("Guardian acceptance must use the configured test project.")
    result = {
        "SUPABASE_URL": endpoint,
        "SUPABASE_PUBLISHABLE_KEY": key,
        "AUTH_REDIRECT_URL": "io.dopmi.app://auth/callback",
        "ENABLE_GUARDIAN_TEST": str(guardian_test).lower(),
    }
    for name in ("ENABLE_GOOGLE_AUTH", "ENABLE_APPLE_AUTH"):
        value = env.get(name, "false").strip().lower() or "false"
        if value not in ("true", "false"):
            raise ValueError(f"{name} must be true or false.")
        result[name] = value
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--guardian-test", action="store_true")
    args = parser.parse_args()
    target = Path("config.json")
    # A failed validation must not leave an older connected configuration behind.
    target.unlink(missing_ok=True)
    try:
        config = build_config(os.environ, args.guardian_test)
    except ValueError as error:
        raise SystemExit(str(error)) from None
    target.write_text(json.dumps(config, indent=2) + "\n")
    target.chmod(0o600)
    print(f"Flutter configuration ready. Guardian test: {config['ENABLE_GUARDIAN_TEST']}.")


if __name__ == "__main__":
    main()
