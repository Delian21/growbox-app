import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/screens/cart_screen.dart';
import 'package:growbox/screens/checkout_screen.dart';
import 'package:growbox/theme.dart';
import 'package:growbox/widgets/pinned_bottom_bar.dart';

VendorProduct _product(
  String name,
  int price, {
  String vendor = 'Green Farm',
  String? unit,
}) =>
    VendorProduct(
      image: '',
      name: name,
      description: name,
      price: price,
      category: 'GRAINS',
      vendorName: vendor,
      unit: unit,
    );

CartNotifier _cartWith(List<VendorProduct> products) {
  final cart = CartNotifier();
  for (final product in products) {
    cart.add(product);
  }
  return cart;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StockTracker.seed();
  });

  Future<void> pumpCart(WidgetTester tester, CartNotifier cart) async {
    // Tall enough that every row clears the pinned bar and stays tappable.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<CartNotifier>.value(
        value: cart,
        child: const MaterialApp(home: CartScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('minus and plus share one style and 44x44 taps; trash at 1',
      (tester) async {
    final cart = _cartWith([_product('Rice', 2550, unit: 'kg')]);
    await pumpCart(tester, cart);

    // At one unit the minus slot is the delete control; no separate X.
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);

    // Unit sits next to the price.
    expect(find.text('₦2,550 / kg'), findsOneWidget);

    final deleteBox = tester.getSize(find
        .ancestor(
          of: find.byIcon(Icons.delete_outline),
          matching: find.byType(Container),
        )
        .first);
    final addBox = tester.getSize(find
        .ancestor(
          of: find.byIcon(Icons.add),
          matching: find.byType(Container),
        )
        .first);
    expect(deleteBox, const Size(44, 44));
    expect(addBox, const Size(44, 44));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Two units: the minus returns and the line total appears.
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('2 x ₦2,550 = ₦5,100'), findsOneWidget);

    final minusBox = tester.getSize(find
        .ancestor(
          of: find.byIcon(Icons.remove),
          matching: find.byType(Container),
        )
        .first);
    expect(minusBox, const Size(44, 44));
  });

  testWidgets('a product without a unit shows just its price', (tester) async {
    final cart = _cartWith([_product('Rice', 2550)]);
    await pumpCart(tester, cart);

    // Item price + Subtotal, and nothing with a "/" unit suffix.
    expect(find.text('₦2,550'), findsNWidgets(2));
    expect(find.textContaining(' / '), findsNothing);
  });

  testWidgets('delete shows the shared snackbar and Undo restores the position',
      (tester) async {
    final cart = _cartWith([
      _product('Rice', 2550, unit: 'kg'),
      _product('Tomatoes', 500, vendor: 'Yummy Bunch', unit: 'basket'),
      _product('Beans', 1800, unit: 'kg'),
    ]);
    await pumpCart(tester, cart);

    final tomatoesRow = find.ancestor(
      of: find.text('Tomatoes'),
      matching: find.byType(Dismissible),
    );
    await tester.tap(find.descendant(
      of: tomatoesRow,
      matching: find.byIcon(Icons.delete_outline),
    ));
    // The snackbar is created after the dismissal animation; settle so it has
    // finished expanding before measuring or tapping its action.
    await tester.pumpAndSettle();

    expect(cart.items.map((p) => p.name), ['Rice', 'Beans']);
    expect(find.text('Tomatoes removed from cart'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // The snackbar's painted surface clears the checkout bar rather than
    // covering its total. (SnackBar's own box includes the transparent margin
    // that reserves room for the nav, so measure its Material.)
    final surface = tester.getRect(find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first);
    final bar = tester.getRect(find.byKey(PinnedBottomBar.surfaceKey));
    expect(surface.bottom, lessThanOrEqualTo(bar.top - 8 + 0.01));

    await tester.tap(find.text('Undo'));
    await tester.pump();

    // Back in the middle of the box, not appended.
    expect(cart.items.map((p) => p.name), ['Rice', 'Tomatoes', 'Beans']);
  });

  testWidgets('vendor meta and the bar summary include delivery fees',
      (tester) async {
    final cart = _cartWith([
      _product('Rice', 2550, unit: 'kg'),
      _product('Tomatoes', 500, vendor: 'Yummy Bunch', unit: 'basket'),
    ]);
    await pumpCart(tester, cart);

    // Vendor model: 500 fee for Green Farm, free for Yummy Bunch.
    expect(find.text('25-35 min · ₦500 delivery'), findsOneWidget);
    expect(find.text('30-40 min · Free delivery'), findsOneWidget);

    // 2,550 + 500 goods, 500 delivery, 3,550 payable.
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('₦3,050'), findsOneWidget);
    expect(find.text('₦500'), findsOneWidget);
    expect(find.text('₦3,550'), findsOneWidget);
  });

  testWidgets('checkout shows the same amounts as the cart bar',
      (tester) async {
    final products = [
      _product('Rice', 2550, unit: 'kg'),
      _product('Tomatoes', 500, vendor: 'Yummy Bunch', unit: 'basket'),
    ];
    final cart = _cartWith(products);
    await pumpCart(tester, cart);

    // Cart bar: 3,050 goods + 500 Green Farm delivery (Yummy Bunch is free).
    expect(find.text('₦3,050'), findsOneWidget);
    expect(find.text('₦3,550'), findsOneWidget);

    await tester.pumpWidget(
      ChangeNotifierProvider<CartNotifier>.value(
        value: cart,
        child: MaterialApp(home: CheckoutScreen(products: products)),
      ),
    );
    await tester.pump();

    // The order summary and the CTA report the same payable total.
    expect(find.text('₦3,050'), findsOneWidget);
    expect(find.text('₦3,550'), findsOneWidget);
    expect(find.text('Place order · ₦3,550'), findsOneWidget);
    // The old flat checkout fee is gone for good.
    expect(find.text('₦1,500'), findsNothing);
  });

  testWidgets('the checkout button is the primary fill with on-primary text',
      (tester) async {
    final cart = _cartWith([_product('Rice', 2550, unit: 'kg')]);
    await pumpCart(tester, cart);

    final context = tester.element(find.text('Checkout'));
    final label = tester.widget<Text>(find.text('Checkout'));
    final arrow = tester.widget<Icon>(find.byIcon(Icons.arrow_forward));
    final button = tester.widget<Container>(find
        .ancestor(of: find.text('Checkout'), matching: find.byType(Container))
        .first);

    expect((button.decoration as BoxDecoration).color, C.primary(context));
    expect(label.style!.color, C.onPrimary(context));
    expect(arrow.color, C.onPrimary(context));
  });
}
