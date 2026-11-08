import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'data/addresses.dart';
import 'data/app_state.dart';
import 'data/mock_data.dart';
import 'data/orders.dart';
import 'data/session.dart';
import 'screens/login_screen.dart';
import 'routes.dart';
import 'services/connectivity.dart';
import 'widgets/app_entry_gate.dart';
import 'widgets/offline_banner.dart';
import 'widgets/page_transitions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Any widget that fails to build (the map platform view is the usual
  // suspect when the Maps JavaScript key is missing on web) would otherwise
  // paint Flutter's stock grey "Sorry! Something went wrong" panel. Swap it
  // for an on-brand state so a failure never looks like a broken app.
  ErrorWidget.builder = (FlutterErrorDetails details) =>
      const BrandedErrorView();

  // Seed mock purchase history for Buy Again + personalisation.
  seedPurchaseHistory();
  StockTracker.seed();

  // Restore persisted user data (profile, favorites, orders) before the first
  // frame so screens read hydrated state.
  await Future.wait([
    CustomerData.restore(),
    restoreFavorites(),
    restoreOrders(),
    // Session before the first frame, so the entry gate can decide
    // synchronously-ish and an expired session is already dropped.
    SessionStore.restore(),
  ]);

  // Addresses are restored through their repository, after the profile: the
  // storage bucket is chosen from the logged-in account.
  await addressesStore.load();
  await browsingAreaStore.load();

  // Orders are read through the repository-backed store; warm it up so the
  // home banner and orders screen have data on their first frame.
  await ordersStore.load();

  // Listen for the browser's online/offline events before the first frame, so
  // the banner is correct the moment the app opens.
  connectivityStore.start();

  // Restore the appearance choice before the first frame, so a user who picked
  // Dark never sees a light flash on launch.
  final savedThemeMode = await ThemeNotifier.loadSavedMode();

  runApp(GrowboxApp(initialThemeMode: savedThemeMode));
}

class GrowboxApp extends StatefulWidget {
  /// Appearance restored from storage; defaults to following the device.
  final ThemeMode initialThemeMode;

  const GrowboxApp({super.key, this.initialThemeMode = ThemeMode.system});

  @override
  State<GrowboxApp> createState() => _GrowboxAppState();
}

class _GrowboxAppState extends State<GrowboxApp> with WidgetsBindingObserver {
  late final ThemeNotifier _themeNotifier = ThemeNotifier(
    initialMode: widget.initialThemeMode,
  );

  /// Lets the away-timer replace the stack with the login screen from outside
  /// the widget tree (the app lifecycle callback has no BuildContext).
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeNotifier.dispose();
    super.dispose();
  }

  /// Away-timer.
  ///
  /// Leaving the app stamps `lastActiveAt`; coming back compares now against
  /// it. Staying in the app never triggers this path, so nobody is signed out
  /// while the app is open and in use.
  /// The state before the current one, so [inactive] can be told apart from
  /// the same state when it is the *return* transition.
  AppLifecycleState? _previousLifecycle;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = _previousLifecycle;
    _previousLifecycle = state;

    switch (state) {
      case AppLifecycleState.inactive:
        // `inactive` opens every leave (resumed → inactive → hidden/paused)
        // and every return (paused → inactive → resumed). Stamping on return
        // would reset the away window the moment the app comes back, which is
        // exactly when it has to be measured. So only a leave from a resumed
        // app writes here; being visible-but-inactive (control centre, a
        // permission dialog) is a real pause of activity.
        if (previous == null || previous == AppLifecycleState.resumed) {
          SessionStore.markActive(force: true);
        }
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Genuinely backgrounded: the exact moment the customer left.
        SessionStore.markActive(force: true);
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _onResumed() async {
    final signedOut = await SessionStore.clearIfExpired();
    if (!mounted) return;
    if (signedOut) {
      // Only the session was cleared: cart, addresses, selected address,
      // theme and onboardingSeen stay exactly as they were.
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginScreen(notice: SessionStore.signedOutNotice),
        ),
        (route) => false,
      );
      return;
    }
    // Still inside the window: keep the customer signed in and where they
    // were. Re-running the gate here would throw away in-progress work (a half
    // filled checkout), so the gate's rule is only applied on entry.
    await SessionStore.markActive(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      notifier: _themeNotifier,
      child: AnimatedBuilder(
        animation: _themeNotifier,
        builder: (context, _) {
          // Google Fonts text themes need a base whose colors match the
          // theme brightness. The ambient Theme.of(context) here resolves to
          // the default *light* text theme (near-black), which made dark-mode
          // text that relies on theme defaults — e.g. TextField input and
          // hint text — render black on black.
          final lightTextBase = ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
          ).textTheme;
          final darkTextBase = ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
          ).textTheme;
          return ChangeNotifierProvider(
            create: (_) => CartNotifier(),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Growbox',
              navigatorKey: _navigatorKey,
              navigatorObservers: [routeObserver],
              // The offline banner sits above the navigator and pushes the
              // current screen down, so no header or nav is ever covered.
              //
              // The Listener around everything is the "still here" heartbeat:
              // any touch refreshes lastActiveAt, throttled to once a minute
              // inside SessionStore so scrolling does not write constantly.
              builder: (context, child) => Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => SessionStore.markActive(),
                child:
                    OfflineBannerHost(child: child ?? const SizedBox.shrink()),
              ),
              themeMode: _themeNotifier.value,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                  brightness: Brightness.light,
                ),
                scaffoldBackgroundColor: AppColors.background,
                textTheme: GoogleFonts.interTextTheme(lightTextBase).copyWith(
                  // Headlines use Poppins
                  headlineLarge: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  headlineMedium: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  headlineSmall: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  titleLarge: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  titleMedium: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  titleSmall: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  // Buttons use Poppins
                  labelLarge: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  labelMedium: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: SlideFadeTransitionsBuilder(),
                    // Cupertino on iOS: that builder is what installs the
                    // edge-swipe back gesture on a pushed route. The app's
                    // slide-fade has no interactive dismiss, so swiping back
                    // did nothing on iOS.
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.windows: SlideFadeTransitionsBuilder(),
                    TargetPlatform.macOS: SlideFadeTransitionsBuilder(),
                    TargetPlatform.linux: SlideFadeTransitionsBuilder(),
                  },
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: AppDarkColors.background,
                textTheme: GoogleFonts.interTextTheme(darkTextBase).copyWith(
                  headlineLarge: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  headlineMedium: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  headlineSmall: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  titleLarge: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  titleMedium: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  titleSmall: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  labelLarge: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  labelMedium: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: SlideFadeTransitionsBuilder(),
                    // Cupertino on iOS: that builder is what installs the
                    // edge-swipe back gesture on a pushed route. The app's
                    // slide-fade has no interactive dismiss, so swiping back
                    // did nothing on iOS.
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.windows: SlideFadeTransitionsBuilder(),
                    TargetPlatform.macOS: SlideFadeTransitionsBuilder(),
                    TargetPlatform.linux: SlideFadeTransitionsBuilder(),
                  },
                ),
              ),
              routes: AppRoutes.routes,
              // One gate for every cold start: it shows the splash, reads the
              // persisted facts and replaces the stack with the destination.
              home: const AppEntryGate(),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error fallback
// ---------------------------------------------------------------------------

/// On-brand replacement for Flutter's default error panel.
///
/// Deliberately dependency-free: no GoogleFonts, no Theme lookup, no Material
/// ancestors. An error widget runs in a broken subtree, so anything it needs
/// from its surroundings may itself be the thing that failed.
class BrandedErrorView extends StatelessWidget {
  const BrandedErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: AppColors.errorSoft,
        padding: const EdgeInsets.all(AppSpacing.lg),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 28, color: AppColors.error),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'This part could not load. Try again in a moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
