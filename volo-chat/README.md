# Volo Chat

WhatsApp-style messenger by **BWP Experts** — Flutter app (Android + iOS) with a WordPress backend plugin.

- Phone number sign-up with SMS code (Twilio Verify) + email verification
- Real-time chat with ✓ sent / ✓✓ delivered / green ✓✓ seen, typing…, online / last seen
- Replies, delete for everyone, photos with captions, voice notes, location
- HD voice & video calls (WebRTC, TURN-ready), call history, busy / missed detection
- Status (24-hour stories: text & photo) with viewers list
- Groups, live group map, meeting points, SOS alerts with location + voice clip
- Android background connection: calls and messages arrive with the app closed
- Optional Firebase push (keys entered on the website, no rebuild)

## Server
Install `wordpress-plugin/bwp-volo-chat` on the WordPress site the app points to
(default `https://umrahtrip.sbs`, change with `--dart-define=VOLO_API_BASE=https://your-site`).
Settings: **WP Admin → Settings → Volo Chat** (Twilio Verify, test code, TURN, Firebase).

## Builds
GitHub Actions build the APK/AAB and an unsigned IPA on every push and publish them
to the `latest` release.
