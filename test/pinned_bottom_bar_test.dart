import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/screens/address_management_screen.dart';
import 'package:growbox/screens/cart_screen.dart';
import 'package:growbox/theme.dart';
import 'package:growbox/widgets/bottom_nav.dart';
import 'package:growbox/widgets/pinned_bottom_bar.dart';
import 'package:growbox/widgets/scaffold_with_nav.dart';

/// Phone-sized surface used for every geometry assertion.
const Size _surface = Size(400, 800);

void _configureSurface(
  WidgetTester tester, {
  double gestureInset = 0,
  double keyboard = 0,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _surface;
  tester.view.padding = FakeViewPadding(bottom: gestureInset);
  tester.view.viewPadding = FakeViewPadding(bottom: gestureInset);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
}

Widget _harness() => ChangeNotifierProvider(
      create: (_) => CartNotifier(),
      child: MaterialApp(
        home: ScaffoldWithNav(
          activeIndex: 1,
          fadeContent: false,
          child: ScreenWithPinnedBar(
            body: Container(
              key: const ValueKey('body'),
              color: AppColors.background,
              child: const Align(
                alignment: Alignment.topCenter,
                child: TextField(),
              ),
            ),
            bar: const SizedBox(
              key: ValueKey('barContent'),
              height: 56,
              child: Text('Checkout'),
            ),
          ),
        ),
      ),
    );

/// Bottom of the pill's reserved zone, measured from the bottom of the screen.
double _navReserved(WidgetTester tester) {
  final context = tester.element(find.byType(ScaffoldWithNav));
  return BottomNavMetrics.reserved(context);
}

void main() {
  testWidgets('the bar sits directly on the nav with no gesture inset',
      (tester) async {
    _configureSurface(tester);
    await tester.pumpWidget(_harness());
    await tester.pump();

    final bar = tester.getRect(find.byKey(PinnedBottomBar.surfaceKey));
    final nav = tester.getRect(find.byType(BottomNav));
    final body = tester.getRect(find.byKey(const ValueKey('body')));
    final reserved = _navReserved(tester);

    expect(reserved, BottomNavMetrics.barHeight + BottomNavMetrics.barMargin);
    // Flush with the top of the floating pill: no gap, no overlap.
    expect(bar.bottom, closeTo(nav.top, 0.01));
    expect(bar.bottom, closeTo(_surface.height - reserved, 0.01));
    // The body ends exactly where the bar begins.
    expect(body.bottom, closeTo(bar.top, 0.01));
    expect(find.text('Checkout'), findsOneWidget);
  });

  testWidgets('the bar clears the nav on a device with a gesture inset',
      (tester) async {
    _configureSurface(tester, gestureInset: 34);
    await tester.pumpWidget(_harness());
    await tester.pump();

    final bar = tester.getRect(find.byKey(PinnedBottomBar.surfaceKey));
    final nav = tester.getRect(find.byType(BottomNav));

    expect(_navReserved(tester), BottomNavMetrics.barHeight + BottomNavMetrics.barMargin + 34);
    expect(bar.bottom, closeTo(nav.top, 0.01));
    expect(bar.bottom, closeTo(_surface.height - (72 + 12 + 34), 0.01));
  });

  testWidgets('the body is inset by the nav plus the bar height', (tester) async {
    _configureSurface(tester, gestureInset: 34);
    await tester.pumpWidget(_harness());
    await tester.pump();

    final body = tester.getRect(find.byKey(const ValueKey('body')));
    final bar = tester.getRect(find.byKey(PinnedBottomBar.surfaceKey));
    final reserved = _navReserved(tester);

    // Nothing can hide under the bar or the nav: the scrollable's viewport
    // already ends above both.
    expect(bar.height, greaterThan(0));
    expect(_surface.height - body.bottom, closeTo(bar.height + reserved, 0.01));
  });

  testWidgets('the bar sits on the keyboard and the nav hides while typing',
      (tester) async {
    _configureSurface(tester, gestureInset: 34, keyboard: 300);
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byType(BottomNav), findsNothing);

    final bar = tester.getRect(find.byKey(PinnedBottomBar.surfaceKey));
    final body = tester.getRect(find.byKey(const ValueKey('body')));

    // Flush with the keyboard, not 118px above it.
    expect(bar.bottom, closeTo(_surface.height - 300, 0.01));
    expect(body.bottom, closeTo(bar.top, 0.01));
    expect(body.bottom, lessThanOrEqualTo(_surface.height - 300));
  });

  // ── Migrated screens ────────────────────────────────────────────────────

  testWidgets('the cart checkout bar is pinned above the nav', (tester) async {
    _configureSurface(tester);
    final cart = CartNotifier()
      ..add(const VendorProduct(
        image: '',
        name: 'Rice',
        description: 'Rice',
        price: 2550,
        category: 'GRAINS',
        vendorName: 'Green Farm',
      ));

    await tester.pumpWidget(ChangeNotifierProvider<CartNotifier>.value(
      value: cart,
      child: const MaterialApp(home: CartScreen()),
    ));
    await tester.pump();

    final bar = tester.getRect(find.byKey(PinnedBottomBar.surfaceKey));
    final nav = tester.getRect(find.byType(BottomNav));

    // Floating checkout bar: 10px of air above the pill, inset to the pill's
    // own width.
    expect(bar.bottom, closeTo(nav.top - 10, 0.01));
    expect(bar.width, closeTo(400 - BottomNavMetrics.barHorizontalPadding * 2, 0.01));
    expect(find.text('Checkout'), findsOneWidget);
    // Subtotal in the bar (the line item above it shows the same price).
    expect(find.text('₦2,550'), findsNWidgets(2));
    expect(find.text('Delivery'), findsOneWidget);
    // Total = subtotal + the vendor's ₦500 fee.
    expect(find.text('₦3,050'), findsOneWidget);

    // The checkout button lives inside the bar rather than in the list.
    final button = tester.getRect(find.text('Checkout'));
    expect(button.top, greaterThanOrEqualTo(bar.top));
    expect(button.bottom, lessThanOrEqualTo(bar.bottom));
  });

  testWidgets('the address list pins its add button above the nav',
      (tester) async {
    _configureSurface(tester);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => CartNotifier(),
      child: const MaterialApp(home: AddressManagementScreen()),
    ));
    await tester.pump();

    final bar = tester.getRect(find.byKey(PinnedBottomBar.surfaceKey));
    final nav = tester.getRect(find.byType(BottomNav));

    expect(bar.bottom, closeTo(nav.top, 0.01));
    expect(find.text('+ Add New Address'), findsOneWidget);
  });
}
