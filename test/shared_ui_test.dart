import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/categories.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/data/orders.dart';
import 'package:growbox/screens/home_screen.dart';
import 'package:growbox/screens/menu_screen.dart';
import 'package:growbox/screens/vendor_screen.dart';
import 'package:growbox/theme.dart';
import 'package:growbox/widgets/bottom_nav.dart';
import 'package:growbox/widgets/scaffold_with_nav.dart';
import 'package:growbox/widgets/vendor_card.dart';

class _FakeOrdersRepository implements OrdersRepository {
  _FakeOrdersRepository(this._orders);

  final List<Order> _orders;

  @override
  Future<List<Order>> getOrders() async => List<Order>.of(_orders);

  @override
  Future<void> advanceStatus(String orderId) async {}
}

Order _activeOrder() => Order(
      id: 'GBX-900',
      vendorName: 'Green Farm',
      status: OrderStatus.onTheWay,
      createdAt: DateTime(2026, 10, 24, 12),
      items: const [
        OrderItem(
          name: 'Rice',
          vendorName: 'Green Farm',
          category: 'GRAINS',
          image: '',
          price: 2550,
          quantity: 1,
        ),
      ],
      deliveryAddress: 'Gwarinpa, Abuja',
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CustomerData.clear();
    purchaseHistory.clear();
    favoriteVendors.clear();
  });

  Widget app(Widget home) => ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: MaterialApp(home: home),
      );

  test('one category list, with a sprout icon for Legumes', () {
    expect(
      kCategories.map((c) => c.label).toList(),
      ['Grains', 'Fruits', 'Vegetables', 'Legumes', 'Tubers', 'Proteins',
        'Herbs', 'Oils'],
    );
    final legumes = kCategories.firstWhere((c) => c.label == 'Legumes');
    expect(legumes.icon, Icons.spa);
  });

  testWidgets('Browse renders the shared list, including Tubers',
      (tester) async {
    await tester.pumpWidget(app(const MenuScreen()));
    await tester.pumpAndSettle();

    for (final category in kCategories) {
      expect(find.text(category.label), findsWidgets,
          reason: '${category.label} missing from Browse');
    }
    // The old coffee-cup Legumes icon is gone.
    expect(find.byIcon(Icons.emoji_food_beverage), findsNothing);
    expect(find.byIcon(Icons.spa), findsOneWidget);
  });

  testWidgets('Browse uses the same VendorCard, with a favourite overlay',
      (tester) async {
    await tester.pumpWidget(app(const MenuScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(VendorCard), findsWidgets);
    // One heart per vendor, overlaid on the photo.
    expect(find.byIcon(Icons.favorite_border), findsNWidgets(7));

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pump();

    // The heart handled the tap; the card did not open the vendor.
    expect(find.byType(VendorScreen), findsNothing);
    expect(favoriteVendors.single['name'], 'Green Farm');
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('active order banner sits above the profile nudge',
      (tester) async {
    await tester.pumpWidget(
      app(
        HomeScreen(store: OrdersStore(_FakeOrdersRepository([_activeOrder()]))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final bannerY = tester
        .getTopLeft(find.text('Your order from Green Farm is on the way'))
        .dy;
    final nudgeY =
        tester.getTopLeft(find.byKey(const ValueKey('profileNudge'))).dy;
    expect(bannerY, lessThan(nudgeY));
  });

  testWidgets('profile nudge can be dismissed and stays dismissed',
      (tester) async {
    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profileNudge')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profileNudge')), findsNothing);

    // A fresh screen reads the saved choice, not just local state.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profileNudge')), findsNothing);
  });

  testWidgets('Order Again product names may wrap to two lines',
      (tester) async {
    seedPurchaseHistory();
    final firstName = getBuyAgainItems().first.name;

    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pumpAndSettle();

    final name = tester.widget<Text>(find.text(firstName).first);
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);
  });

  testWidgets('the scrim spans the full width and is opaque behind the pill',
      (tester) async {
    await tester.pumpWidget(
      app(const ScaffoldWithNav(activeIndex: 0, child: SizedBox.expand())),
    );

    final context = tester.element(find.byType(ScaffoldWithNav));
    final background = C.background(context);
    final reserved = BottomNavMetrics.reserved(context);

    final opaque = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(ScaffoldWithNav),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == background,
        ),
      ),
    );
    expect(opaque.color, background);

    final rect = tester.getRect(find.descendant(
      of: find.byType(ScaffoldWithNav),
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == background,
      ),
    ));
    expect(rect.width, tester.view.physicalSize.width / tester.view.devicePixelRatio);
    expect(rect.height, reserved);
    expect(rect.bottom, tester.view.physicalSize.height / tester.view.devicePixelRatio);
  });
}
