import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/screens/home_screen.dart';
import 'package:growbox/widgets/vendor_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('vendor feed has one rating style, fee labels and an end note',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // One card per vendor plus the end-of-list note.
    expect(find.byType(VendorCard), findsNWidgets(7));

    // Exactly one rating surface: the pill with the percentage.
    expect(find.text('84%'), findsOneWidget);
    expect(find.textContaining('liked'), findsNothing);

    // Vendors without a rating get the "New" tag in the same slot.
    expect(find.text('New'), findsNWidgets(3));

    // Delivery fee is labelled, and free delivery is called out.
    expect(find.text('₦500 delivery'), findsWidgets);
    expect(find.text('Free delivery'), findsOneWidget);

    // Category line sits under the vendor name.
    expect(find.text('Fruits · Vegetables'), findsWidgets);

    // The list closes with a message rather than a bare card.
    expect(find.textContaining('every vendor nearby'), findsOneWidget);
  });
}
