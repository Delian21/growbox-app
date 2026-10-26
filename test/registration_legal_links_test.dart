import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:growbox/screens/cookies_screen.dart';
import 'package:growbox/screens/privacy_policy_screen.dart';
import 'package:growbox/screens/registration_screen.dart';
import 'package:growbox/screens/terms_screen.dart';
import 'package:growbox/theme.dart';

Future<void> _pumpRegistration(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1200);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      home: const RegistrationScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

/// The consent sentence exactly as it should read, in the same words checkout
/// uses: "By `action`, you agree to our …".
const String kConsentSentence =
    'By continuing, you agree to our Terms & Conditions, Privacy Policy and '
    'Cookies Policy.';

/// The whole legal sentence as rendered, plain text.
String _legalText(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .firstWhere((r) => r.text.toPlainText().contains("By continuing,"))
    .text
    .toPlainText();

/// The legal sentence is one [RichText]; pull the span whose text matches.
TextSpan _spanFor(WidgetTester tester, String text) {
  final rich = tester
      .widgetList<RichText>(find.byType(RichText))
      .firstWhere((r) => r.text.toPlainText().contains('By continuing,'));

  TextSpan? found;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text == text) {
      found = span;
      return false;
    }
    return true;
  });
  expect(found, isNotNull, reason: 'no span reading "$text"');
  return found!;
}

void main() {
  testWidgets('the terms link opens the Terms & Conditions page',
      (tester) async {
    await _pumpRegistration(tester);

    await tester.tapOnText(find.textRange.ofSubstring('Terms & Conditions'));
    await tester.pumpAndSettle();

    expect(find.byType(TermsScreen), findsOneWidget);
    expect(find.text('1. About these terms'), findsOneWidget);
  });

  testWidgets('the privacy link opens the Privacy Policy page',
      (tester) async {
    await _pumpRegistration(tester);

    await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(find.text('What we collect'), findsOneWidget);
  });

  testWidgets('the cookies link opens the Cookies Policy page',
      (tester) async {
    await _pumpRegistration(tester);

    await tester.tapOnText(find.textRange.ofSubstring('Cookies Policy'));
    await tester.pumpAndSettle();

    expect(find.byType(CookiesScreen), findsOneWidget);
    expect(find.text('Managing cookies'), findsOneWidget);
  });

  testWidgets('all three links use the theme-aware primary colour',
      (tester) async {
    await _pumpRegistration(tester);

    final context = tester.element(find.byType(RegistrationScreen));
    final primary = C.primary(context);

    expect(_spanFor(tester, 'Terms & Conditions').style!.color, primary);
    expect(_spanFor(tester, 'Privacy Policy').style!.color, primary);
    expect(_spanFor(tester, 'Cookies Policy').style!.color, primary);
    expect(
      _spanFor(tester, 'Terms & Conditions').style!.decoration,
      TextDecoration.underline,
    );

    // Recognizers are real tap targets, not decorative text.
    expect(_spanFor(tester, 'Terms & Conditions').recognizer,
        isA<TapGestureRecognizer>());
    expect(_spanFor(tester, 'Privacy Policy').recognizer,
        isA<TapGestureRecognizer>());
    expect(_spanFor(tester, 'Cookies Policy').recognizer,
        isA<TapGestureRecognizer>());
  });

  testWidgets('the links also appear on the email step', (tester) async {
    await _pumpRegistration(tester);

    await tester.tap(find.text('Continue with Email'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.textRange.ofSubstring('Terms & Conditions'), findsOneWidget);

    await tester.tapOnText(find.textRange.ofSubstring('Terms & Conditions'));
    await tester.pumpAndSettle();
    expect(find.byType(TermsScreen), findsOneWidget);
  });

  testWidgets('welcome, email, password and name all state that same sentence',
      (tester) async {
    await _pumpRegistration(tester);

    // Step 1 – Welcome, which ends in "Continue with Email".
    expect(_legalText(tester), kConsentSentence,
        reason: 'welcome step: the sentence must match checkout word for word');

    // Step 2 – Email.
    await tester.ensureVisible(find.text('Continue with Email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Email'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(_legalText(tester), kConsentSentence, reason: 'email step');

    // Step 3 – Password (password + confirmation).
    await tester.enterText(find.byType(TextField), 'ada@growbox.ng');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(_legalText(tester), kConsentSentence, reason: 'password step');

    // Step 4 – Name.
    await tester.enterText(find.byType(TextField).at(0), 'secret123');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What is your name?'), findsOneWidget);
    expect(_legalText(tester), kConsentSentence, reason: 'name step');

    // The three names are still real links on the last step that shows them.
    expect(_spanFor(tester, 'Terms & Conditions').recognizer,
        isA<TapGestureRecognizer>());
    expect(_spanFor(tester, 'Privacy Policy').recognizer,
        isA<TapGestureRecognizer>());
    expect(_spanFor(tester, 'Cookies Policy').recognizer,
        isA<TapGestureRecognizer>());
  });
}
