#!/usr/bin/env python3
"""Patch the flutter-create generated android/ and ios/ folders with the
permissions, metadata and keys Umrah Trip needs.

Idempotent: safe to run repeatedly (locally and in CI).
Run from the app/ directory:  python3 ../scripts/patch_platforms.py
Env:
  MAPS_API_KEY              optional Google Maps key injected into both platforms.
  ANDROID_KEYSTORE_BASE64   optional release keystore (base64 .jks) — when set
  ANDROID_KEYSTORE_PASSWORD together with this, release APK/AAB are signed with
  ANDROID_KEY_ALIAS         the permanent Umrah Trip key (same app forever).
"""
import base64
import os
import plistlib
import re
import sys
from pathlib import Path

APP = Path.cwd()
MAPS_KEY = os.environ.get("MAPS_API_KEY", "")
KS_B64 = os.environ.get("ANDROID_KEYSTORE_BASE64", "")
KS_PASS = os.environ.get("ANDROID_KEYSTORE_PASSWORD", "")
KS_ALIAS = os.environ.get("ANDROID_KEY_ALIAS", "umrahtrip")


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
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
        '<uses-permission android:name="android.permission.CAMERA"/>',
        '<uses-permission android:name="android.permission.VIBRATE"/>',
    ]
    for p in perms:
        if p.split('"')[1] not in text:
            text = text.replace("<application", f"    {p}\n    <application", 1)

    # Maps API key meta-data. Never leave the value empty — some Play
    # Services versions crash the whole app at launch on an empty key.
    safe_key = MAPS_KEY if MAPS_KEY else "PLACEHOLDER_SET_MAPS_API_KEY"
    if "com.google.android.geo.API_KEY" not in text:
        meta = (
            '        <meta-data android:name="com.google.android.geo.API_KEY" '
            f'android:value="{safe_key}"/>\n'
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
    data["MinimumOSVersion"] = "15.5"
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
    # mobile_scanner (MLKit) needs iOS 15.5+
    if re.search(r"^platform :ios", text, flags=re.M):
        text = re.sub(r"^#?\s*platform :ios.*$", "platform :ios, '15.5'", text, count=1, flags=re.M)
    else:
        text = "platform :ios, '15.5'\n" + text
    pf.write_text(text)
    print("ok: Podfile platform set to iOS 15.5")


def patch_ios_deployment_target() -> None:
    """Xcode project min iOS → 15.5 (mobile_scanner/MLKit requirement)."""
    pbx = APP / "ios/Runner.xcodeproj/project.pbxproj"
    if not pbx.exists():
        print("!! project.pbxproj not found — run flutter create first")
        return
    t = pbx.read_text()
    t2 = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = \d+(\.\d+)?;",
                "IPHONEOS_DEPLOYMENT_TARGET = 15.5;", t)
    if t2 != t:
        pbx.write_text(t2)
    print("ok: IPHONEOS_DEPLOYMENT_TARGET = 15.5")


def patch_android_desugaring() -> None:
    """flutter_local_notifications needs core-library desugaring; the QR
    scanner (mobile_scanner) needs minSdk 23."""
    kts = APP / "android/app/build.gradle.kts"
    groovy = APP / "android/app/build.gradle"
    if kts.exists():
        t = kts.read_text()
        t = t.replace("minSdk = flutter.minSdkVersion", "minSdk = 23")
        t = re.sub(r"minSdk\s*=\s*2[012]\b", "minSdk = 23", t)
        if "isCoreLibraryDesugaringEnabled" not in t:
            t = re.sub(
                r"(compileOptions\s*\{\n)",
                r"\1        isCoreLibraryDesugaringEnabled = true\n",
                t,
                count=1,
            )
            if "compileOptions" not in t:
                t = re.sub(
                    r"(android\s*\{\n)",
                    r"\1    compileOptions {\n        isCoreLibraryDesugaringEnabled = true\n    }\n",
                    t,
                    count=1,
                )
        if "desugar_jdk_libs" not in t:
            t += (
                "\ndependencies {\n"
                "    coreLibraryDesugaring(\"com.android.tools:desugar_jdk_libs:2.1.4\")\n"
                "}\n"
            )
        kts.write_text(t)
        print("ok: desugaring enabled (build.gradle.kts)")
    elif groovy.exists():
        t = groovy.read_text()
        t = t.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion 23")
        if "coreLibraryDesugaringEnabled" not in t:
            t = re.sub(
                r"(compileOptions\s*\{\n)",
                r"\1        coreLibraryDesugaringEnabled true\n",
                t,
                count=1,
            )
        if "desugar_jdk_libs" not in t:
            t += (
                "\ndependencies {\n"
                "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n"
                "}\n"
            )
        groovy.write_text(t)
        print("ok: desugaring enabled (build.gradle)")


def patch_android_signing() -> None:
    """Sign release builds with the permanent Umrah Trip keystore when the
    ANDROID_KEYSTORE_* env vars are present (CI secrets / local env). Without
    them the default debug signing is kept, so builds never break."""
    if not KS_B64 or not KS_PASS:
        print("-- no ANDROID_KEYSTORE_* env: keeping debug signing")
        return
    app_dir = APP / "android/app"
    if not app_dir.exists():
        print("!! android/app missing — run flutter create first")
        return
    (app_dir / "release.jks").write_bytes(base64.b64decode(KS_B64))
    (APP / "android/key.properties").write_text(
        f"storeFile=release.jks\nstorePassword={KS_PASS}\n"
        f"keyPassword={KS_PASS}\nkeyAlias={KS_ALIAS}\n"
    )
    kts = app_dir / "build.gradle.kts"
    groovy = app_dir / "build.gradle"
    if kts.exists():
        t = kts.read_text()
        if "key.properties" not in t:
            loader = (
                "import java.util.Properties\n"
                "import java.io.FileInputStream\n\n"
                "val keystoreProperties = Properties()\n"
                "val keystorePropertiesFile = rootProject.file(\"key.properties\")\n"
                "if (keystorePropertiesFile.exists()) {\n"
                "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
                "}\n\n"
            )
            t = loader + t
            signing = (
                "    signingConfigs {\n"
                "        create(\"release\") {\n"
                "            if (keystorePropertiesFile.exists()) {\n"
                "                keyAlias = keystoreProperties[\"keyAlias\"] as String\n"
                "                keyPassword = keystoreProperties[\"keyPassword\"] as String\n"
                "                storeFile = file(keystoreProperties[\"storeFile\"] as String)\n"
                "                storePassword = keystoreProperties[\"storePassword\"] as String\n"
                "            }\n"
                "        }\n"
                "    }\n"
            )
            t = re.sub(r"(android\s*\{\n)", r"\1" + signing, t, count=1)
            t = t.replace(
                'signingConfig = signingConfigs.getByName("debug")',
                'signingConfig = if (keystorePropertiesFile.exists()) '
                'signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
            )
            kts.write_text(t)
        print("ok: release signing wired (build.gradle.kts)")
    elif groovy.exists():
        t = groovy.read_text()
        if "key.properties" not in t:
            loader = (
                "def keystoreProperties = new Properties()\n"
                "def keystorePropertiesFile = rootProject.file('key.properties')\n"
                "if (keystorePropertiesFile.exists()) {\n"
                "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
                "}\n\n"
            )
            t = loader + t
            signing = (
                "    signingConfigs {\n"
                "        release {\n"
                "            if (keystorePropertiesFile.exists()) {\n"
                "                keyAlias keystoreProperties['keyAlias']\n"
                "                keyPassword keystoreProperties['keyPassword']\n"
                "                storeFile file(keystoreProperties['storeFile'])\n"
                "                storePassword keystoreProperties['storePassword']\n"
                "            }\n"
                "        }\n"
                "    }\n"
            )
            t = re.sub(r"(android\s*\{\n)", r"\1" + signing, t, count=1)
            t = t.replace(
                "signingConfig signingConfigs.debug",
                "signingConfig keystorePropertiesFile.exists() ? "
                "signingConfigs.release : signingConfigs.debug",
            )
            groovy.write_text(t)
        print("ok: release signing wired (build.gradle)")
    else:
        print("!! no build.gradle(.kts) found")


if __name__ == "__main__":
    if not (APP / "pubspec.yaml").exists():
        sys.exit("Run this from the app/ directory (pubspec.yaml not found).")
    patch_android_manifest()
    patch_android_desugaring()
    patch_ios_plist()
    patch_ios_appdelegate()
    patch_ios_podfile()
    patch_ios_deployment_target()
    patch_android_signing()
    print("Platform patching complete.")
