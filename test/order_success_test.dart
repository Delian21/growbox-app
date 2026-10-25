import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/data/orders.dart';
import 'package:growbox/routes.dart';
import 'package:growbox/screens/checkout_screen.dart';
import 'package:growbox/screens/delivery_tracking_screen.dart';
import 'package:growbox/screens/order_success_screen.dart';
import 'package:growbox/theme.dart';

/// WCAG 2.1 relative-luminance contrast ratio.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

VendorProduct _product(String name, int price, {String vendor = 'Green Farm'}) =>
    VendorProduct(
      image: '',
      name: name,
      description: name,
      price: price,
      category: 'GRAINS',
      vendorName: vendor,
    );

/// Two lines from one vendor: subtotal 6,300, delivery 500, total 6,800.
Order _order({
  String vendor = 'Green Farm',
  String address = 'No. 12 Gwarinpa Estate, Gwarinpa, Abuja, Nigeria',
}) =>
    Order(
      id: 'GBX-10482',
      vendorName: vendor,
      status: OrderStatus.confirmed,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      items: [
        OrderItem(
          name: 'Rice',
          vendorName: 'Green Farm',
          category: 'GRAINS',
          image: '',
          price: 2550,
          quantity: 2,
        ),
        OrderItem(
          name: 'Beans',
          vendorName: 'Green Farm',
          category: 'LEGUMES',
          image: '',
          price: 1200,
          quantity: 1,
        ),
      ],
      deliveryAddress: address,
      deliveryFee: 500,
    );

Widget harness(Order order, {bool disableAnimations = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: OrderSuccessScreen(order: order),
      ),
      routes: {
        AppRoutes.home: (_) => const Scaffold(body: Text('Home stub')),
      },
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StockTracker.seed();
    storedOrders.clear();
  });

  testWidgets('every line comes from the order', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);

    final order = _order();
    await tester.pumpWidget(harness(order));
    await tester.pumpAndSettle();

    // Headline and vendor-aware body copy.
    expect(find.text('Order placed!'), findsOneWidget);
    expect(
      find.text('Green Farm has your order and will start packing it shortly.'),
      findsOneWidget,
    );

    // One order number, the shared "#GBX-…" format.
    expect(find.text('#GBX-10482'), findsOneWidget);

    // Summary: vendor, item count, subtotal, delivery, bold total.
    expect(find.text('Green Farm'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('₦6,300'), findsOneWidget);
    expect(find.text('₦500'), findsOneWidget);
    expect(find.text('₦6,800'), findsOneWidget);

    // Arrival is derived, not the old hardcoded "2:00 PM – 4:00 PM".
    expect(find.textContaining(' · by '), findsOneWidget);
    expect(find.textContaining('2:00 PM'), findsNothing);

    // Country dropped from the address.
    expect(find.textContaining('Nigeria'), findsNothing);

    // Both pinned actions, and the old Box History button is gone.
    expect(find.text('Track delivery'), findsOneWidget);
    expect(find.text('Continue shopping'), findsOneWidget);
    expect(find.textContaining('Box History'), findsNothing);
  });

  testWidgets('falls back to the neutral copy without a vendor',
      (tester) async {
    await tester.pumpWidget(harness(_order(vendor: '')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Thank you for your order. We've received it and will begin processing it shortly.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping the order number copies it and confirms', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(harness(_order()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('#GBX-10482'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final copy = calls.where((c) => c.method == 'Clipboard.setData');
    expect(copy, isNotEmpty);
    expect((copy.first.arguments as Map)['text'], '#GBX-10482');
    expect(find.text('Order number copied'), findsOneWidget);
  });

  testWidgets('badge scale-in is skipped when animations are disabled',
      (tester) async {
    await tester.pumpWidget(harness(_order(), disableAnimations: true));
    await tester.pump();

    final badge = tester.widget<ScaleTransition>(
      find.byKey(const ValueKey('successBadge')),
    );
    expect(badge.scale.value, 1.0);
  });

  testWidgets('Continue shopping replaces the stack with Home', (tester) async {
    await tester.pumpWidget(harness(_order()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue shopping'));
    await tester.pumpAndSettle();

    expect(find.text('Home stub'), findsOneWidget);
    expect(find.text('Order placed!'), findsNothing);
  });

  testWidgets('system back goes Home instead of leaving the app',
      (tester) async {
    await tester.pumpWidget(harness(_order()));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Home stub'), findsOneWidget);
  });

  testWidgets('Track delivery opens tracking for the same order',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);

    final order = _order();
    await tester.pumpWidget(harness(order));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Track delivery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Same number and the same arrival promise as the confirmation. The
    // confirmation is still mounted underneath, so look inside the pushed
    // screen rather than counting matches.
    final tracking = find.byType(DeliveryTrackingScreen);
    expect(tracking, findsOneWidget);
    expect(
      find.descendant(of: tracking, matching: find.text('#GBX-10482')),
      findsWidgets,
    );
    // The tracking screen quotes the ETA twice (countdown card + details row).
    expect(
      find.descendant(of: tracking, matching: find.text(formatArrival(order.eta))),
      findsWidgets,
    );
  });

  testWidgets('placing an order clears the cart and records it',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);

    final cart = CartNotifier()..addAll([_product('Rice', 2550)]);
    expect(cart.isNotEmpty, isTrue);

    await tester.pumpWidget(
      ChangeNotifierProvider<CartNotifier>.value(
        value: cart,
        child: MaterialApp(
          home: CheckoutScreen(products: cart.items),
          routes: {
            AppRoutes.home: (_) => const Scaffold(body: Text('Home stub')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Place Order'));
    await tester.pumpAndSettle();

    expect(find.text('Order placed!'), findsOneWidget);
    expect(cart.isEmpty, isTrue, reason: 'the box was bought');
    expect(storedOrders.single.orderNumber, startsWith('GBX-'));
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('reads in the ${brightness.name} theme', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 1000);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, brightness: brightness),
          home: OrderSuccessScreen(order: _order()),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OrderSuccessScreen));
      final page = C.background(context);
      final card = C.surface(context);

      void expectReadable(Finder text, Color on, String what) {
        final color = tester.widget<Text>(text).style!.color!;
        expect(contrastRatio(color, on), greaterThanOrEqualTo(4.5),
            reason: '"$what" must be readable in ${brightness.name}');
      }

      expectReadable(find.text('Order placed!'), page, 'headline');
      expectReadable(
        find.text('Green Farm has your order and will start packing it shortly.'),
        page,
        'body copy',
      );
      expectReadable(find.text('#GBX-10482'), card, 'order number');
      expectReadable(find.text('Order number'), card, 'card label');
      expectReadable(find.text('Green Farm'), card, 'vendor');
      expectReadable(find.text('Subtotal'), card, 'summary label');
      expectReadable(find.text('Total'), card, 'total label');
      expectReadable(find.text('₦6,800'), card, 'total value');
      expectReadable(find.textContaining(' · by '), card, 'arrival');
    });
  }

  testWidgets('lays out on a small phone without overflowing', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(_order()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The bar is pinned below a scrolling body, so both actions stay reachable.
    expect(find.text('Track delivery'), findsOneWidget);
    expect(find.text('Continue shopping'), findsOneWidget);
  });

  test('orderNumberLabel writes one format', () {
    expect(orderNumberLabel('GBX-10482'), '#GBX-10482');
    expect(orderNumberLabel('#GBX-10482'), '#GBX-10482');
  });

  test('formatArrival reads as a wait and a clock time', () {
    final now = DateTime(2026, 10, 25, 16, 35);
    expect(
      formatArrival(DateTime(2026, 10, 25, 17, 5), now: now),
      'About 30 min · by 5:05 PM',
    );
    // A passed ETA never claims a negative wait.
    expect(
      formatArrival(DateTime(2026, 10, 25, 16, 20), now: now),
      'Any minute now · by 4:20 PM',
    );
  });
}
