# GROWBOX — Grocery Delivery App (Consumer)

A Flutter (Material 3) grocery-delivery app for consumers. There is no backend:
the catalog, cart, and orders live in in-memory mock data and every image is a
bundled asset, so the app's own screens need no network. Two parts still do:
Google Maps for the address picker, and Google Fonts, which fetches its font
files on first run. It shares branding and design language with the vendor app
in a sibling project (`growbox_vendor`).

**New here?** [ARCHITECTURE.md §1](ARCHITECTURE.md#1-the-app-in-ten-lines) is the
ten-line map of the app, and §3 answers "where do I change this?" without a
search through the code.

## Highlights

- **Branded entry flow** — splash with a one-pass logo sheen, first-run
  onboarding, and a 5-step registration wizard with email confirmation
- **Shopping experience** — home feed (promo banner, category rail, Order Again,
  nearby vendors), product search with **voice search**, vendor pages, product
  details, and an animated fly-to-cart add flow
- **Persistent cart & orders** — the cart and order history survive app
  restarts via `shared_preferences`; past orders freeze price/image at purchase
  time; reorder from history; simulated live delivery tracking
- **Full profile area** — saved addresses, favorites, dark mode toggle, account
  settings (email/phone), privacy controls, FAQ, notifications
- **No backend** — catalogue, cart and orders are in-app, every image is
  bundled, and only the map picker and Google Fonts reach the network

## Tech stack

| Package | Used for |
|---|---|
| Flutter + `provider` | UI and cart state (the theme uses its own `InheritedNotifier`) |
| `shared_preferences` | Persistence (cart, orders, profile, addresses, favorites) |
| `cupertino_icons` | iOS-style icons |
| `google_fonts` | Inter (body) + Poppins (headlines/buttons) |
| `google_maps_flutter` | The address picker's map; tracking draws its route with painters |
| `connectivity_plus` | Online/offline signal for the banner and checkout (native builds only; web uses the browser's own events) |
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
- The site deploys automatically on every push to the connected branch.

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

- [ARCHITECTURE.md](ARCHITECTURE.md) — the ten-line map, the store table, a
  "where do I change this?" index, and the seams worth knowing.
