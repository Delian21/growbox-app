import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/orders.dart';
import 'package:growbox/routes.dart';
import 'package:growbox/screens/order_history_screen.dart';

/// A backend with nothing in it: what a brand-new install looks like once no
/// delivery is in flight and none has finished yet.
class _EmptyRepository implements OrdersRepository {
  @override
  Future<List<Order>> getOrders() async => const [];

  @override
  Future<void> advanceStatus(String orderId) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storedOrders.clear();
  });

  test('demo orders cover packing, picked up and on the way', () async {
    final orders = await MockOrdersRepository().getOrders();
    final statuses = orders.map((o) => o.status).toSet();

    expect(statuses, contains(OrderStatus.packing));
    expect(statuses, contains(OrderStatus.pickedUp));
    expect(statuses, contains(OrderStatus.onTheWay));

    final pickedUp = orders.firstWhere((o) => o.status == OrderStatus.pickedUp);
    // The pickup has a real time of its own, and the step after it does not
    // exist yet.
    expect(pickedUp.timestamps[OrderStatus.pickedUp], isNotNull);
    expect(pickedUp.timestamps[OrderStatus.onTheWay], isNull);
  });

  test('each fresh demo order has reached its status and no further', () async {
    final store = OrdersStore(MockOrdersRepository());
    await store.load();

    // The home banner follows the newest active order, which is the packing one
    // — the other two are further along only because they are older.
    expect(store.latestActiveOrder?.status, OrderStatus.packing);

    for (final status in [
      OrderStatus.packing,
      OrderStatus.pickedUp,
      OrderStatus.onTheWay,
    ]) {
      final order = store.activeOrders.firstWhere((o) => o.status == status);
      expect(order.timestamps[status], isNotNull,
          reason: '${status.label} must be stamped');
      expect(order.timestamps[status.nextActive!], isNull,
          reason: 'a ${status.label} order must not have reached the next step');
    }
  });

  test('seeded history that is weeks old never shows as active', () async {
    await restoreOrders(); // seeds the four mock history records
    expect(storedOrders, isNotEmpty);

    final orders = await MockOrdersRepository().getOrders();
    final old = orders
        .where((o) => DateTime.now().difference(o.createdAt).inDays > 1)
        .toList();

    expect(old, isNotEmpty);
    expect(old.every((o) => !o.isActive), isTrue,
        reason: 'a month-old record cannot still be packing');

    // Specifically the old "Pending" record: retired as delivered, with the
    // timeline to match.
    final pending = old.firstWhere((o) => o.id == 'GBX-10475');
    expect(pending.status, OrderStatus.delivered);
    expect(pending.timestamps[OrderStatus.delivered], isNotNull);
  });

  test('a recent pending record is still an active packing order', () async {
    await restoreOrders();
    storedOrders.insert(
      0,
      StoredOrder(
        orderNumber: 'GBX-NEW',
        placedAt: DateTime.now().subtract(const Duration(minutes: 4)),
        status: 'Pending',
        deliveryAddress: 'Gwarinpa, Abuja',
        deliveryFee: 500,
        items: const [],
      ),
    );

    final orders = await MockOrdersRepository().getOrders();
    final fresh = orders.firstWhere((o) => o.id == 'GBX-NEW');

    // The retirement rule is about age, not the word "Pending".
    expect(fresh.status, OrderStatus.packing);
    expect(fresh.isActive, isTrue);
  });

  testWidgets('Picked up is visible in Active without the debug button',
      (tester) async {
    final store = OrdersStore(MockOrdersRepository());

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: MaterialApp(home: OrderHistoryScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Picked up'), findsOneWidget);

    // The state came from the data, not from tapping the debug action.
    final advance = find.text('Advance status');
    expect(advance, findsWidgets);
    expect(find.text('On the way'), findsOneWidget);
    expect(find.text('Packing'), findsOneWidget);
  });

  test('demo deliveries age instead of being re-stamped on every fetch',
      () async {
    var now = DateTime(2026, 10, 25, 12);
    final repo = MockOrdersRepository(clock: () => now);

    await repo.getOrders(); // places the demo deliveries
    final fresh = await repo.getOrders();
    expect(fresh.where((o) => o.isActive), hasLength(3));
    expect(fresh.firstWhere((o) => o.id == 'GBX-10521').status,
        OrderStatus.packing);

    // Ten minutes on, every delivery has moved a step along, and none of the
    // placement times have been rewritten.
    now = now.add(const Duration(minutes: 10));
    final later = await repo.getOrders();
    expect(
      later.map((o) => (o.id, o.createdAt)).toSet(),
      fresh.map((o) => (o.id, o.createdAt)).toSet(),
    );
    expect(
      later.where((o) => o.isActive).map((o) => o.status),
      everyElement(OrderStatus.onTheWay),
    );

    // Delivered at 30 minutes: Active empties on its own.
    now = now.add(const Duration(minutes: 20));
    final aged = await repo.getOrders();
    expect(aged.where((o) => o.isActive), isEmpty);
    expect(
      aged.where((o) => o.id.startsWith('GBX-105')).map((o) => o.status),
      everyElement(OrderStatus.delivered),
    );
  });

  testWidgets('an install whose deliveries finished shows the empty Active tab',
      (tester) async {
    var now = DateTime(2026, 10, 25, 12);
    final repo = MockOrdersRepository(clock: () => now);
    await repo.getOrders(); // place the demo deliveries

    // Come back 45 minutes later, when everything has been delivered.
    now = now.add(const Duration(minutes: 45));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: MaterialApp(home: OrderHistoryScreen(store: OrdersStore(repo))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active orders'), findsOneWidget);
    expect(find.text('Start shopping'), findsOneWidget);
  });

  testWidgets('no deliveries: Active explains itself and offers a shop button',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: MaterialApp(
          home: OrderHistoryScreen(store: OrdersStore(_EmptyRepository())),
          routes: {
            AppRoutes.home: (_) => const Scaffold(body: Text('Home stub')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active orders'), findsOneWidget);
    expect(find.text('Orders on their way will show up here.'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);

    // "Start shopping" is the only way forward, and it lands on Home.
    await tester.tap(find.text('Start shopping'));
    await tester.pumpAndSettle();
    expect(find.text('Home stub'), findsOneWidget);
  });

  testWidgets('no deliveries: Past explains itself without an action button',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: MaterialApp(
          home: OrderHistoryScreen(store: OrdersStore(_EmptyRepository())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();

    expect(find.text('No past orders'), findsOneWidget);
    expect(find.text('Delivered and cancelled orders live here.'),
        findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    // Shopping from an empty history is what the Active tab is for.
    expect(find.text('Start shopping'), findsNothing);
  });

  test('a fresh install lists the demo deliveries and aged-out history',
      () async {
    await restoreOrders();
    final store = OrdersStore(MockOrdersRepository());
    await store.load();

    // The demo orders are stamped relative to now on every fetch, so a new
    // install always has something in flight — they never age out.
    expect(store.activeOrders, hasLength(3));
    expect(
      store.activeOrders.every(
          (o) => DateTime.now().difference(o.createdAt).inMinutes < 60),
      isTrue,
    );

    // Everything older has already retired into Past, so the two tabs never
    // show the same order.
    expect(store.pastOrders, hasLength(4));
    expect(
      store.pastOrders.every((o) => !o.isActive),
      isTrue,
    );
  });
}
