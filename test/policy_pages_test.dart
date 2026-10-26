import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:growbox/routes.dart';
import 'package:growbox/screens/cookies_screen.dart';
import 'package:growbox/screens/privacy_policy_screen.dart';
import 'package:growbox/screens/terms_screen.dart';
import 'package:growbox/theme.dart';

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('terms page renders real terms and returns with back',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                ),
                child: const Text('Open terms'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open terms'));
    await tester.pumpAndSettle();

    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.text('Last updated 25 October 2026'), findsOneWidget);
    expect(find.text('1. About these terms'), findsOneWidget);
    expect(find.text('4. Delivery'), findsOneWidget);
    expect(find.text('5. Cancellations, refunds and replacements'),
        findsOneWidget);
    // The document names a real contact route rather than a placeholder.
    expect(find.textContaining(TermsScreen.supportEmail), findsOneWidget);
    expect(find.textContaining('lorem ipsum'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Open terms'), findsOneWidget);
  });

  testWidgets('privacy page explains data use and the privacy controls',
      (tester) async {
    await _pumpPage(tester, const PrivacyPolicyScreen());

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Last updated 25 October 2026'), findsOneWidget);
    expect(find.text('What we collect'), findsOneWidget);
    expect(find.text('Who we share it with'), findsOneWidget);
    expect(find.text('Your choices'), findsOneWidget);
    expect(find.textContaining('Profile › Manage Privacy'), findsOneWidget);
    expect(find.textContaining(TermsScreen.supportEmail), findsOneWidget);
  });

  testWidgets('long policy text scrolls and reads in the dark theme',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: const TermsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Body copy uses a token that is readable on the dark page.
    final body = tester.widget<Text>(
      find.textContaining('These terms are the agreement').first,
    );
    final context = tester.element(find.byType(TermsScreen));
    expect(body.style!.color, C.textSecondary(context));
    expect(body.style!.color, isNotNull);
  });

  testWidgets('cookies page is short and describes real local storage',
      (tester) async {
    await _pumpPage(tester, const CookiesScreen());

    expect(find.text('Cookies Policy'), findsOneWidget);
    expect(find.text('Last updated 25 October 2026'), findsOneWidget);
    expect(find.text('What GROWBOX stores'), findsOneWidget);
    expect(find.text('What we do not use'), findsOneWidget);
    expect(find.text('Managing cookies'), findsOneWidget);
    expect(find.textContaining('No advertising cookies'), findsOneWidget);
    expect(find.textContaining('Profile › Manage Privacy'), findsWidgets);
    expect(find.textContaining(TermsScreen.supportEmail), findsOneWidget);
  });

  test('legal pages are registered routes', () {
    expect(AppRoutes.routes[AppRoutes.terms], isNotNull);
    expect(AppRoutes.routes[AppRoutes.privacyPolicy], isNotNull);
    expect(AppRoutes.routes[AppRoutes.cookies], isNotNull);
    expect(AppRoutes.terms, isNot(AppRoutes.privacy));
    expect(AppRoutes.cookies, isNot(AppRoutes.privacy));
  });
}
