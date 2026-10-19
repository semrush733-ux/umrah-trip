#!/usr/bin/env python3
"""Patch the flutter-create generated android/ and ios/ folders with the
permissions, metadata and keys Umrah Trip needs.

Idempotent: safe to run repeatedly (locally and in CI).
Run from the app/ directory:  python3 ../scripts/patch_platforms.py
Env:
  MAPS_API_KEY   optional Google Maps key injected into both platforms.
"""
import os
import plistlib
import re
import sys
from pathlib import Path

APP = Path.cwd()
MAPS_KEY = os.environ.get("MAPS_API_KEY", "")


def patch_android_manifest() -> None:
    mf = APP / "android/app/src/main/AndroidManifest.xml"
    if not mf.exists():
        print("!! AndroidManifest.xml not found — run flutter create first")
        return
    text = mf.read_text()

    perms = [
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>',
        '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>',
    ]
    for p in perms:
        if p.split('"')[1] not in text:
            text = text.replace("<application", f"    {p}\n    <application", 1)

    # Maps API key meta-data (placeholder kept even when empty so release
    # builds can be re-signed with a key later without a code change).
    if "com.google.android.geo.API_KEY" not in text:
        meta = (
            '        <meta-data android:name="com.google.android.geo.API_KEY" '
            f'android:value="{MAPS_KEY}"/>\n'
        )
        text = re.sub(r"(<application[^>]*>\n)", r"\1" + meta, text, count=1)
    elif MAPS_KEY:
        text = re.sub(
            r'(android:name="com\.google\.android\.geo\.API_KEY"\s+android:value=")[^"]*(")',
            r"\g<1>" + MAPS_KEY + r"\g<2>",
            text,
        )

    # App label
    text = text.replace('android:label="umrah_journey"', 'android:label="Umrah Trip"')
    mf.write_text(text)
    print("ok: AndroidManifest.xml patched")


def patch_ios_plist() -> None:
    pl = APP / "ios/Runner/Info.plist"
    if not pl.exists():
        print("!! ios/Runner/Info.plist not found — run flutter create first")
        return
    with pl.open("rb") as f:
        data = plistlib.load(f)
    data["CFBundleDisplayName"] = "Umrah Trip"
    data["NSLocationWhenInUseUsageDescription"] = (
        "Umrah Trip uses your location to show nearby Ziyarat places, distances, "
        "one-tap navigation and (only when you turn it on) live sharing with "
        "your paired partner. It is never tracked in the background."
    )
    data["NSCameraUsageDescription"] = (
        "Umrah Trip opens the camera only when you tap the camera button, to "
        "take a photo and send it to your paired partner."
    )
    data["NSPhotoLibraryUsageDescription"] = (
        "Umrah Trip accesses photos only when you choose one to send to your "
        "paired partner."
    )
    data["GMapsAPIKey"] = MAPS_KEY
    # TTS / AVSpeech needs no permission; url_launcher queries:
    data.setdefault("LSApplicationQueriesSchemes", [])
    for scheme in ("comgooglemaps", "maps"):
        if scheme not in data["LSApplicationQueriesSchemes"]:
            data["LSApplicationQueriesSchemes"].append(scheme)
    with pl.open("wb") as f:
        plistlib.dump(data, f)
    print("ok: Info.plist patched")


def patch_ios_appdelegate() -> None:
    ad = APP / "ios/Runner/AppDelegate.swift"
    if not ad.exists():
        print("!! AppDelegate.swift not found — skipping")
        return
    text = ad.read_text()
    if "GMSServices" in text:
        print("ok: AppDelegate already patched")
        return
    if "import Flutter" in text:
        text = text.replace("import Flutter", "import Flutter\nimport GoogleMaps", 1)
    inject = (
        "    let mapsKey = (Bundle.main.object(forInfoDictionaryKey: \"GMapsAPIKey\") as? String) ?? \"\"\n"
        "    if !mapsKey.isEmpty { GMSServices.provideAPIKey(mapsKey) }\n"
    )
    text = re.sub(
        r"(didFinishLaunchingWithOptions[^\{]*\{\n)",
        r"\1" + inject,
        text,
        count=1,
    )
    ad.write_text(text)
    print("ok: AppDelegate.swift patched")


def patch_ios_podfile() -> None:
    pf = APP / "ios/Podfile"
    if not pf.exists():
        print("!! Podfile not found yet — will exist after first pod setup")
        return
    text = pf.read_text()
    if re.search(r"^platform :ios", text, flags=re.M):
        text = re.sub(r"^#?\s*platform :ios.*$", "platform :ios, '14.0'", text, count=1, flags=re.M)
    else:
        text = "platform :ios, '14.0'\n" + text
    pf.write_text(text)
    print("ok: Podfile platform set to iOS 14.0")


if __name__ == "__main__":
    if not (APP / "pubspec.yaml").exists():
        sys.exit("Run this from the app/ directory (pubspec.yaml not found).")
    patch_android_manifest()
    patch_ios_plist()
    patch_ios_appdelegate()
    patch_ios_podfile()
    print("Platform patching complete.")
