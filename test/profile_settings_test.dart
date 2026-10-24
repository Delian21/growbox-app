import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/screens/account_screen.dart';
import 'package:growbox/screens/edit_profile_screen.dart';
import 'package:growbox/screens/profile_screen.dart';
import 'package:growbox/theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CustomerData.clear();
  });

  Widget profileHarness(ThemeNotifier notifier) {
    return ChangeNotifierProvider(
      create: (_) => CartNotifier(),
      child: ThemeProvider(
        notifier: notifier,
        child: AnimatedBuilder(
          animation: notifier,
          builder: (context, _) => MaterialApp(
            theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
            darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
            themeMode: notifier.value,
            home: const ProfileScreen(),
          ),
        ),
      ),
    );
  }

  Widget accountHarness() {
    return ChangeNotifierProvider(
      create: (_) => CartNotifier(),
      child: const MaterialApp(home: AccountScreen()),
    );
  }

  /// Fill colour of the appearance option carrying [label].
  Color? optionFill(WidgetTester tester, String label) {
    final container = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    return (container.decoration as BoxDecoration).color;
  }

  // ── Appearance ──────────────────────────────────────────────────────────

  testWidgets('appearance selector tracks the theme mode, even on system dark',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final notifier = ThemeNotifier();
    await tester.pumpWidget(profileHarness(notifier));
    await tester.pumpAndSettle();

    // The old switch read `value == ThemeMode.dark`, which is false while the
    // app follows a dark system — it is gone, replaced by three options.
    expect(find.byType(Switch), findsNothing);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    final ctx = tester.element(find.text('System'));
    expect(C.isDark(ctx), isTrue, reason: 'device is dark');
    expect(notifier.value, ThemeMode.system);

    // "System" is the selected option, so the control matches reality.
    expect(optionFill(tester, 'System'), AppDarkColors.primary);
    expect(optionFill(tester, 'Light'), AppColors.transparent);
    expect(optionFill(tester, 'Dark'), AppColors.transparent);
  });

  testWidgets('choosing Light switches the app and persists the choice',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final notifier = ThemeNotifier();
    await tester.pumpWidget(profileHarness(notifier));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Light'));
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(notifier.value, ThemeMode.light);
    expect(C.isDark(tester.element(find.text('Light'))), isFalse);

    final ctx = tester.element(find.text('Light'));
    expect(optionFill(tester, 'Light'), C.primary(ctx));
    expect(optionFill(tester, 'System'), AppColors.transparent);

    // Persisted for the next launch.
    expect(await ThemeNotifier.loadSavedMode(), ThemeMode.light);
  });

  test('a saved choice is restored at startup', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    expect(await ThemeNotifier.loadSavedMode(), ThemeMode.dark);

    SharedPreferences.setMockInitialValues({});
    expect(await ThemeNotifier.loadSavedMode(), ThemeMode.system);
  });

  // ── Delete account ──────────────────────────────────────────────────────

  testWidgets('Delete Account moved to Account settings and needs DELETE',
      (tester) async {
    await tester.pumpWidget(profileHarness(ThemeNotifier()));
    await tester.pumpAndSettle();
    expect(find.text('Delete Account'), findsNothing);

    await tester.pumpWidget(accountHarness());
    await tester.pumpAndSettle();

    final row = find.text('Delete Account');
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();

    final deleteButton = find.widgetWithText(TextButton, 'Delete');
    expect(tester.widget<TextButton>(deleteButton).onPressed, isNull);

    // Wrong case does not unlock it.
    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(tester.widget<TextButton>(deleteButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    expect(tester.widget<TextButton>(deleteButton).onPressed, isNotNull);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // The existing deletion flow opens; nothing about it changed.
    expect(find.text('Right of Cancellation'), findsOneWidget);
  });

  // ── Section spacing ─────────────────────────────────────────────────────

  testWidgets('every section label keeps the same gap above it',
      (tester) async {
    CustomerData.name = 'Ada Obi';
    CustomerData.email = 'ada@example.com';

    await tester.pumpWidget(profileHarness(ThemeNotifier()));
    await tester.pumpAndSettle();

    double gapAboveLabel(String label, Key blockAbove) {
      final blockBottom = tester.getRect(find.byKey(blockAbove)).bottom;
      return tester.getTopLeft(find.text(label)).dy - blockBottom;
    }

    // Including the label directly under the profile card.
    expect(gapAboveLabel('Orders', const ValueKey('profileCard')),
        AppSpacing.xxl);
    expect(gapAboveLabel('Account', const ValueKey('sectionCard-Orders')),
        AppSpacing.xxl);
    expect(gapAboveLabel('Preferences', const ValueKey('sectionCard-Account')),
        AppSpacing.xxl);
  });

  // ── Missing details prompt ──────────────────────────────────────────────

  testWidgets('missing name or email shows a prompt that opens the editor',
      (tester) async {
    await tester.pumpWidget(profileHarness(ThemeNotifier()));
    await tester.pumpAndSettle();

    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Add your name and email'), findsOneWidget);

    await tester.tap(find.text('Add your name and email'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
  });

  testWidgets('editing the profile fills the missing details', (tester) async {
    await tester.pumpWidget(profileHarness(ThemeNotifier()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add your name and email'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Ada Obi');
    await tester.enterText(find.byType(TextField).at(1), 'ada@example.com');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(CustomerData.name, 'Ada Obi');
    expect(CustomerData.email, 'ada@example.com');
    // Back on the profile, now complete.
    expect(find.text('Add your name and email'), findsNothing);
    expect(find.text('ada@example.com'), findsOneWidget);
  });

  testWidgets('prompt stays while only the email is missing', (tester) async {
    CustomerData.name = 'Ada Obi';

    await tester.pumpWidget(profileHarness(ThemeNotifier()));
    await tester.pumpAndSettle();

    expect(find.text('No email added'), findsOneWidget);
    expect(find.text('Add your name and email'), findsOneWidget);
  });

  testWidgets('complete profile shows no prompt', (tester) async {
    CustomerData.name = 'Ada Obi';
    CustomerData.email = 'ada@example.com';

    await tester.pumpWidget(profileHarness(ThemeNotifier()));
    await tester.pumpAndSettle();

    expect(find.text('Add your name and email'), findsNothing);
    expect(find.text('ada@example.com'), findsOneWidget);
  });

  testWidgets('profile card fits a narrow phone with the prompt showing',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // A long name stresses the column beside the avatar and edit button.
    CustomerData.name = 'Adebayo Oluwaseun Chukwuemeka';

    await tester.pumpWidget(profileHarness(ThemeNotifier()));
    await tester.pumpAndSettle();

    // An overflow would have thrown during the pump.
    expect(find.text('Add your name and email'), findsOneWidget);
  });

  // ── Destructive colour ──────────────────────────────────────────────────

  test('errorBright clears 4.5:1 on the dark background', () {
    double contrast(Color a, Color b) {
      final high = a.computeLuminance() > b.computeLuminance()
          ? a.computeLuminance()
          : b.computeLuminance();
      final low = a.computeLuminance() > b.computeLuminance()
          ? b.computeLuminance()
          : a.computeLuminance();
      return (high + 0.05) / (low + 0.05);
    }

    expect(
      contrast(AppColors.errorBright, AppDarkColors.background),
      greaterThanOrEqualTo(4.5),
    );
    // The previous red is the reason the token exists.
    expect(
      contrast(AppColors.error, AppDarkColors.background),
      lessThan(4.5),
    );
  });

  testWidgets('Log Out uses the bright red on a dark surface', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(profileHarness(ThemeNotifier()));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(find.byIcon(Icons.logout_outlined));
    expect(icon.color, AppColors.errorBright);
  });

}
