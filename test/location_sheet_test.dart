import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/main.dart';
import 'package:growbox/screens/location_screen.dart';
import 'package:growbox/theme.dart';
import 'package:growbox/widgets/bottom_nav.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpLocationScreen(WidgetTester tester) async {
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

  testWidgets('address sheet opens with a detecting state, then the address',
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
    // sheet's first row (the warning chip).
    final pin = find.byWidgetPredicate((w) =>
        w is Icon && w.icon == Icons.location_on && w.size == 44);
    expect(tester.getRect(pin).bottom, lessThan(sheetRect.top),
        reason: 'pin must not overlap the sheet header');

    // Detection resolves to the saved default address.
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Detecting your location...'), findsNothing);
    expect(find.text('Asokoro, Abuja'), findsOneWidget);
  });

  testWidgets('missing-details chip opens the add-address flow', (tester) async {
    await pumpLocationScreen(tester);
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.text('Missing address details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Dialog title and the sheet button share the label.
    expect(find.text('Add a new address'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
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
