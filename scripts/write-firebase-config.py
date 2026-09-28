"""Restore validated Firebase client config from Codemagic secret variables."""
import base64
import json
import os
from pathlib import Path
import plistlib


ROOT = Path(__file__).resolve().parents[1] / "apps" / "mobile"


def decode(name: str) -> bytes:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"{name} is missing from dopmi_firebase.")
    try:
        return base64.b64decode(value, validate=True)
    except ValueError:
        raise SystemExit(f"{name} is not valid base64.") from None


android = decode("FIREBASE_ANDROID_CONFIG_BASE64")
ios = decode("FIREBASE_IOS_CONFIG_BASE64")
try:
    android_value = json.loads(android)
    ios_value = plistlib.loads(ios)
    android_client = next(
        client for client in android_value["client"]
        if client["client_info"]["android_client_info"]["package_name"] == "com.mycompany.dopmi"
    )
except (KeyError, ValueError, StopIteration, plistlib.InvalidFileException):
    raise SystemExit("Firebase configuration is invalid.") from None
if android_value["project_info"]["project_id"] != "dopmi-e3b6a" \
        or android_client["client_info"]["mobilesdk_app_id"] != "1:623928073757:android:d2022415cbf2751e41b0f4" \
        or ios_value.get("PROJECT_ID") != "dopmi-e3b6a" \
        or ios_value.get("BUNDLE_ID") != "com.mycompany.dopmi":
    raise SystemExit("Firebase configuration belongs to another app or environment.")

targets = {
    ROOT / "android" / "app" / "google-services.json": android,
    ROOT / "ios" / "Runner" / "GoogleService-Info.plist": ios,
}
for path, contents in targets.items():
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(contents)
    path.chmod(0o600)
print("Firebase client configuration ready for com.mycompany.dopmi.")
