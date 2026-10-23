import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/orders.dart';
import 'package:growbox/routes.dart';
import 'package:growbox/screens/home_screen.dart';
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
}) =>
    Order(
      id: id,
      vendorName: vendor,
      status: status,
      createdAt: DateTime(2026, 10, 24, 12).subtract(age),
      items: items ?? [_line('Rice', 2550, qty: 2)],
      deliveryAddress: 'Gwarinpa, Abuja',
      deliveryFee: deliveryFee,
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

    // Past its last step the button stops moving it and the order stays put.
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

    expect(find.text('Your order is on the way'), findsOneWidget);

    await tester.tap(find.text('Your order is on the way'));
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
