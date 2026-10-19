# Umrah Trip 🕋

**Your Smart Umrah & Ziyarat Companion** — a premium Flutter travel app by **BWP Experts** that helps pilgrims discover, learn about, navigate to and track Ziyarat destinations across Saudi Arabia.

<p align="center"><img src="app/assets/images/logo.png" width="220" alt="Umrah Trip logo"></p>

## What's inside (current round — Phases 1–3 core)

| Feature | Status |
| --- | --- |
| Animated logo splash (coded: elastic logo pop, golden tawaf-ring orbit, glow) | ✅ |
| 5-tab premium UI (Home · Explore · Map · My Trip · Profile), emerald/ivory/gold theme, light + dark | ✅ |
| 31 preloaded destinations (Makkah, Madinah, Jeddah, Riyadh/Diriyah, Taif, Eastern Province) with Arabic/Urdu/Roman names, history, significance, tips, **verification flags + source URLs + last-verified dates** | ✅ |
| Real GPS position, nearest-city detection, straight-line distances (clearly labelled — never fake driving ETAs) | ✅ |
| **One-tap real navigation** from every destination (opens Google Maps turn-by-turn; Apple Maps option on iOS) | ✅ |
| Date-wise trip planner: unlimited days, timed visits, drag-and-drop reorder, per-day city | ✅ |
| "Plan best route" greedy suggestion (straight-line, suggestion-only, never overrides user order/times) | ✅ |
| Visited / Planned / Skipped / Not-planned states, manual Mark Visited, proximity **Check In Here** with confirmation, undo | ✅ |
| My Travel Memories (visit history + notes + optional GPS check-in) | ✅ |
| Live Google Map with status-coloured markers + filters (needs `MAPS_API_KEY`; honest setup card + list fallback without it) | ✅ |
| Global search (English/Arabic/Urdu/Roman Urdu + aliases) and smart filters incl. verified free entry | ✅ |
| Budget & expense tracker (SAR, 6 categories, optional user-entered PKR rate with timestamp) | ✅ |
| Offline-first: destinations bundled; trip, visits, favourites, expenses in SQLite — survive restarts | ✅ |
| EN / اردو / العربية UI with RTL + Roman Urdu descriptions toggle | ✅ |
| Unit tests for itinerary management & visit tracking | ✅ |
| CI: Android APK + AAB, iOS **unsigned IPA** artifacts on every push | ✅ |
| Laravel API + PostgreSQL + Next.js admin, reminders/notifications, Routes-API ETAs, text-to-speech polish | 🔜 next rounds (see Roadmap) |

**Data honesty rules baked in:** unverified coordinates/fees/hours are flagged in the UI; no invented prices, no simulated routes, no auto-marking visits.

## Repo layout

```
app/        Flutter application (Dart source, assets, tests)
scripts/    Platform bootstrap + patch scripts (used locally and by CI)
.github/    CI workflows: Android APK/AAB, iOS unsigned IPA
docs/       Setup & build documentation
```

`android/` and `ios/` folders are **generated** by `scripts/bootstrap_platforms.sh` (via `flutter create`) and then patched — they are not committed, so upgrades stay clean.

## Quick start (local)

```bash
cd app
bash ../scripts/bootstrap_platforms.sh        # generates android/ + ios/, icons, permissions
flutter run                                    # or: flutter run --dart-define=MAPS_API_KEY=YOUR_KEY
```

## Get the builds (CI)

Every push to `main` produces downloadable artifacts under **Actions**:

- **Android Build** → `UmrahTrip-release-apk`, `UmrahTrip-release-aab`
- **iOS Build** → `UmrahTrip-unsigned-ipa` (install via AltStore/Sideloadly, or sign with your Apple certs)

Add repo secret `MAPS_API_KEY` to light up the in-app Google Map. For a **signed** IPA/TestFlight, follow `docs/SETUP.md` → *iOS signing*.

## Roadmap

1. ~~Phase 1 — Core app, premium UI, verified destination database~~ ✅
2. ~~Phase 2 — GPS, markers, one-tap navigation~~ ✅ (in-app Routes-API road ETAs: next)
3. ~~Phase 3 — Date-wise planner, visited tracking, favourites, route suggestion~~ ✅ (visit reminders: next)
4. Phase 4 — Notifications/reminders, full TTS narration, sync layer, richer offline packs
5. Phase 5 — Laravel REST API + PostgreSQL, Next.js admin dashboard, licensed photo pipeline, store releases

---
© BWP Experts · bwpexperts.com
