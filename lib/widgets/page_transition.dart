import 'package:flutter/material.dart';

/// Smooth slide transition for page navigation.
/// Usage: Navigator.push(context, SlideRoute(page: NextScreen()));
class SlideRoute extends PageRouteBuilder {
  final Widget page;
  final SlideDirection direction;

  SlideRoute({
    required this.page,
    this.direction = SlideDirection.right,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween(
              begin: _getBeginOffset(direction),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic));

            final reverseTween = Tween(
              begin: Offset.zero,
              end: _getBeginOffset(direction),
            ).chain(CurveTween(curve: Curves.easeInCubic));

            return SlideTransition(
              position: animation.drive(tween),
              child: SlideTransition(
                position: secondaryAnimation.drive(reverseTween),
                child: child,
              ),
            );
          },
        );

  static Offset _getBeginOffset(SlideDirection direction) {
    switch (direction) {
      case SlideDirection.right:
        return const Offset(1.0, 0.0);
      case SlideDirection.left:
        return const Offset(-1.0, 0.0);
      case SlideDirection.bottom:
        return const Offset(0.0, 1.0);
      case SlideDirection.top:
        return const Offset(0.0, -1.0);
    }
  }
}

enum SlideDirection { right, left, bottom, top }

/// Fade transition for subtle page changes.
class FadeRoute extends PageRouteBuilder {
  final Widget page;

  FadeRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        );
}

/// Scale transition for modal-like pages.
class ScaleRoute extends PageRouteBuilder {
  final Widget page;

  ScaleRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: child,
            );
          },
        );
}
