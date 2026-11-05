import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../routes.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/pinned_bottom_bar.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/skeleton_loader.dart';

class ProductDetailsScreen extends StatefulWidget {
  final VendorProduct product;
  const ProductDetailsScreen({super.key, required this.product});
  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int quantity = 1;
  int _selectedBundleIndex = 0;

  /// Whether this product is sold by weight or by unit.
  bool get _isByWeight => widget.product.pricingType == PricingType.byWeight;

  /// Whether this product is sold in fixed-price bundles.
  bool get _isByBundle => widget.product.pricingType == PricingType.byBundle;

  /// The currently selected bundle (null if not a bundle product or no bundles).
  ProductBundle? get _selectedBundle {
    if (!_isByBundle || widget.product.bundles == null || widget.product.bundles!.isEmpty) return null;
    return widget.product.bundles![_selectedBundleIndex.clamp(0, widget.product.bundles!.length - 1)];
  }

  /// The base price (now stored as int directly).
  int get _basePrice => widget.product.price;

  /// " / kg" when the product says what one price buys, '' when it does not.
  String get _unitSuffix => widget.product.unit == null
      ? ''
      : ' / ${widget.product.unit}';

  /// Bulk discount multiplier for by-unit items based on quantity selected.
  double get _bulkMultiplier {
    final bulk = widget.product.bulkMultipliers;
    if (bulk == null || bulk.isEmpty) return 1.0;
    // Find the best (highest) threshold the quantity meets.
    double bestMul = 1.0;
    for (final entry in bulk.entries) {
      if (quantity >= entry.key) {
        bestMul = entry.value;
      }
    }
    return bestMul;
  }

  /// Bulk discount for by-unit items; 1.0 for bundles, which price themselves.
  double get _priceMultiplier {
    if (_isByBundle) return 1.0; // bundles use fixed pricing
    return _bulkMultiplier;
  }

  /// The effective per-unit price after applying multipliers.
  /// For bundles, returns the bundle's unit price.
  int get _effectivePrice {
    if (_isByBundle && _selectedBundle != null) {
      return _selectedBundle!.unitPrice;
    }
    return (_basePrice * _priceMultiplier).round();
  }

  /// Total price = effective price × quantity.
  /// For bundles, returns the bundle's fixed price × quantity.
  int get _totalPrice {
    if (_isByBundle && _selectedBundle != null) {
      return _selectedBundle!.price * quantity;
    }
    return _effectivePrice * quantity;
  }



  /// Build a suffix like '(Crate)' for the chosen bundle.
  String get _variantSuffix {
    if (_isByBundle && _selectedBundle != null) {
      return ' (${_selectedBundle!.name})';
    }
    return '';
  }

  /// Get the best bulk discount info to display.
  MapEntry<int, double>? get _bestBulkTier {
    final bulk = widget.product.bulkMultipliers;
    if (bulk == null || bulk.isEmpty) return null;
    // Find the next threshold above current quantity.
    final sortedKeys = bulk.keys.toList()..sort();
    for (final key in sortedKeys) {
      if (quantity < key) return MapEntry(key, bulk[key]!);
    }
    return null;
  }

  /// Display bundle options for byBundle products.
  Widget _bundleSection() {
    final bundles = widget.product.bundles!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Bundle',
            style: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.bold, color: C.textPrimary(context))),
          const SizedBox(height: AppSpacing.sm),
          ...bundles.asMap().entries.map((entry) {
            final index = entry.key;
            final bundle = entry.value;
            final isSelected = index == _selectedBundleIndex;
            final individualPrice = _basePrice * bundle.quantity;
            final savings = individualPrice - bundle.price;
            final savingsPct = individualPrice > 0 ? ((savings / individualPrice) * 100).round() : 0;
            return _BundleOption(
              bundle: bundle,
              isSelected: isSelected,
              savingsPct: savingsPct,
              onTap: () => setState(() => _selectedBundleIndex = index),
            );
          }),
        ],
      ),
    );
  }

  /// Display bulk quantity discount tiers for by-unit products.
  Widget _bulkQuantitySection() {
    final bulk = widget.product.bulkMultipliers!;
    final sortedKeys = bulk.keys.toList()..sort();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bulk Pricing',
            style: TextStyle(fontSize: 16, height: 24/16, fontWeight: FontWeight.bold, color: C.textPrimary(context))),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm + 2,
            runSpacing: AppSpacing.sm,
            children: sortedKeys.map((threshold) {
              final mul = bulk[threshold]!;
              final pctOff = ((1 - mul) * 100).round();
              final isCurrentTier = quantity >= threshold;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isCurrentTier ? C.primaryTint(context) : AppColors.grey100,
                  borderRadius: BorderRadius.circular(18),
                  border: isCurrentTier ? Border.all(color: C.primary(context), width: 1.5) : null),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$threshold+', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                    const SizedBox(width: 4),
                    Text('-$pctOff%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isCurrentTier ? C.success(context) : AppColors.accentOrangeDeep)),
                  ]));
            }).toList()),
        ]),
    );
  }

  Widget _buildStockBadge() {
    final status = StockTracker.statusFor(widget.product.vendorName, widget.product.name);
    switch (status) {
      case StockStatus.outOfStock:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: C.errorSoft(context),
            borderRadius: BorderRadius.circular(AppRadii.sm)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 14, color: C.onErrorSoft(context)),
            const SizedBox(width: 4),
            Text('Out of Stock',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.onErrorSoft(context)))]));
      case StockStatus.lowStock:
        final qty = StockTracker.quantityFor(widget.product.vendorName, widget.product.name);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: C.warningSoft(context),
            borderRadius: BorderRadius.circular(AppRadii.sm)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning_amber, size: 14, color: C.onWarningSoft(context)),
            const SizedBox(width: 4),
            Text('Only $qty left in stock',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.onWarningSoft(context)))]));
      case StockStatus.inStock:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: C.successSoft(context),
            borderRadius: BorderRadius.circular(AppRadii.sm)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_outline, size: 14, color: C.onSuccessSoft(context)),
            const SizedBox(width: 4),
            Text('In Stock',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.onSuccessSoft(context)))]));
    }
  }

  Widget _productImage() {
    return Hero(
      tag: 'product_image_${widget.product.name}_${widget.product.vendorName}',
      child: SkeletonImage(
        imageUrl: widget.product.image,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        scrim: kProductImageScrim,
        errorWidget: Container(
          color: C.shimmer(context),
          alignment: Alignment.center,
          child: Icon(Icons.image_outlined,
              color: C.textMuted(context), size: 40),
        ),
      ),
    );
  }

  /// The same stepper the cart uses, so changing quantity here and in the box
  /// feels identical. It never drops below one: there is nothing to remove
  /// until the item has actually been added.
  Widget _quantitySelector() {
    return QuantityStepper(
      quantity: quantity,
      onDecrement: () => setState(() => quantity--),
      onIncrement: () => setState(() => quantity++),
    );
  }

  void _addToBox() {
    final stockStatus = StockTracker.statusFor(widget.product.vendorName, widget.product.name);
    if (stockStatus == StockStatus.outOfStock) {
      showAppSnackBar(context, 'This item is out of stock', isError: true);
      return;
    }
    // Create a variant product with size/weight in name and adjusted price
    final variantName = '${widget.product.name}$_variantSuffix';
    final variant = VendorProduct(
      image: widget.product.image,
      name: variantName,
      description: widget.product.description,
      price: _effectivePrice,
      category: widget.product.category,
      vendorName: widget.product.vendorName,
      pricingType: widget.product.pricingType,
      // Keep the unit so the cart can still say "₦… / kg".
      unit: widget.product.unit,
    );
    int added = 0;
    for (int i = 0; i < quantity; i++) {
      if (StockTracker.decrement(widget.product.vendorName, widget.product.name)) {
        context.read<CartNotifier>().add(variant);
        added++;
      } else {
        break; // no more stock
      }
    }
    if (added < quantity && added > 0) {
      showAppSnackBar(
        context,
        'Only $added available, added to box',
        actionLabel: 'View box',
        onAction: () => AppRoutes.pushReplaceAll(context, AppRoutes.cart),
      );
    } else {
      showAppSnackBar(
        context,
        '$variantName × $added added to box',
        actionLabel: 'View box',
        onAction: () => AppRoutes.pushReplaceAll(context, AppRoutes.cart),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double imageHeight = (screenWidth * 0.68).clamp(240.0, 340.0);
    final double horizontalPadding =
        screenWidth < 360 ? 14 : screenWidth > 600 ? 24 : AppSpacing.lg;

    return Scaffold(
      backgroundColor: C.background(context),
      // No bottom nav on this route, so the bar rests on its own SafeArea
      // inset instead of leaving a nav-sized strip under it.
      body: SafeArea(
        child: ScreenWithPinnedBar(
          respectNav: false,
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: imageHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _productImage()),
                      Positioned(
                        left: horizontalPadding,
                        top: 18,
                        child: _closeButton(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.xl - 2),
                      AnimatedEntrance(
                        index: 0,
                        child: Text(
                          widget.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            height: 24 / 24,
                            fontWeight: FontWeight.bold,
                            color: C.textPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm + 2),
                      // The unit travels with the price: "N2,550 / kg" already
                      // says what one price buys, so a by-weight product needs
                      // no separate Size/Weight picker.
                      if ((!_isByWeight && quantity > 1) ||
                          (_isByBundle && quantity > 1)) ...[
                        Text(
                          '₦${formatPrice(_totalPrice)}',
                          style: TextStyle(
                            fontSize: 18,
                            height: 24 / 16,
                            fontWeight: FontWeight.bold,
                            color: C.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (_isByBundle && _selectedBundle != null) ...[
                          Text(
                            '${_selectedBundle!.name} × $quantity',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  C.textPrimary(context).withValues(alpha: 0.5),
                            ),
                          ),
                        ] else ...[
                          Text(
                            '₦${formatPrice(_effectivePrice)}$_unitSuffix × $quantity',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  C.textPrimary(context).withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ] else ...[
                        Text(
                          '₦${formatPrice(_effectivePrice)}$_unitSuffix',
                          style: TextStyle(
                            fontSize: 16,
                            height: 24 / 16,
                            fontWeight: FontWeight.bold,
                            color: C.textPrimary(context),
                          ),
                        ),
                      ],
                      if (_priceMultiplier != 1.0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Base price: ₦${widget.product.price}$_unitSuffix',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                C.textPrimary(context).withValues(alpha: 0.5),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      // Show bulk discount hint for by-unit items (not bundles)
                      if (!_isByWeight &&
                          !_isByBundle &&
                          widget.product.bulkMultipliers != null) ...[
                        const SizedBox(height: 2),
                        Builder(builder: (context) {
                          final nextTier = _bestBulkTier;
                          if (nextTier != null) {
                            final pctOff =
                                ((1 - nextTier.value) * 100).round();
                            return Text(
                              'Buy ${nextTier.key}+ for $pctOff% off each',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: C.success(context),
                              ),
                            );
                          } else if (_bulkMultiplier < 1.0) {
                            final pctOff =
                                ((1 - _bulkMultiplier) * 100).round();
                            return Text(
                              'Bulk discount applied: $pctOff% off',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: C.success(context),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      _buildStockBadge(),
                      const SizedBox(height: AppSpacing.sm + 2),
                      AnimatedEntrance(
                        index: 3,
                        child: Text(
                          widget.product.description,
                          style: TextStyle(
                            fontSize: 16,
                            height: 24 / 16,
                            fontWeight: FontWeight.normal,
                            color: C.textPrimary(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // Bundles are the only options the model actually
                      // carries, so they are the only picker left.
                      if (_isByBundle &&
                          widget.product.bundles != null &&
                          widget.product.bundles!.isNotEmpty) ...[
                        _bundleSection(),
                      ],
                      // Show bulk quantity tiers for by-unit products
                      if (!_isByWeight &&
                          !_isByBundle &&
                          widget.product.bulkMultipliers != null &&
                          widget.product.bulkMultipliers!.isNotEmpty) ...[
                        _bulkQuantitySection(),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _quantitySelector(),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // The screen's only primary action, so it gets a full-width pinned
          // bar instead of scrolling away with the content.
          bar: AppButton(
            label: 'Add to box · ₦${formatPrice(_totalPrice)}',
            onPressed: _addToBox,
            icon: Icons.shopping_bag_outlined,
            expand: true,
            height: 52,
            radius: 14,
          ),
        ),
      ),
    );
  }

  /// A dark translucent disc behind the close glyph, so the icon stays readable
  /// over any product photo. 44x44 keeps it tappable without covering much.
  Widget _closeButton(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.surfaceDark(context).withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 22, color: AppColors.white),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bundle Option Widget
// ---------------------------------------------------------------------------

class _BundleOption extends StatelessWidget {
  final ProductBundle bundle;
  final bool isSelected;
  final int savingsPct;
  final VoidCallback onTap;

  const _BundleOption({
    required this.bundle,
    required this.isSelected,
    required this.savingsPct,
    required this.onTap,  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? C.primaryTint(context) : AppColors.grey100,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
            ? Border.all(color: C.primary(context), width: 1.5)
            : Border.all(color: AppColors.grey300, width: 1),
        ),
        child: Row(
          children: [
            // Bundle info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bundle.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: C.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${bundle.quantity} items · ₦${formatPrice(bundle.unitPrice)}/pc',
                    style: TextStyle(fontSize: 13, color: C.textSecondary(context)),
                  ),
                ],
              ),
            ),
            // Price and savings
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₦${formatPrice(bundle.price)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: C.textPrimary(context),
                  ),
                ),
                if (savingsPct > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Save $savingsPct%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: C.success(context),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
