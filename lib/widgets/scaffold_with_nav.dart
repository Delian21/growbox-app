import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../routes.dart';
import 'bottom_nav.dart';

/// Standard shell that wraps screen content with the floating BottomNav.
///
/// Use this instead of manually constructing [BottomNav.growbox] in every screen.
/// The [child] is placed in the Scaffold body; the nav bar floats at the bottom.
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
    return Scaffold(
      backgroundColor: C.background(context),
      body: Column(
        children: [
          Expanded(child: child),
          Consumer<CartNotifier>(
            builder: (context, cart, _) {
              return BottomNav.growbox(
                activeIndex: activeIndex,
                cartBadgeCount: cart.length,
                onHome: activeIndex == 0
                    ? () {}
                    : () => AppRoutes.pushReplaceAll(context, AppRoutes.home),
                onSearch: activeIndex == 1
                    ? () {}
                    : () => AppRoutes.pushReplaceAll(context, AppRoutes.search),
                onCart: activeIndex == 2
                    ? () {}
                    : () => AppRoutes.pushReplaceAll(context, AppRoutes.cart),
                onProfile: activeIndex == 3
                    ? () {}
                    : () => AppRoutes.pushReplaceAll(context, AppRoutes.profile),
              );
            },
          ),
        ],
      ),
    );
  }
}
