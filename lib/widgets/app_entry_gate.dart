import 'package:flutter/material.dart';

import '../data/addresses.dart';
import '../data/session.dart';
import '../screens/login_screen.dart';
import '../screens/location_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/registration_screen.dart';
import '../screens/splash_screen.dart';
import 'root_shell.dart';

/// Where a cold start (or a fresh sign-in) should land.
enum EntryDestination {
  /// First launch: the three intro slides.
  onboarding,

  /// Onboarding seen, nobody signed in: the welcome/sign-up screen.
  welcome,

  /// The session was dropped for being away too long: login with a notice.
  login,

  /// Signed in, but no delivery address and no browsing area yet.
  locationSetup,

  /// Signed in and somewhere to deliver: the app itself.
  home,
}

/// THE entry point. Every cold start and every sign-in goes through here, so
/// there is exactly one place that decides what the customer sees first, and
/// the stack is replaced rather than pushed onto — Back can never return to
/// the splash, the welcome screen or the login form.
///
/// The decision is made from three persisted facts only:
/// 1. `onboardingSeen` — [OnboardingScreen.hasCompleted];
/// 2. a valid session — [SessionStore] (present and not past
///    [kSessionAwayLimit]);
/// 3. a selected address or a browsing area — [addressesStore],
///    [browsingAreaStore].
class AppEntryGate extends StatefulWidget {
  const AppEntryGate({
    super.key,
    this.minimumSplash = const Duration(seconds: 4),
  });

  /// How long the splash stays up. The branding dwell belongs to the cold
  /// start; after sign-in it is zero so the customer does not watch it twice.
  final Duration minimumSplash;

  /// Resolves the destination from storage. Kept public and free of UI so
  /// tests (and the resume path) can ask the same question the gate asks.
  static Future<EntryDestination> resolveDestination() async {
    // Onboarding wins before anything else: a first-run customer has no
    // session to judge, and the slides are what introduces the product.
    final hasSeenOnboarding = await OnboardingScreen.hasCompleted();
    if (!hasSeenOnboarding) return EntryDestination.onboarding;

    // Drop a session that outlived the away limit and say why on the way in.
    final expired = await SessionStore.clearIfExpired();
    if (expired) return EntryDestination.login;
    if (!SessionStore.isSignedIn) return EntryDestination.welcome;

    // Restore both stores before deciding: "no address" must mean "nothing
    // saved", not "not loaded yet".
    await addressesStore.load();
    await browsingAreaStore.load();
    final hasPlace = addressesStore.selectedAddress != null ||
        browsingAreaStore.hasArea;
    return hasPlace ? EntryDestination.home : EntryDestination.locationSetup;
  }

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final destination = await AppEntryGate.resolveDestination();

    // Let the splash finish its dwell even if storage answered instantly, so
    // the branding does not flash.
    if (widget.minimumSplash > Duration.zero) {
      await Future<void>.delayed(widget.minimumSplash);
    }
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => _screenFor(destination)),
      // Removes the gate and the splash behind it.
      (route) => false,
    );
  }

  Widget _screenFor(EntryDestination destination) {
    switch (destination) {
      case EntryDestination.onboarding:
        return const OnboardingScreen();
      case EntryDestination.welcome:
        return const RegistrationScreen();
      case EntryDestination.login:
        return LoginScreen(notice: SessionStore.signedOutNotice);
      case EntryDestination.locationSetup:
        // First-run flavour: saving or picking an address finishes setup by
        // going Home instead of popping back to a form.
        return const LocationScreen(isFirstRun: true);
      case EntryDestination.home:
        // The signed-in app is one shell with four tabs; Home is its first tab.
        return const RootShell();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The branding screen doubles as the "resolving" state.
    return const SplashScreen();
  }
}
