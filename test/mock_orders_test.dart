import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/orders.dart';
import 'package:growbox/screens/order_history_screen.dart';

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
}
