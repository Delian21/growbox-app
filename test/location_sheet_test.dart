import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/addresses.dart';
import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/main.dart';
import 'package:growbox/screens/location_screen.dart';
import 'package:growbox/theme.dart';
import 'package:growbox/widgets/bottom_nav.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CustomerData.clear();
    // The app-wide store survives between tests; reload it from the (empty)
    // mock storage so each test starts with a new customer.
    await addressesStore.load(force: true);
  });

  Future<void> pumpLocationScreen(WidgetTester tester) async {
    // Tall enough that the sheet's address list and warning chip are on-screen.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: const MaterialApp(home: LocationScreen()),
      ),
    );
    // First frame → the post-frame callback opens the address sheet.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('address sheet opens with a detecting state, then no area',
      (tester) async {
    await pumpLocationScreen(tester);

    expect(find.text('Where should we deliver?'), findsOneWidget);
    expect(find.text('Detecting your location...'), findsOneWidget);
    // Regression guard: the stock Flutter error panel must never be what the
    // sheet's backdrop shows.
    expect(find.textContaining('Sorry'), findsNothing);

    // The sheet is a root-navigator modal: it starts above the bottom nav and
    // so covers it.
    final sheetRect = tester.getRect(find.byType(FractionallySizedBox));
    final navRect = tester.getRect(find.byType(BottomNav));
    expect(sheetRect.top, lessThan(navRect.top),
        reason: 'sheet must cover the bottom nav');

    // The map pin sits inside the uncovered part of the map, clear of the
    // sheet's first row.
    final pin = find.byWidgetPredicate((w) =>
        w is Icon && w.icon == Icons.location_on && w.size == 44);
    expect(tester.getRect(pin).bottom, lessThan(sheetRect.top),
        reason: 'pin must not overlap the sheet header');

    // Detection resolves to the browsing area — and says so when there is no
    // fake default to fall back on.
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Detecting your location...'), findsNothing);
    expect(find.text('No saved area yet — tap to set one'), findsOneWidget);
    expect(find.text('Asokoro, Abuja'), findsNothing,
        reason: 'the hardcoded default is gone');
  });

  testWidgets('an incomplete address offers the missing-details fix',
      (tester) async {
    // An area-only address: the rider has nowhere to go.
    await addressesStore.save(
      const Address(id: 'a1', label: 'Home', area: 'Gwarinpa, Abuja'),
    );

    await pumpLocationScreen(tester);
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.text('Missing address details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The existing address editor opens, ready to fill in the street line.
    expect(find.text('Edit Address'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('error fallback is on-brand rather than the stock panel',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandedErrorView())),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('Sorry'), findsNothing);
    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(icon.color, AppColors.error);
  });
}
