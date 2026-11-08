import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../tabs.dart';
import 'bottom_nav.dart';
import 'root_shell.dart';

/// Standard shell that wraps screen content with the floating BottomNav.
///
/// Use this instead of manually constructing [BottomNav.growbox] in every screen.
/// The [child] fills the screen and the nav bar floats on top of it, so content
/// scrolls beneath the glass pill. Scrollables should reserve
/// [BottomNavMetrics.contentInset] at their end so their last row stays clear
/// of the bar; the fade scrim drawn behind the pill hides whatever has already
/// travelled under it.
///
/// Screens that pin an action bar with `ScreenWithPinnedBar` should pass
/// `fadeContent: false`: their bar already covers the area above the pill, and
/// the scrim would tint the bar's own surface.
class ScaffoldWithNav extends StatelessWidget {
  final int activeIndex;
  final Widget child;

  /// The fade that hides content scrolling under the pill. Turn it off on
  /// screens whose bottom is covered by a pinned bar.
  final bool fadeContent;

  const ScaffoldWithNav({
    super.key,
    required this.activeIndex,
    required this.child,
    this.fadeContent = true,
  });

  @override
  Widget build(BuildContext context) {
    // Inside the signed-in shell the Scaffold, the fade and the nav belong to
    // the shell, which draws them once around all four tabs. A tab root only
    // contributes its content there; rendering its own Scaffold and nav would
    // stack two bars on top of each other.
    if (RootShellScope.isInside(context)) return child;

    final background = C.background(context);

    // Read above the Scaffold: it removes viewInsets from the body, so a widget
    // inside would always read zero. This also registers the dependency that
    // rebuilds the shell when the keyboard shows or hides.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final navVisible = !keyboardOpen;

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          // The screen subtree knows whether a nav is there to clear.
          Positioned.fill(
            child: BottomNavScope(isVisible: navVisible, child: child),
          ),
          if (navVisible && fadeContent)
            // Scrim, edge to edge: a short fade above the pill, then solid
            // page background behind the pill itself. The old single
            // gradient was still translucent at the pill's top edge, so card
            // images showed through on both sides of it.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fade out over the strip just above the pill.
                    Container(
                      width: double.infinity,
                      height: AppSpacing.xxl,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            background.withValues(alpha: 0),
                            background,
                          ],
                        ),
                      ),
                    ),
                    // Fully opaque behind the pill and the gesture inset.
                    SizedBox(
                      width: double.infinity,
                      height: BottomNavMetrics.reserved(context),
                      child: ColoredBox(color: background),
                    ),
                  ],
                ),
              ),
            ),
          // The nav steps aside for the keyboard so it never covers the field
          // being typed into.
          if (navVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Consumer<CartNotifier>(
                builder: (context, cart, _) {
                  return BottomNav.growbox(
                    activeIndex: activeIndex,
                    cartBadgeCount: cart.length,
                    // A tap switches the tab instead of replacing the route.
                    // [openTab] also drops any screen pushed on top, so the
                    // bar works from a pushed page (the catalog) too, where
                    // this nav is drawn on its own.
                    onHome: activeIndex == 0
                        ? () {}
                        : () => openTab(context, AppTab.home),
                    onSearch: activeIndex == 1
                        ? () {}
                        : () => openTab(context, AppTab.search),
                    onCart: activeIndex == 2
                        ? () {}
                        : () => openTab(context, AppTab.cart),
                    onProfile: activeIndex == 3
                        ? () {}
                        : () => openTab(context, AppTab.profile),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
