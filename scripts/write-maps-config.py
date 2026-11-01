"""Bind native Maps keys from the build environment without printing values."""
import argparse
import os
from pathlib import Path
import re


def write_config(env, platform, root):
    if platform not in ("android", "ios"):
        raise ValueError("Unsupported native Maps platform.")
    target = root / "ios/Flutter/DopmiMaps.local.xcconfig"
    if platform == "ios":
        target.unlink(missing_ok=True)
    enabled = env.get("ENABLE_GOOGLE_MAPS", "false").strip().lower()
    if enabled not in ("true", "false"):
        raise ValueError("ENABLE_GOOGLE_MAPS must be true or false.")
    name = "GOOGLE_MAPS_ANDROID_API_KEY" if platform == "android" else "GOOGLE_MAPS_IOS_API_KEY"
    key = env.get(name, "").strip() if enabled == "true" else ""
    if enabled == "true" and not re.fullmatch(r"AIza[A-Za-z0-9_-]{35}", key):
        raise ValueError("Enabled Maps requires the platform's restricted native API key.")
    if platform == "ios":
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("DOPMI_MAPS_IOS_KEY=" + key + "\n", encoding="utf-8")
        target.chmod(0o600)
    # Android reads only this platform key through manifestPlaceholders.
    return enabled == "true"


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=("android", "ios"), required=True)
    args = parser.parse_args()
    try:
        active = write_config(os.environ, args.platform, Path.cwd())
    except ValueError as error:
        raise SystemExit(str(error)) from None
    print(f"Native Maps configuration ready for {args.platform}. Enabled: {active}.")
