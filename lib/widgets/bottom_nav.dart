import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'micro_interactions.dart';

// ---------------------------------------------------------------------------
// Layout metrics
// ---------------------------------------------------------------------------

/// Shared measurements for the floating bottom nav.
///
/// The bar floats over the page content instead of taking a slice out of it,
/// so every scrollable that renders inside [ScaffoldWithNav] needs to reserve
/// [contentInset] at its end. Keeping the numbers here means the bar and the
/// padding that clears it can never drift apart.
class BottomNavMetrics {
  BottomNavMetrics._();

  /// Height of the pill itself, excluding the margin below it.
  static const double barHeight = 72;

  /// Gap between the pill and the bottom safe area.
  static const double barMargin = AppSpacing.md;

  /// Side inset of the pill from the screen edge.
  static const double barHorizontalPadding = AppSpacing.xxl;

  /// System gesture/nav inset that the pill must sit above.
  static double safeInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom;

  /// Vertical space the pill occupies, measured from the bottom of the screen.
  static double reserved(BuildContext context) =>
      barHeight + barMargin + safeInset(context);

  /// Bottom padding a scrollable needs so its last row clears the pill.
  static double contentInset(BuildContext context) =>
      reserved(context) + AppSpacing.md;
}

/// Tells the screen subtree whether the floating nav is on screen.
///
/// The nav hides while the keyboard is up, and a pinned action bar has to know:
/// it reserves [BottomNavMetrics.reserved] only when there is a nav to clear,
/// and otherwise sits straight on the keyboard.
class BottomNavScope extends InheritedWidget {
  const BottomNavScope({
    super.key,
    required this.isVisible,
    required super.child,
  });

  final bool isVisible;

  /// Defaults to true outside the nav shell (`ScaffoldWithNav`), so a bar used
  /// on its own still leaves room for the nav it is pinned above.
  static bool isVisibleOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BottomNavScope>()
          ?.isVisible ??
      true;

  @override
  bool updateShouldNotify(BottomNavScope oldWidget) =>
      oldWidget.isVisible != isVisible;
}

// ---------------------------------------------------------------------------
// Data Model
// ---------------------------------------------------------------------------

/// A single item in the bottom navigation bar.
class BottomNavItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isHighlighted;
  final int badgeCount;

  const BottomNavItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
    this.isHighlighted = false,
    this.badgeCount = 0,
  });
}

// ---------------------------------------------------------------------------
// Floating Glassmorphism Bottom Nav
// ---------------------------------------------------------------------------

/// A floating, glassmorphism-styled bottom navigation bar.
///
/// Features:
///   - Floating pill shape with rounded corners (not flush to screen edge)
///   - Frosted-glass translucency via BackdropFilter + gradient overlay
///   - Solid primary-green indicator that slides between tabs (200 ms easeOut)
///   - Active icon and label in the colour that reads on the green fill
///   - Labels always visible; inactive labels use the muted text token
///   - Optional badge counter (e.g. cart item count) with a tap-in bounce
///   - Full dark-mode support via the C.* theme tokens
class BottomNav extends StatefulWidget {
  final List<BottomNavItem> items;
  final int activeIndex;
  final int? cartBadgeCount;

  const BottomNav({
    super.key,
    required this.items,
    this.activeIndex = -1,
    this.cartBadgeCount,
  });

  /// Convenience constructor for the standard 4-tab GROWBOX nav.
  ///
  /// [activeIndex] highlights that tab (0=home, 1=search, 2=cart, 3=profile).
  /// Provide navigation callbacks for each tab.
  static Widget growbox({
    Key? key,
    required int activeIndex,
    required VoidCallback onHome,
    required VoidCallback onSearch,
    required VoidCallback onCart,
    required VoidCallback onProfile,
    int? cartBadgeCount,
  }) {
    return BottomNav(
      key: key,
      activeIndex: activeIndex,
      cartBadgeCount: cartBadgeCount,
      items: [
        BottomNavItem(
          icon: Icons.home_outlined,
          label: 'Home',
          onTap: onHome,
          isActive: activeIndex == 0,
        ),
        BottomNavItem(
          icon: Icons.search,
          label: 'Search',
          onTap: onSearch,
          isActive: activeIndex == 1,
        ),
        BottomNavItem(
          icon: Icons.shopping_cart_outlined,
          label: 'Cart',
          onTap: onCart,
          isActive: activeIndex == 2,
          badgeCount: cartBadgeCount ?? 0,
        ),
        BottomNavItem(
          icon: Icons.person_outline,
          label: 'Profile',
          onTap: onProfile,
          isActive: activeIndex == 3,
        ),
      ],
    );
  }

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  /// How long the green indicator takes to travel between tabs.
  static const Duration _indicatorDuration = Duration(milliseconds: 200);

  /// Breathing room between the indicator and the pill's rounded edge.
  static const EdgeInsets _indicatorPadding =
      EdgeInsets.symmetric(horizontal: 6, vertical: AppSpacing.sm);

  /// Fractional position for [AnimatedAlign]: item 0 sits at -1 (left edge),
  /// the last item at +1 (right edge), so the indicator is centred on the
  /// tab without any manual pixel maths.
  Alignment _indicatorAlignment(int index) {
    final count = widget.items.length;
    if (count <= 1) return Alignment.center;
    return Alignment(2 * index / (count - 1) - 1, 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = C.isDark(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Sizing – percentage-based so the pill scales with screen width.
    final barWidth = (screenWidth * 0.88).clamp(280.0, 420.0);
    final activeIndex = widget.activeIndex;
    final hasActive = activeIndex >= 0 && activeIndex < widget.items.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BottomNavMetrics.barHorizontalPadding,
          0,
          BottomNavMetrics.barHorizontalPadding,
          BottomNavMetrics.barMargin,
        ),
        child: SizedBox(
          height: BottomNavMetrics.barHeight,
          child: Center(
            child: SizedBox(
              width: barWidth,
              height: BottomNavMetrics.barHeight,
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(BottomNavMetrics.barHeight / 2),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(BottomNavMetrics.barHeight / 2),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                AppDarkColors.surface.withValues(alpha: 0.8),
                                AppDarkColors.surfaceLight.withValues(alpha: 0.67),
                              ]
                            : [
                                AppColors.white.withValues(alpha: 0.94),
                                AppColors.background.withValues(alpha: 0.9),
                              ],
                      ),
                      // 1px surface hairline: separates the pill from the page
                      // in both themes (a 13%-black hairline vanished on dark).
                      border: Border.all(
                        color: C.surfaceLighter(context),
                        width: 1,
                      ),
                      boxShadow: AppNeumorphic.floatShadows(context),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(BottomNavMetrics.barHeight / 2),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cellWidth =
                              constraints.maxWidth / widget.items.length;
                          return Stack(
                            children: [
                              // Sliding indicator: a solid green pill that
                              // animates to the active tab.
                              if (hasActive)
                                Positioned.fill(
                                  child: AnimatedAlign(
                                    duration: _indicatorDuration,
                                    curve: Curves.easeOut,
                                    alignment: _indicatorAlignment(activeIndex),
                                    child: SizedBox(
                                      width: cellWidth,
                                      height: BottomNavMetrics.barHeight,
                                      child: Padding(
                                        padding: _indicatorPadding,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: C.primary(context),
                                            borderRadius: BorderRadius.circular(
                                                AppRadii.pill),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Nav items row – Expanded guarantees equal split.
                              Row(
                                children: List.generate(
                                  widget.items.length,
                                  (index) => Expanded(
                                    child: _NavItem(
                                      item: widget.items[index],
                                      isActive: index == activeIndex,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual Nav Item
// ---------------------------------------------------------------------------

class _NavItem extends StatefulWidget {
  final BottomNavItem item;
  final bool isActive;

  const _NavItem({
    required this.item,
    required this.isActive,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  /// Small pop when the badge count grows (adding something to the cart).
  late final AnimationController _badgeBounce;
  late final Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();
    _badgeBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.22)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.22, end: 1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_badgeBounce);
  }

  @override
  void didUpdateWidget(covariant _NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.badgeCount > oldWidget.item.badgeCount) {
      _badgeBounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _badgeBounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;

    // Active content sits on the solid primary fill, so it uses the token that
    // is legible on primary (white on the deep green, near-black on the lifted
    // green). Inactive content uses the muted text token.
    final activeColor = C.onPrimary(context);
    final inactiveColor = C.textMuted(context);
    final foreground = isActive ? activeColor : inactiveColor;

    return TapFeedback(
      onTap: widget.item.onTap != null
          ? () {
              HapticFeedback.selectionClick();
              widget.item.onTap!();
            }
          : null,
      child: SizedBox(
        height: double.infinity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with badge – pops when the count grows.
              AnimatedScale(
                scale: isActive ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: ScaleTransition(
                  key: const ValueKey('navBadgeBounce'),
                  scale: _badgeScale,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          widget.item.icon,
                          key: ValueKey('${widget.item.label}_$isActive'),
                          size: 22,
                          color: foreground,
                        ),
                      ),
                      // Badge
                      if (widget.item.badgeCount > 0)
                        Positioned(
                          right: -8,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.item.badgeCount > 99
                                  ? '99+'
                                  : '${widget.item.badgeCount}',
                              style: AppTypography.navLabel.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTypography.navLabel.copyWith(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                  height: 1.0,
                ),
                child: Text(widget.item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
