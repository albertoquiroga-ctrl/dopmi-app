"""Restore pinned Firebase client configs without logging their contents."""
import argparse
import base64
import json
import os
from pathlib import Path
import plistlib
import re


ROOT = Path(__file__).resolve().parents[1] / "apps" / "mobile"
PACKAGE = "com.mycompany.dopmi"
TEST_PROJECT = "dopmi-e3b6a"
TEST_PROJECT_NUMBER = "623928073757"
TEST_ANDROID_APP = "1:623928073757:android:d2022415cbf2751e41b0f4"


def decode(env, name):
    value = env.get(name, "").strip()
    if not value:
        raise ValueError(f"{name} is required.")
    try:
        return base64.b64decode(value, validate=True)
    except ValueError:
        raise ValueError(f"{name} is not valid base64.") from None


def production_pins(env):
    project = env.get("FIREBASE_PRODUCTION_PROJECT_ID", "").strip()
    if not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", project) \
            or project == TEST_PROJECT \
            or re.search(r"(?:^|-)(?:test|testing|ci|dummy|placeholder|fixture)(?:-|$)", project):
        raise ValueError("A registered production Firebase project pin is required.")
    app_ids = []
    for platform in ("ANDROID", "IOS"):
        value = env.get(f"FIREBASE_PRODUCTION_{platform}_APP_ID", "").strip()
        match = re.fullmatch(rf"1:([1-9][0-9]{{5,19}}):{platform.lower()}:([0-9a-f]{{16,64}})", value)
        if not match or set(match[2]) == {"0"} or match[1] == TEST_PROJECT_NUMBER:
            raise ValueError("A registered production Firebase app pin is required.")
        app_ids.append((value, match[1]))
    if app_ids[0][1] != app_ids[1][1]:
        raise ValueError("Production Firebase app pins belong to different projects.")
    return project, app_ids[0][0], app_ids[1][0], app_ids[0][1]


def has_emulator(value):
    if isinstance(value, dict):
        return any(("emulator" in str(key).lower() and bool(child)) or has_emulator(child)
                   for key, child in value.items())
    if isinstance(value, list):
        return any(has_emulator(child) for child in value)
    if isinstance(value, str):
        return bool(re.search(r"https?://(?:localhost|127\.0\.0\.1|0\.0\.0\.0|10\.0\.2\.2|\[::1\])(?=[:/]|$)", value, re.I))
    return False


def google_ios_scheme(env, ios_value, production_beta=False, platform="both"):
    enabled = env.get("ENABLE_GOOGLE_AUTH", "false").strip().lower() or "false"
    if enabled not in ("true", "false"):
        raise ValueError("ENABLE_GOOGLE_AUTH must be true or false.")
    if enabled == "false":
        return None
    # The selected registration owns the number; downloaded metadata cannot
    # redefine TEST as another project while retaining its PROJECT_ID/BUNDLE_ID.
    number = production_pins(env)[3] if production_beta else TEST_PROJECT_NUMBER
    if (str(ios_value.get("GCM_SENDER_ID", "")) != number
            or not re.fullmatch(rf"1:{re.escape(number)}:ios:[0-9a-f]{{16,64}}", ios_value.get("GOOGLE_APP_ID", ""))):
        raise ValueError("Google sign-in requires the selected Firebase project number and app ID.")
    clients = []
    names = ("GOOGLE_SERVER_CLIENT_ID",) if platform == "android" else ("GOOGLE_SERVER_CLIENT_ID", "GOOGLE_IOS_CLIENT_ID")
    for name in names:
        value = env.get(name, "").strip()
        if not re.fullmatch(rf"{re.escape(number)}-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com", value):
            raise ValueError("Google sign-in requires Web and iOS client IDs for the selected profile.")
        clients.append(value)
    if platform == "android":
        return None
    client = clients[1]
    scheme = "com.googleusercontent.apps." + client.removesuffix(".apps.googleusercontent.com")
    if (ios_value.get("CLIENT_ID", client) != client
            or ios_value.get("REVERSED_CLIENT_ID", scheme) != scheme):
        raise ValueError("Firebase Google iOS identity does not match the selected profile.")
    return scheme


def build_ios_info(env, contents, ios_config, production_beta=False):
    """Derive only Google URL schemes; retain application identity and other URLs."""
    try:
        info = plistlib.loads(contents)
        scheme = google_ios_scheme(env, plistlib.loads(ios_config), production_beta, platform="ios")
        entries = info["CFBundleURLTypes"]
        if not isinstance(entries, list):
            raise ValueError()
        preserved = []
        for entry in entries:
            schemes = entry["CFBundleURLSchemes"]
            if not isinstance(schemes, list) or any(not isinstance(value, str) for value in schemes):
                raise ValueError()
            remaining = [value for value in schemes if not value.startswith("com.googleusercontent.apps.")]
            if remaining or not schemes:
                preserved.append({**entry, "CFBundleURLSchemes": remaining})
        if not any("io.dopmi.app" in entry["CFBundleURLSchemes"] for entry in preserved):
            raise ValueError()
        if scheme:
            preserved.append({"CFBundleURLSchemes": [scheme]})
        info["CFBundleURLTypes"] = preserved
        return plistlib.dumps(info, sort_keys=False)
    except (KeyError, TypeError, ValueError, plistlib.InvalidFileException):
        raise ValueError("iOS application identity or Google URL scheme is invalid.") from None


def build_config(env, production_beta=False, platform="both"):
    """Return both validated files unchanged; performs no I/O or provider calls."""
    if platform not in ("android", "ios", "both"):
        raise ValueError("Firebase configuration platform must be android, ios or both.")
    environment = env.get("DOPMI_ENVIRONMENT", "test")
    if environment not in ("test", "production") or (environment == "production") != production_beta:
        raise ValueError("Production Firebase requires DOPMI_ENVIRONMENT=production and --production-beta together.")
    if production_beta:
        project, android_app, ios_app, project_number = production_pins(env)
        prefix = "FIREBASE_PRODUCTION_"
    else:
        project, android_app = TEST_PROJECT, TEST_ANDROID_APP
        prefix = "FIREBASE_"
    android = decode(env, f"{prefix}ANDROID_CONFIG_BASE64")
    ios = decode(env, f"{prefix}IOS_CONFIG_BASE64")
    try:
        android_value = json.loads(android)
        ios_value = plistlib.loads(ios)
        clients = [client for client in android_value["client"]
                   if client["client_info"]["android_client_info"]["package_name"] == PACKAGE]
        if len(clients) != 1:
            raise ValueError()
        client_app = clients[0]["client_info"]["mobilesdk_app_id"]
        valid = (android_value["project_info"]["project_id"] == project
                 and client_app == android_app
                 and ios_value.get("PROJECT_ID") == project
                 and ios_value.get("BUNDLE_ID") == PACKAGE)
        if production_beta:
            valid = (valid and ios_value.get("GOOGLE_APP_ID") == ios_app
                     and str(android_value["project_info"]["project_number"]) == project_number
                     and str(ios_value.get("GCM_SENDER_ID")) == project_number
                     and not has_emulator(android_value) and not has_emulator(ios_value))
        if not valid:
            raise ValueError()
    except (KeyError, TypeError, ValueError, OverflowError, plistlib.InvalidFileException):
        raise ValueError("Firebase configuration belongs to another app or environment, or is invalid.") from None
    google_ios_scheme(env, ios_value, production_beta, platform)
    if env.get("ENABLE_GOOGLE_AUTH", "false").strip().lower() == "true":
        number = production_pins(env)[3] if production_beta else TEST_PROJECT_NUMBER
        if str(android_value["project_info"].get("project_number", "")) != number:
            raise ValueError("Google sign-in requires the selected Android Firebase project number.")
    return android, ios


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--production-beta", action="store_true")
    parser.add_argument("--platform", choices=("android", "ios", "both"), default="both")
    args = parser.parse_args(argv)
    paths = (ROOT / "android" / "app" / "google-services.json",
             ROOT / "ios" / "Runner" / "GoogleService-Info.plist")
    info_path = ROOT / "ios" / "Runner" / "Info.plist"
    # A rejected environment must not leave older connected files for a build.
    for path in paths:
        path.unlink(missing_ok=True)
    try:
        configs = build_config(os.environ, args.production_beta, args.platform)
        info_contents = (build_ios_info(os.environ, info_path.read_bytes(), configs[1], args.production_beta)
                         if args.platform != "android" else None)
    except ValueError as error:
        raise SystemExit(str(error)) from None
    for path, contents in zip(paths, configs):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(contents)
        path.chmod(0o600)
    if info_contents is not None:
        info_path.write_bytes(info_contents)
    print("Firebase client configuration ready for com.mycompany.dopmi.")


if __name__ == "__main__":
    main()
