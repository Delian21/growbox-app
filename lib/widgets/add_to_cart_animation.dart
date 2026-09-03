import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

/// A global key registry for cart icons across the app.
/// Register the cart icon's GlobalKey so the fly animation knows where to go.
class CartKeyRegistry {
  CartKeyRegistry._();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static GlobalKey? cartIconKey;
}

/// Shows a fly-to-cart animation overlay.
///
/// Call [AddToCartOverlay.show] from any screen to animate a product
/// thumbnail flying from [sourcePosition] toward the registered cart icon.
class AddToCartOverlay {
  AddToCartOverlay._();

  static OverlayEntry? _currentEntry;

  /// Show the fly animation from [sourceContext] toward the cart icon.
  ///
  /// [productImage] is the URL or null to show a placeholder icon.
  /// [onFlightComplete] is called when the animation finishes.
  static void show({
    required BuildContext sourceContext,
    String? productImage,
    VoidCallback? onFlightComplete,
  }) {
    // Remove any existing animation.
    _currentEntry?.remove();
    _currentEntry = null;

    final RenderBox sourceBox =
        sourceContext.findRenderObject() as RenderBox;
    final Offset sourcePosition =
        sourceBox.localToGlobal(Offset.zero, ancestor: null);
    final Size sourceSize = sourceBox.size;

    // Find the cart icon position. Fall back to top-right if not registered.
    Offset targetPosition;
    final cartKey = CartKeyRegistry.cartIconKey;
    if (cartKey != null && cartKey.currentContext != null) {
      final RenderBox cartBox =
          cartKey.currentContext!.findRenderObject() as RenderBox;
      targetPosition = cartBox.localToGlobal(
        Offset(cartBox.size.width / 2, cartBox.size.height / 2),
        ancestor: null,
      );
    } else {
      // Fallback: fly to top-right area
      final screenSize = MediaQuery.of(sourceContext).size;
      targetPosition = Offset(screenSize.width - 60, 50);
    }

    final OverlayState overlay = Overlay.of(sourceContext);

    _currentEntry = OverlayEntry(
      builder: (context) => _FlyAnimation(
        sourcePosition: sourcePosition,
        sourceSize: sourceSize,
        targetPosition: targetPosition,
        productImage: productImage,
        onFlightComplete: () {
          _currentEntry?.remove();
          _currentEntry = null;
          onFlightComplete?.call();
        },
      ),
    );

    overlay.insert(_currentEntry!);
  }
}

class _FlyAnimation extends StatefulWidget {
  final Offset sourcePosition;
  final Offset targetPosition;
  final Size sourceSize;
  final String? productImage;
  final VoidCallback onFlightComplete;

  const _FlyAnimation({
    required this.sourcePosition,
    required this.targetPosition,
    required this.sourceSize,
    this.productImage,
    required this.onFlightComplete,
  });

  @override
  State<_FlyAnimation> createState() => _FlyAnimationState();
}

class _FlyAnimationState extends State<_FlyAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Scale: start full size, shrink as it flies
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.3),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 0.0),
        weight: 30,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInCubic,
    ));

    // Opacity: stay visible then fade at the end
    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0),
        weight: 40,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFlightComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Interpolate position along a curved path
        final t = _controller.value;
        final curve = Curves.easeInOut.transform(t);

        // Current position: lerp from source to target
        final dx = widget.sourcePosition.dx +
            (widget.targetPosition.dx - widget.sourcePosition.dx) * curve;
        final dy = widget.sourcePosition.dy +
            (widget.targetPosition.dy - widget.sourcePosition.dy) * curve;

        // Add an arc: fly upward first, then come down
        final arcHeight = -80.0 * sin(pi * curve);

        final currentSize = widget.sourceSize.width * _scaleAnim.value;

        return Positioned(
          left: dx - currentSize / 2,
          top: dy - currentSize / 2 + arcHeight,
          child: Opacity(
            opacity: _opacityAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Container(
                width: widget.sourceSize.width,
                height: widget.sourceSize.height,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: widget.productImage != null &&
                        widget.productImage!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        child: Image.asset(
                          widget.productImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.shopping_basket_outlined,
                                color: AppColors.primaryDark, size: 20),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.shopping_basket_outlined,
                            color: AppColors.primaryDark, size: 20),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// An enhanced "Add to Box" button with a scale-bounce + ripple effect.
/// Wraps the child with a satisfying tap animation.
class AddToCartButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const AddToCartButton({
    super.key,
    this.onTap,
    required this.child,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  State<AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<AddToCartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.1), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _glowAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 70),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap != null ? _handleTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? AppColors.primaryLight,
                borderRadius:
                    widget.borderRadius ?? BorderRadius.circular(AppRadii.lg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark
                        .withValues(alpha: 0.3 * _glowAnim.value),
                    blurRadius: 12 * _glowAnim.value,
                    spreadRadius: 2 * _glowAnim.value,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A badge that shows the cart item count with a bounce animation.
class CartBadge extends StatefulWidget {
  final int count;

  const CartBadge({super.key, required this.count});

  @override
  State<CartBadge> createState() => _CartBadgeState();
}

class _CartBadgeState extends State<CartBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void didUpdateWidget(covariant CartBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count && widget.count > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 0) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        );
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadii.circle),
        ),
        child: Text(
          widget.count > 99 ? '99+' : '$widget.count',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
