import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/orders.dart';
import 'package:growbox/routes.dart';
import 'package:growbox/screens/home_screen.dart';
import 'package:growbox/screens/order_details_screen.dart';
import 'package:growbox/screens/order_history_screen.dart';

/// Deterministic in-memory repository, so the screen tests never depend on the
/// mock catalog or on shared_preferences.
class _FakeOrdersRepository implements OrdersRepository {
  _FakeOrdersRepository(this._orders);

  final List<Order> _orders;

  @override
  Future<List<Order>> getOrders() async => List<Order>.of(_orders);

  @override
  Future<void> advanceStatus(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return;
    final next = _orders[index].status.nextActive;
    if (next == null) return;
    _orders[index] = _orders[index].copyWith(status: next);
  }
}

OrderItem _line(String name, int price, {int qty = 1}) => OrderItem(
      name: name,
      vendorName: 'Green Farm',
      category: 'GRAINS',
      image: 'assets/images/rice.jpg',
      price: price,
      quantity: qty,
    );

Order _order({
  required String id,
  required OrderStatus status,
  String vendor = 'Green Farm',
  List<OrderItem>? items,
  int deliveryFee = 500,
  Duration age = const Duration(hours: 1),
  Map<OrderStatus, DateTime> timestamps = const {},
}) =>
    Order(
      id: id,
      vendorName: vendor,
      status: status,
      createdAt: DateTime(2026, 10, 24, 12).subtract(age),
      items: items ?? [_line('Rice', 2550, qty: 2)],
      deliveryAddress: 'Gwarinpa, Abuja',
      deliveryFee: deliveryFee,
      timestamps: timestamps,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget harness({
    required OrdersStore store,
    CartNotifier? cart,
    Map<String, WidgetBuilder>? routes,
  }) {
    return ChangeNotifierProvider(
      create: (_) => cart ?? CartNotifier(),
      child: MaterialApp(
        home: OrderHistoryScreen(store: store),
        routes: routes ?? const {},
      ),
    );
  }

  testWidgets('Active shows in-flight orders, Past shows the finished ones',
      (tester) async {
    final repo = _FakeOrdersRepository([
      _order(id: 'GBX-1', status: OrderStatus.confirmed, age: const Duration(minutes: 5)),
      _order(
        id: 'GBX-2',
        status: OrderStatus.delivered,
        vendor: 'Yummy Bunch',
        items: [_line('Tomatoes', 1200)],
        age: const Duration(days: 3),
      ),
      _order(
        id: 'GBX-3',
        status: OrderStatus.cancelled,
        vendor: 'Real Green',
        items: [_line('Spinach', 800)],
        age: const Duration(days: 9),
      ),
    ]);

    await tester.pumpWidget(harness(store: OrdersStore(repo)));
    await tester.pumpAndSettle();

    // Active: vendor, item count, total, status chip, progress track.
    expect(find.text('Green Farm'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('₦5,600'), findsOneWidget); // 2 × 2,550 + 500
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.byKey(const ValueKey('orderProgress')), findsOneWidget);
    expect(find.text('Reorder'), findsNothing);
    expect(find.text('Yummy Bunch'), findsNothing);

    // Past: delivered + cancelled, reorder, no progress track.
    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();

    expect(find.text('Yummy Bunch'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Real Green'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Reorder'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('orderProgress')), findsNothing);
    expect(find.text('Green Farm'), findsNothing);
  });

  testWidgets('empty Active tab offers a way to shop', (tester) async {
    final repo = _FakeOrdersRepository([
      _order(id: 'GBX-9', status: OrderStatus.delivered),
    ]);

    await tester.pumpWidget(harness(
      store: OrdersStore(repo),
      routes: {AppRoutes.home: (_) => const Scaffold(body: Text('Home stub'))},
    ));
    await tester.pumpAndSettle();

    expect(find.text('No active orders'), findsOneWidget);
    expect(find.text('Start shopping'), findsOneWidget);

    await tester.tap(find.text('Start shopping'));
    await tester.pumpAndSettle();
    expect(find.text('Home stub'), findsOneWidget);
  });

  testWidgets('Reorder adds the order items back to the cart', (tester) async {
    final cart = CartNotifier();
    final repo = _FakeOrdersRepository([
      _order(
        id: 'GBX-4',
        status: OrderStatus.delivered,
        items: [_line('Rice', 2550, qty: 3)],
      ),
    ]);

    await tester.pumpWidget(harness(store: OrdersStore(repo), cart: cart));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reorder'));
    await tester.pump();

    expect(cart.length, 3);
    expect(cart.items.every((p) => p.name == 'Rice'), isTrue);
  });

  testWidgets('debug advance button moves an order to the next status',
      (tester) async {
    final repo = _FakeOrdersRepository([
      _order(id: 'GBX-5', status: OrderStatus.confirmed),
    ]);
    final store = OrdersStore(repo);

    await tester.pumpWidget(harness(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Advance status'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);

    await tester.tap(find.text('Advance status'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmed'), findsNothing);
    expect(find.text('Packing'), findsOneWidget);

    // The rider collecting the box is a step of its own now.
    await tester.tap(find.text('Advance status'));
    await tester.pumpAndSettle();
    expect(find.text('Picked up'), findsOneWidget);

    await tester.tap(find.text('Advance status'));
    await tester.pumpAndSettle();
    expect(find.text('On the way'), findsOneWidget);
  });

  testWidgets('order card survives a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakeOrdersRepository([
      _order(
        id: 'GBX-11',
        status: OrderStatus.onTheWay,
        items: [
          _line('Rice', 2550, qty: 12),
          _line('Beans', 3200, qty: 8),
        ],
      ),
    ]);

    await tester.pumpWidget(harness(store: OrdersStore(repo)));
    await tester.pumpAndSettle();

    // An overflow would have thrown during the pump.
    expect(find.text('20 items'), findsOneWidget);
    expect(find.text('₦56,700'), findsOneWidget);
  });

  // ── Order details ───────────────────────────────────────────────────────

  Widget detailsHarness(Order order, {OrdersStore? store}) =>
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: MaterialApp(
          home: OrderDetailsScreen(order: order, store: store),
        ),
      );

  testWidgets('details are driven by the order and show its timeline',
      (tester) async {
    final placed = DateTime(2026, 10, 24, 11);
    final order = _order(
      id: 'GBX-12',
      status: OrderStatus.onTheWay,
      timestamps: {
        OrderStatus.confirmed: placed,
        OrderStatus.packing: placed.add(const Duration(minutes: 5)),
        OrderStatus.onTheWay: placed.add(const Duration(minutes: 12)),
      },
    );

    await tester.pumpWidget(detailsHarness(order));
    await tester.pumpAndSettle();

    // Identity, vendor and item count all come from the order itself.
    expect(find.text('#GBX-12'), findsOneWidget);
    expect(find.text('Green Farm · 2 items'), findsOneWidget);
    expect(find.text('Placed Oct 24, 2026 at 11:00 AM'), findsOneWidget);
    expect(find.byKey(const ValueKey('orderTimeline')), findsOneWidget);

    // Reached steps carry their time, the current one says in progress and the
    // untouched one stays pending.
    expect(find.text('11:00 AM'), findsOneWidget);
    expect(find.text('11:05 AM'), findsOneWidget);
    expect(find.text('In progress · 11:12 AM'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);

    // Totals are derived: 2 × 2,550 subtotal (+ 500 delivery).
    expect(find.text('₦5,100'), findsNWidgets(2));
    expect(find.text('₦5,600'), findsOneWidget);

    expect(find.text('Track Delivery'), findsOneWidget);
    expect(find.text('Reorder All Items'), findsNothing);
  });

  testWidgets('timeline follows status changes from the store', (tester) async {
    final repo = _FakeOrdersRepository([
      _order(id: 'GBX-13', status: OrderStatus.confirmed),
    ]);
    final store = OrdersStore(repo);
    await store.load();

    await tester.pumpWidget(
      detailsHarness(store.orders.single, store: store),
    );
    await tester.pumpAndSettle();

    // Chip + timeline label for the current status.
    expect(find.text('Confirmed'), findsNWidgets(2));
    expect(find.text('Packing'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);

    await store.advanceStatus('GBX-13');
    await tester.pumpAndSettle();

    // The open screen re-renders from the store rather than its snapshot.
    expect(find.text('Confirmed'), findsOneWidget); // timeline only
    expect(find.text('Packing'), findsNWidgets(2));
    expect(find.text('In progress'), findsOneWidget);
  });

  testWidgets('a cancelled order ends its timeline and offers a reorder',
      (tester) async {
    await tester.pumpWidget(detailsHarness(
      _order(id: 'GBX-14', status: OrderStatus.cancelled),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('orderTimeline')), findsOneWidget);
    expect(find.text('Cancelled'), findsNWidgets(2)); // chip + timeline row
    expect(find.text('Pending'), findsNWidgets(4)); // steps never reached
    expect(find.text('Reorder All Items'), findsOneWidget);
    expect(find.text('Track Delivery'), findsNothing);
    expect(find.text('Payment refunded'), findsOneWidget);
  });

  testWidgets('free delivery reads as Free in the summary', (tester) async {
    await tester.pumpWidget(detailsHarness(
      _order(id: 'GBX-15', status: OrderStatus.delivered, deliveryFee: 0),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Reorder All Items'), findsOneWidget);
  });

  testWidgets('Track Delivery hands the real order to the tracking screen',
      (tester) async {
    final placed = DateTime(2026, 10, 24, 11);
    final order = _order(
      id: 'GBX-17',
      status: OrderStatus.onTheWay,
      timestamps: {
        OrderStatus.confirmed: placed,
        OrderStatus.packing: placed.add(const Duration(minutes: 5)),
        OrderStatus.onTheWay: placed.add(const Duration(minutes: 12)),
      },
    );

    await tester.pumpWidget(detailsHarness(order));
    await tester.pumpAndSettle();

    // The button sits at the bottom of the scrollable details page.
    await tester.ensureVisible(find.text('Track Delivery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Track Delivery'));
    // The tracking screen pulses forever, so no pumpAndSettle here.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // Identity, stage and step times all come from the order, not the demo.
    expect(find.text('#GBX-17'), findsOneWidget);
    expect(find.text('11:00 AM'), findsOneWidget);
    expect(find.text('11:05 AM'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(3));
  });

  testWidgets('tapping an order opens the details timeline', (tester) async {
    final repo = _FakeOrdersRepository([
      _order(id: 'GBX-16', status: OrderStatus.onTheWay),
    ]);

    await tester.pumpWidget(harness(store: OrdersStore(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Green Farm'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('orderTimeline')), findsOneWidget);
    expect(find.text('Track Delivery'), findsOneWidget);
  });

  // ── Home banner ─────────────────────────────────────────────────────────

  Widget homeHarness(OrdersStore store) => ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: MaterialApp(
          home: HomeScreen(store: store),
          routes: {
            AppRoutes.home: (_) => const Scaffold(body: Text('Home stub')),
          },
        ),
      );

  testWidgets('home shows a status banner for the newest active order',
      (tester) async {
    final repo = _FakeOrdersRepository([
      _order(id: 'GBX-6', status: OrderStatus.onTheWay, age: const Duration(minutes: 10)),
      _order(
        id: 'GBX-7',
        status: OrderStatus.packing,
        age: const Duration(minutes: 40),
      ),
    ]);

    await tester.pumpWidget(homeHarness(OrdersStore(repo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The banner names the vendor so a multi-vendor feed is unambiguous.
    expect(find.text('Your order from Green Farm is on the way'), findsOneWidget);

    await tester.tap(find.text('Your order from Green Farm is on the way'));
    await tester.pumpAndSettle();

    // Lands on the orders screen, Active tab.
    expect(find.byType(OrderHistoryScreen), findsOneWidget);
    expect(find.text('Confirmed'), findsNothing);
    expect(find.text('Packing'), findsOneWidget);
    expect(find.text('On the way'), findsOneWidget);
  });

  testWidgets('home hides the banner when nothing is active', (tester) async {
    final repo = _FakeOrdersRepository([
      _order(id: 'GBX-8', status: OrderStatus.delivered),
      _order(id: 'GBX-10', status: OrderStatus.cancelled),
    ]);

    await tester.pumpWidget(homeHarness(OrdersStore(repo)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Your order is'), findsNothing);
    expect(find.textContaining('Order confirmed'), findsNothing);
  });
}
