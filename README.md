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

## Docs

- [ARCHITECTURE.md](ARCHITECTURE.md) — folder structure, theme system, state
  management, navigation flow, screen/widget maps, and conventions.
