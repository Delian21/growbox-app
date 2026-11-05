import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/addresses.dart';
import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/data/payment_method.dart';
import 'package:growbox/routes.dart';
import 'package:growbox/screens/checkout_screen.dart';
import 'package:growbox/screens/order_result_screens.dart';
import 'package:growbox/widgets/saved_address_picker.dart';

VendorProduct _product(String name, int price, {String vendor = 'Green Farm'}) =>
    VendorProduct(
      image: '',
      name: name,
      description: name,
      price: price,
      category: 'GRAINS',
      vendorName: vendor,
    );

final _products = [_product('Rice', 2550)];

const _address = Address(
  id: 'a1',
  label: 'Home',
  street: 'No. 12 Gwarinpa Estate',
  area: 'Gwarinpa, Abuja',
);

/// A submit that records like the real one, so a test can inspect the draft.
Future<StoredOrder> _record(CheckoutDraft draft) async => recordOrder(
  orderNumber: draft.orderNumber,
  cartItems: draft.products,
  deliveryFee: draft.deliveryFee,
  deliveryAddress: draft.deliveryAddress,
  riderNote: draft.riderNote,
  paymentMethod: draft.paymentMethod,
);

Widget _harness({
  required AddressesStore store,
  required CartNotifier cart,
  Future<StoredOrder> Function(CheckoutDraft draft)? placeOrder,
}) {
  return ChangeNotifierProvider<CartNotifier>.value(
    value: cart,
    child: MaterialApp(
      home: CheckoutScreen(
        products: cart.items,
        addressStore: store,
        placeOrder: placeOrder ?? _record,
      ),
      routes: {AppRoutes.home: (_) => const Scaffold(body: Text('Home stub'))},
    ),
  );
}

Future<CartNotifier> _pump(
  WidgetTester tester, {
  Future<StoredOrder> Function(CheckoutDraft draft)? placeOrder,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 1000);
  addTearDown(tester.view.reset);

  final store = AddressesStore(LocalAddressRepository(account: () => 'test'));
  await store.load();
  await store.save(_address);

  final cart = CartNotifier()..addAll(_products);
  await tester.pumpWidget(
    _harness(store: store, cart: cart, placeOrder: placeOrder),
  );
  await tester.pumpAndSettle();
  return cart;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storedOrders.clear();
  });

  testWidgets('the address card is one tap target with no chevron', (
    tester,
  ) async {
    await _pump(tester);

    // The duplicated affordance is gone; "Change" stays.
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('Change'), findsOneWidget);

    // The card itself still opens the picker.
    await tester.tap(find.text('No. 12 Gwarinpa Estate, Gwarinpa, Abuja'));
    await tester.pumpAndSettle();
    expect(find.byType(SavedAddressPicker), findsOneWidget);
  });

  testWidgets('the note and the chosen method are saved on the order', (
    tester,
  ) async {
    final drafts = <CheckoutDraft>[];
    await _pump(
      tester,
      placeOrder: (draft) {
        drafts.add(draft);
        return _record(draft);
      },
    );

    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '  Ring the bell  ');
    await tester.pump();

    await tester.tap(find.textContaining('Place order'));
    await tester.pumpAndSettle();

    // Trimmed, and stored on the order rather than only on the screen.
    expect(drafts.single.riderNote, 'Ring the bell');
    expect(storedOrders.single.riderNote, 'Ring the bell');

    // The default method is recorded and shown in the confirmation summary.
    expect(storedOrders.single.paymentMethod, PaymentMethod.payOnDelivery);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Pay on delivery'), findsOneWidget);
  });

  testWidgets('an empty note is stored as null, not as blank text', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.textContaining('Place order'));
    await tester.pumpAndSettle();

    expect(storedOrders.single.riderNote, isNull);
  });

  testWidgets('only pay on delivery can be chosen', (tester) async {
    final drafts = <CheckoutDraft>[];
    await _pump(
      tester,
      placeOrder: (draft) {
        drafts.add(draft);
        return _record(draft);
      },
    );

    await tester.ensureVisible(find.text('Card'));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsNWidgets(2));

    // The two listed-but-unwired methods refuse the tap.
    await tester.tap(find.text('Card'));
    await tester.tap(find.text('Bank transfer'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Place order'));
    await tester.pumpAndSettle();

    expect(drafts.single.paymentMethod, PaymentMethod.payOnDelivery);
    expect(storedOrders.single.paymentMethod, PaymentMethod.payOnDelivery);
  });

  testWidgets('a tap disables the button and only one request is sent', (
    tester,
  ) async {
    final completer = Completer<StoredOrder>();
    var calls = 0;

    await _pump(
      tester,
      placeOrder: (draft) {
        calls++;
        completer.complete(recordOrder(
          orderNumber: draft.orderNumber,
          cartItems: draft.products,
          deliveryFee: draft.deliveryFee,
          deliveryAddress: draft.deliveryAddress,
          riderNote: draft.riderNote,
          paymentMethod: draft.paymentMethod,
        ));
        return completer.future;
      },
    );

    await tester.tap(find.textContaining('Place order'));
    await tester.pump();

    // The label is replaced by a spinner inside the same button.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Place order'), findsNothing);

    // A second tap while it is in flight does nothing.
    await tester.tap(find.byType(GestureDetector).last, warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);

    await tester.pumpAndSettle();
    expect(find.text('Order placed!'), findsOneWidget);
    expect(storedOrders, hasLength(1));
  });

  testWidgets('a failure lands on Order Failed and keeps everything', (
    tester,
  ) async {
    final drafts = <CheckoutDraft>[];
    var failNext = true;

    final cart = await _pump(
      tester,
      placeOrder: (draft) {
        drafts.add(draft);
        if (failNext) throw Exception('network is down');
        return _record(draft);
      },
    );

    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Leave at the gate');
    await tester.pump();

    await tester.tap(find.textContaining('Place order'));
    await tester.pumpAndSettle();

    // Same id as the attempt that failed, and nothing was recorded.
    expect(find.byType(OrderFailedScreen), findsOneWidget);
    expect(find.text('#${drafts.single.orderNumber}'), findsOneWidget);
    expect(storedOrders, isEmpty);
    expect(cart.isEmpty, isFalse, reason: 'a failure never clears the cart');

    failNext = false;

    // "Try again" returns to this very checkout, selections intact.
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(cart.items, hasLength(1));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Leave at the gate',
    );

    await tester.tap(find.textContaining('Place order'));
    await tester.pumpAndSettle();

    // The retry reused the id instead of minting a second one.
    expect(drafts, hasLength(2));
    expect(drafts[0].orderNumber, drafts[1].orderNumber);
    expect(storedOrders, hasLength(1));
    expect(storedOrders.single.riderNote, 'Leave at the gate');
  });

  testWidgets('an empty cart cannot place an order', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);

    final store = AddressesStore(LocalAddressRepository(account: () => 'test'));
    await store.load();
    await store.save(_address);

    final cart = CartNotifier();
    var calls = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<CartNotifier>.value(
        value: cart,
        child: MaterialApp(
          home: CheckoutScreen(
            products: const [],
            addressStore: store,
            placeOrder: (draft) async {
              calls++;
              return _record(draft);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Place order'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(storedOrders, isEmpty);
    expect(find.byType(CheckoutScreen), findsOneWidget);
  });
}
