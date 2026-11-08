import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/cart_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/search_screen.dart';
import '../tabs.dart';
import 'app_snack_bar.dart';
import 'scaffold_with_nav.dart';

/// Tells a tab root that it is inside [RootShell], and that the shell — not the
/// screen — owns the Scaffold, the bottom nav and the content fade.
///
/// The four tab screens are also rendered on their own (the gallery, tests),
/// where they do need their own nav. Rather than duplicate them, this scope is
/// how `ScaffoldWithNav` knows to render only the child.
class RootShellScope extends InheritedWidget {
  const RootShellScope({super.key, required super.child});

  static bool isInside(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RootShellScope>() != null;

  @override
  bool updateShouldNotify(RootShellScope oldWidget) => false;
}

/// The signed-in app: four tabs in one stack, one bottom nav, one Back policy.
///
/// What this replaced: each tab was its own route, pushed with
/// `pushNamedAndRemoveUntil(..., (_) => false)`. Switching tabs therefore
/// unmounted the old tab (losing scroll position, typed search text, a
/// half-filled form) and left a single route on the stack, so Back on any tab
/// closed the app instead of going Home.
///
/// Now all four tabs stay mounted in an [IndexedStack] and only the visible one
/// is painted. Pushed screens (vendor, product, checkout…) are still ordinary
/// routes above this one, so Back pops them one level at a time, dialogs and
/// sheets included.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  /// How long "Press back again to exit" stays armed.
  static const Duration exitWindow = Duration(seconds: 2);

  /// Tabs that have been shown at least once.
  ///
  /// The stack keeps a tab's state by staying mounted, but a tab nobody has
  /// visited has no state worth keeping — and building all four on a cold
  /// start would fire four loads, focus Search's field and mount Profile's
  /// theme switch before the first frame. So each tab is created on its first
  /// visit and then kept.
  final Set<AppTab> _mounted = {AppTab.home};

  /// When the exit prompt was last shown, or null when it is not armed.
  DateTime? _exitArmedAt;

  /// Fires when the window closes so the prompt cannot stay armed forever after
  /// a snackbar the customer dismissed by swiping.
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    tabNavigator.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    tabNavigator.removeListener(_onTabChanged);
    _exitTimer?.cancel();
    super.dispose();
  }

  /// Mounts a tab the first time it is shown.
  ///
  /// The index itself is read straight from [tabNavigator] during build; this
  /// listener only grows the mounted set, which the children list needs before
  /// the frame that paints the new tab.
  void _onTabChanged() {
    if (!mounted) return;
    setState(() => _mounted.add(tabNavigator.tab));
  }

  /// Back at the bottom of the stack.
  ///
  /// Order matters: a tab that is not Home goes Home and stops there — nobody
  /// expects the first Back press on Cart to close the app. Only Home asks for
  /// a second press, and only inside [exitWindow].
  void _handleRootBack() {
    if (tabNavigator.backToHome()) return;

    final armedAt = _exitArmedAt;
    final now = DateTime.now();
    final stillArmed = armedAt != null && now.difference(armedAt) < exitWindow;

    if (stillArmed) {
      _exitTimer?.cancel();
      _exitArmedAt = null;
      // On Android and desktop this closes the app. On web the engine turns it
      // into a history back, which is the closest thing a page has to leaving
      // (the browser tab itself is not ours to close). iOS has no concept of
      // quitting an app, so the second press there is a no-op by design.
      if (defaultTargetPlatform != TargetPlatform.iOS) {
        SystemNavigator.pop();
      }
      return;
    }

    _exitArmedAt = now;
    _exitTimer?.cancel();
    _exitTimer = Timer(exitWindow, () {
      if (mounted) _exitArmedAt = null;
    });
    showAppSnackBar(context, 'Press back again to exit', duration: exitWindow);
  }

  /// The widget for [tab]: itself once visited, otherwise an empty slot of the
  /// same size so the [IndexedStack] indices stay fixed.
  Widget _tab(AppTab tab) {
    if (!_mounted.contains(tab)) return const SizedBox.shrink();
    switch (tab) {
      case AppTab.home:
        return const HomeScreen();
      case AppTab.search:
        return const SearchScreen();
      case AppTab.cart:
        return const CartScreen();
      case AppTab.profile:
        return const ProfileScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The shell is the first route, so there is nothing underneath: every
      // back press is handled here rather than popping the app off screen.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleRootBack();
      },
      child: ScaffoldWithNav(
        activeIndex: tabNavigator.index,
        // The cart pins a bar over the strip the fade would darken.
        fadeContent: tabNavigator.tab != AppTab.cart,
        child: RootShellScope(
          child: IndexedStack(
            index: tabNavigator.index,
            // A tab that has been shown stays mounted, so it keeps its scroll
            // position, its filters and its form state — what the route-per-tab
            // version threw away on every switch.
            children: [
              _tab(AppTab.home),
              _tab(AppTab.search),
              _tab(AppTab.cart),
              _tab(AppTab.profile),
            ],
          ),
        ),
      ),
    );
  }
}
