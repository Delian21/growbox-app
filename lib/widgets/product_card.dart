import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../routes.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/skeleton_loader.dart';
import '../screens/product_details_screen.dart';

/// A reusable product card that shows image, name, price, and add-to-cart.
///
/// Used in search results, vendor product lists, and buy-again rows.
/// Variants:
/// - [showVendorName] shows the vendor name below the product name
/// - [showDescription] shows the product description
/// - [showStockBadge] shows low/out-of-stock badges
/// - [imageSize] controls the thumbnail size (default 64)
class ProductCard extends StatelessWidget {
  final VendorProduct product;
  final bool showVendorName;
  final bool showDescription;
  final bool showStockBadge;
  final double imageSize;

  const ProductCard({
    super.key,
    required this.product,
    this.showVendorName = false,
    this.showDescription = false,
    this.showStockBadge = false,
    this.imageSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = StockTracker.isAvailable(product.vendorName, product.name);
    final stockStatus = StockTracker.statusFor(product.vendorName, product.name);
    // How many of this product are in the box: the card's "+" becomes a
    // stepper once that is above zero, so the card always agrees with the cart.
    final cart = context.watch<CartNotifier>();
    final int inBox = cart.countOf(product);

    return TapFeedback(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.surface(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Product image with Hero transition
            Hero(
              tag: 'product_image_${product.name}_${product.vendorName}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: imageSize,
                  height: imageSize,
                  // Fades the photo in instead of popping, and shows a
                  // skeleton tile while a bundled asset is decoding.
                  child: SkeletonImage(
                    imageUrl: product.image,
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.cover,
                    scrim: kProductImageScrim,
                    errorWidget: Container(
                      color: C.shimmer(context),
                      child: Icon(Icons.shopping_basket_outlined,
                          color: C.textMuted(context), size: imageSize * 0.44),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: C.textPrimary(context),
                          ),
                        ),
                      ),
                      if (showStockBadge &&
                          stockStatus == StockStatus.lowStock) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: C.warningSoft(context),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Low stock',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: C.onWarningSoft(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (showVendorName) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.vendorName,
                      style: TextStyle(fontSize: 12, color: C.textMuted(context)),
                    ),
                  ],
                  if (showDescription) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: C.textMuted(context)),
                    ),
                  ],
                  const SizedBox(height: 4),
                  // Price and the add control share one row, so the stepper
                  // takes the "+" slot without eating the name's width.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.unit == null
                              ? '₦${formatPrice(product.price)}'
                              : '₦${formatPrice(product.price)} / ${product.unit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: C.accentOrange(context),
                          ),
                        ),
                      ),
                      if (inBox == 0)
                        GestureDetector(
                          onTap: isAvailable
                              ? () {
                                  if (StockTracker.decrement(
                                      product.vendorName, product.name)) {
                                    cart.add(product);
                                    showAppSnackBar(
                                      context,
                                      '${product.name} added to box',
                                      actionLabel: 'View box',
                                      onAction: () => AppRoutes.pushReplaceAll(
                                          context, AppRoutes.cart),
                                    );
                                  }
                                }
                              : null,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? C.primaryTint(context)
                                  : C.surfaceLighter(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isAvailable
                                  ? Icons.add
                                  : Icons.remove_shopping_cart,
                              size: 20,
                              color: isAvailable
                                  ? C.primary(context)
                                  : C.textMuted(context),
                            ),
                          ),
                        )
                      else
                        QuantityStepper(
                          quantity: inBox,
                          onDecrement: () => cart.removeOne(product),
                          onDelete: () => cart.removeOne(product),
                          onIncrement: !isAvailable
                              ? null
                              : () {
                                  if (StockTracker.decrement(
                                      product.vendorName, product.name)) {
                                    cart.add(product);
                                  }
                                },
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
}
