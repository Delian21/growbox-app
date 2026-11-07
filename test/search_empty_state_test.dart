import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/screens/search_screen.dart';
import 'package:growbox/widgets/category_chip.dart';
import 'package:growbox/widgets/status_view.dart';

/// The no-results state is only allowed to appear after a search has actually
/// run: never on an empty box, never mid-word.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StockTracker.seed();
    recentSearches.clear();
  });

  Future<void> pumpSearch(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('typing alone never reports "no results"', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();

    // Mid-word: no verdict yet.
    expect(find.byType(StatusView), findsNothing);
    expect(find.text("No results for 'zzz'"), findsNothing);

    // A pause means the search ran and matched nothing.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("No results for 'zzz'"), findsOneWidget);
    expect(
      find.text('Check the spelling or try a broader word.'),
      findsOneWidget,
    );
    // Dead end still offers a way forward: categories, from the shared rail.
    expect(find.text('Or browse by category'), findsOneWidget);
    expect(find.byType(CategoryChip), findsWidgets);

    // Clearing drops straight back to the idle state.
    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(find.byType(StatusView), findsNothing);
    expect(find.text('Start searching'), findsOneWidget);
  });

  testWidgets('submitting the query shows no results immediately',
      (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'qqqq');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(find.text("No results for 'qqqq'"), findsOneWidget);
  });
}
