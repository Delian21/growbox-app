// Screenshot sweep — one PNG per page, in both themes.
//
//     flutter test tool/screenshots/capture.dart
//
// Opt-in (tool/, not test/) because it needs the real fonts, which are not in
// the repository: see tool/real_fonts.dart for the one-time fetch into build/.
//
// What it does: boots the real app (`GrowboxApp`) with a seeded returning
// customer — profile, favourites, a saved address, a filled box and the demo
// deliveries — then pushes each page, photographs it in the light theme, flips
// the live ThemeNotifier to dark, photographs the same page again, and pops.
// Nothing here is a mock of the UI: same widgets, same theme objects, same
// providers the app itself runs.
//
// Output: screenshots/light/<page>.png and screenshots/dark/<page>.png, at
// 390x844 logical pixels with a notched-phone safe area, rasterised at 2x
// (780x1688). Every shot prints SHOT <path> <size> on the way past.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/addresses.dart';
import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/data/orders.dart';
import 'package:growbox/main.dart';
import 'package:growbox/screens/account_screen.dart';
import 'package:growbox/screens/address_management_screen.dart';
import 'package:growbox/screens/cart_screen.dart';
import 'package:growbox/screens/category_vendors_screen.dart';
import 'package:growbox/screens/change_email_screen.dart';
import 'package:growbox/screens/change_phone_screen.dart';
import 'package:growbox/screens/checkout_screen.dart';
import 'package:growbox/screens/cookies_screen.dart';
import 'package:growbox/screens/deactivation_screen.dart';
import 'package:growbox/screens/delivery_tracking_screen.dart';
import 'package:growbox/screens/edit_profile_screen.dart';
import 'package:growbox/screens/faq_screen.dart';
import 'package:growbox/screens/favorites_screen.dart';
import 'package:growbox/screens/forgot_password_screen.dart';
import 'package:growbox/screens/home_screen.dart';
import 'package:growbox/screens/location_screen.dart';
import 'package:growbox/screens/login_screen.dart';
import 'package:growbox/screens/menu_screen.dart';
import 'package:growbox/screens/notifications_screen.dart';
import 'package:growbox/screens/onboarding_screen.dart';
import 'package:growbox/screens/order_details_screen.dart';
import 'package:growbox/screens/order_history_screen.dart';
import 'package:growbox/screens/order_result_screens.dart';
import 'package:growbox/screens/order_success_screen.dart';
import 'package:growbox/screens/privacy_policy_screen.dart';
import 'package:growbox/screens/privacy_screen.dart';
import 'package:growbox/screens/product_details_screen.dart';
import 'package:growbox/screens/profile_screen.dart';
import 'package:growbox/screens/registration_screen.dart';
import 'package:growbox/screens/search_screen.dart';
import 'package:growbox/screens/terms_screen.dart';
import 'package:growbox/screens/vendor_screen.dart';
import 'package:growbox/theme.dart';

import '../real_fonts.dart';

// ---------------------------------------------------------------------------
// Device
// ---------------------------------------------------------------------------

/// A notched phone, in logical pixels. The safe area is real, so the screens
/// lay out the way they do on the device they were designed for.
const Size _screen = Size(390, 844);
const FakeViewPadding _safeArea = FakeViewPadding(top: 44, bottom: 34);

/// Rasterised at twice the logical size, so the PNGs stay crisp when zoomed.
const double _captureScale = 2;

const String _outDir = 'screenshots';
final GlobalKey _shotKey = GlobalKey();

/// A `GoogleMap` cannot exist, let alone be photographed, off-device: there is
/// no native view host to ask for a texture. This stands in for the plugin's
/// platform and draws nothing, which leaves the location screen's map area
/// blank in that one shot — a limit of photographing native views in a widget
/// test, not of the screen.
class _NoMapPlatform extends GoogleMapsFlutterPlatform {
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
    Map<String, dynamic> mapOptions = const <String, dynamic>{},
  }) {
    return const SizedBox.expand();
  }

  @override
  Future<void> init(int mapId) async {}

  @override
  void dispose({required int mapId}) {}
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// The box the cart and checkout screens show: two units from one vendor and
/// one from another, both real catalog products so their images load.
final List<VendorProduct> _box = () {
  final green = MockProducts.all.firstWhere((p) => p.vendorName == 'Green Farm');
  final other = MockProducts.all.firstWhere((p) => p.vendorName != 'Green Farm');
  return [green, green, other];
}();

/// An order mid-delivery, with the step times the timeline and the tracking
/// screen read. Placed 18 minutes ago so the ETA is still in the future.
Order _liveOrder() {
  final placed = DateTime.now().subtract(const Duration(minutes: 18));
  return Order(
    id: 'GBX-10482',
    vendorName: 'Green Farm',
    status: OrderStatus.onTheWay,
    createdAt: placed,
    estimatedArrival: placed.add(const Duration(minutes: 30)),
    deliveryAddress: 'No. 12 Gwarinpa Estate, Gwarinpa, Abuja',
    timestamps: {
      OrderStatus.confirmed: placed,
      OrderStatus.packing: placed.add(const Duration(minutes: 6)),
      OrderStatus.onTheWay: placed.add(const Duration(minutes: 14)),
    },
    items: [
      OrderItem(
        name: 'Rice',
        vendorName: 'Green Farm',
        category: 'GRAINS',
        image: _box.first.image,
        price: 2550,
        quantity: 2,
      ),
      OrderItem(
        name: 'Beans',
        vendorName: 'Green Farm',
        category: 'LEGUMES',
        image: _box[2].image,
        price: 1200,
        quantity: 1,
      ),
    ],
  );
}

/// Boots the app's global state the way `main()` does, then seeds the
/// returning customer whose pages are being photographed.
Future<void> _boot() async {
  // This file is run through `flutter test`, but it lives in tool/ rather than
  // test/, so the lint that allows visible-for-testing APIs by directory needs
  // telling explicitly.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'cart_items_v1': jsonEncode(_box.map((p) => p.toJson()).toList()),
  });

  CustomerData.name = 'Ada Obi';
  CustomerData.email = 'ada@growbox.ng';
  CustomerData.phone = '0803 555 0134';

  final vendor = MockVendors.vendors.first;
  favoriteVendors
    ..clear()
    ..add({
      'name': vendor['name'] as String,
      'image': vendor['image'] as String,
      'logo': vendor['logo'] as String,
      'rating': vendor['rating'].toString(),
      'reviews': vendor['reviews'] as String,
    });

  await browsingAreaStore.load();
  // The bucket is chosen from the profile, so this runs after CustomerData.
  await addressesStore.load(force: true);
  await addressesStore.save(const Address(
    id: 'home',
    label: 'Home',
    street: 'No. 12 Gwarinpa Estate',
    area: 'Gwarinpa, Abuja',
    landmark: 'Blue gate beside the bakery',
    phone: '0803 555 0134',
  ));
  await addressesStore.save(const Address(
    id: 'office',
    label: 'Office',
    street: 'Plot 44 Aminu Kano Crescent',
    area: 'Wuse 2, Abuja',
  ));
  await addressesStore.select('home');

  seedPurchaseHistory();
  StockTracker.seed();
  await ordersStore.load();
}

// ---------------------------------------------------------------------------
// Interactions
// ---------------------------------------------------------------------------

typedef Steps = Future<void> Function(WidgetTester tester);

/// Taps [label] if it is on screen, after scrolling it into view. A label that
/// is not there prints MISS instead of failing, so one drifted label cannot
/// cost the whole sweep.
Future<void> _tap(WidgetTester tester, String label,
    {bool scroll = false, int settle = 700}) async {
  final finder = find.text(label);
  if (finder.evaluate().isEmpty) {
    debugPrint('MISS no "$label" to tap');
    return;
  }
  if (scroll) {
    await tester.ensureVisible(finder.first);
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.tap(finder.first, warnIfMissed: false);
  await tester.pump();
  // The pump with a duration is what lets a faked `Future.delayed` fire; its
  // setState only rebuilds on the frames after it, so pump again (and once more
  // for the step transition) before the next interaction looks for widgets.
  await tester.pump(Duration(milliseconds: settle));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The password reset screen takes its six digits one TextField at a time, so
/// a code has to be typed a character into each.
Future<void> _typeCode(WidgetTester tester, String code) async {
  for (var i = 0; i < code.length; i++) {
    await tester.enterText(find.byType(TextField).at(i), code[i]);
    await tester.pump();
  }
}

Future<void> _type(WidgetTester tester, String text, {int index = 0}) async {
  final fields = find.byType(TextField);
  if (fields.evaluate().length <= index) {
    debugPrint('MISS no text field #$index');
    return;
  }
  await tester.enterText(fields.at(index), text);
  await tester.pump();
}

/// Sign-up wizard, step 2 and on: each step is reached through the previous
/// one, exactly as the app's own tests walk it.
Future<void> _signUpEmail(WidgetTester t) => _tap(t, 'Continue with Email');

Future<void> _signUpPassword(WidgetTester t) async {
  await _signUpEmail(t);
  await _type(t, 'ada@growbox.ng');
  await _tap(t, 'Continue');
}

Future<void> _signUpName(WidgetTester t) async {
  await _signUpPassword(t);
  await _type(t, 'secret123', index: 0);
  await _type(t, 'secret123', index: 1);
  await _tap(t, 'Continue');
}

Future<void> _signUpVerify(WidgetTester t) async {
  await _signUpName(t);
  await _type(t, 'Ada Obi');
  await _tap(t, 'Continue');
}

// ---------------------------------------------------------------------------
// Pages
// ---------------------------------------------------------------------------

/// One page to photograph. [build] returns the page itself; [steps] drives any
/// interaction needed to reach the state worth seeing.
class Shot {
  const Shot(this.name, this.build, {this.steps});

  final String name;
  final Widget Function() build;
  final Steps? steps;
}

List<Shot> _pages() {
  final vendor = MockVendors.find('Green Farm')!;
  final vendorProducts = vendor['products'] as List<VendorProduct>;

  return [
    // ── Onboarding and sign-up ──────────────────────────────────────────
    Shot('onboarding-1-fresh-produce', () => const OnboardingScreen()),
    Shot('onboarding-2-local-vendors', () => const OnboardingScreen(),
        steps: (t) => _tap(t, 'Next')),
    Shot('onboarding-3-fast-delivery', () => const OnboardingScreen(),
        steps: (t) async {
          await _tap(t, 'Next');
          await _tap(t, 'Next');
        }),
    Shot('signup-welcome', () => const RegistrationScreen()),
    Shot('signup-email', () => const RegistrationScreen(),
        steps: _signUpEmail),
    Shot('signup-password', () => const RegistrationScreen(),
        steps: _signUpPassword),
    Shot('signup-name', () => const RegistrationScreen(), steps: _signUpName),
    Shot('signup-confirm-email', () => const RegistrationScreen(),
        steps: _signUpVerify),
    Shot('login', () => const LoginScreen()),
    Shot('forgot-password-step-1-email', () => const ForgotPasswordScreen()),
    Shot('forgot-password-step-2-code', () => const ForgotPasswordScreen(),
        steps: (t) async {
          await _type(t, 'ada@growbox.ng');
          // Each step fakes a one-second send/verify delay, so the pump after a
          // tap has to outlast it before the next step exists.
          await _tap(t, 'Send Reset Code', settle: 1500);
        }),
    Shot('forgot-password-step-3-new-password',
        () => const ForgotPasswordScreen(), steps: (t) async {
      await _type(t, 'ada@growbox.ng');
      await _tap(t, 'Send Reset Code', settle: 1500);
      await _typeCode(t, '123456');
      await _tap(t, 'Verify Code', settle: 1500);
    }),
    Shot('forgot-password-step-4-done', () => const ForgotPasswordScreen(),
        steps: (t) async {
          await _type(t, 'ada@growbox.ng');
          await _tap(t, 'Send Reset Code', settle: 1500);
          await _typeCode(t, '123456');
          await _tap(t, 'Verify Code', settle: 1500);
          await _type(t, 'newsecret123', index: 0);
          await _type(t, 'newsecret123', index: 1);
          await _tap(t, 'Reset Password', settle: 1500);
        }),

    // ── Tabs and the shopping flow ──────────────────────────────────────
    Shot('home', () => const HomeScreen()),
    Shot('search', () => const SearchScreen()),
    Shot('browse-produce', () => const MenuScreen()),
    Shot(
      'nearby-vendors',
      // The same produce list the Home feed's "See all" opens, under its own
      // title, so the two entries can be compared.
      () => const MenuScreen(
        title: 'Nearby Vendors',
        allFilterLabel: 'Nearby Vendors',
      ),
    ),
    Shot('category-vendors-fruits',
        () => const CategoryVendorsScreen(category: 'Fruits')),
    Shot('vendor', () => _vendorScreen(vendor, vendorProducts)),
    Shot(
      'product-details',
      () => ProductDetailsScreen(product: vendorProducts.first),
    ),
    Shot('cart', () => const CartScreen()),
    Shot('checkout', () => CheckoutScreen(products: _box)),
    Shot('order-success', () => OrderSuccessScreen(order: _liveOrder())),
    Shot('order-pending', () => const OrderPendingScreen()),
    Shot('order-failed', () => const OrderFailedScreen()),
    Shot('orders-active', () => const OrderHistoryScreen()),
    Shot('orders-past', () => const OrderHistoryScreen(),
        steps: (t) => _tap(t, 'Past')),
    Shot('order-details', () => OrderDetailsScreen(order: _liveOrder())),
    Shot('delivery-tracking',
        () => DeliveryTrackingScreen(order: _liveOrder())),

    // ── Profile and settings ────────────────────────────────────────────
    Shot('profile', () => const ProfileScreen()),
    Shot('edit-profile', () => const EditProfileScreen()),
    Shot('favorites', () => const FavoritesScreen()),
    Shot('notifications', () => const NotificationsScreen()),
    Shot('location-sheet', () => const LocationScreen()),
    Shot('addresses', () => const AddressManagementScreen()),
    Shot('addresses-add-sheet',
        () => const AddressManagementScreen(startAdding: true)),
    Shot('account-settings', () => const AccountScreen()),
    Shot('delete-account-dialog', () => const AccountScreen(),
        steps: (t) => _tap(t, 'Delete Account', scroll: true)),
    Shot('change-email', () => const ChangeEmailScreen()),
    Shot('change-phone', () => const ChangePhoneNumberScreen()),
    Shot('privacy', () => const ManagePrivacyScreen()),
    Shot('deactivate-account', () => const DeactivationScreen()),

    // ── Policies and help ───────────────────────────────────────────────
    Shot('terms', () => const TermsScreen()),
    Shot('privacy-policy', () => const PrivacyPolicyScreen()),
    Shot('cookies-policy', () => const CookiesScreen()),
    Shot('faq', () => const FAQScreen()),
  ];
}

Widget _vendorScreen(Map<String, dynamic> vendor, List<VendorProduct> products) =>
    VendorScreen(
      vendorName: vendor['name'] as String,
      vendorCoverImage: vendor['image'] as String,
      vendorLogoImage: vendor['logo'] as String,
      categories: {
        for (final p in products) p.category,
      }.toList(),
      products: products,
    );

// ---------------------------------------------------------------------------
// Shutter
// ---------------------------------------------------------------------------

/// Lets the page settle without `pumpAndSettle`, which several screens never
/// reach: the tracking screen pulses forever and the skeletons repeat. Fixed
/// pumps finish the route transition, the data loads and the entrance
/// animations instead, and leave repeating ones mid-cycle.
Future<void> _advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400)); // route transition
  // Entrance animations stagger over about a second on most screens, so every
  // page gets the long settle: shooting earlier catches content mid-slide, low
  // on the screen and looking clipped.
  await tester.pump(const Duration(milliseconds: 900)); // data load
  await tester.pump(const Duration(milliseconds: 900)); // entrance


  await _decodeImages(tester);
}

/// Product photos, vendor covers and the splash logo decode off the fake clock,
/// so a shot taken straight after `pump` catches empty image slots: hand the
/// real event loop a moment, then pump the decoded frames into the tree.
Future<void> _decodeImages(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _save(WidgetTester tester, String relative) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  final Uint8List bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _captureScale);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;

  final file = File('$_outDir/$relative')..createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  debugPrint('SHOT ${file.path.replaceAll(r'\', '/')} '
      '(${(bytes.length / 1024).round()} KB)');
}

Future<void> _shootBoth(
  WidgetTester tester,
  NavigatorState navigator,
  ThemeNotifier theme,
  Shot shot,
) async {
  navigator.push<void>(MaterialPageRoute(builder: (_) => shot.build()));
  await _advance(tester);
  if (shot.steps != null) {
    await shot.steps!(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }

  await _save(tester, 'light/${shot.name}.png');
  _reportExceptions(tester, 'light/${shot.name}');

  // The app's own theme switch: the same page, live, in dark mode.
  theme.select(ThemeMode.dark);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await _save(tester, 'dark/${shot.name}.png');
  _reportExceptions(tester, 'dark/${shot.name}');

  // Dialogs and sheets live on the root overlay, and tearing the page down
  // underneath one disposes its controllers while it is still building — the
  // framework then reports "used after being disposed" and a duplicate
  // GlobalKey on the next page. One pop closes whatever is modal on top; a
  // page with nothing modal simply loses the page itself, and the popUntil
  // then has nothing left to unwind.
  theme.select(ThemeMode.light);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  navigator.pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  navigator.popUntil((route) => route.isFirst);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  _reportExceptions(tester, '${shot.name} (teardown)');
}

/// Anything the page threw while it was up is worth knowing about, but it
/// should not cost the rest of the sweep: report every pending exception and
/// drain the queue so the next page starts clean.
void _reportExceptions(WidgetTester tester, String where) {
  while (true) {
    final error = tester.takeException();
    if (error == null) return;
    final first = error.toString().split('\n').first;
    final overflowed = error.toString().split('\n').any(
        (line) => line.contains('overflowed') || line.contains('overflow'));
    debugPrint('${overflowed ? 'OVERFLOW' : 'EXCEPTION'} $where -> $first');
  }
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture every page in both themes', (tester) async {
    // In the test body, not setUpAll: the binding hands out a fresh binary
    // messenger for every test, which would drop the asset handler that keeps
    // google_fonts offline.
    await loadRealFonts();

    // flutter_test switches shadows off and draws them as hard black shapes,
    // which is right for assertions and wrong for a screenshot: it put a black
    // ring behind the snack bar and a black edge under every card. Photograph
    // what a device paints.
    debugDisableShadows = false;

    // The location screen mounts a real GoogleMap. Its platform view asks a
    // native host to create a texture, and the plugin's channel implementation
    // then calls methods its own interface leaves unimplemented — neither
    // exists in a widget test, so the page throws into the test framework even
    // though it renders fine around the gap. Point the plugin at a platform
    // that paints nothing, so the page's own chrome is what gets photographed.
    GoogleMapsFlutterPlatform.instance = _NoMapPlatform();

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _screen;
    tester.view.padding = _safeArea;
    addTearDown(tester.view.reset);

    await _boot();

    await tester.pumpWidget(
      RepaintBoundary(key: _shotKey, child: GrowboxApp()),
    );

    // The splash is the app's first frame. Its logo, footer and tagline animate
    // in over the first 1.1s, and it navigates away on a 4s timer, so shoot
    // once the entrance has finished and unwind past the navigation before the
    // first page, so every page sits on the app's own landing route.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    // The logo is a bundled PNG: without a turn of the real event loop it has
    // not decoded yet and the frame is bare gradient.
    await _decodeImages(tester);
    await tester.pump(const Duration(milliseconds: 300));
    final theme = ThemeProvider.of(tester.element(find.byType(MaterialApp)));
    await _save(tester, 'light/splash.png');
    _reportExceptions(tester, 'light/splash');
    theme.select(ThemeMode.dark);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await _save(tester, 'dark/splash.png');
    _reportExceptions(tester, 'dark/splash');
    theme.select(ThemeMode.light);

    // Past the splash's own navigation and its 500ms fade.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 700));
    _reportExceptions(tester, 'splash navigation');

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);

    for (final shot in _pages()) {
      await _shootBoth(tester, navigator, theme, shot);
    }

    // Dispose the app and drain its timers before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));

    // flutter_test asserts that its painting debug flags are back where it left
    // them, and it checks inside the test body, before any tear-down runs.
    debugDisableShadows = true;
  });
}
