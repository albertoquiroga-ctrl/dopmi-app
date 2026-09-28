"""Write non-secret Firebase placeholders used only by compile-only CI builds."""

from pathlib import Path
import json
import plistlib


ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "apps/mobile/android/app/google-services.json"
IOS = ROOT / "apps/mobile/ios/Runner/GoogleService-Info.plist"


def main() -> None:
    ANDROID.write_text(
        json.dumps(
            {
                "project_info": {
                    "project_number": "000000000000",
                    "project_id": "dopmi-ci-placeholder",
                    "storage_bucket": "dopmi-ci-placeholder.invalid",
                },
                "client": [
                    {
                        "client_info": {
                            "mobilesdk_app_id": "1:000000000000:android:0000000000000000",
                            "android_client_info": {"package_name": "com.mycompany.dopmi"},
                        },
                        "oauth_client": [],
                        "api_key": [{"current_key": "ci-placeholder-not-a-real-api-key"}],
                        "services": {"appinvite_service": {"other_platform_oauth_client": []}},
                    }
                ],
                "configuration_version": "1",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    with IOS.open("wb") as output:
        plistlib.dump(
            {
                "API_KEY": "ci-placeholder-not-a-real-api-key",
                "GCM_SENDER_ID": "000000000000",
                "PLIST_VERSION": "1",
                "BUNDLE_ID": "com.mycompany.dopmi",
                "PROJECT_ID": "dopmi-ci-placeholder",
                "STORAGE_BUCKET": "dopmi-ci-placeholder.invalid",
                "IS_ADS_ENABLED": False,
                "IS_ANALYTICS_ENABLED": False,
                "IS_APPINVITE_ENABLED": False,
                "IS_GCM_ENABLED": False,
                "IS_SIGNIN_ENABLED": False,
                "GOOGLE_APP_ID": "1:000000000000:ios:0000000000000000",
            },
            output,
            sort_keys=False,
        )


if __name__ == "__main__":
    main()
