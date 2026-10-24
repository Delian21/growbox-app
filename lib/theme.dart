import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Theme Notifier – controls light/dark mode across the app
// ---------------------------------------------------------------------------

/// InheritedNotifier that lets any widget read + change the current theme.
class ThemeProvider extends InheritedNotifier<ThemeNotifier> {
  const ThemeProvider({
    super.key,
    required ThemeNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ThemeNotifier of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProvider>()!.notifier!;
  }
}

class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier({ThemeMode initialMode = ThemeMode.system})
      : super(initialMode) {
    // Apply the chrome for the restored choice, so a saved Dark/Light mode
    // does not start with the wrong status bar.
    _updateSystemUI(initialMode);
  }

  /// SharedPreferences key holding the user's appearance choice.
  static const String _prefsKey = 'theme_mode';

  /// Reads the persisted choice; falls back to [ThemeMode.system].
  static Future<ThemeMode> loadSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _fromStoredName(prefs.getString(_prefsKey));
    } catch (_) {
      return ThemeMode.system;
    }
  }

  static ThemeMode _fromStoredName(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// Applies and persists an explicit choice: System, Light or Dark.
  void select(ThemeMode mode) {
    if (value == mode) return;
    value = mode;
    _persist(mode);
    _updateSystemUI(mode);
  }

  Future<void> _persist(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // Persistence is best-effort; the in-memory choice still applies.
    }
  }

  void _updateSystemUI(ThemeMode mode) {
    // System mode follows the platform, so resolve it rather than assuming
    // light; otherwise a dark device would get a green bar over a dark page.
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: isDark ? AppDarkColors.background : AppColors.primary,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.light,
      systemNavigationBarColor: isDark ? AppDarkColors.background : AppColors.white,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
  }
}

// ---------------------------------------------------------------------------
// Design Tokens – Colors (Light)
// ---------------------------------------------------------------------------
class AppColors {
  AppColors._();

  // ── Brand green: one primary, one tint, one dark surface ────────────────

  /// The brand green. Splash background, branded panels, primary text and
  /// icons. 10.6:1 against white.
  static const Color primary = Color(0xFF1C4815);

  /// The single green tint, for chips, pills, selected states and CTA fills.
  /// Always paired with [textPrimary] or [primary] on top of it.
  static const Color primaryTint = Color(0xFF9AEB8D);

  /// Deep green surface for branded panels that sit behind white text
  /// (bottom nav, hero banners, splash-adjacent blocks). 14.4:1 vs white.
  static const Color surfaceDark = Color(0xFF12300E);

  // ── Surfaces ────────────────────────────────────────────────────────────

  /// Page background behind cards and sheets.
  static const Color background = Color(0xFFFAFAF5);

  /// Card, sheet and dialog surface.
  static const Color cardSurface = Color(0xFFFFFFFF);

  // ── Accent orange (sampled from the Growbox wordmark) ───────────────────

  /// Logo orange. Fills only: price highlights, promo banners, badges,
  /// notification dots. 9.1:1 on the dark background, 2.0:1 on white, so it
  /// is never used for text on light surfaces — use [accentOrangeDeep].
  static const Color accentOrange = Color(0xFFFBA127);

  /// Deep orange for orange text and icons on light surfaces (4.8:1 on the
  /// page background, 5.0:1 on a card). Also the "low stock" label colour.
  static const Color accentOrangeDeep = Color(0xFFB45309);

  // ── Text ────────────────────────────────────────────────────────────────

  static const Color textPrimary = Color(0xFF1A1A1A);

  /// Secondary body text: 6.9:1 on [background], 7.2:1 on a card.
  static const Color textSecondary = Color(0xFF4F5A4C);

  /// Muted labels and captions: 4.7:1 on [background], 5.0:1 on a card.
  static const Color textMuted = Color(0xFF6B7268);

  // ── Status tints (chip and banner backgrounds) ──────────────────────────
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color errorSoft = Color(0xFFFEE2E2);

  // ── Category markers ────────────────────────────────────────────────────
  static const Color categoryGrains = Color(0xFF8D6E63);
  static const Color categoryFruits = Color(0xFFEF5350);
  static const Color categoryLegumes = Color(0xFF66BB6A);
  static const Color categoryVegetables = Color(0xFF43A047);
  static const Color categoryTubers = Color(0xFF8D6E63);
  static const Color categoryProteins = Color(0xFFEF5350);
  static const Color categoryHerbs = Color(0xFF66BB6A);
  static const Color categoryOils = Color(0xFFF9A825);

  // ── Neutral / Grey ──────────────────────────────────────────────────────
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // ── Overlay ramp ────────────────────────────────────────────────────────
  // Alpha-only utilities for scrims, dividers drawn over imagery and tinted
  // glass. These are opacity primitives, not design colours.
  static const Color transparent = Colors.transparent;
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color black26 = Color(0x42000000);
  static const Color black12 = Color(0x1F000000);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEDEDED);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFD7D7D7);
  static const Color grey500 = Color(0xFFBDBDBD);
  static const Color grey600 = Color(0xFF979797);
  static const Color grey700 = Color(0xFF808080);
  static const Color grey800 = Color(0xFF666666);
  static const Color grey900 = Color(0xFF555555);

  // ── Semantic ────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);

  /// Destructive red for dark surfaces. 6.8:1 on the dark page (#121212) and
  /// 6.0:1 on a dark card, where [error] only reaches 3.5:1. Too pale on white
  /// (2.8:1), so light surfaces keep [error]; [C.errorBright] picks per theme.
  static const Color errorBright = Color(0xFFF87171);
  static const Color warning = Color(0xFFF4C430);
  static const Color info = Color(0xFF292D32);

  // ── Misc ────────────────────────────────────────────────────────────────
  static const Color divider = Color(0xFFE5E7EB);
  static const Color shimmer = Color(0xFFEDEDED);
  static const Color warningYellow = Color(0xFF747100);
  static const Color gold = Color(0xFFA37C1E);

}

// ---------------------------------------------------------------------------
// Design Tokens – Neumorphic Shadows & Decorations
// ---------------------------------------------------------------------------

class AppNeumorphic {
  AppNeumorphic._();

  // ── Light-mode shadow presets ──────────────────────────────────────────

  /// Default card: subtle float above background.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D000000), // 5% black
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x08000000), // 3% black
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Pressed / inset card.
  static const List<BoxShadow> cardInset = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// Elevated button / interactive element.
  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color(0x1A000000), // 10% black
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
  ];

  /// Floating action / highlight.
  static const List<BoxShadow> float = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  /// Green glow for primary actions.
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color(0x331C4815), // 20% primary green
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  // ── Dark-mode shadow presets �n  // In dark mode, black shadows vanish against dark backgrounds.
  // Use lighter shadows or slightly boosted opacity instead.

  static List<BoxShadow> get darkCard => const [
    BoxShadow(
      color: Color(0x3D000000), // 24% black (boosted for dark bg)
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x1A000000), // 10% black
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get darkCardInset => const [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get darkButton => const [
    BoxShadow(
      color: Color(0x4D000000), // 30% black
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get darkFloat => const [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get darkPrimaryGlow => const [
    BoxShadow(
      color: Color(0x4D3EC930), // 30% dark primary green
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  // ── Context-aware shadow accessors ──────────────────────────────────────

  static List<BoxShadow> cardShadows(BuildContext context) =>
      C.isDark(context) ? darkCard : card;

  static List<BoxShadow> cardInsetShadows(BuildContext context) =>
      C.isDark(context) ? darkCardInset : cardInset;

  static List<BoxShadow> buttonShadows(BuildContext context) =>
      C.isDark(context) ? darkButton : button;

  static List<BoxShadow> floatShadows(BuildContext context) =>
      C.isDark(context) ? darkFloat : float;

  static List<BoxShadow> primaryGlowShadows(BuildContext context) =>
      C.isDark(context) ? darkPrimaryGlow : primaryGlow;

  // ── Context-aware decoration builders ───────────────────────────────────

  static BoxDecoration cardDecoration({double radius = 16, BuildContext? context}) {
    return BoxDecoration(
      color: context != null ? C.surface(context) : AppColors.cardSurface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: context != null ? cardShadows(context) : card,
    );
  }

  static BoxDecoration buttonDecoration({double radius = 26, BuildContext? context}) {
    return BoxDecoration(
      color: context != null ? C.primaryTint(context) : AppColors.primaryTint,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: context != null ? buttonShadows(context) : button,
    );
  }

  static BoxDecoration chipDecoration({bool selected = false, BuildContext? context}) {
    return BoxDecoration(
      color: selected
          ? (context != null ? C.primaryTint(context) : AppColors.primaryTint)
          : (context != null ? C.surface(context) : AppColors.cardSurface),
      borderRadius: BorderRadius.circular(26),
      boxShadow: selected
          ? (context != null ? primaryGlowShadows(context) : primaryGlow)
          : (context != null ? cardInsetShadows(context) : cardInset),
    );
  }
}

// ---------------------------------------------------------------------------
// Design Tokens – Colors (Dark)
// ---------------------------------------------------------------------------
class AppDarkColors {
  AppDarkColors._();

  // ── Backgrounds ─────────────────────────────────────────────────────────
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2A2A2A);
  static const Color surfaceLighter = Color(0xFF333333);

  /// Deep green for branded panels in dark mode. 13.2:1 vs white text.
  static const Color surfaceDark = Color(0xFF0E2409);

  // ── Brand green: one primary, one tint ──────────────────────────────────

  /// The brand green lifted for dark surfaces: 9.1:1 on a dark card, so it
  /// is safe for icons, labels and prices on [surface].
  static const Color primary = Color(0xFF7ED36B);

  /// The single green tint on dark: chip and pill backgrounds that carry
  /// light text.
  static const Color primaryTint = Color(0xFF1A3D15);

  // ── Accent orange (from the Growbox wordmark) ───────────────────────────
  static const Color accentOrange = Color(0xFFFBA127); // 8.1:1 on a dark card

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F5);   // 15.3:1 on a card
  /// 8.9:1 on a dark card, 10.0:1 on the dark background.
  static const Color textSecondary = Color(0xFFBDBDBD);
  /// 6.4:1 on a dark card, 7.2:1 on the dark background.
  static const Color textMuted = Color(0xFF9AA396);

  // ── Borders & Dividers ──────────────────────────────────────────────────
  static const Color divider = Color(0xFF333333);
  static const Color shimmer = Color(0xFF2A2A2A);
  static const Color border = Color(0xFF404040);

  // ── Semantic (same, but may need adjustments) ───────────────────────────
  static const Color success = Color(0xFF4ADE80);
  static const Color error = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFFE5E5E5);
  static const Color gold = Color(0xFFD4A843);
}

// ---------------------------------------------------------------------------
// Theme-aware color accessor — use this instead of AppColors.xxx
// ---------------------------------------------------------------------------

/// Returns the correct color based on the current brightness.
/// Usage: Theme.of(context).brightness == Brightness.dark ? AppDarkColors.xxx : AppColors.xxx
///
/// For convenience, provide a context-based accessor:
class C {
  C._();

  static Color background(BuildContext context) =>
      _isDark(context) ? AppDarkColors.background : AppColors.background;

  static Color surface(BuildContext context) =>
      _isDark(context) ? AppDarkColors.surface : AppColors.cardSurface;

  static Color surfaceLight(BuildContext context) =>
      _isDark(context) ? AppDarkColors.surfaceLight : AppColors.grey100;

  static Color surfaceLighter(BuildContext context) =>
      _isDark(context) ? AppDarkColors.surfaceLighter : AppColors.grey200;

  static Color surfaceDark(BuildContext context) =>
      _isDark(context) ? AppDarkColors.surfaceDark : AppColors.surfaceDark;

  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? AppDarkColors.textPrimary : AppColors.textPrimary;

  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? AppDarkColors.textSecondary : AppColors.textSecondary;

  static Color textMuted(BuildContext context) =>
      _isDark(context) ? AppDarkColors.textMuted : AppColors.textMuted;

  static Color divider(BuildContext context) =>
      _isDark(context) ? AppDarkColors.divider : AppColors.divider;

  static Color primary(BuildContext context) =>
      _isDark(context) ? AppDarkColors.primary : AppColors.primary;

  static Color primaryTint(BuildContext context) =>
      _isDark(context) ? AppDarkColors.primaryTint : AppColors.primaryTint;

  /// Foreground for content painted on top of [primary].
  ///
  /// The light primary is deep green (white is 10.6:1 on it); the dark primary
  /// is lifted green, where white would be only 1.7:1 — near-black is 10.3:1.
  static Color onPrimary(BuildContext context) =>
      _isDark(context) ? AppDarkColors.background : AppColors.white;

  /// Orange for foregrounds (text, icons). Uses the deep orange on light
  /// surfaces where the bright logo orange would fail contrast.
  static Color accentOrange(BuildContext context) =>
      _isDark(context) ? AppDarkColors.accentOrange : AppColors.accentOrangeDeep;

  static Color success(BuildContext context) =>
      _isDark(context) ? AppDarkColors.success : AppColors.success;

  static Color error(BuildContext context) =>
      _isDark(context) ? AppDarkColors.error : AppColors.error;

  /// Destructive foreground that is readable on the current surface: the
  /// bright red on dark, the standard red on light.
  static Color errorBright(BuildContext context) =>
      _isDark(context) ? AppColors.errorBright : AppColors.error;

  static Color warning(BuildContext context) =>
      _isDark(context) ? AppDarkColors.warning : AppColors.warning;

  static Color gold(BuildContext context) =>
      _isDark(context) ? AppDarkColors.gold : AppColors.gold;

  static Color shimmer(BuildContext context) =>
      _isDark(context) ? AppDarkColors.shimmer : AppColors.shimmer;

  static bool isDark(BuildContext context) => _isDark(context);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}

// ---------------------------------------------------------------------------
// Design Tokens – Typography
// ---------------------------------------------------------------------------
class AppTypography {
  AppTypography._();

  // ── Font families ───────────────────────────────────────────────────────
  // Poppins: headings, titles, buttons (geometric, modern, bold presence)
  // Inter: body text, labels, captions (designed for screens, crisp at small sizes)

  // ── Headings (Poppins) ──────────────────────────────────────────────────
  static TextStyle headingLarge = GoogleFonts.poppins(
    fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static TextStyle headingMedium = GoogleFonts.poppins(
    fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static TextStyle headingSmall = GoogleFonts.poppins(
    fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static TextStyle title = GoogleFonts.poppins(
    fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary);

  // ── Body text (Inter) ───────────────────────────────────────────────────
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.normal, color: AppColors.textPrimary);
  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.textPrimary);
  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary);

  // ── Labels (Inter, semi-bold) ───────────────────────────────────────────
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textSecondary);

  // ── Misc (Inter) ────────────────────────────────────────────────────────
  static TextStyle subtitle = GoogleFonts.inter(
    fontSize: 16, color: AppColors.textSecondary);
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 13, color: AppColors.textMuted);
  static TextStyle link = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accentOrangeDeep,
    decoration: TextDecoration.underline);
  static TextStyle navLabel = GoogleFonts.inter(
    fontSize: 12, color: AppColors.textPrimary);
}

// ---------------------------------------------------------------------------
// Design Tokens – Spacing & Layout
// ---------------------------------------------------------------------------
class AppSpacing {
  AppSpacing._();
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;
}

// ---------------------------------------------------------------------------
// Design Tokens – Border Radii
// ---------------------------------------------------------------------------
class AppRadii {
  AppRadii._();
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 20.0;
  static const double xl = 21.0;
  static const double pill = 26.0;
  static const double circle = 999.0;
}

// ---------------------------------------------------------------------------
// Design Tokens – Decorations
// ---------------------------------------------------------------------------
class AppDecorations {
  AppDecorations._();

  static InputDecoration inputDecoration({String? hintText, BuildContext? context}) {
    final borderColor = context != null ? C.divider(context) : AppColors.grey600;
    final focusColor = context != null ? C.textPrimary(context) : AppColors.black;
    final hintColor =
        context != null ? C.textMuted(context) : AppColors.grey600;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: hintColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: BorderSide(color: focusColor),
      ),
    );
  }

  static ButtonStyle primaryButtonStyle({double radius = AppRadii.pill, BuildContext? context}) {
    return ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: context != null ? C.primaryTint(context) : AppColors.primaryTint,
      foregroundColor: context != null ? C.textPrimary(context) : AppColors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Formatting Helpers
// ---------------------------------------------------------------------------

/// Format an int price with comma separators (e.g. 2550 → '2,550').
String formatPrice(int price) {
  return price.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}

// ---------------------------------------------------------------------------
// Design Tokens – Responsive sizing helpers
// ---------------------------------------------------------------------------
class AppSizing {
  AppSizing._();

  static double logoAreaHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.34).clamp(210.0, 290.0);
  }

  static double logoAreaHeightLarge(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.36).clamp(200.0, 310.0);
  }

  static double logoWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.88).clamp(220.0, 345.0);
  }

  static double titleFontSize(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.065).clamp(25.0, 28.0);
  }

  static double welcomeFontSize(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.075).clamp(28.0, 32.0);
  }

  static double horizontalPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.045).clamp(16.0, 24.0);
  }

  static double buttonHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.07).clamp(50.0, 52.0);
  }

  static double buttonHeightLarge(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.075).clamp(52.0, 56.0);
  }
}
