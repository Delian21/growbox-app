import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/routes.dart';
import 'package:growbox/screens/home_screen.dart';
import 'package:growbox/screens/menu_screen.dart';
import 'package:growbox/screens/order_history_screen.dart';
import 'package:growbox/screens/search_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    purchaseHistory.clear();
  });

  Widget harness() {
    return ChangeNotifierProvider(
      create: (_) => CartNotifier(),
      child: MaterialApp(
        initialRoute: AppRoutes.home,
        routes: AppRoutes.routes,
      ),
    );
  }

  Future<void> openHome(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Order Again See all opens Order History on the Past tab',
      (tester) async {
    seedPurchaseHistory();
    await openHome(tester);

    // Order Again is the first section; Nearby Vendors has the second link.
    final seeAll = find.text('See all').first;
    await tester.ensureVisible(seeAll);
    await tester.pumpAndSettle();
    await tester.tap(seeAll);
    await tester.pumpAndSettle();

    final screen = tester.widget<OrderHistoryScreen>(
      find.byType(OrderHistoryScreen),
    );
    expect(screen.initialTab, OrdersTab.past);
    // Past is the list on screen, not just the constructor argument.
    expect(find.text('No past orders'), findsOneWidget);
    expect(find.text('No active orders'), findsNothing);
  });

  testWidgets('Nearby Vendors See all labels the list as a vendor directory',
      (tester) async {
    await openHome(tester);

    final seeAll = find.text('See all');
    expect(seeAll, findsOneWidget);
    await tester.ensureVisible(seeAll);
    await tester.pumpAndSettle();
    await tester.tap(seeAll);
    await tester.pumpAndSettle();

    final menu = tester.widget<MenuScreen>(find.byType(MenuScreen));
    expect(menu.title, 'Nearby Vendors');
    expect(menu.allFilterLabel, 'All Vendors');
    expect(find.text('Nearby Vendors'), findsWidgets);
    expect(find.text('All Vendors'), findsOneWidget);
    expect(find.text('Browse Produce'), findsNothing);
    expect(find.text('All Produce'), findsNothing);
  });

  testWidgets('the catalog entry point keeps its Browse Produce labels',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: const MaterialApp(home: MenuScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Browse Produce'), findsOneWidget);
    expect(find.text('All Produce'), findsOneWidget);
  });

  testWidgets('system back from the search handoff returns to Home',
      (tester) async {
    await openHome(tester);

    await tester.tap(find.text('Search for produce...'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    // System back, not just the header arrow.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SearchScreen), findsNothing);
  });
}
