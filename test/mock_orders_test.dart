import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/orders.dart';
import 'package:growbox/screens/order_history_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  test('the newest active demo order is still the one on the way', () async {
    // The home banner follows the newest active order, so adding the picked-up
    // demo must not push the on-the-way delivery out of that slot.
    final store = OrdersStore(MockOrdersRepository());
    await store.load();

    expect(store.latestActiveOrder?.status, OrderStatus.onTheWay);
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
