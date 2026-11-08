import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/addresses.dart';
import 'package:growbox/data/app_state.dart';
import 'package:growbox/screens/home_screen.dart';
import 'package:growbox/screens/login_screen.dart';
import 'package:growbox/screens/onboarding_screen.dart';
import 'package:growbox/tabs.dart';
import 'package:growbox/theme.dart';
import 'package:growbox/widgets/root_shell.dart';

/// Back must never be able to throw a customer out of the app by surprise.
///
/// Every test here sends a real system back through
/// `tester.binding.handlePopRoute()` (what Android sends, and what the iOS
/// swipe and the browser's Back end up calling), rather than tapping a button,
/// because the bug was in the route stack and not in any one widget.
void main() {
  late ThemeNotifier theme;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tabNavigator.reset();
    theme = ThemeNotifier(initialMode: ThemeMode.light);
  });

  tearDown(() => theme.dispose());

  Widget harness({Widget home = const RootShell()}) {
    return ChangeNotifierProvider(
      create: (_) => CartNotifier(),
      child: ThemeProvider(
        notifier: theme,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
          home: home,
        ),
      ),
    );
  }

  /// One system back press, followed by the frames it causes.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<void> openShell(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    // The feed's simulated latency plus its entrance animations.
    await tester.pumpAndSettle();
  }

  testWidgets('back on Search, Cart or Profile goes to Home first',
      (tester) async {
    await openShell(tester);

    for (final tab in [AppTab.search, AppTab.cart, AppTab.profile]) {
      tabNavigator.select(tab);
      await tester.pumpAndSettle();
      expect(tabNavigator.tab, tab);

      await pressBack(tester);

      // Home, not the exit prompt and not a popped route: the shell is still
      // the first route and nothing was removed.
      expect(tabNavigator.tab, AppTab.home);
      expect(find.byType(RootShell), findsOneWidget);
      expect(find.text('Press back again to exit'), findsNothing);
    }
  });

  testWidgets('back on Home asks once, and a second press exits',
      (tester) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await openShell(tester);

    await pressBack(tester);

    // The app is still here, and it says what the next press will do.
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(platformCalls.any((c) => c.method == 'SystemNavigator.pop'), isFalse);

    await pressBack(tester);

    expect(platformCalls.any((c) => c.method == 'SystemNavigator.pop'), isTrue);
  });

  testWidgets('the exit prompt expires after two seconds', (tester) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await openShell(tester);
    await pressBack(tester);
    expect(find.text('Press back again to exit'), findsOneWidget);

    // Past the window: a press now only re-arms the prompt instead of leaving.
    await tester.pump(const Duration(seconds: 3));
    await pressBack(tester);

    expect(platformCalls.any((c) => c.method == 'SystemNavigator.pop'), isFalse);
    expect(find.text('Press back again to exit'), findsOneWidget);
  });

  testWidgets('back on a pushed screen pops one level, then reaches Home',
      (tester) async {
    await openShell(tester);

    // A real pushed screen, opened the way the app opens them: on the root
    // navigator, above the shell.
    Navigator.of(tester.element(find.byType(HomeScreen))).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('pushed screen')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('pushed screen'), findsOneWidget);

    await pressBack(tester);

    // One level, not the whole stack and not the app.
    expect(find.text('pushed screen'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Press back again to exit'), findsNothing);

    // And now Home's own policy applies.
    await pressBack(tester);
    expect(find.text('Press back again to exit'), findsOneWidget);
  });

  testWidgets('a sheet closes before the screen under it', (tester) async {
    await openShell(tester);

    final navigator = Navigator.of(tester.element(find.byType(HomeScreen)));
    navigator.push(
      MaterialPageRoute(
        builder: (sheetContext) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: sheetContext,
                builder: (_) => const SizedBox(
                  height: 200,
                  child: Text('sheet body'),
                ),
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsOneWidget);

    await pressBack(tester);

    // The sheet, and only the sheet.
    expect(find.text('sheet body'), findsNothing);
    expect(find.text('open sheet'), findsOneWidget);

    await pressBack(tester);

    expect(find.text('open sheet'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('after signing in, back on Home never returns to the login form',
      (tester) async {
    // A browsing area answers the gate's "do we know where you are" question,
    // so signing in lands on Home instead of the first-run location step.
    await browsingAreaStore.setArea('Kigali');
    // Onboarding done and an area known: the two other facts the gate reads.
    await OnboardingScreen.markCompleted();
    await tester.pumpWidget(harness(home: const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter your email address')
          .first,
      'tester@growbox.app',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter your password').first,
      'secret123',
    );
    await tester.tap(find.text('Log in'));
    // The mock sign-in waits a second, then the gate resolves with no splash.
    await tester.pump(const Duration(seconds: 1));
    // The gate resolves from storage (a microtask) and then pushes with zero
    // splash dwell; a couple of frames covers both.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(RootShell), findsOneWidget);

    await pressBack(tester);

    // Home, not the form that is no longer signed in.
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    // First press is still inside the shell, so it only arms the exit prompt.
    expect(find.text('Press back again to exit'), findsOneWidget);
  });
}
