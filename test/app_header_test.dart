import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:growbox/theme.dart';
import 'package:growbox/widgets/app_header.dart';

/// A pushed-screen shape: header above a scrollable body, inside one Scaffold.
Widget harness({bool dark = false}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor:
          dark ? AppDarkColors.background : AppColors.background,
    ),
    home: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'Account'),
            Expanded(
              child: ListView.builder(
                itemCount: 40,
                itemBuilder: (_, i) => SizedBox(
                  height: 48,
                  child: Text('Row $i'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// `AnimatedContainer` folds `color` into `decoration`, so read it from there.
Color? dividerColour(WidgetTester tester) {
  final divider =
      tester.widget<AnimatedContainer>(find.byKey(AppHeader.dividerKey));
  return (divider.decoration as BoxDecoration?)?.color;
}

void main() {
  testWidgets('title, back target and icons use the primary text token',
      (tester) async {
    await tester.pumpWidget(harness());

    final context = tester.element(find.text('Account'));
    final title = tester.widget<Text>(find.text('Account'));
    expect(title.style!.fontSize, inInclusiveRange(18, 20));
    expect(title.style!.fontWeight, FontWeight.w600);
    expect(title.style!.color, C.textPrimary(context));

    // 48x48 target, and the glyph in textPrimary rather than a dim grey.
    final back = tester.getSize(find
        .ancestor(
          of: find.byIcon(Icons.arrow_back),
          matching: find.byType(SizedBox),
        )
        .first);
    expect(back.width, greaterThanOrEqualTo(48));
    expect(back.height, greaterThanOrEqualTo(48));
    expect(
      tester.widget<Icon>(find.byIcon(Icons.arrow_back)).color,
      C.textPrimary(context),
    );
  });

  testWidgets('the hairline stays hidden until the page scrolls',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(dividerColour(tester), Colors.transparent);

    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(dividerColour(tester), isNot(Colors.transparent));

    // Scrolled back to the top: the header is flush with the content again.
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(dividerColour(tester), Colors.transparent);
  });

  testWidgets('trailing actions keep the title centred', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: AppHeader(
              title: 'My Addresses',
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final titleCentre = tester.getCenter(find.text('My Addresses')).dx;
    final screenCentre = tester.getSize(find.byType(Scaffold)).width / 2;
    expect(titleCentre, closeTo(screenCentre, 1));
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
