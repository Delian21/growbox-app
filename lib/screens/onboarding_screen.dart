import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'registration_screen.dart';

/// Shows the onboarding flow on first launch.
/// Returns the user's destination widget after onboarding completes.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  /// Check if onboarding has been completed.
  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  /// Mark onboarding as completed.
  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 3;

  /// Content column cap, so the flow doesn't stretch edge to edge on tablets
  /// and desktop windows.
  static const double _contentMaxWidth = 480;

  /// Title/body measure: long lines are hard to read past roughly this width.
  static const double _textMaxWidth = 320;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _skip() async {
    await OnboardingScreen.markCompleted();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegistrationScreen()),
      );
    }
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _getStarted();
    }
  }

  void _getStarted() async {
    await OnboardingScreen.markCompleted();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegistrationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLastPage = _currentPage == _totalPages - 1;

    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: Column(
              children: [
                // ── Skip button ──────────────────────────────────────
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
                    // Hidden on the last slide, but the space is kept so the
                    // pages don't jump upwards when it disappears.
                    child: Visibility(
                      visible: !isLastPage,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: GestureDetector(
                        onTap: _skip,
                        // 48dp minimum touch target, even though the label
                        // itself is only a word.
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 64,
                            minHeight: 48,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text(
                            'Skip',
                            style: AppTypography.labelLarge.copyWith(
                              color: C.textPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Page view ────────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _totalPages,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (context, index) =>
                        _buildPage(index, screenHeight),
                  ),
                ),
                // ── Bottom section (dots + button) ───────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    0,
                    AppSpacing.xxl,
                    AppSpacing.huge,
                  ),
                  child: Column(
                    children: [
                      _buildDotIndicators(context),
                      const SizedBox(height: AppSpacing.xxxl),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: _ctaStyle(context),
                          child: Text(
                            isLastPage ? 'Get Started' : 'Next',
                            style: AppTypography.labelLarge
                                .copyWith(color: _ctaForeground(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Same primary CTA shape as the welcome screen's "Continue with Email"
  /// (pill, full width, bold label) but theme-aware: on the dark background
  /// the deep brand green would disappear, so it flips to the lifted green
  /// with dark text instead of staying white-on-dark-green.
  ButtonStyle _ctaStyle(BuildContext context) {
    return ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: C.primary(context),
      foregroundColor: _ctaForeground(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    );
  }

  Color _ctaForeground(BuildContext context) =>
      C.isDark(context) ? AppColors.primary : AppColors.white;

  Widget _buildPage(int index, double screenHeight) {
    final pages = [
      const _OnboardingPageData(
        icon: Icons.shopping_basket_outlined,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryTint,
        title: 'Fresh Produce,\nDelivered',
        imagePath: null, // drop a bundled illustration path here later
        subtitle:
            'Browse farm-fresh vegetables, fruits, grains and more from local vendors near you.',
      ),
      const _OnboardingPageData(
        icon: Icons.storefront_outlined,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryTint,
        title: 'Browse Local\nVendors',
        imagePath: null,
        subtitle:
            'Discover trusted vendors in your area. Compare prices, read reviews, and find the best deals.',
      ),
      const _OnboardingPageData(
        icon: Icons.local_shipping_outlined,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryTint,
        title: 'Fast & Reliable\nDelivery',
        imagePath: null,
        subtitle:
            'Get your fresh produce delivered right to your doorstep.',
      ),
    ];

    final page = pages[index];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Aim for 40% of the screen, but never eat the space the title and
        // body need on short viewports.
        final double maxHero = (constraints.maxHeight - 190).clamp(140.0, 400.0);
        final double targetHero = screenHeight * 0.40;
        final double heroHeight =
            targetHero <= maxHero ? targetHero : maxHero;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hero area — one widget per slide, ready for an illustration
                // (see [_OnboardingPageData.imagePath]).
                SizedBox(
                  height: heroHeight,
                  child: Center(
                    child: _OnboardingVisual(
                      icon: page.icon,
                      imagePath: page.imagePath,
                      size: heroHeight * 0.82,
                      backgroundColor: page.iconBgColor,
                      iconColor: page.iconColor,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _textMaxWidth),
                  child: Column(
                    children: [
                      Text(
                        page.title,
                        textAlign: TextAlign.center,
                        style: AppTypography.headingMedium.copyWith(
                          color: C.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        page.subtitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge.copyWith(
                          fontSize: 15,
                          height: 1.5,
                          color: C.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDotIndicators(BuildContext context) {
    final Color activeColor = C.primary(context);
    final Color inactiveColor =
        C.textMuted(context).withValues(alpha: 0.45);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalPages, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          width: isActive ? 32 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Slide visual
// ═══════════════════════════════════════════════════════════════════════════

/// Hero artwork for one slide.
///
/// Leave [imagePath] null to show the icon in its tinted circle; set it to a
/// bundled asset and the same slot renders that illustration instead, so the
/// rest of the layout needs no change when art lands.
class _OnboardingVisual extends StatelessWidget {
  final IconData icon;
  final String? imagePath;
  final double size;
  final Color backgroundColor;
  final Color iconColor;

  const _OnboardingVisual({
    required this.icon,
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = imagePath == null
        ? Icon(icon, size: size * 0.45, color: iconColor)
        : Image.asset(
            imagePath!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Icon(icon, size: size * 0.45, color: iconColor),
          );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: content,
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;

  /// Optional bundled illustration. Null keeps the icon treatment.
  final String? imagePath;

  const _OnboardingPageData({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    this.imagePath,
  });
}
