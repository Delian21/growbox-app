import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Theme Notifier – controls light/dark mode across the app
// ---------------------------------------------------------------------------

/// InheritedNotifier that lets any widget read + toggle the current theme.
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
  ThemeNotifier() : super(ThemeMode.system);

  bool get isDark => value == ThemeMode.dark;

  void toggle() {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
    _updateSystemUI(value);
  }

  void setDark(bool dark) {
    value = dark ? ThemeMode.dark : ThemeMode.light;
    _updateSystemUI(value);
  }

  void _updateSystemUI(ThemeMode mode) {
    final isDark = mode == ThemeMode.dark;
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

  // ── Brand / Primary ─────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1C4815);
  static const Color primaryLight = Color(0xFF9AEB8D);
  static const Color primaryDark = Color(0xFF1F880E);
  static const Color accent = Color(0xFF16A34A);

  // ── Neutral / Grey ──────────────────────────────────────────────────────
  static const Color white = Colors.white;
  static const Color black = Colors.black;
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
  static const Color warning = Color(0xFFF4C430);
  static const Color info = Color(0xFF292D32);

  // ── Misc ────────────────────────────────────────────────────────────────
  static const Color divider = Color(0xFFE5E7EB);
  static const Color shimmer = Color(0xFFEDEDED);
  static const Color warningYellow = Color(0xFF747100);
  static const Color gold = Color(0xFFA37C1E);

  // ── Warm backgrounds (neumorphism base) ────────────────────────────────
  static const Color background = Color(0xFFFAFAF5);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color borderWarm = Color(0xFFE8E5DE);
  static const Color textSoft = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0xFF6B7268);
  static const Color primarySoft = Color(0xFFE8F5E2);
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
      color: context != null ? C.primaryLight(context) : AppColors.primaryLight,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: context != null ? buttonShadows(context) : button,
    );
  }

  static BoxDecoration chipDecoration({bool selected = false, BuildContext? context}) {
    return BoxDecoration(
      color: selected
          ? (context != null ? C.primaryLight(context) : AppColors.primarySoft)
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

  // ── Brand / Primary (brighter for dark backgrounds) ─────────────────────
  static const Color primary = Color(0xFF2D6B22);
  static const Color primaryLight = Color(0xFF1A3D15);
  static const Color primaryDark = Color(0xFF3EC930);
  static const Color accent = Color(0xFF4ADE80);

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFBDBDBD);
  static const Color textMuted = Color(0xFF808080);

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
      _isDark(context) ? AppDarkColors.background : AppColors.white;

  static Color surface(BuildContext context) =>
      _isDark(context) ? AppDarkColors.surface : AppColors.white;

  static Color surfaceLight(BuildContext context) =>
      _isDark(context) ? AppDarkColors.surfaceLight : AppColors.grey100;

  static Color surfaceLighter(BuildContext context) =>
      _isDark(context) ? AppDarkColors.surfaceLighter : AppColors.grey200;

  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? AppDarkColors.textPrimary : AppColors.black;

  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? AppDarkColors.textSecondary : AppColors.grey700;

  static Color textMuted(BuildContext context) =>
      _isDark(context) ? AppDarkColors.textMuted : AppColors.grey800;

  static Color divider(BuildContext context) =>
      _isDark(context) ? AppDarkColors.divider : AppColors.divider;

  static Color primary(BuildContext context) =>
      _isDark(context) ? AppDarkColors.primary : AppColors.primary;

  static Color primaryLight(BuildContext context) =>
      _isDark(context) ? AppDarkColors.primaryLight : AppColors.primaryLight;

  static Color primaryDark(BuildContext context) =>
      _isDark(context) ? AppDarkColors.primaryDark : AppColors.primaryDark;

  static Color accent(BuildContext context) =>
      _isDark(context) ? AppDarkColors.accent : AppColors.accent;

  static Color success(BuildContext context) =>
      _isDark(context) ? AppDarkColors.success : AppColors.success;

  static Color error(BuildContext context) =>
      _isDark(context) ? AppDarkColors.error : AppColors.error;

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
    fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.black);
  static TextStyle headingMedium = GoogleFonts.poppins(
    fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.black);
  static TextStyle headingSmall = GoogleFonts.poppins(
    fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.black);
  static TextStyle title = GoogleFonts.poppins(
    fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.black);

  // ── Body text (Inter) ───────────────────────────────────────────────────
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.normal, color: AppColors.black);
  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.black);
  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.black);

  // ── Labels (Inter, semi-bold) ───────────────────────────────────────────
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.black);
  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.black);
  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.grey700);

  // ── Misc (Inter) ────────────────────────────────────────────────────────
  static TextStyle subtitle = GoogleFonts.inter(
    fontSize: 16, color: AppColors.grey800);
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 13, color: AppColors.grey900);
  static TextStyle link = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent,
    decoration: TextDecoration.underline);
  static TextStyle navLabel = GoogleFonts.inter(
    fontSize: 12, color: AppColors.info);
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
      backgroundColor: context != null ? C.primaryLight(context) : AppColors.primaryLight,
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
