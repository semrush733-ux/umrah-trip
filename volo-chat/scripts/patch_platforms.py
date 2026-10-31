#!/usr/bin/env python3
"""Patch the flutter-create generated android/ and ios/ folders with the
permissions, metadata and keys Volo Chat needs.

Idempotent: safe to run repeatedly (locally and in CI).
Run from the app/ directory:  python3 ../scripts/patch_platforms.py
Env:
  MAPS_API_KEY              optional Google Maps key injected into both platforms.
  ANDROID_KEYSTORE_BASE64   optional release keystore (base64 .jks) — when set
  ANDROID_KEYSTORE_PASSWORD together with this, release APK/AAB are signed with
  ANDROID_KEY_ALIAS         the permanent Volo Chat key (same app forever).
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
KS_ALIAS = os.environ.get("ANDROID_KEY_ALIAS", "volochat")


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
        '<uses-permission android:name="android.permission.RECORD_AUDIO"/>',
        '<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>',
        '<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>',
        '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>',
        '<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>',
        '<uses-permission android:name="android.permission.WAKE_LOCK"/>',
        '<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>',
        '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING"/>',
        '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>',
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

    # Allow the http fallback for the pairing server (Android 9+ blocks
    # cleartext by default).
    if 'android:usesCleartextTraffic' not in text:
        text = text.replace("<application", '<application android:usesCleartextTraffic="true"', 1)

    # App label
    text = text.replace('android:label="volo_chat"', 'android:label="Volo Chat"')

    # Background connection service (flutter_background_service) runs as a
    # "remoteMessaging" foreground service — no daily time limit, unlike dataSync.
    if 'xmlns:tools=' not in text:
        text = text.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)
    if 'id.flutter.flutter_background_service.BackgroundService' not in text:
        svc = ('        <service android:name="id.flutter.flutter_background_service.BackgroundService"\n'
               '            android:foregroundServiceType="remoteMessaging"\n'
               '            tools:replace="android:foregroundServiceType" />\n')
        text = text.replace('</application>', svc + '    </application>', 1)
    # Incoming-call notification may open the app over the lock screen.
    if 'android:showWhenLocked' not in text:
        text = re.sub(r'(<activity\s+android:name="\.MainActivity")',
                      r'\1 android:showWhenLocked="true" android:turnScreenOn="true"', text, count=1)
    mf.write_text(text)
    print("ok: AndroidManifest.xml patched")


def patch_ios_plist() -> None:
    pl = APP / "ios/Runner/Info.plist"
    if not pl.exists():
        print("!! ios/Runner/Info.plist not found — run flutter create first")
        return
    with pl.open("rb") as f:
        data = plistlib.load(f)
    data["CFBundleDisplayName"] = "Volo Chat"
    data["NSLocationWhenInUseUsageDescription"] = (
        "Volo Chat uses your location only when you share it in a chat, "
        "turn on live location for your groups, set a meeting point or send an SOS."
    )
    data["NSCameraUsageDescription"] = (
        "Volo Chat uses the camera for video calls and for photos you choose to send."
    )
    data["NSMicrophoneUsageDescription"] = (
        "Volo Chat uses the microphone for voice and video calls and voice messages."
    )
    data.setdefault("UIBackgroundModes", [])
    for m in ("audio",):
        if m not in data["UIBackgroundModes"]:
            data["UIBackgroundModes"].append(m)
    data["NSPhotoLibraryUsageDescription"] = (
        "Volo Chat opens your photos only when you choose one to send or post as a status."
    )
    data["GMapsAPIKey"] = MAPS_KEY
    # TTS / AVSpeech needs no permission; url_launcher queries:
    data["MinimumOSVersion"] = "15.5"
    # The app falls back to http://umrahtrip.sbs when SSL is unavailable;
    # without this exception iOS ATS silently blocks every pairing call.
    ats = data.setdefault("NSAppTransportSecurity", {})
    ex = ats.setdefault("NSExceptionDomains", {})
    ex["umrahtrip.sbs"] = {
        "NSIncludesSubdomains": True,
        "NSExceptionAllowsInsecureHTTPLoads": True,
    }
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


def patch_android_plugin_compile_sdk() -> None:
    """Some plugins (e.g. flutter_webrtc) still compile against android-31,
    but their AndroidX dependencies need 34+. Force every Android library
    module to compile against SDK 35 (compile-time only; minSdk unchanged)."""
    kts = APP / "android/build.gradle.kts"
    groovy = APP / "android/build.gradle"
    marker = "// volo-chat: force plugin compileSdk"
    if kts.exists():
        t = kts.read_text()
        if marker not in t:
            block = (
                f"{marker}\n"
                "subprojects {\n"
                "    afterEvaluate {\n"
                "        val ext = project.extensions.findByName(\"android\")\n"
                "        if (ext is com.android.build.gradle.BaseExtension) {\n"
                "            val cur = ext.compileSdkVersion?.removePrefix(\"android-\")?.toIntOrNull() ?: 0\n"
                "            if (cur < 35) ext.compileSdkVersion(35)\n"
                "        }\n"
                "    }\n"
                "}\n\n"
            )
            # Must run before `subprojects { project.evaluationDependsOn(":app") }`
            idx = t.find("subprojects {")
            t = t[:idx] + block + t[idx:] if idx != -1 else t + "\n" + block
            kts.write_text(t)
        print("ok: plugin compileSdk forced to 35 (build.gradle.kts)")
    elif groovy.exists():
        t = groovy.read_text()
        if marker not in t:
            block = (
                f"{marker}\n"
                "subprojects {\n"
                "    afterEvaluate { project ->\n"
                "        if (project.hasProperty('android')) {\n"
                "            def cur = (project.android.compileSdkVersion ?: '').toString().replace('android-', '')\n"
                "            if (!cur.isInteger() || cur.toInteger() < 35) project.android.compileSdkVersion 35\n"
                "        }\n"
                "    }\n"
                "}\n\n"
            )
            idx = t.find("subprojects {")
            t = t[:idx] + block + t[idx:] if idx != -1 else t + "\n" + block
            groovy.write_text(t)
        print("ok: plugin compileSdk forced to 35 (build.gradle)")


def patch_android_signing() -> None:
    """Sign release builds with the permanent Volo Chat keystore when the
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
    patch_android_plugin_compile_sdk()
    patch_ios_plist()
    patch_ios_podfile()
    patch_ios_deployment_target()
    patch_android_signing()
    print("Platform patching complete.")
