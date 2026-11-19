# GROWBOX — a map of the code

GROWBOX is a consumer grocery-delivery app in Flutter (Material 3). There is no
server: the catalogue is mock data in `lib/data/`, and everything the customer
creates — cart, orders, addresses, profile, favourites, theme — is saved on the
device with `shared_preferences`. The app therefore runs with no network at all.

This file is written to be read in small pieces: the first two sections are the
whole picture, and the tables after them answer "where do I edit this?" without
a search.

---

## 1. The app in ten lines

```
main()                      restores what was saved, then runApp()
  AppEntryGate              shows the splash, then replaces the stack with ONE of:
                            Onboarding · Registration(welcome) · Login · Location setup · RootShell
  RootShell                 signed in: four tabs in one IndexedStack + one floating bottom nav
                            Home · Search · Cart · Profile
  pushed above the shell    vendor, product, checkout, orders, tracking, profile sub-pages…
  every screen              reads a store (lib/data/ or lib/services/) and never writes storage itself
  the stores                save themselves and notify the screens that listen
  no backend                "requests" go through MockBackend: 600 ms delay, can be made to fail
```

Two things follow from that shape, and they explain most of the layout:

- **One entry decision.** Only `AppEntryGate` decides where a cold start lands;
  screens do not check "am I signed in?" themselves.
- **One owner per fact.** Cart, orders, addresses, session, theme and network
  state each live in exactly one object. A screen that shows one of them reads
  the owner instead of keeping a copy.

---

## 2. Folders

| Path | What lives there | Rule of thumb |
|---|---|---|
| `lib/main.dart` | Composition root: restore order, providers, `MaterialApp`, themes, the on-brand error widget, the app-lifecycle (away-timer) hooks | Only startup wiring — no screen code |
| `lib/theme.dart` | The whole design system: palettes, `C.*(context)` accessors, type, spacing, radii, button styles, `formatPrice()` | Every colour and measurement comes from here |
| `lib/tabs.dart` | `AppTab`, `TabNavigator` (which tab is showing), `openTab()` | The only place tabs are numbered |
| `lib/routes.dart` | `AppRoutes` named-route table + `routeObserver` | Register a route here; ad-hoc pushes stay local |
| `lib/config.dart` | `kSessionAwayLimit` (30 minutes) | The one tunable that is not a colour |
| `lib/data/` (12 files) | Models, the mock catalogue, the stores, persistence, repositories | If it survives a restart, it belongs here |
| `lib/screens/` (34 files) | One file per screen (35 screens; `order_result_screens.dart` holds two) | A screen is a whole page; it may use widgets, not the other way round |
| `lib/widgets/` (31 files) | Shared UI: nav, cards, headers, sheets, skeletons, transitions | Used by two or more screens |
| `lib/services/` (7 files) | Connectivity (web/native split) and the voice-search stack | Platform-facing or stateful helpers, no UI |
| `test/` (42 files) | Widget and data tests, named after the behaviour they pin | See §11 |
| `tool/` | Screenshot capture, test-font fetch, one-off checks | Not shipped in the app |
| `assets/images/` | Every image the app renders | Reached only through `PlaceholderImages` |

---

## 3. Where do I change…?

| I want to change | Open |
|---|---|
| Brand green, or any colour | `lib/theme.dart` — `AppColors` (light), `AppDarkColors` (dark) |
| A colour that must work in both themes | Use `C.xxx(context)`; never raw `AppColors`, see §9 |
| Buttons | `lib/widgets/app_button.dart` (`AppButton`), `AppDecorations.primaryButtonStyle()` |
| Spacing, radii, pill sizes | `AppSpacing`, `AppRadii` in `lib/theme.dart` |
| Fonts / heading sizes | `AppTypography` plus the text themes in `lib/main.dart` |
| How a price is written | `formatPrice()` in `lib/theme.dart` |
| A product, its price, photo or vendor | `lib/data/mock_data.dart` (`MockVendors.vendors`) |
| Which image a product shows | `lib/data/placeholder_images.dart`, file in `assets/images/` |
| A vendor's delivery fee | `MockVendors.deliveryFeeFor` in `lib/data/mock_data.dart` |
| Which areas are offered | A vendor's `serviceAreas` list — the picker derives itself from it (§6) |
| The category rail | `lib/data/categories.dart` (`kCategories`) |
| What a cold start shows | `lib/widgets/app_entry_gate.dart` |
| The 30-minute sign-out window | `lib/config.dart` |
| Cart totals and delivery fees | `CartTotals` in `lib/data/app_state.dart` |
| Order statuses, their labels and order | `OrderStatus` in `lib/data/orders.dart` |
| Payment options | `lib/data/payment_method.dart` |
| Which tabs exist | `AppTab` in `lib/tabs.dart`, `_tab()` in `root_shell.dart`, items in `bottom_nav.dart` |
| A screen's title bar / back button | `lib/widgets/app_header.dart` |
| Empty and error states | `lib/widgets/status_view.dart`, `lib/widgets/load_error_view.dart` |
| Loading skeletons | `lib/widgets/skeleton_loader.dart` |
| Page transition animation | `lib/widgets/page_transitions.dart` (app-wide default) |
| Legal copy (terms, privacy, cookies) | `lib/screens/terms_screen.dart`, `privacy_policy_screen.dart`, `cookies_screen.dart` |
| The version/build label | `lib/data/build_info.dart` + `version:` in `pubspec.yaml` |
| Fake latency or a forced failure | `lib/data/mock_backend.dart` |
| Demo-only switches and the state gallery | `kDemoTools` branches in `lib/screens/profile_screen.dart` |
| Add a screen | New file in `lib/screens/`; add a constant + entry in `AppRoutes` only if it needs a name |

---

## 4. The stores: who owns what

All except the cart are plain singletons (`ordersStore`, `addressesStore`,
`connectivityStore`, `tabNavigator`, static `SessionStore`). That is deliberate:
a pushed screen is not a descendant of the shell, so a `Provider` could not
reach it. Screens `addListener`/`AnimatedBuilder` on the store they show.

| Object | File | Owns | Saved under |
|---|---|---|---|
| `CartNotifier` | `data/app_state.dart` | Cart lines (one entry per unit), totals | `cart_items_v1` |
| `OrdersStore` | `data/orders.dart` | The `Order` list the screens read | `order_history_v1` |
| `AddressesStore` | `data/addresses.dart` | Saved addresses + selected address | `delivery_addresses_v2:<account>`, `selected_address_v2:<account>` |
| `BrowsingAreaStore` | `data/addresses.dart` | The area the feed is browsed from | `browsing_area_v1`, `browsing_area_id_v1`, `browsing_area_recents_v1` |
| `SessionStore` | `data/session.dart` | Who is signed in, `lastActiveAt` | `mock_session_v1` |
| `CustomerData` | `data/mock_data.dart` | Name, email, phone | `customer_profile_v1` |
| `ThemeNotifier` | `theme.dart` | Light / dark / system | `theme_mode` |
| `TabNavigator` | `tabs.dart` | Selected tab + search-focus request | not persisted |
| `ConnectivityStore` | `services/connectivity.dart` | Online/offline | not persisted |
| Favourites | `data/app_state.dart` | Followed vendors | `favorite_vendors_v1` |

`OnboardingScreen.hasCompleted()` keeps its flag (`onboarding_completed`) because
it is read before any store exists.

**A browsing area is not a delivery address.** The area decides what the feed
shows and may be typed freely; checkout only ever uses a saved `Address` with a
street line, which is what `Address.isComplete` checks.

---

## 5. A cold start, in order

```
main()
 ├─ ErrorWidget.builder = BrandedErrorView      (never Flutter's grey error panel)
 ├─ seedPurchaseHistory(), StockTracker.seed()
 ├─ restore: CustomerData · favourites · orders · SessionStore   (Future.wait)
 ├─ addressesStore.load() · browsingAreaStore.load()              (per-account bucket)
 ├─ ordersStore.load() · connectivityStore.start()
 ├─ ThemeNotifier.loadSavedMode()                (no light flash for dark-mode users)
 └─ runApp()

AppEntryGate (home of MaterialApp)
 ├─ OnboardingScreen.hasCompleted()      → false: OnboardingScreen
 ├─ SessionStore.clearIfExpired()        → true:  LoginScreen with the notice
 ├─ SessionStore.isSignedIn              → false: RegistrationScreen (welcome)
 ├─ address or browsing area saved?      → false: LocationScreen(isFirstRun: true)
 └─ otherwise                            → RootShell
```

The splash dwells for `minimumSplash` (4 s on a cold start, zero after signing
in) and the gate *replaces* the stack, so Back can never return to the splash,
the welcome screen or the login form. On resume, `GrowboxApp` re-checks the away
limit once: expired → login; still valid → stay exactly where the customer was.

---

## 6. Tabs and the Back rule

`RootShell` keeps the four tabs mounted in an `IndexedStack` (a tab is built on
its first visit and then kept, so scroll position, typed search text and form
state survive switching). Pushed screens are ordinary routes above it.

- Back on a tab that is not Home → Home.
- Back on Home → "Press back again to exit" within 2 seconds.
- `openTab(context, AppTab.cart)` pops to the shell, then selects the tab — use
  it instead of pushing a tab route.

---

## 7. The fake network

There is no HTTP anywhere. Repositories (`catalogRepository`, `ordersStore`,
`AddressesStore` via `AddressRepository`) are the seam, and catalogue/order reads
go through `MockBackend.run()`:

- 600 ms of latency so loading states are real, 10 s deadline so a hang still
  ends in the error state;
- `failNextRequest()` / `failNextOrder()` fail exactly once, so the retry
  succeeds — that is what the demo buttons and the failure screens rely on.

Swapping in a real backend means implementing `OrdersRepository` /
`AddressRepository` / `CatalogRepository` and changing the one line that
constructs them. No widget changes.

---

## 8. Two order types — read this before touching orders

| Type | File | Why it exists |
|---|---|---|
| `Order`, `OrderStatus`, `OrderRating`, `OrdersRepository`, `OrdersStore` | `data/orders.dart` | What every screen consumes. Plain data, no knowledge of where it came from |
| `StoredOrder`, `OrderItem`, `recordOrder()`, `storedOrders` | `data/app_state.dart` | The original persisted history; still what checkout writes and what `MockOrdersRepository` reads to produce `Order`s |

So: **checkout writes a `StoredOrder`; screens read `Order`s built from it.**
Both freeze price and image at purchase time — a later catalogue change never
rewrites history. `orderFromStored()` is the conversion. If you add a field to
an order, it generally has to exist on both.

---

## 9. Look and feel

- `C.surface(context)`, `C.textPrimary(context)`, `C.divider(context)`,
  `C.isDark(context)` … return the dark variant automatically. **Use these**
  anywhere the surface can be either theme.
- `AppTypography` styles are light-theme coloured by default — pair with
  `.copyWith(color: C.xxx(context))` in dark mode.
- Brand entry screens (splash, registration banner) are constant
  `AppColors.primary` in both themes on purpose: the white-art logo sits on
  green there. Do not "fix" them with a brightness swap.
- All images go through `PlaceholderImages`; no asset path is typed in a screen.
- The fixed white Google button and black Apple button are brand colours on
  purpose.
- Appearance is restored before the first frame, so a dark-mode user never sees
  a light flash.

---

## 10. Voice search — four files, four jobs

| File | Job |
|---|---|
| `services/speech_service.dart` | The interface: `SpeechPartial` / `SpeechFinal` / `SpeechFailure` events |
| `services/speech_to_text_service.dart` | The real engine (`speech_to_text`), configured once for short queries |
| `services/voice_search_service.dart` | `VoiceSearchMatcher`: maps misheard words ("rise" → rice) onto catalogue names |
| `services/voice_search_session.dart` | `VoiceSearchSession`: start, live partials, stop-on-silence, submit |
| `widgets/voice_search_button.dart` + `search_screen.dart` | Draw the state and host it |

The screen never touches the plugin, and the timing rules are tested against a
fake engine (`test/voice_search_test.dart`).

---

## 11. Tests and demo tools

```bash
flutter test                 # 42 files; run before committing anything behavioural
flutter analyze
```

Tests are behaviour-named (`cart_persistence_test`, `session_entry_test`,
`checkout_order_flow_test`, `service_areas_test`, …). Two are regression pins
with a story in their comments: `registration_navigation_test` (a `Stack` child
without a key rebuilt the wizard's `PageView`) and `orders_screen_test`
(pumped manually because the old splash pulsed forever).

`kDemoTools` (`data/mock_backend.dart`) is true in debug and in a release built
with `--dart-define=DEMO_TOOLS=true`. It adds Profile's demo section, the
one-shot failure switches, and `StateGalleryScreen` — every empty/loading/error
state using the *real* widgets. A normal release compiles all of it out.

---

## 12. Rules that keep the code coherent

- **One owner per fact** (§4). If you are about to copy state into a screen,
  read the store instead.
- **Resolve catalogue data, don't re-create it**: `MockProducts.find(name:,
  vendorName:)`. Past orders are the exception — they snapshot on purpose.
- **Conditional `Stack` children need stable `ValueKey`s**, or inserting one
  re-creates its siblings.
- **Derive, don't duplicate**: the served areas come from vendor data, the tab
  order from `AppTab`, the transition from one builder.
- **Say why, not what.** Every non-obvious decision in this codebase is a `//`
  or `///` that explains the bug it prevents. Keep that habit — it is what makes
  the code readable without the history.

---

## 13. Seams a newcomer will hit (known, intentional)

| Looks odd | The reason |
|---|---|
| `page_transition.dart` **and** `page_transitions.dart` | The plural one is the app-wide `PageTransitionsBuilder` used in `main.dart`; the singular one is optional `SlideRoute` / `FadeRoute` / `ScaleRoute` for one-off pushes |
| Two classes named `SkeletonBox` (`micro_interactions.dart`, `skeleton_loader.dart`) | The older shimmer box vs the static block. Three files import both, so an unqualified `SkeletonBox` there is an ambiguous-import error — use `skeleton_loader.dart`'s and import it with `show` if you hit it |
| Orders and favourites are device-wide, addresses are per account | Addresses needed a bucket per login; the rest predate that. If you make another store per-account, follow `LocalAddressRepository`'s `:<account>` key pattern |
| `StoredOrder` and `Order` both exist | §8 |
| The entry point is `widgets/app_entry_gate.dart`, not `main.dart` | `main.dart` only wires the app; the landing decision is the gate (§5) |
| `state_gallery_screen.dart` is 878 lines and unreachable in a release | Demo-only; it exists to look at states without faking data |
