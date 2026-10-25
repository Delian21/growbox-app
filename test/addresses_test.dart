import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/addresses.dart';
import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/data/orders.dart';
import 'package:growbox/screens/checkout_screen.dart';
import 'package:growbox/screens/home_screen.dart';

class _NoOrders implements OrdersRepository {
  @override
  Future<List<Order>> getOrders() async => const [];

  @override
  Future<void> advanceStatus(String orderId) async {}
}

/// A store over device storage, as the app wires it up in `main()`.
AddressesStore newStore([String? Function()? account]) =>
    AddressesStore(LocalAddressRepository(account: account));

const _home = Address(
  id: 'a1',
  label: 'Home',
  street: 'No. 12 Gwarinpa Estate',
  area: 'Gwarinpa, Abuja',
);

const _office = Address(
  id: 'a2',
  label: 'Office',
  street: 'Plot 5 Ahmadu Bello Way',
  area: 'Garki, Abuja',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CustomerData.clear();
  });

  group('Address rejections of a fake default', () {
    test('a brand-new account has no addresses and no selection', () async {
      CustomerData.email = 'new@growbox.com';
      final store = newStore();
      await store.load();

      expect(store.addresses, isEmpty);
      expect(store.selectedAddress, isNull);
      expect(store.selectionNeedsStreet, isFalse);
    });

    test('an address with only an area needs a street', () {
      const areaOnly = Address(id: 'x', label: 'Home', area: 'Asokoro, Abuja');

      expect(areaOnly.isComplete, isFalse);
      // The full address still reads sensibly for display.
      expect(areaOnly.fullAddress, 'Asokoro, Abuja');
      expect(areaOnly.summary, 'Asokoro, Abuja');
    });
  });

  group('Selected address persistence', () {
    test('the address and its selection survive a reload', () async {
      CustomerData.email = 'ada@growbox.com';
      final store = newStore();
      await store.load();
      await store.save(_home);

      // The first saved address is selected, so checkout has something to use.
      expect(store.selectedAddress?.id, 'a1');

      // A fresh store over the same storage is what an app restart looks like.
      final reloaded = newStore();
      await reloaded.load();

      expect(reloaded.addresses.single.street, 'No. 12 Gwarinpa Estate');
      expect(reloaded.addresses.single.area, 'Gwarinpa, Abuja');
      expect(reloaded.selectedAddress?.id, 'a1');
    });

    test('a logout and the same login bring the selection back', () async {
      CustomerData.email = 'ada@growbox.com';
      final store = newStore();
      await store.load();
      await store.save(_home);
      await store.save(_office);
      await store.select('a2');

      // Log out: the account key disappears with the profile.
      CustomerData.clear();
      final signedOut = newStore();
      await signedOut.load();
      expect(signedOut.addresses, isEmpty,
          reason: 'the guest bucket is not the customer\'s');
      expect(signedOut.selectedAddress, isNull);

      // The same person signs in again.
      CustomerData.email = 'ada@growbox.com';
      final signedIn = newStore();
      await signedIn.load();

      expect(signedIn.addresses.length, 2);
      expect(signedIn.selectedAddress?.id, 'a2');
    });

    test('two accounts on one device never share addresses', () async {
      // Each repository reads the account it was created for, so the two
      // sessions below cannot see each other's bucket.
      final ada = newStore(() => 'ada@growbox.com');
      await ada.load();
      await ada.save(_home);

      final bola = newStore(() => 'bola@growbox.com');
      await bola.load();
      expect(bola.addresses, isEmpty);

      await bola.save(_office);
      expect(bola.selectedAddress?.id, 'a2');

      // Ada still sees only her own address and selection.
      final adaAgain = newStore(() => 'ada@growbox.com');
      await adaAgain.load();
      expect(adaAgain.addresses.single.id, 'a1');
      expect(adaAgain.selectedAddress?.id, 'a1');
    });
  });

  group('Deleting the selected address', () {
    test('falls back to another saved address, never to a placeholder',
        () async {
      CustomerData.email = 'ada@growbox.com';
      final store = newStore();
      await store.load();
      await store.save(_home);
      await store.save(_office);
      await store.select('a1');

      await store.delete('a1');

      expect(store.addresses.single.id, 'a2');
      expect(store.selectedAddress?.id, 'a2');

      // The fallback is persisted, not just held in memory.
      final reloaded = newStore();
      await reloaded.load();
      expect(reloaded.selectedAddress?.id, 'a2');
    });

    test('clears the selection when the last address goes', () async {
      CustomerData.email = 'ada@growbox.com';
      final store = newStore();
      await store.load();
      await store.save(_home);

      await store.delete('a1');

      expect(store.addresses, isEmpty);
      expect(store.selectedAddress, isNull);

      final reloaded = newStore();
      await reloaded.load();
      expect(reloaded.selectedAddress, isNull);
    });

    test('deleting a different address keeps the selection', () async {
      CustomerData.email = 'ada@growbox.com';
      final store = newStore();
      await store.load();
      await store.save(_home);
      await store.save(_office);
      await store.select('a1');

      await store.delete('a2');

      expect(store.selectedAddress?.id, 'a1');
    });
  });

  testWidgets('the home header names the area, or asks for a location',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    // Wide enough that the unrelated search bar does not wrap under test fonts.
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);

    CustomerData.email = 'ada@growbox.com';
    await addressesStore.load(force: true);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: MaterialApp(
          home: HomeScreen(store: OrdersStore(_NoOrders())),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Choose location'), findsOneWidget,
        reason: 'no fake default address');

    await addressesStore.save(_home);
    await tester.pump();

    // The header names the selected address's area, not its street.
    expect(find.text('Gwarinpa, Abuja'), findsOneWidget);
    expect(find.text('Choose location'), findsNothing);

    // Let the feed's entrance animations finish so no timer outlives the test.
    await tester.pump(const Duration(seconds: 1));
  });

  group('Checkout', () {
    VendorProduct product() => const VendorProduct(
          image: '',
          name: 'Rice',
          description: 'Rice',
          price: 2550,
          category: 'GRAINS',
          vendorName: 'Green Farm',
        );

    Future<void> pumpCheckout(
      WidgetTester tester,
      AddressesStore store,
      List<VendorProduct> products,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 1000);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<CartNotifier>(
          create: (_) => CartNotifier()..addAll(products),
          child: MaterialApp(
            home: CheckoutScreen(products: products, addressStore: store),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks for a street and refuses to order without one',
        (tester) async {
      CustomerData.email = 'ada@growbox.com';
      final store = newStore();
      await store.load();
      await store.save(
        const Address(id: 'a1', label: 'Home', area: 'Gwarinpa, Abuja'),
      );

      final products = [product()];
      await pumpCheckout(tester, store, products);

      expect(
        find.text('Add your street address so the rider can find you'),
        findsOneWidget,
      );
      expect(find.text('Add details'), findsOneWidget);

      await tester.tap(find.textContaining('Place Order'));
      await tester.pumpAndSettle();

      expect(find.text('Order placed!'), findsNothing,
          reason: 'an address with no street cannot be delivered to');
    });

    testWidgets('snapshots the selected address on the placed order',
        (tester) async {
      CustomerData.email = 'ada@growbox.com';
      final store = newStore();
      await store.load();
      await store.save(_home);

      final products = [product()];
      await pumpCheckout(tester, store, products);

      expect(find.textContaining('Add your street address'), findsNothing);

      await tester.tap(find.textContaining('Place Order'));
      await tester.pumpAndSettle();

      expect(find.text('Order placed!'), findsOneWidget);
      // The order keeps the address as it was when it was placed, not a
      // pointer at the saved address.
      expect(storedOrders.first.deliveryAddress,
          'No. 12 Gwarinpa Estate, Gwarinpa, Abuja');
    });
  });
}
