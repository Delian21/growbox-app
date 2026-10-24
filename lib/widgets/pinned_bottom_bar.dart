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

  const PinnedBottomBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final navVisible = BottomNavScope.isVisibleOf(context);
    final hp = AppSizing.horizontalPadding(context);

    return Padding(
      // Clears the floating pill (or nothing when the keyboard replaced it).
      padding: EdgeInsets.only(
        bottom: navVisible ? BottomNavMetrics.reserved(context) : 0,
      ),
      child: Container(
        key: surfaceKey,
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(hp, AppSpacing.md, hp, AppSpacing.md),
        decoration: BoxDecoration(
          color: C.surface(context),
          border: Border(
            top: BorderSide(color: C.divider(context), width: 1),
          ),
        ),
        child: child,
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

  const ScreenWithPinnedBar({
    super.key,
    required this.body,
    required this.bar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: body),
        PinnedBottomBar(child: bar),
      ],
    );
  }
}
