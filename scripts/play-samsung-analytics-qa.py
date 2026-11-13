"""One-off device QA. The only track written here is a new unpublished draft."""
import json
import os
from pathlib import Path
import re
import time

from google.auth.transport.requests import AuthorizedSession
from google.oauth2.service_account import Credentials

PACKAGE = "com.mycompany.dopmi"
TRACK = "analytics-samsung-qa"
BASE = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}"
bundle = Path("build/app/outputs/bundle/release/app-release.aab")
build_info = Path("build/guardian-build-info.txt")
info = build_info.read_text()
assert "\nEnvironment: production\n" in info
assert "\nFirebase project: dopmi-production\n" in info
assert "\nGuardian: false\n" in info
assert "\nStripe live client: false\n" in info
version = int(re.search(r"^Version: .*? \((\d+)\)$", info, re.M)[1])
assert version > 388
expected_cert = os.environ["DOPMI_QA_PLAY_CERT_SHA256"].lower()
assert re.fullmatch("[0-9a-f]{64}", expected_cert)

raw_key = os.environ["GCLOUD_SERVICE_ACCOUNT_CREDENTIALS"]
key = json.loads(raw_key)
credentials = Credentials.from_service_account_info(
    key, scopes=["https://www.googleapis.com/auth/androidpublisher"]
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
    assert not any(t["track"] == TRACK for t in tracks), "The dedicated QA track already exists"
    bundles = request("GET", f"{edit}/bundles").json().get("bundles", [])
    used = {int(code) for t in tracks for r in t.get("releases", []) for code in r.get("versionCodes", [])}
    used.update(bundle["versionCode"] for bundle in bundles)
    assert all(version > code for code in used), "Version must exceed all existing track releases"
    track = request(
        "POST", f"{edit}/tracks",
        json={"track": TRACK, "type": "CLOSED_TESTING", "formFactor": "DEFAULT"},
    ).json()
    assert track["track"] == TRACK
    with bundle.open("rb") as stream:
        response = request(
            "POST", edit.replace("/androidpublisher/v3/", "/upload/androidpublisher/v3/") + "/bundles",
            params={"uploadType": "media"},
            headers={"Content-Type": "application/octet-stream"}, data=stream,
        ).json()
    assert response["versionCode"] == version
    release = {"name": "Samsung QA Analytics", "status": "draft", "versionCodes": [str(version)]}
    draft = request("PUT", f"{edit}/tracks/{TRACK}", json={"track": TRACK, "releases": [release]}).json()
    assert len(draft["releases"]) == 1 and draft["releases"][0]["status"] == "draft"
    request("POST", f"{edit}:validate")
    request("POST", f"{edit}:commit")
    committed = True
finally:
    if not committed:
        session.delete(edit, timeout=(15, 20))

print(f"Google Play saved version {version} as draft on {TRACK}.")
apk_list = f"{BASE}/generatedApks/{version}"
for _ in range(24):
    response = session.get(apk_list, timeout=(15, 30))
    if response.ok:
        apks = response.json().get("generatedApks", [])
        download = next(
            (row["generatedUniversalApk"]["downloadId"] for row in apks
             if row["certificateSha256Hash"].replace(":", "").lower() == expected_cert
             and row.get("generatedUniversalApk")),
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
    "GET", f"{apk_list}/downloads/{download}:download",
    params={"alt": "media"}, stream=True,
) as response:
    with Path("build/play-analytics-qa.apk").open("wb") as target:
        for chunk in response.iter_content(chunk_size=1024 * 1024):
            target.write(chunk)

Path("build/play-analytics-qa.json").write_text(json.dumps({
    "package": PACKAGE, "versionCode": version, "track": TRACK,
    "status": "draft", "signer_sha256": expected_cert,
}) + "\n")
build_info.write_text(info.replace(
    "Distribution: Google Play internal", f"Distribution: Google Play {TRACK} draft, Samsung ADB",
))
