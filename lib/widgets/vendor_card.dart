import 'package:flutter/material.dart';

import '../theme.dart';
import 'skeleton_loader.dart';

/// Vendor tile used by the home feed.
///
/// One layout for every vendor: same image ratio, same single rating pill,
/// same meta row. Where a vendor has no rating yet the pill slot carries a
/// "New" tag instead, so the rows stay aligned across the list.
class VendorCard extends StatelessWidget {
  final String name;
  final String image;
  final List<String> categories;
  final String deliveryTime;

  /// Percentage of customers who liked the vendor (0–100). Zero means the
  /// vendor has no rating yet.
  final double ratingPercentage;

  /// Delivery fee in naira. Zero renders as "Free delivery".
  final int deliveryFee;

  final VoidCallback onTap;

  const VendorCard({
    super.key,
    required this.name,
    required this.image,
    required this.categories,
    required this.deliveryTime,
    required this.ratingPercentage,
    required this.deliveryFee,
    required this.onTap,
  });

  static const double _imageAspectRatio = 16 / 9;

  bool get _hasRating => ratingPercentage > 0;

  /// First two categories, e.g. "Fruits · Vegetables".
  String get _categoryLine => categories.take(2).join(' · ');

  String get _deliveryLabel => deliveryFee == 0
      ? 'Free delivery'
      : '₦${formatPrice(deliveryFee)} delivery';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: C.surface(context),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: AppNeumorphic.cardShadows(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(context),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.title.copyWith(
                            fontSize: 16,
                            color: C.textPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildRatingSlot(context),
                    ],
                  ),
                  if (_categoryLine.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _categoryLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall
                          .copyWith(color: C.textMuted(context)),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: C.textMuted(context)),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        deliveryTime,
                        style: AppTypography.bodySmall
                            .copyWith(color: C.textMuted(context)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Icon(Icons.delivery_dining,
                          size: 14, color: C.accentOrange(context)),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _deliveryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: C.accentOrange(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 16:9 cover image with a bottom scrim, so every card's photo reads the
  /// same regardless of the source image's framing or brightness.
  Widget _buildImage(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadii.lg),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final height = width / _imageAspectRatio;
          return SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SkeletonImage(
                  imageUrl: image,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: C.shimmer(context),
                    child: Center(
                      child: Icon(Icons.storefront_outlined,
                          color: C.textMuted(context), size: 40),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.55, 1.0],
                      colors: [
                        AppColors.transparent,
                        AppColors.black.withValues(alpha: 0.28),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Rating pill, or a "New" tag in the same slot when there is no rating.
  Widget _buildRatingSlot(BuildContext context) {
    if (!_hasRating) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentOrange,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: const Text(
          'New',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(
            '${ratingPercentage.round()}%',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
