import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/addresses.dart';
import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_backend.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/screens/checkout_screen.dart';
import 'package:growbox/screens/home_screen.dart';
import 'package:growbox/screens/profile_screen.dart';
import 'package:growbox/services/connectivity.dart';
import 'package:growbox/theme.dart';
import 'package:growbox/widgets/offline_banner.dart';
import 'package:growbox/widgets/skeleton_loader.dart';
import 'package:growbox/widgets/vendor_card.dart';

VendorProduct _product(String name, int price, {String vendor = 'Green Farm'}) =>
    VendorProduct(
      image: '',
      name: name,
      description: name,
      price: price,
      category: 'GRAINS',
      vendorName: vendor,
    );

const _address = Address(
  id: 'a1',
  label: 'Home',
  street: 'No. 12 Gwarinpa Estate',
  area: 'Gwarinpa, Abuja',
);

/// Two Rice plus one Tomatoes: 5,600 goods + 500 delivery = 6,100 payable.
final _products = [
  _product('Rice', 2550),
  _product('Rice', 2550),
  _product('Tomatoes', 500, vendor: 'Yummy Bunch'),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StockTracker.seed();
    connectivityStore.setSimulatedOffline(false);
  });

  tearDown(() => connectivityStore.setSimulatedOffline(false));

  Widget homeHarness() => ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: const MaterialApp(home: HomeScreen()),
      );

  testWidgets('the feed shows skeletons at the card height, then the cards',
      (tester) async {
    await tester.pumpWidget(homeHarness());
    await tester.pump();

    // First frame: placeholders, inside one shared shimmer.
    expect(find.byType(VendorCardSkeleton), findsWidgets);
    expect(find.byType(VendorCard), findsNothing);
    expect(find.byType(Shimmer), findsOneWidget);

    // Past the simulated latency: the real feed, same layout.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(VendorCardSkeleton), findsNothing);
    expect(find.byType(VendorCard), findsNWidgets(7));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed feed load explains itself and retries', (tester) async {
    MockBackend.failNextRequest();
    await tester.pumpWidget(homeHarness());
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load vendors"), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);

    // One failure was armed, so the retry succeeds once its latency passes.
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load vendors"), findsNothing);
    expect(find.byType(VendorCard), findsNWidgets(7));
  });

  testWidgets('the offline banner appears above content, then confirms recovery',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OfflineBannerHost(child: Scaffold(body: Text('content'))),
      ),
    );
    expect(find.text("You're offline. Some things may not work."), findsNothing);

    connectivityStore.setSimulatedOffline(true);
    await tester.pump();
    expect(
      find.text("You're offline. Some things may not work."),
      findsOneWidget,
    );
    // The screen is still laid out below the bar, not hidden behind it.
    expect(find.text('content'), findsOneWidget);

    connectivityStore.setSimulatedOffline(false);
    await tester.pump();
    expect(find.text('Back online'), findsOneWidget);

    // Two seconds later the confirmation is gone again.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Back online'), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('a platform with no connectivity plugin stays online', (
    tester,
  ) async {
    // The native signal asks connectivity_plus, and a widget test has no
    // platform channel for it — the same shape as a host that cannot answer.
    // Starting the store must leave the app online, not throw.
    connectivityStore.start();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(connectivityStore.isOnline, isTrue);
    expect(connectivityStore.simulatedOffline, isFalse);
  });

  testWidgets('checkout disables Place order offline and keeps the box',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);

    final store = AddressesStore(LocalAddressRepository(account: () => 'test'));
    await store.load();
    await store.save(_address);

    final cart = CartNotifier()..addAll(_products);
    connectivityStore.setSimulatedOffline(true);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: cart,
        child: MaterialApp(
          home: CheckoutScreen(products: cart.items, addressStore: store),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The price is gone from the label while the order cannot be sent.
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.textContaining('Place order'), findsNothing);

    await tester.tap(find.text("You're offline"), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(cart.items, hasLength(3), reason: 'nothing was submitted');

    // Back online: the real CTA returns, exactly as before.
    connectivityStore.setSimulatedOffline(false);
    await tester.pump();
    expect(find.text('Place order · ₦6,100'), findsOneWidget);
  });

  testWidgets('demo tools drive the shared connectivity store', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: ThemeProvider(
          notifier: ThemeNotifier(),
          child: const MaterialApp(home: ProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The section sits at the bottom of Profile.
    await tester.scrollUntilVisible(find.text('Demo tools'), 300);
    await tester.pumpAndSettle();

    // Debug builds carry the section; release builds omit it entirely.
    expect(find.text('Demo tools'), findsOneWidget);
    expect(find.text('Simulate offline'), findsOneWidget);
    expect(find.text('Fail next load'), findsOneWidget);

    await tester.scrollUntilVisible(find.byType(Switch), 100);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(connectivityStore.simulatedOffline, isTrue);
    expect(connectivityStore.isOnline, isFalse);
  });
}
