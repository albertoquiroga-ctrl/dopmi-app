"""Generate a Play-signed QA APK from a new, unpublished closed-track draft."""
import json
import os
from pathlib import Path
import re
import time

from google.auth.transport.requests import AuthorizedSession
from google.oauth2.service_account import Credentials
from requests import RequestException

PACKAGE = "com.mycompany.dopmi"
BASE = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
BUNDLE = Path("build/app/outputs/bundle/release/app-release.aab")
BUILD_INFO = Path("build/guardian-build-info.txt")


def require(condition, message):
    if not condition:
        raise SystemExit(message)


info = BUILD_INFO.read_text(encoding="utf-8")
for setting in (
    "Environment: production",
    "Firebase project: dopmi-production",
    "Adoption only: true",
    "Store review: false",
    "Guardian: false",
    "Stripe live client: false",
):
    require(setting in info.splitlines(), f"Unexpected Samsung QA profile. Expected {setting}.")
version_match = re.search(r"^Version: 2\.3\.5 \((\d+)\)$", info, re.M)
require(version_match is not None, "Expected the Dopmi 2.3.5 release profile.")
version = int(version_match[1])
require(version > 395, "Version must exceed the installed Samsung build.")
require(BUNDLE.is_file() and BUNDLE.stat().st_size > 0, "Signed Android App Bundle is missing.")
track_name = f"analytics-samsung-qa-{version}"
expected_cert = os.environ["DOPMI_QA_PLAY_CERT_SHA256"].lower()
require(re.fullmatch("[0-9a-f]{64}", expected_cert), "Expected the installed APK certificate SHA-256.")

credentials = Credentials.from_service_account_info(
    json.loads(os.environ["GCLOUD_SERVICE_ACCOUNT_CREDENTIALS"]),
    scopes=["https://www.googleapis.com/auth/androidpublisher"],
)
session = AuthorizedSession(credentials)


def request(method, url, **kwargs):
    response = session.request(method, url, timeout=(15, 150), **kwargs)
    if not response.ok:
        try:
            message = response.json().get("error", {}).get("message", "")
        except ValueError:
            message = ""
        raise SystemExit(f"Google Play {method} returned {response.status_code}: {message}")
    return response


edit_id = request("POST", f"{BASE}/edits", json={}).json()["id"]
edit = f"{BASE}/edits/{edit_id}"
committed = False
try:
    tracks = request("GET", f"{edit}/tracks").json().get("tracks", [])
    require(all(track["track"] != track_name for track in tracks), "The QA draft track already exists.")
    bundles = request("GET", f"{edit}/bundles").json().get("bundles", [])
    used = {
        int(code)
        for track in tracks
        for release in track.get("releases", [])
        for code in release.get("versionCodes", [])
    }
    used.update(bundle["versionCode"] for bundle in bundles)
    require(all(version > code for code in used), "Version must exceed the existing Play builds.")
    track = request(
        "POST",
        f"{edit}/tracks",
        json={"track": track_name, "type": "CLOSED_TESTING", "formFactor": "DEFAULT"},
    ).json()
    require(track["track"] == track_name, "Google Play returned a different track.")
    with BUNDLE.open("rb") as stream:
        upload = request(
            "POST",
            edit.replace("/androidpublisher/v3/", "/upload/androidpublisher/v3/") + "/bundles",
            params={"uploadType": "media"},
            headers={"Content-Type": "application/octet-stream"},
            data=stream,
        ).json()
    require(upload["versionCode"] == version, "Google Play received a different version.")
    release = {"name": "Samsung QA Analytics", "status": "draft", "versionCodes": [str(version)]}
    draft = request(
        "PUT",
        f"{edit}/tracks/{track_name}",
        json={"track": track_name, "releases": [release]},
    ).json()
    releases = draft.get("releases", [])
    require(
        draft["track"] == track_name
        and len(releases) == 1
        and releases[0]["status"] == "draft"
        and releases[0]["versionCodes"] == [str(version)],
        "Google Play did not return the expected draft.",
    )
    request("POST", f"{edit}:validate")
    request(
        "POST",
        f"{edit}:commit",
        params={
            "changesNotSentForReview": "true",
            "changesInReviewBehavior": "ERROR_IF_IN_REVIEW",
        },
    )
    committed = True
finally:
    if not committed:
        try:
            session.delete(edit, timeout=(15, 20))
        except RequestException:
            print("Google Play edit cleanup could not be confirmed.")

print(f"Google Play saved version {version} as draft on {track_name}.")
apk_list = f"{BASE}/generatedApks/{version}"
for _ in range(24):
    response = session.get(apk_list, timeout=(15, 30))
    if response.ok:
        apks = response.json().get("generatedApks", [])
        download = next(
            (
                row["generatedUniversalApk"]["downloadId"]
                for row in apks
                if row["certificateSha256Hash"].replace(":", "").lower() == expected_cert
                and row.get("generatedUniversalApk")
            ),
            None,
        )
        if download:
            break
    elif response.status_code not in (404, 429, 503):
        raise SystemExit(f"Google Play generatedApks list returned {response.status_code}")
    time.sleep(10)
else:
    raise SystemExit("Play has not generated a universal APK with the installed certificate.")

with request(
    "GET",
    f"{apk_list}/downloads/{download}:download",
    params={"alt": "media"},
    stream=True,
) as response:
    with Path("build/play-analytics-qa.apk").open("wb") as target:
        for chunk in response.iter_content(chunk_size=1024 * 1024):
            target.write(chunk)

Path("build/play-analytics-qa.json").write_text(
    json.dumps({
        "package": PACKAGE,
        "versionCode": version,
        "track": track_name,
        "status": "draft",
        "signer_sha256": expected_cert,
    }) + "\n",
    encoding="utf-8",
)
BUILD_INFO.write_text(
    info.replace("Distribution: Google Play internal", f"Distribution: Google Play {track_name} draft, Samsung ADB"),
    encoding="utf-8",
)
