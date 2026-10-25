import 'package:flutter/material.dart';

import '../theme.dart';
import 'bottom_nav.dart';

/// A bottom action bar pinned directly above the floating nav.
///
/// The bar owns the offset that clears the nav ([BottomNavMetrics.reserved]), so
/// screens never compute it themselves, and it drops that offset while the
/// keyboard is open (the nav is hidden then) so it lands on the keyboard
/// instead of floating in the middle of it.
///
/// It paints the standard chrome — surfaced background, hairline top divider and
/// the same horizontal padding as screen content — and nothing else, so callers
/// pass their own row of controls as [child].
class PinnedBottomBar extends StatelessWidget {
  /// Key on the bar's painted surface, for measuring it in tests.
  static const Key surfaceKey = ValueKey('pinnedBottomBar');

  final Widget child;

  /// Extra space between the bar and the floating nav. Zero keeps the bar
  /// attached to the strip above the pill.
  final double gap;

  /// Corner radius of the bar surface. Zero keeps the full-bleed slab.
  final double radius;

  /// Horizontal inset, used together with [radius] to float the bar like the
  /// nav pill instead of touching the screen edges.
  final double horizontalInset;

  /// Whether the bar must clear the floating nav.
  ///
  /// True by default, because the bar usually sits on a tab screen. Screens
  /// without the nav (checkout, order confirmation) pass false so the bar rests
  /// on their own SafeArea instead of leaving an empty nav-sized strip.
  final bool respectNav;

  const PinnedBottomBar({
    super.key,
    required this.child,
    this.gap = 0,
    this.radius = 0,
    this.horizontalInset = 0,
    this.respectNav = true,
  });

  @override
  Widget build(BuildContext context) {
    final navVisible =
        respectNav && BottomNavScope.isVisibleOf(context);
    final hp = AppSizing.horizontalPadding(context);
    final floating = radius > 0;

    return Padding(
      // Clears the floating pill (or nothing when the keyboard replaced it),
      // plus any requested breathing room.
      padding: EdgeInsets.only(
        bottom: navVisible ? BottomNavMetrics.reserved(context) + gap : 0,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalInset),
        child: Container(
          key: surfaceKey,
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            floating ? AppSpacing.lg : hp,
            AppSpacing.md,
            floating ? AppSpacing.lg : hp,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: C.surface(context),
            borderRadius:
                floating ? BorderRadius.circular(radius) : BorderRadius.zero,
            // A floating bar borrows the nav's treatment: hairline outline and
            // float shadow. An attached bar keeps its single top divider.
            border: floating
                ? Border.all(color: C.surfaceLighter(context), width: 1)
                : Border(
                    top: BorderSide(color: C.divider(context), width: 1),
                  ),
            boxShadow: floating ? AppNeumorphic.floatShadows(context) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A screen body with a [PinnedBottomBar] below it.
///
/// The bar is a sibling of the body rather than an overlay, so the body's
/// viewport ends exactly where the bar begins: a scrollable inside it is already
/// inset by the bar's height plus the space the nav needs, with no measured
/// padding to keep in sync.
class ScreenWithPinnedBar extends StatelessWidget {
  final Widget body;
  final Widget bar;

  /// Forwarded to [PinnedBottomBar] so a screen can float its bar above the
  /// nav without rebuilding the widget itself.
  final double gap;
  final double radius;
  final double horizontalInset;

  /// Forwarded to [PinnedBottomBar]: false on screens without the bottom nav.
  final bool respectNav;

  const ScreenWithPinnedBar({
    super.key,
    required this.body,
    required this.bar,
    this.gap = 0,
    this.radius = 0,
    this.horizontalInset = 0,
    this.respectNav = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: body),
        PinnedBottomBar(
          gap: gap,
          radius: radius,
          horizontalInset: horizontalInset,
          respectNav: respectNav,
          child: bar,
        ),
      ],
    );
  }
}
