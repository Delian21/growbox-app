import 'package:flutter/material.dart';

import '../theme.dart';

/// A soft highlight that sweeps across its child while it loads.
///
/// Wrapped around a group of [SkeletonBox]es it gives the whole placeholder
/// block one shared animation, so a list of cards costs one controller rather
/// than one per card. Both ends of the sweep come from surface tokens, so the
/// effect is a faint sheen on light and on dark.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce motion: keep the placeholder, drop the sweep.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    final base = C.shimmer(context);
    final highlight = C.shimmerHighlight(context);

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // The band travels from left of the bounds to right of them over one
        // cycle; outside the band both stops are the base tone.
        final double t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.6 + 3.2 * t, 0),
            end: Alignment(-0.6 + 3.2 * t, 0),
            colors: [base, highlight, base],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// One placeholder block: the skeleton tone, optionally sized and rounded.
///
/// Everything hidden while loading is built from these, which is why the
/// skeletons only need the surface tokens and no hard-coded greys.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = AppRadii.sm,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: C.shimmer(context),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton block for an image or any single surface.
///
/// Static by design: image placeholders sit inside a [Shimmer] when they are
/// part of a loading list, so they never need an animation of their own.
class SkeletonLoader extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: C.shimmer(context),
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadii.sm),
      ),
    );
  }
}

/// Placeholder for a [ProductCard]: same outer margin, padding, image size and
/// row height, so the list does not move when the real cards arrive.
///
/// [imageSize] mirrors `ProductCard.imageSize` at the call site (64 in search,
/// 80 in a vendor menu), which is what sets the card's height.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({
    super.key,
    this.imageSize = 64,
    this.showDescription = false,
  });

  final double imageSize;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          SkeletonBox(
            width: imageSize,
            height: imageSize,
            radius: AppRadii.sm,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Name line.
                const SkeletonBox(height: 16, width: 150),
                const SizedBox(height: 8),
                if (showDescription) ...[
                  const SkeletonBox(height: 11, width: double.infinity),
                  const SizedBox(height: 6),
                ],
                // Vendor / weight line.
                const SkeletonBox(height: 12, width: 96),
                const SizedBox(height: 8),
                // Price.
                const SkeletonBox(height: 14, width: 64),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder for a [VendorCard]: 16:9 cover plus the three text rows of the
/// real card, with the same outer radius and padding.
class VendorCardSkeleton extends StatelessWidget {
  const VendorCardSkeleton({super.key});

  /// The real card's cover ratio; keeping it means the skeleton is the exact
  /// height the loaded card will be.
  static const double _imageAspectRatio = 16 / 9;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: _imageAspectRatio,
            child: SkeletonBox(
              width: double.infinity,
              height: double.infinity,
              radius: 0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + rating pill.
                const Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 18)),
                    SizedBox(width: AppSpacing.sm),
                    SkeletonBox(width: 52, height: 22, radius: AppRadii.pill),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                // Category line.
                const SkeletonBox(width: 128, height: 16),
                const SizedBox(height: AppSpacing.sm),
                // Time + fee row.
                const Row(
                  children: [
                    SkeletonBox(width: 96, height: 16),
                    SizedBox(width: AppSpacing.md),
                    SkeletonBox(width: 88, height: 16),
                  ],
                ),
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

  /// Glyph for the built-in error placeholder; call sites pass the icon that
  /// names what the image was (a storefront for a vendor, a basket for a
  /// product) so a failed photo still reads as the right thing.
  final IconData errorIcon;

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
    this.errorIcon = Icons.image_outlined,
    this.scrim = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Bundled assets load synchronously, so loadingBuilder does not apply.
    final isNetwork = imageUrl.startsWith('http');

    Widget frameBuilder(
        BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded) return child;
      // The fade is decoration: skip it when the platform asks for less motion.
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return AnimatedOpacity(
        opacity: frame == null ? 0 : 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: child,
      );
    }

    // Fills the same box the image would have, so a failed photo can never
    // collapse the card or show a broken-image glyph.
    Widget errorBuilder(BuildContext context, Object error, StackTrace? stackTrace) {
      return errorWidget ??
          Container(
            width: width,
            height: height,
            color: C.surfaceVariant(context),
            alignment: Alignment.center,
            child: Icon(
              errorIcon,
              color: C.textMuted(context),
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
            child: Container(color: AppColors.white.withValues(alpha: scrim)),
          ),
        ),
      ],
    );
  }
}
