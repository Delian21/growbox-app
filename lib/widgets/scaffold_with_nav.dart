import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../routes.dart';
import 'bottom_nav.dart';

/// Standard shell that wraps screen content with the floating BottomNav.
///
/// Use this instead of manually constructing [BottomNav.growbox] in every screen.
/// The [child] fills the screen and the nav bar floats on top of it, so content
/// scrolls beneath the glass pill. Scrollables should reserve
/// [BottomNavMetrics.contentInset] at their end so their last row stays clear
/// of the bar; the fade scrim drawn behind the pill hides whatever has already
/// travelled under it.
class ScaffoldWithNav extends StatelessWidget {
  final int activeIndex;
  final Widget child;

  const ScaffoldWithNav({
    super.key,
    required this.activeIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final background = C.background(context);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          // Scrim: page content fades into the background before it reaches
          // the pill, so the cut-off edge under the bar never shows.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: BottomNavMetrics.reserved(context) + AppSpacing.xxl,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      background.withValues(alpha: 0),
                      background,
                    ],
                    stops: const [0, 0.62],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Consumer<CartNotifier>(
              builder: (context, cart, _) {
                return BottomNav.growbox(
                  activeIndex: activeIndex,
                  cartBadgeCount: cart.length,
                  onHome: activeIndex == 0
                      ? () {}
                      : () => AppRoutes.pushReplaceAll(context, AppRoutes.home),
                  onSearch: activeIndex == 1
                      ? () {}
                      : () =>
                          AppRoutes.pushReplaceAll(context, AppRoutes.search),
                  onCart: activeIndex == 2
                      ? () {}
                      : () => AppRoutes.pushReplaceAll(context, AppRoutes.cart),
                  onProfile: activeIndex == 3
                      ? () {}
                      : () =>
                          AppRoutes.pushReplaceAll(context, AppRoutes.profile),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
