=== BWP Umrah Pair ===
Contributors: bwpexperts
Tags: umrah, travel, pairing, location
Requires at least: 5.8
Tested up to: 6.7
Requires PHP: 7.4
Stable tag: 1.0.0
License: GPLv2 or later

Backend for the Umrah Trip mobile app's couple-pairing feature.

== Description ==
One 6-character security code links exactly two devices (e.g. husband & wife on Umrah) for:

* Consensual live-location sharing (toggle on each phone; cleared the moment it's turned off)
* Shared "visited Ziyarat" sync — see what each of you has completed
* A private shared photo gallery (camera photos sent from the app)

REST namespace: `umrah-pair/v1` (create / join / sync / photo / unpair).
Data is stored in one custom table plus photo files under `wp-content/uploads/umrah-pair/`.
Pairs untouched for 60 days are cleaned up automatically. Un-pair deletes the pair row immediately.

== Installation ==
1. WP Admin → Plugins → Add New → Upload Plugin → choose `bwp-umrah-pair.zip` → Install → Activate.
2. Make sure permalinks are enabled (Settings → Permalinks → anything except "Plain").
3. In the Umrah Trip app: Profile → Couple Pairing → Server → enter your site URL (e.g. https://your-site.com) → Save.
4. Phone 1: "Create security code". Phone 2: "Join with code".

== Privacy ==
Both devices must enter the same code. Location is stored only while a device has sharing ON and is wiped when it's switched off or the pair is deleted. No accounts, emails or personal data are collected.
