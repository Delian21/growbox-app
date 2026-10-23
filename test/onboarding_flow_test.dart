import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/screens/onboarding_screen.dart';
import 'package:growbox/theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('onboarding advances, hides Skip on the last slide',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pump();

    // Three indicators, one per slide.
    expect(find.byType(AnimatedContainer), findsNWidgets(3));

    // First slide: Skip is present and tappable at a full-size target.
    expect(find.text('Fresh Produce,\nDelivered'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    final skipTarget = find.ancestor(
      of: find.text('Skip'),
      matching: find.byType(Container),
    );
    expect(tester.getSize(skipTarget.first).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(skipTarget.first).width, greaterThanOrEqualTo(48));

    // The CTA is the primary green pill.
    final cta = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(cta.style?.backgroundColor?.resolve({}), AppColors.primary);
    final shape = cta.style?.shape?.resolve({}) as RoundedRectangleBorder?;
    expect((shape?.borderRadius as BorderRadius?)?.topLeft.x, AppRadii.pill);

    // Advance to the last slide.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Fast & Reliable\nDelivery'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Delivery slide copy no longer promises live tracking.
    expect(
      find.text('Get your fresh produce delivered right to your doorstep.'),
      findsOneWidget,
    );
    expect(find.textContaining('real-time'), findsNothing);

    // Skip keeps its space but is no longer visible on the last slide.
    final visibility = tester.widget<Visibility>(
      find.ancestor(of: find.text('Skip'), matching: find.byType(Visibility)).first,
    );
    expect(visibility.visible, isFalse);
  });

  testWidgets('CTA and active indicator lift on the dark background',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const OnboardingScreen(),
      ),
    );
    await tester.pump();

    // On dark the deep brand green would vanish, so the CTA flips to the
    // lifted green with dark text.
    final cta = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(cta.style?.backgroundColor?.resolve({}), AppDarkColors.primary);
    expect(cta.style?.foregroundColor?.resolve({}), AppColors.primary);

    // The active indicator uses the same lifted green, not the deep one.
    final activeDot =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    final dotColor = (activeDot.decoration as BoxDecoration).color;
    expect(dotColor, AppDarkColors.primary);
  });
}
