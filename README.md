# GROWBOX — Grocery Delivery App (Consumer)

A Flutter (Material 3) grocery-delivery app for consumers. There is no backend:
the catalog, cart, and orders live in in-memory mock data and every image is a
bundled asset, so the app runs fully offline. It shares branding and design
language with the vendor app in a sibling project (`growbox_vendor`).

## Highlights

- **Branded entry flow** — animated splash screen, first-run onboarding, and a
  5-step registration wizard with email confirmation
- **Shopping experience** — home feed (promo banners, categories, Buy Again,
  deals), product search with **voice search**, vendor pages, product details,
  and an animated fly-to-cart add flow
- **Persistent cart & orders** — cart, checkout, and order history survive app
  restarts via `shared_preferences`; past orders freeze price/image at purchase
  time; reorder from history; simulated live delivery tracking
- **Full profile area** — saved addresses, favorites, dark mode toggle, account
  settings (email/phone), privacy controls, FAQ, notifications
- **Works offline** — zero network dependency at runtime; every asset bundled

## Tech stack

| Package | Used for |
|---|---|
| Flutter + `provider` | UI and state (cart, theme) |
| `shared_preferences` | Persistence (cart, orders, profile, addresses, favorites) |
| `google_fonts` | Inter (body) + Poppins (headlines/buttons) |
| `google_maps_flutter` | Location picker and delivery-tracking maps |
| `speech_to_text` | Voice search |

## Getting started

Prerequisites: the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(Dart SDK ^3.12.2).

```bash
flutter pub get
flutter run        # pick a device/emulator; add -d chrome for web
```

Run the tests:

```bash
flutter test
```

## Web build & deployment

The repo includes a Netlify setup for hosting the web build:

- `netlify.toml` / `netlify-build.sh` — build config (installs the pinned
  Flutter SDK, then `flutter build web --release`, publishing `build/web`).
- The site deploys automatically on every push to `main`.

Local web build for a quick check:

```bash
flutter build web --release
```

The Profile screen prints the running build at the bottom, as
`Growbox v1.0.0 · <id>`. Pass the id at build time:

```bash
# Git Bash / macOS / Linux, from the growbox/ directory
flutter build web --release \
  --pwa-strategy=none \
  --dart-define=BUILD_ID=$(git rev-parse --short HEAD)

# PowerShell
flutter build web --release --pwa-strategy=none `
  --dart-define=BUILD_ID=$(git rev-parse --short HEAD)

# cmd.exe (no inline $(...); run git first)
git rev-parse --short HEAD
flutter build web --release --pwa-strategy=none --dart-define=BUILD_ID=9ed2acc
```

A build without the define prints `dev`, which is deliberately unhelpful so
an unidentified build is obvious. Netlify passes `$COMMIT_REF` for you.

### Why `--pwa-strategy=none`

Flutter's default `offline-first` service worker serves the app shell from
cache before checking the network, so testers could see the previous deploy
until a second reload. `none` registers no service worker at all, which
removes that layer while we are testing; `web/_headers` additionally marks
`index.html`, `flutter_service_worker.js`, `version.json` and `main.dart.js`
`no-cache` so they are revalidated instead of reused. Switching back to
`offline-first` later keeps working — the headers make the next deploy land
on the first reload either way.

## Docs

- [ARCHITECTURE.md](ARCHITECTURE.md) — folder structure, theme system, state
  management, navigation flow, screen/widget maps, and conventions.
