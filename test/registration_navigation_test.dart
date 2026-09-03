import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growbox/screens/registration_screen.dart';

void main() {
  testWidgets('Continue with Email advances to the email step', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
    await tester.pump(const Duration(milliseconds: 50));

    // Welcome step is visible.
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);

    // Make sure the CTA is on screen, then tap it.
    await tester.ensureVisible(find.text('Continue with Email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Email'));
    await tester.pump();
    await tester.pumpAndSettle();

    // The email step should now be visible: an email field and a
    // "Continue" button; the welcome CTA should be gone. (Regression
    // guard: the mid-animation rebuild that inserts the back button
    // used to reset the PageView back to the welcome step.)
    final pv = tester.widget<PageView>(find.byType(PageView));
    expect(pv.controller?.page, 1.0,
        reason: 'PageView should have settled on the email step');
    expect(find.byType(TextField), findsOneWidget,
        reason: 'Email input field should be visible on the email step');
    expect(find.text('Continue with Email'), findsNothing,
        reason: 'Welcome step should no longer be visible');
  });
}