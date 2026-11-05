import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/orders.dart';
import 'package:growbox/screens/order_details_screen.dart';
import 'package:growbox/screens/order_result_screens.dart';

/// The attempt both screens render: 2 × ₦2,550 plus ₦500 delivery.
Order _attempt() => Order(
      id: 'GBX-2001',
      vendorName: 'Green Farm',
      status: OrderStatus.confirmed,
      createdAt: DateTime(2026, 10, 24, 12),
      items: [
        OrderItem(
          name: 'Rice',
          vendorName: 'Green Farm',
          category: 'GRAINS',
          image: 'assets/images/rice.jpg',
          price: 2550,
          quantity: 2,
        ),
      ],
      deliveryAddress: 'Gwarinpa, Abuja',
    );

Widget harness(Widget child) => ChangeNotifierProvider(
      create: (_) => CartNotifier(),
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('Order Pending is built from the order, not a template',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(OrderPendingScreen(order: _attempt())));
    await tester.pumpAndSettle();

    expect(find.text('Confirming your order'), findsOneWidget);
    expect(
      find.text("We're confirming your order with Green Farm."),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

    // Identity and money come from the order.
    expect(find.text('#GBX-2001'), findsOneWidget);
    expect(find.text('Gwarinpa, Abuja'), findsOneWidget);
    expect(find.text('₦5,100'), findsOneWidget); // subtotal
    expect(find.text('₦5,600'), findsOneWidget); // + ₦500 delivery

    // The old template's hardcoded facts are gone.
    expect(find.textContaining('Nigeria'), findsNothing);
    expect(find.text('Today, 2:00 PM - 4:00 PM'), findsNothing);
    expect(find.text('₦26,000'), findsNothing);

    // Sentence-case actions, and nothing about money changing hands.
    expect(find.text('View order'), findsOneWidget);
    expect(find.text('Continue shopping'), findsOneWidget);
    expect(find.textContaining('Payment'), findsNothing);
  });

  testWidgets('Order Pending opens the order it is confirming', (tester) async {
    await tester.pumpWidget(harness(OrderPendingScreen(order: _attempt())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View order'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailsScreen), findsOneWidget);
  });

  testWidgets('Order Failed uses the order and offers a retry', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(OrderFailedScreen(order: _attempt())));
    await tester.pumpAndSettle();

    expect(find.text("We couldn't place your order"), findsOneWidget);
    expect(
      find.text('Something went wrong on our side. '
          'Your box is safe, so you can try again.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

    expect(find.text('#GBX-2001'), findsOneWidget);
    expect(find.text('Gwarinpa, Abuja'), findsOneWidget);
    expect(find.text('₦5,600'), findsOneWidget);

    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Back to box'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsNothing);

    // No delivery estimate and no payment talk on a failure.
    expect(find.text('Today, 2:00 PM - 4:00 PM'), findsNothing);
    expect(find.textContaining('Arriv'), findsNothing);
    expect(find.textContaining('Payment'), findsNothing);
  });
}
