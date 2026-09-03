import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'data/app_state.dart';
import 'data/mock_data.dart';
import 'screens/splash_screen.dart';
import 'routes.dart';
import 'widgets/page_transitions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Seed mock purchase history for Buy Again + personalisation.
  seedPurchaseHistory();
  StockTracker.seed();

  // Restore persisted user data (profile, addresses, favorites, orders)
  // before the first frame so screens read hydrated state.
  await Future.wait([
    CustomerData.restore(),
    restoreAddresses(),
    restoreFavorites(),
    restoreOrders(),
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.primary,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const GrowboxApp());
}

class GrowboxApp extends StatefulWidget {
  const GrowboxApp({super.key});

  @override
  State<GrowboxApp> createState() => _GrowboxAppState();
}

class _GrowboxAppState extends State<GrowboxApp> {
  final ThemeNotifier _themeNotifier = ThemeNotifier();

  @override
  void dispose() {
    _themeNotifier.dispose();
    super.dispose();
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
        title: 'GROWBOX',
        themeMode: _themeNotifier.value,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: AppColors.white,
              textTheme: GoogleFonts.interTextTheme(
                lightTextBase,
              ).copyWith(
                // Headlines use Poppins
                headlineLarge: GoogleFonts.poppins(
                  fontSize: 32, fontWeight: FontWeight.bold),
                headlineMedium: GoogleFonts.poppins(
                  fontSize: 28, fontWeight: FontWeight.bold),
                headlineSmall: GoogleFonts.poppins(
                  fontSize: 24, fontWeight: FontWeight.bold),
                titleLarge: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold),
                titleMedium: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600),
                titleSmall: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
                // Buttons use Poppins
                labelLarge: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
                labelMedium: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600),
              ),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: SlideFadeTransitionsBuilder(),
                  TargetPlatform.iOS: SlideFadeTransitionsBuilder(),
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
              textTheme: GoogleFonts.interTextTheme(
                darkTextBase,
              ).copyWith(
                headlineLarge: GoogleFonts.poppins(
                  fontSize: 32, fontWeight: FontWeight.bold),
                headlineMedium: GoogleFonts.poppins(
                  fontSize: 28, fontWeight: FontWeight.bold),
                headlineSmall: GoogleFonts.poppins(
                  fontSize: 24, fontWeight: FontWeight.bold),
                titleLarge: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold),
                titleMedium: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600),
                titleSmall: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
                labelLarge: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
                labelMedium: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600),
              ),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: SlideFadeTransitionsBuilder(),
                  TargetPlatform.iOS: SlideFadeTransitionsBuilder(),
                  TargetPlatform.windows: SlideFadeTransitionsBuilder(),
                  TargetPlatform.macOS: SlideFadeTransitionsBuilder(),
                  TargetPlatform.linux: SlideFadeTransitionsBuilder(),
                },
              ),
            ),
            routes: AppRoutes.routes,
            home: const SplashScreen(),
          ),
        );
        },
      ),
    );
  }
}
