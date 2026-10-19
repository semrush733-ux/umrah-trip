# Couple Pairing — Setup Guide (Umrah Trip ↔ WordPress)

The pairing feature links **two phones with one 6-character security code**
(made for a husband & wife travelling together). Everything runs on **your own
WordPress site** — no Firebase, no third-party service.

## What it does
- **One code, two devices.** Phone 1 creates the code; Phone 2 joins with it. Max 2 devices per code.
- **Live pin location** — each phone has a *Share my live location* toggle. While ON (and the app is open), the partner sees a live pin on the Pairing page and on the in-app map, with an *Open in Maps* shortcut. Turning it OFF wipes the stored location immediately. Foreground only — no background tracking.
- **Shared visited sync** — every ~5 seconds the app syncs each person's *visited* Ziyarat list. The **Shared Experiences** page shows: yours ✓, partner's ✓, and the ones you've done **together** ❤.
- **Photo sharing** — tap *Camera*, the OS asks for camera permission; if you allow, the photo is captured and sent to your partner's shared gallery (max ~900 KB, auto-compressed). Gallery picking also available. Photos are only ever sent by a tap — never automatically.
- **Un-pair** — either phone can un-pair; the server row is deleted for both.

## Server setup (2 minutes)
1. Take `wordpress-plugin/bwp-umrah-pair.zip` from this repo.
2. WP Admin → **Plugins → Add New → Upload Plugin** → upload → **Activate**.
3. Settings → Permalinks must not be "Plain" (any pretty permalink setting is fine).
4. Done. Endpoints live at `https://YOUR-SITE.com/wp-json/umrah-pair/v1/…`

Quick test in a browser/terminal:
```bash
curl -X POST https://YOUR-SITE.com/wp-json/umrah-pair/v1/create \
  -H 'Content-Type: application/json' -d '{"name":"Test"}'
# → {"ok":true,"code":"ABC234","token":"..."}
```

## App setup
Profile → **Couple Pairing**:
1. **Server** → enter `https://YOUR-SITE.com` → Save server.
2. Enter your name.
3. Phone 1: **Create security code** → share the 6-character code.
4. Phone 2 (same server URL): enter code → **Join with code**.

Optionally bake the server in at build time so step 1 is pre-filled:
```bash
flutter build apk --release --dart-define=PAIR_API_BASE=https://YOUR-SITE.com
```
(CI: add repo secret `PAIR_API_BASE` — both workflows pass it through.)

## Security & privacy model
- Auth = the 6-char **code** + a per-device 32-char **token** issued at create/join; every request needs both. A code locks after 2 members join.
- Codes use an unambiguous 31-character alphabet (≈ 887M combinations) and endpoints are rate-limited; stale pairs auto-delete after 60 days of inactivity.
- Location is only accepted while that device reports `sharing=true`, and is nulled the moment sharing stops.
- Use the feature only between consenting adults who have each entered the code on their own phone — it is designed (and visibly indicates) mutual sharing, not covert tracking.
- Photos are stored under `wp-content/uploads/umrah-pair/` on **your** server. Keep the site on HTTPS.

## API summary (`umrah-pair/v1`)
| Endpoint | Body | Returns |
| --- | --- | --- |
| `POST /create` | `{name}` | `{code, token}` |
| `POST /join` | `{code, name}` | `{token}` |
| `POST /sync` | `{code, token, sharing, lat?, lng?, acc?, visits{destId:ts}}` | `{partner{...}, photos[], members}` |
| `POST /photo` | `{code, token, image(base64 jpg/png), caption?}` | `{url}` |
| `POST /unpair` | `{code, token}` | `{}` |
