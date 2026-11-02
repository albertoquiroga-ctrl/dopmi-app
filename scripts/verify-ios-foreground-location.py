#!/usr/bin/env python3
"""Reject unused Always-location code in a built iOS app, without dumping data."""

import argparse
import json
from pathlib import Path
import plistlib
from zipfile import ZipFile


MACHO_MAGIC = {
    b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe",
    b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe",
    b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",
    b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca",
}
FORBIDDEN_SELECTORS = (
    b"requestAlwaysAuthorization\0",
    b"containsLocationAlwaysDescription\0",
)


def inspect(info, entries, main_name):
    errors = []
    if not isinstance(info.get("NSLocationWhenInUseUsageDescription"), str) or not info[
        "NSLocationWhenInUseUsageDescription"
    ].strip():
        errors.append("WhenInUse purpose missing or empty")
    for key in ("NSLocationAlwaysUsageDescription", "NSLocationAlwaysAndWhenInUseUsageDescription"):
        if key in info:
            errors.append("Always purpose is outside the foreground-only policy")
    if "location" in info.get("UIBackgroundModes", []):
        errors.append("Background location capability is outside the policy")
    binaries = 0
    main_found = False
    when_in_use = False
    for name, data in entries:
        if data[:4] not in MACHO_MAGIC:
            continue
        binaries += 1
        if name == main_name:
            main_found = True
        when_in_use = when_in_use or b"requestWhenInUseAuthorization\0" in data
        for selector in FORBIDDEN_SELECTORS:
            if selector in data:
                errors.append(f"Always-location selector remains in {name}")
                break
    if not main_found or not binaries:
        errors.append("Native app executable not found")
    if not when_in_use:
        errors.append("Native WhenInUse authorization path not found")
    if errors:
        raise ValueError("; ".join(errors))
    return {"state": "IOS_FOREGROUND_LOCATION_VERIFIED", "native_binaries": binaries,
            "when_in_use": True, "always_selectors": False, "background_location": False}


def from_ipa(path):
    with ZipFile(path) as archive:
        infos = [n for n in archive.namelist()
                 if n.startswith("Payload/") and n.count("/") == 2 and n.endswith(".app/Info.plist")]
        if len(infos) != 1:
            raise ValueError("Exactly one payload app required")
        prefix = infos[0][:-len("Info.plist")]
        info = plistlib.loads(archive.read(infos[0]))

        def entries():
            for item in archive.infolist():
                if item.is_dir() or not item.filename.startswith(prefix):
                    continue
                with archive.open(item) as stream:
                    magic = stream.read(4)
                    if magic in MACHO_MAGIC:
                        yield item.filename[len(prefix):], magic + stream.read()
        return inspect(info, entries(), info["CFBundleExecutable"])


def from_app(path):
    info = plistlib.loads((path / "Info.plist").read_bytes())

    def entries():
        for item in path.rglob("*"):
            if item.is_file():
                with item.open("rb") as stream:
                    magic = stream.read(4)
                    if magic in MACHO_MAGIC:
                        yield item.relative_to(path).as_posix(), magic + stream.read()
    return inspect(info, entries(), info["CFBundleExecutable"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--ipa", type=Path)
    group.add_argument("--app", type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(from_ipa(args.ipa) if args.ipa else from_app(args.app)))
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f"iOS foreground-location check failed: {error}\n")


if __name__ == "__main__":
    main()
