import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/orders.dart';
import 'package:growbox/screens/delivery_tracking_screen.dart';
import 'package:growbox/screens/faq_screen.dart';
import 'package:growbox/screens/home_screen.dart';
import 'package:growbox/screens/order_history_screen.dart';

/// Deterministic repository: instant, and it really applies the mutations so
/// the screens can be checked after the write.
class _Repo implements OrdersRepository {
  _Repo(this.orders);

  final List<Order> orders;

  @override
  Future<List<Order>> getOrders() async => List<Order>.of(orders);

  @override
  Future<void> advanceStatus(String orderId) async {
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return;
    final next = orders[index].status.nextActive;
    if (next == null) return;
    orders[index] = orders[index].copyWith(status: next);
  }

  @override
  Future<void> rateOrder(String orderId, OrderRating rating) async {
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return;
    orders[index] = orders[index].copyWith(rating: rating);
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return;
    orders[index] = orders[index]
        .copyWith(status: OrderStatus.cancelled, cancelReason: reason);
  }

  @override
  Future<void> makeLate(String orderId) async {
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return;
    orders[index] = orders[index].copyWith(
      estimatedArrival: DateTime.now().subtract(const Duration(minutes: 5)),
    );
  }
}

final Map<OrderStatus, DateTime> _fullTimeline = {
  OrderStatus.confirmed: DateTime(2026, 10, 25, 10, 12),
  OrderStatus.packing: DateTime(2026, 10, 25, 10, 16),
  OrderStatus.pickedUp: DateTime(2026, 10, 25, 10, 22),
  OrderStatus.onTheWay: DateTime(2026, 10, 25, 10, 26),
  OrderStatus.delivered: DateTime(2026, 10, 25, 10, 48),
};

Order _order({
  OrderStatus status = OrderStatus.delivered,
  String vendor = 'Green Farm',
  Map<OrderStatus, DateTime>? timestamps,
  DateTime? deliveredAt,
  String? cancelReason,
  OrderRating? rating,
  DateTime? estimatedArrival,
}) =>
    Order(
      id: 'GBX-1050',
      vendorName: vendor,
      status: status,
      createdAt: DateTime(2026, 10, 25, 10, 12),
      estimatedArrival: estimatedArrival,
      items: const [],
      timestamps: timestamps ?? _fullTimeline,
      deliveredAt: deliveredAt,
      cancelReason: cancelReason,
      rating: rating,
    );

Widget _tracking(Order order, OrdersStore store) => ChangeNotifierProvider(
      create: (_) => CartNotifier(),
      child: MaterialApp(
        home: DeliveryTrackingScreen(order: order, store: store),
      ),
    );

Widget _history(OrdersStore store, {OrdersTab tab = OrdersTab.past}) =>
    ChangeNotifierProvider(
      create: (_) => CartNotifier(),
      child: MaterialApp(
        home: OrderHistoryScreen(store: store, initialTab: tab),
      ),
    );

Widget _home(OrdersStore store, {Key? key}) => ChangeNotifierProvider(
      create: (_) => CartNotifier(),
      // A fresh key per scenario, so Home starts over (and loads the new
      // store) instead of reusing the previous State.
      child: MaterialApp(key: key, home: HomeScreen(store: store)),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the model', () {
    test('a stored record round-trips its terminal stamps and feedback', () {
      final stored = StoredOrder(
        orderNumber: 'GBX-77',
        placedAt: DateTime(2026, 10, 20, 9),
        status: 'Delivered',
        deliveryAddress: 'Gwarinpa, Abuja',
        deliveryFee: 1500,
        items: const [],
        deliveredAt: DateTime(2026, 10, 20, 9, 30),
        feedback: 'notGreat',
        feedbackReasons: const ['Late'],
        feedbackComment: 'Arrived cold',
      );

      final decoded = StoredOrder.fromJson(stored.toJson());

      expect(decoded.deliveredAt, DateTime(2026, 10, 20, 9, 30));
      expect(decoded.feedback, 'notGreat');
      expect(decoded.feedbackReasons, ['Late']);
      expect(decoded.feedbackComment, 'Arrived cold');
    });

    test('a stored cancellation keeps its reason and the UI reads it', () {
      final stored = StoredOrder(
        orderNumber: 'GBX-78',
        placedAt: DateTime(2026, 10, 20, 9),
        status: 'Cancelled',
        deliveryAddress: 'Gwarinpa, Abuja',
        deliveryFee: 0,
        items: const [],
        cancelledAt: DateTime(2026, 10, 20, 9, 4),
        cancelReason: 'Ordered by mistake',
      );

      final order = orderFromStored(stored);

      expect(order.status, OrderStatus.cancelled);
      expect(order.cancelledAt, DateTime(2026, 10, 20, 9, 4));
      expect(order.cancelReason, 'Ordered by mistake');
      expect(order.rating, isNull);
    });

    test('an unrated delivery is waiting for feedback; a skip is not', () {
      expect(_order().awaitsFeedback, isTrue);
      expect(
        _order(rating: const OrderRating(feedback: OrderFeedback.skipped))
            .awaitsFeedback,
        isFalse,
      );
      expect(
        _order(rating: const OrderRating(feedback: OrderFeedback.liked))
            .awaitsFeedback,
        isFalse,
      );
    });
  });

  testWidgets('a delivered order shows when it arrived and asks for feedback',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1200);
    addTearDown(tester.view.reset);

    final order = _order(deliveredAt: DateTime(2026, 10, 25, 11, 42));
    final store = OrdersStore(_Repo([order]));

    await tester.pumpWidget(_tracking(order, store));
    await tester.pumpAndSettle();

    expect(find.text('Delivered at 11:42 AM'), findsOneWidget);
    // Nothing left to track: no route, no rider, no call buttons.
    expect(find.text('Your Rider'), findsNothing);
    expect(find.text('Call rider'), findsNothing);
    expect(find.text('How was your order?'), findsOneWidget);

    await tester.ensureVisible(find.text('Rate your order'));
    await tester.tap(find.text('Rate your order'));
    await tester.pumpAndSettle();

    // The question names the vendor, and answers in thumbs not stars.
    expect(
      find.text('Did you enjoy your order from Green Farm?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Liked it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();

    // Saved on the order, and the prompt is replaced by the answer.
    expect(store.orders.single.rating!.feedback, OrderFeedback.liked);
    expect(find.text('You liked it'), findsOneWidget);
    expect(find.text('Rate your order'), findsNothing);
  });

  testWidgets('a thumbs down can name reasons and leave a comment',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1200);
    addTearDown(tester.view.reset);

    final repo = _Repo([_order()]);
    final store = OrdersStore(repo);
    await store.load();

    await tester.pumpWidget(_history(store));
    await tester.pumpAndSettle();

    // A delivered, unrated order offers Rate in Past.
    expect(find.text('Rate'), findsOneWidget);
    await tester.tap(find.text('Rate'));
    await tester.pumpAndSettle();

    // The chips only appear after the thumbs down.
    expect(find.text('Late'), findsNothing);
    await tester.tap(find.text('Not great'));
    await tester.pumpAndSettle();

    for (final reason in orderFeedbackReasons) {
      expect(find.text(reason), findsOneWidget);
    }

    await tester.tap(find.text('Late'));
    await tester.enterText(find.byType(TextField), 'Arrived cold');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();

    expect(repo.orders.single.rating!.feedback, OrderFeedback.notGreat);
    expect(repo.orders.single.rating!.reasons, ['Late']);
    expect(repo.orders.single.rating!.comment, 'Arrived cold');
    // Once answered, the card shows the result instead of asking again.
    expect(find.text('Not great · Late'), findsOneWidget);
    expect(find.text('Rate'), findsNothing);
  });

  testWidgets('skipping the prompt is saved and never asks again',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1200);
    addTearDown(tester.view.reset);

    final repo = _Repo([_order()]);
    final store = OrdersStore(repo);
    await store.load();

    await tester.pumpWidget(_history(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(repo.orders.single.rating!.feedback, OrderFeedback.skipped);
    // Skipped is an answer: the button does not come back.
    expect(find.text('Rate'), findsNothing);
    expect(store.latestAwaitingFeedback, isNull);
  });

  testWidgets('a cancelled order replaces tracking with its ending',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1200);
    addTearDown(tester.view.reset);

    final order = _order(
      status: OrderStatus.cancelled,
      cancelReason: 'Ordered by mistake',
      timestamps: {
        OrderStatus.confirmed: DateTime(2026, 10, 25, 10, 12),
        OrderStatus.cancelled: DateTime(2026, 10, 25, 10, 15),
      },
    );

    await tester.pumpWidget(_tracking(order, OrdersStore(_Repo([order]))));
    await tester.pumpAndSettle();

    expect(find.text('Order cancelled'), findsOneWidget);
    expect(find.text('Ordered by mistake'), findsOneWidget);
    expect(find.text('Reorder'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
    // No map, no rider, no live delivery.
    expect(find.text('Your Rider'), findsNothing);
    expect(find.text('Your Address'), findsNothing);
    expect(find.textContaining('min ·'), findsNothing);

    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();
    expect(find.byType(FAQScreen), findsOneWidget);
  });

  testWidgets('demo tools cancel an order and make it late', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1200);
    addTearDown(tester.view.reset);

    final repo = _Repo([
      _order(
        status: OrderStatus.onTheWay,
        timestamps: {
          OrderStatus.confirmed: DateTime(2026, 10, 25, 10, 12),
        },
      ),
    ]);
    final store = OrdersStore(repo);
    await store.load();

    await tester.pumpWidget(_history(store, tab: OrdersTab.active));
    await tester.pumpAndSettle();

    expect(find.text('Cancel order'), findsOneWidget);
    expect(find.text('Make late'), findsOneWidget);

    await tester.tap(find.text('Make late'));
    await tester.pumpAndSettle();
    // Five minutes past the promise.
    expect(store.orders.single.eta.isBefore(DateTime.now()), isTrue);

    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    expect(store.orders.single.status, OrderStatus.cancelled);
    expect(store.activeOrders, isEmpty);
  });

  testWidgets('the home banner speaks each status and wraps to two lines',
      (tester) async {
    // Default 800x600: the Ahem test font is much wider than the real one, so
    // a phone-width Home overflows on unrelated rows before the banner is
    // even checked.

    Future<void> pumpFor(OrderStatus status) async {
      await tester.pumpWidget(
        _home(
          OrdersStore(_Repo([_order(status: status)])),
          key: ValueKey(status),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpFor(OrderStatus.confirmed);
    expect(find.text('Green Farm confirmed your order'), findsOneWidget);

    await pumpFor(OrderStatus.packing);
    expect(find.text('Green Farm is packing your order'), findsOneWidget);

    await pumpFor(OrderStatus.onTheWay);
    expect(find.text('Your order is on the way'), findsOneWidget);

    // Nothing truncates: two lines are allowed, one is used.
    final text = tester.widget<Text>(find.text('Your order is on the way'));
    expect(text.maxLines, 2);

    await pumpFor(OrderStatus.cancelled);
    expect(find.textContaining('cancelled'), findsNothing);

    await pumpFor(OrderStatus.delivered);
    expect(find.text('Rate your order from Green Farm'), findsOneWidget);

    // Dismissing hides the prompt for good (the id is remembered).
    await tester.tap(find.bySemanticsLabel('Dismiss rating prompt'));
    await tester.pumpAndSettle();
    expect(find.text('Rate your order from Green Farm'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('rating_prompt_dismissed'), ['GBX-1050']);
  });
}
