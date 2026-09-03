import 'package:flutter/material.dart';

/// A custom [PageRouteBuilder] that combines a slide-from-right with a fade-in.
///
/// Used globally via [pageTransitionsTheme] so every Navigator.push gets
/// a smooth, consistent animation without touching individual push calls.
class SlideFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideFadeRoute({required this.page})
      : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            // Slide from right (15% offset for a subtle parallax feel)
            final slideTween = Tween<Offset>(
              begin: const Offset(0.15, 0),
              end: Offset.zero,
            ).animate(curved);

            // Fade in
            final fadeTween = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(curved);

            return SlideTransition(
              position: slideTween,
              child: FadeTransition(
                opacity: fadeTween,
                child: child,
              ),
            );
          },
        );
}

/// Custom [PageTransitionsBuilder] that applies [SlideFadeRoute] globally.
///
/// Add this to [PageTransitionsTheme] in both light and dark [ThemeData]
/// so every `MaterialPageRoute` (and any route using the default builder)
/// gets the slide+fade transition automatically.
class SlideFadeTransitionsBuilder extends PageTransitionsBuilder {
  const SlideFadeTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final slideTween = Tween<Offset>(
      begin: const Offset(0.15, 0),
      end: Offset.zero,
    ).animate(curved);

    final fadeTween = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(curved);

    return SlideTransition(
      position: slideTween,
      child: FadeTransition(
        opacity: fadeTween,
        child: child,
      ),
    );
  }
}
