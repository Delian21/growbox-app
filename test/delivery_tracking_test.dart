import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:growbox/data/orders.dart';
import 'package:growbox/screens/delivery_tracking_screen.dart';
import 'package:growbox/theme.dart';

/// Matches "10:42 AM".
final _timePattern = RegExp(r'^\d{1,2}:\d{2} (AM|PM)$');

/// An order whose steps were stamped at fixed wall-clock times.
Order orderWith(
  OrderStatus status, {
  Map<OrderStatus, DateTime>? timestamps,
}) =>
    Order(
      id: 'GBX-10536',
      vendorName: 'Green Farm',
      status: status,
      createdAt: DateTime(2026, 10, 25, 10, 12),
      items: const [],
      timestamps: timestamps ??
          {
            OrderStatus.confirmed: DateTime(2026, 10, 25, 10, 12),
            OrderStatus.packing: DateTime(2026, 10, 25, 10, 16),
            OrderStatus.pickedUp: DateTime(2026, 10, 25, 10, 22),
            OrderStatus.onTheWay: DateTime(2026, 10, 25, 10, 26),
            OrderStatus.delivered: DateTime(2026, 10, 25, 10, 48),
          },
    );

Widget harness({
  Brightness brightness = Brightness.light,
  DeliveryStage stage = DeliveryStage.onTheWay,
  Order? order,
}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? AppDarkColors.background
          : AppColors.background,
    ),
    home: order == null
        ? DeliveryTrackingScreen(orderNumber: 'GBX-10536', initialStage: stage)
        : DeliveryTrackingScreen(order: order),
  );
}

Future<void> pumpScreen(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  DeliveryStage stage = DeliveryStage.onTheWay,
  Size size = const Size(360, 800),
  Order? order,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    harness(brightness: brightness, stage: stage, order: order),
  );
  await tester.pump();
  // Let the route draw-in and the marker settle.
  await tester.pump(const Duration(milliseconds: 1000));
}

void main() {
  testWidgets('header uses the app bar title style with a 48px back target',
      (tester) async {
    await pumpScreen(tester);

    final context = tester.element(find.text('Track Delivery'));
    final title = tester.widget<Text>(find.text('Track Delivery'));
    expect(title.style!.fontSize, inInclusiveRange(20, 22));
    expect(title.style!.fontWeight, FontWeight.w600);
    expect(title.style!.color, C.textPrimary(context));

    // The tap target, not just the glyph.
    final back = tester.getSize(find
        .ancestor(of: find.byIcon(Icons.chevron_left), matching: find.byType(SizedBox))
        .first);
    expect(back.width, greaterThanOrEqualTo(48));
    expect(back.height, greaterThanOrEqualTo(48));
  });

  testWidgets('the rider rides the route at the status-derived point',
      (tester) async {
    await pumpScreen(tester, stage: DeliveryStage.onTheWay);

    final rider = find.descendant(
      of: find.bySemanticsLabel('Rider Ibrahim K.'),
      matching: find.byIcon(Icons.two_wheeler),
    );
    expect(rider, findsOneWidget);

    // Solid primary fill, not the old faded ring.
    final marker = tester.widget<Container>(
      find.ancestor(of: rider, matching: find.byType(Container)).first,
    );
    final context = tester.element(rider);
    expect((marker.decoration as BoxDecoration).color, C.primary(context));

    // Positioned from the status: 60% along, i.e. past halfway between the
    // vendor and the address pins.
    final start = tester.getCenter(find.byIcon(Icons.store));
    final end = tester.getCenter(find.byIcon(Icons.location_on));
    final at = tester.getCenter(rider);
    expect(at.dx, greaterThan(start.dx + (end.dx - start.dx) * 0.45));
    expect(at.dx, lessThan(end.dx));
    expect(at.dy, inInclusiveRange(start.dy, end.dy));

    // The address label hangs below the pin, so the route (which ends at the
    // pin's centre) can never run through the text.
    final label = tester.getRect(find.text('Your Address'));
    expect(label.top, greaterThanOrEqualTo(end.dy + 14));

    // Same spot for every build: it is derived from the status, not a random
    // simulation.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getCenter(rider).dx, closeTo(at.dx, 0.5));
  });

  testWidgets('timeline marks done, current and pending steps distinctly',
      (tester) async {
    await pumpScreen(tester, stage: DeliveryStage.onTheWay);

    final context = tester.element(find.text('Delivery Status'));

    // Three steps behind the rider: filled primary circles with checks.
    expect(find.byIcon(Icons.check), findsNWidgets(3));
    // One current step with a vehicle, plus the marker on the map.
    expect(find.byIcon(Icons.two_wheeler), findsNWidgets(2));

    // The current step's title is the bold one.
    expect(tester.widget<Text>(find.text('On the Way')).style!.fontWeight,
        FontWeight.w700);
    expect(tester.widget<Text>(find.text('Picked Up')).style!.fontWeight,
        FontWeight.w600);

    // Pending steps are readable, not near-invisible grey.
    final pending = tester.widget<Text>(find.text('Delivered'));
    expect(pending.style!.color, C.textMuted(context));
    expect(
      tester.widget<Text>(find.text('Order delivered to your address')).style!.color,
      C.textMuted(context),
    );
  });

  testWidgets('completed steps show a time; pending ones show none',
      (tester) async {
    await pumpScreen(tester, stage: DeliveryStage.onTheWay);

    final times = tester.widgetList<Text>(find.byType(Text)).where(
        (t) => _timePattern.hasMatch(t.data ?? '')).length;
    // Three completed steps (placed, rider assigned, picked up).
    expect(times, 3);
  });

  testWidgets('rider card hides the number and uses a monogram', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);

    expect(find.text('+234 812 345 6789'), findsNothing);
    expect(find.text('Ibrahim K.'), findsOneWidget);
    expect(find.text('IK'), findsOneWidget);

    for (final label in ['Call rider', 'Message rider']) {
      final size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }

    semantics.dispose();
  });

  testWidgets('delivered hides the rider and checks the destination pin',
      (tester) async {
    await pumpScreen(tester, stage: DeliveryStage.delivered);

    expect(find.bySemanticsLabel('Rider Ibrahim K.'), findsNothing);
    expect(find.text('Delivered!'), findsOneWidget);

    // The destination pin's label flips to "Delivered" (the timeline step has
    // the same word, so match the pin's label size).
    expect(
      find.byWidgetPredicate((w) =>
          w is Text && w.data == 'Delivered' && w.style?.fontSize == 9),
      findsOneWidget,
    );
  });

  group('driven by a real order', () {
    testWidgets('the status picks the current step and the timestamps are real',
        (tester) async {
      await pumpScreen(tester, order: orderWith(OrderStatus.onTheWay));

      // "On the way" is the step in progress, with a vehicle not a check.
      expect(tester.widget<Text>(find.text('On the Way')).style!.fontWeight,
          FontWeight.w700);
      expect(find.byIcon(Icons.two_wheeler), findsNWidgets(2));

      // Three steps behind it.
      expect(find.byIcon(Icons.check), findsNWidgets(3));

      // Every completed step carries the order's own event time — including the
      // pickup, which now has one. The current step's own time stays hidden.
      expect(find.text('10:12 AM'), findsOneWidget);
      expect(find.text('10:16 AM'), findsOneWidget);
      expect(find.text('10:22 AM'), findsOneWidget);
      expect(find.text('10:26 AM'), findsNothing);
      expect(
        tester.widgetList<Text>(find.byType(Text)).where(
            (t) => _timePattern.hasMatch(t.data ?? '')).length,
        3,
      );
    });

    testWidgets('the order number and stage come from the order', (tester) async {
      await pumpScreen(tester, order: orderWith(OrderStatus.packing));

      expect(find.text('#GBX-10536'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Rider Assigned')).style!.fontWeight,
          FontWeight.w700);
      // Only "order placed" is behind the rider.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('10:12 AM'), findsOneWidget);
    });

    testWidgets('stages never drift on their own timer', (tester) async {
      // The demo advances after 5 s and again after 12 s; a real order must not.
      await pumpScreen(tester, order: orderWith(OrderStatus.confirmed));
      await tester.pump(const Duration(seconds: 20));

      expect(tester.widget<Text>(find.text('Order Placed')).style!.fontWeight,
          FontWeight.w700);
      expect(tester.widget<Text>(find.text('Picked Up')).style!.fontWeight,
          FontWeight.w500);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('a delivered order completes every step', (tester) async {
      await pumpScreen(tester, order: orderWith(OrderStatus.delivered));

      expect(find.text('Delivered!'), findsOneWidget);
      expect(find.bySemanticsLabel('Rider Ibrahim K.'), findsNothing);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      // Four timeline checks behind the final step, plus the pin.
      expect(find.byIcon(Icons.check), findsNWidgets(6));
      expect(find.text('10:22 AM'), findsOneWidget);
      expect(find.text('10:48 AM'), findsOneWidget);
    });

    testWidgets('a missing timestamp simply omits the time', (tester) async {
      await pumpScreen(
        tester,
        order: orderWith(
          OrderStatus.onTheWay,
          timestamps: const {},
        ),
      );

      expect(
        tester.widgetList<Text>(find.byType(Text)).where(
            (t) => _timePattern.hasMatch(t.data ?? '')).length,
        0,
      );
      // The stages still read from the status.
      expect(tester.widget<Text>(find.text('On the Way')).style!.fontWeight,
          FontWeight.w700);
    });
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('arrival card follows the theme (${brightness.name})',
        (tester) async {
      await pumpScreen(tester, brightness: brightness);

      final card = tester.widget<Container>(
        find.ancestor(of: find.text('Arriving in'), matching: find.byType(Container)).first,
      );
      final context = tester.element(find.text('Arriving in'));

      expect(
        (card.decoration as BoxDecoration).color,
        brightness == Brightness.dark
            ? AppDarkColors.successSoft
            : AppColors.successSoft,
      );
      expect((card.decoration as BoxDecoration).color, C.successSoft(context));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('lays out at a narrow width without overflowing', (tester) async {
    await pumpScreen(tester, size: const Size(320, 700));
    expect(tester.takeException(), isNull);
  });
}
