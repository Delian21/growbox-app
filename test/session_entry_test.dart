import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/config.dart';
import 'package:growbox/data/addresses.dart';
import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/data/session.dart';
import 'package:growbox/main.dart';
import 'package:growbox/screens/home_screen.dart';
import 'package:growbox/screens/location_screen.dart';
import 'package:growbox/screens/login_screen.dart';
import 'package:growbox/widgets/app_entry_gate.dart';

/// Startup flow, entry gate and the 30-minute away timer.
///
/// Time is injected: [SessionStore.clock] returns [now], and the tests move
/// [now] forward instead of waiting. Nothing here sleeps in real time.
void main() {
  late DateTime now;

  const address = Address(
    id: 'addr-1',
    label: 'Home',
    street: '12 Test Street',
    area: 'Gwarinpa, Abuja',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    now = DateTime(2026, 3, 1, 9);
    SessionStore.clock = () => now;
    await SessionStore.clear();
    CustomerData.clear();
    // Addresses are bucketed per account; give the tests a stable bucket.
    CustomerData.email = 'ada@example.com';
    await addressesStore.load(force: true);
    await browsingAreaStore.setArea('');
  });

  Future<void> seedSession() => SessionStore.start(email: 'ada@example.com');

  Future<void> seedAddress() async {
    await addressesStore.load(force: true);
    await addressesStore.save(address);
  }

  /// The gate on its own, no splash dwell, with just the provider Home needs.
  Widget gateHarness() => ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: const MaterialApp(
          home: AppEntryGate(minimumSplash: Duration.zero),
        ),
      );

  /// Pumps past the gate's async resolve and its push transition. The splash
  /// pulses forever, so `pumpAndSettle` is only safe once it is gone.
  Future<void> settleEntry(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    // Drain the screens' own delayed work (the splash entrance chain and the
    // location screen's simulated 700 ms detection) so no timer is pending
    // when the tree is disposed.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('cold start with a valid session lands on Home', (tester) async {
    await seedSession();
    await seedAddress();

    await tester.pumpWidget(gateHarness());
    await settleEntry(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LocationScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('signed in but no address or area opens first-run setup', (
    tester,
  ) async {
    await seedSession();

    await tester.pumpWidget(gateHarness());
    await settleEntry(tester);

    final screen = tester.widget<LocationScreen>(find.byType(LocationScreen));
    expect(screen.isFirstRun, isTrue);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('cold start past the limit lands on login with the message', (
    tester,
  ) async {
    await seedSession();
    await seedAddress();

    // A real cold start: the session is only in storage, and the clock has
    // moved past the limit since it was written.
    now = now.add(kSessionAwayLimit + const Duration(minutes: 5));
    await SessionStore.restore();

    await tester.pumpWidget(gateHarness());
    await settleEntry(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text(
        'You were signed out after 30 minutes away. Please log in again.',
      ),
      findsOneWidget,
    );
    expect(SessionStore.isSignedIn, isFalse);
  });

  testWidgets('first-run location save lands on Home', (tester) async {
    await seedSession();
    await seedAddress();

    // Setup opened as its own root: finishing must go Home, not pop back to
    // a sign-up form the customer already left.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: const MaterialApp(home: LocationScreen(isFirstRun: true)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Home'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LocationScreen), findsNothing);
    expect(addressesStore.selectedAddress?.id, 'addr-1');
  });

  testWidgets('opening the sheet from the Home header only pops', (
    tester,
  ) async {
    await seedAddress();
    Address? chosen;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                chosen = await Navigator.of(context).push<Address?>(
                  MaterialPageRoute(builder: (_) => const LocationScreen()),
                );
              },
              child: const Text('open location'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open location'));
    await tester.pumpAndSettle();

    // The saved address sits in the sheet's scrollable list.
    await tester.ensureVisible(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(LocationScreen), findsNothing);
    expect(find.text('open location'), findsOneWidget);
    expect(chosen?.id, 'addr-1');
    expect(find.byType(HomeScreen), findsNothing);
  });

  group('away timer', () {
    /// Boots the real app so the lifecycle observer and the gate are both live.
    Future<void> bootApp(WidgetTester tester) async {
      await tester.pumpWidget(const GrowboxApp());
      // The gate's 4 s dwell (the splash is animated forever, so no
      // pumpAndSettle until it is off screen).
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    }

    testWidgets('within the limit the customer stays signed in', (
      tester,
    ) async {
      await seedSession();
      await seedAddress();
      await bootApp(tester);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(kSessionAwayLimit - const Duration(minutes: 1));
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(SessionStore.isSignedIn, isTrue);
    });

    testWidgets('past the limit the session is dropped and login explains', (
      tester,
    ) async {
      await seedSession();
      await seedAddress();
      await bootApp(tester);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(kSessionAwayLimit + const Duration(minutes: 1));
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text(
          'You were signed out after 30 minutes away. Please log in again.',
        ),
        findsOneWidget,
      );
      expect(SessionStore.isSignedIn, isFalse);

      // Only the session was cleared: the address survived the sign-out.
      expect(addressesStore.addresses.map((a) => a.id), contains('addr-1'));
    });

    /// The exact sequence a phone emits around a notification: background,
    /// a long silence, then a tap that brings the app back. Nothing here is
    /// platform-specific — these are the lifecycle states Flutter reports on
    /// both Android and iOS, so the rule is one rule everywhere.
    testWidgets('backgrounded past the limit, then opened from a notification', (
      tester,
    ) async {
      await seedSession();
      await seedAddress();
      await bootApp(tester);

      // Leaving the app: inactive → hidden → paused.
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();

      // The background stamp is the moment they left, not the last touch.
      expect(SessionStore.session?.lastActiveAt, now);

      now = now.add(kSessionAwayLimit + const Duration(minutes: 2));

      // A notification tap: the app briefly reads as inactive while the
      // system shade is up, then resumes with the notification's route.
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text(
          'You were signed out after 30 minutes away. Please log in again.',
        ),
        findsOneWidget,
      );
      expect(find.byType(HomeScreen), findsNothing);
      expect(SessionStore.isSignedIn, isFalse);
    });

    testWidgets('backgrounded briefly, then opened from a notification', (
      tester,
    ) async {
      await seedSession();
      await seedAddress();
      await bootApp(tester);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      now = now.add(kSessionAwayLimit - const Duration(minutes: 5));

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Still signed in, and still on the screen they left — a resume is not
      // a restart.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(SessionStore.isSignedIn, isTrue);
      expect(SessionStore.session?.lastActiveAt, now);
    });
  });
}
