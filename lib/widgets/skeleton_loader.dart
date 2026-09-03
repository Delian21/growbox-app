import 'package:flutter/material.dart';
import '../theme.dart';

/// Shimmer skeleton loader for images and content.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.grey200.withValues(alpha: _animation.value),
            borderRadius:
                widget.borderRadius ?? BorderRadius.circular(AppRadii.sm),
          ),
        );
      },
    );
  }
}

/// Skeleton loader for product cards.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SkeletonLoader(width: 72, height: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 120, height: 16),
                const SizedBox(height: 8),
                const SkeletonLoader(width: 80, height: 12),
                const SizedBox(height: 8),
                const SkeletonLoader(width: 60, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for vendor cards.
class VendorCardSkeleton extends StatelessWidget {
  const VendorCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(
            width: double.infinity,
            height: 140,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 150, height: 18),
                const SizedBox(height: 8),
                const SkeletonLoader(width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Default strength of the light uniformity veil applied to product photos
/// (see [SkeletonImage.scrim]). One knob shared by every product-image
/// surface, so tuning the effect app-wide is a single edit.
const double kProductImageScrim = 0.08;

/// Network image with skeleton loader placeholder.
class SkeletonImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;

  /// Faint uniform light veil over the photo (0–1).
  ///
  /// Intended for product photos that come from mixed sources (white studio
  /// shots next to busy lifestyle scenes): the veil lifts the darker/
  /// background-heavy photos toward the lighter ones, so the surface reads as
  /// one catalog without re-sourcing images. Applied in light theme only — in
  /// dark mode a white veil would make every tile glow. Product surfaces pass
  /// the shared [kProductImageScrim] strength.
  final double scrim;

  const SkeletonImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
    this.scrim = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Bundled assets load synchronously, so loadingBuilder does not apply.
    final isNetwork = imageUrl.startsWith('http');

    Widget frameBuilder(
        BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded) return child;
      return AnimatedOpacity(
        opacity: frame == null ? 0 : 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: child,
      );
    }

    Widget errorBuilder(BuildContext context, Object error, StackTrace? stackTrace) {
      return errorWidget ??
          Container(
            width: width,
            height: height,
            color: AppColors.grey100,
            child: const Icon(
              Icons.image_outlined,
              color: AppColors.grey500,
              size: 32,
            ),
          );
    }
    final Widget image = isNetwork
        ? Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            frameBuilder: frameBuilder,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SkeletonLoader(
                width: width,
                height: height,
                borderRadius: borderRadius,
              );
            },
            errorBuilder: errorBuilder,
          )
        : Image.asset(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            frameBuilder: frameBuilder,
            errorBuilder: errorBuilder,
          );

    // Light-theme-only uniform veil (see [scrim]) — never in dark mode.
    final showScrim = scrim > 0 &&
        Theme.of(context).brightness != Brightness.dark;
    if (!showScrim) return image;
    return Stack(
      children: [
        image,
        Positioned.fill(
          child: IgnorePointer(
            child: Container(color: Colors.white.withValues(alpha: scrim)),
          ),
        ),
      ],
    );
  }
}
