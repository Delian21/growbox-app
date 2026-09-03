import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/skeleton_loader.dart';

class ProductDetailsScreen extends StatefulWidget {
  final VendorProduct product;
  const ProductDetailsScreen({super.key, required this.product});
  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int quantity = 1;
  bool sizeExpanded = false;
  bool weightExpanded = false;
  String selectedSize = 'Select size';
  String selectedWeight = 'Select weight';
  int _selectedBundleIndex = 0;

  // Size multipliers: Small is a smaller portion, Large is a bigger portion
  static const Map<String, double> _sizeMultipliers = {
    'Small': 0.8,
    'Medium': 1.0,
    'Large': 1.3,
  };

  // Weight multipliers: relative to a ~1kg base unit
  static const Map<String, double> _weightMultipliers = {
    '1 kg': 1.0,
    '2 kg': 1.8,
    '5 kg': 4.0,
    '10 kg': 7.5,
  };

  /// Whether this product is sold by weight (Size/Weight options) or by unit.
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

  /// Combined multiplier from selected size + weight (only for by-weight products).
  double get _sizeWeightMultiplier {
    final double sizeMul = _sizeMultipliers[selectedSize] ?? 1.0;
    final double weightMul = _weightMultipliers[selectedWeight] ?? 1.0;
    final bool hasSize = selectedSize != 'Select size';
    final bool hasWeight = selectedWeight != 'Select weight';
    if (hasSize && hasWeight) return sizeMul * weightMul;
    if (hasSize) return sizeMul;
    if (hasWeight) return weightMul;
    return 1.0;
  }

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

  /// Combined multiplier: size+weight for by-weight, bulk discount for by-unit.
  /// For bundles, this returns 1.0 since bundles have fixed pricing.
  double get _priceMultiplier {
    if (_isByWeight) return _sizeWeightMultiplier;
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



  /// Build a suffix like '(Large, 5 kg)', '(Crate)', or '(×5)' for the product variant.
  String get _variantSuffix {
    final parts = <String>[];
    if (_isByWeight) {
      if (selectedSize != 'Select size') parts.add(selectedSize);
      if (selectedWeight != 'Select weight') parts.add(selectedWeight);
    } else if (_isByBundle && _selectedBundle != null) {
      parts.add(_selectedBundle!.name);
    }
    if (parts.isEmpty) return '';
    return ' (${parts.join(', ')})';
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

  // Chevron icon slot: an SVG from the design tool was here before the app
  // went fully offline/bundled. Kept empty so the selector rows render the
  // Material chevron icon directly (see usage below).
  static const String arrowDownIcon = '';

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
                  color: isCurrentTier ? AppColors.primaryLight : const Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.circular(18),
                  border: isCurrentTier ? Border.all(color: AppColors.primary, width: 1.5) : null),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$threshold+', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                    const SizedBox(width: 4),
                    Text('-$pctOff%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isCurrentTier ? AppColors.success : const Color(0xFFB45309))),
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
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(AppRadii.sm)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 14, color: AppColors.error),
            SizedBox(width: 4),
            Text('Out of Stock',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error))]));
      case StockStatus.lowStock:
        final qty = StockTracker.quantityFor(widget.product.vendorName, widget.product.name);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(AppRadii.sm)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber, size: 14, color: Color(0xFFB45309)),
            const SizedBox(width: 4),
            Text('Only $qty left in stock',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)))]));
      case StockStatus.inStock:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(AppRadii.sm)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
            SizedBox(width: 4),
            Text('In Stock',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success))]));
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

  Widget _optionSection({
    required String title, required String selectedValue, required bool expanded,
    required VoidCallback onTap, required List<String> options, required ValueChanged<String> onSelected,
  }) {
    final bool hasSelection = selectedValue != 'Select ${title.toLowerCase()}';
    return Column(children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque, onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 70),
          child: Row(children: [
            Expanded(child: Text(title,
              style: TextStyle(fontSize: 16, height: 24/16, fontWeight: FontWeight.bold, color: C.textPrimary(context)))),
            if (hasSelection) Flexible(child: Text(selectedValue, textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: C.textPrimary(context)))),
            const SizedBox(width: AppSpacing.sm),
            arrowDownIcon.isNotEmpty
                ? Image.asset(arrowDownIcon, width: 24, height: 24,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 24, color: C.textPrimary(context)))
                : Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 24, color: C.textPrimary(context)),
          ]))),
      if (expanded)
        Container(
          width: double.infinity, padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Wrap(spacing: AppSpacing.sm + 2, runSpacing: AppSpacing.sm,
            children: options.map((option) {
              final bool selected = selectedValue == option;
              // Show the multiplier badge for size/weight options
              final multipliers = title == 'Size' ? _sizeMultipliers : _weightMultipliers;
              final mul = multipliers[option] ?? 1.0;
              final bool isBase = mul == 1.0;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryLight : const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(option, style: TextStyle(fontSize: 13, color: C.textPrimary(context))),
                      if (!isBase) ...[
                        const SizedBox(width: 4),
                        Text('${mul > 1 ? '+' : ''}${((mul - 1) * 100).round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: mul > 1 ? const Color(0xFFB45309) : AppColors.success)),
                      ],
                    ])));
            }).toList())),
    ]);
  }

  Widget _quantitySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () { if (quantity > 1) setState(() => quantity--); },
          child: SizedBox(width: 40, height: 40, child: Center(
            child: Icon(Icons.remove, size: 24, color: C.textPrimary(context))))),
        const SizedBox(width: AppSpacing.sm - 2),
        SizedBox(width: 35, child: Text('$quantity', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 24/16, fontWeight: FontWeight.bold, color: C.textPrimary(context)))),
        const SizedBox(width: AppSpacing.sm - 2),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => quantity++),
          child: SizedBox(width: 40, height: 40, child: Center(
            child: Icon(Icons.add, size: 24, color: C.textPrimary(context))))),
      ]);
  }

  void _addToBox() {
    final stockStatus = StockTracker.statusFor(widget.product.vendorName, widget.product.name);
    if (stockStatus == StockStatus.outOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('This item is out of stock'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm))));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only $added available, added to box'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm))));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$variantName × $added added to box'),
          duration: const Duration(seconds: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double imageHeight = (screenWidth * 0.68).clamp(240.0, 340.0);
    final double horizontalPadding = screenWidth < 360 ? 14 : screenWidth > 600 ? 24 : AppSpacing.lg;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity, height: imageHeight,
                      child: Stack(
                        children: [
                          Positioned.fill(child: _productImage()),
                          Positioned(
                            left: horizontalPadding, top: 18,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.pop(context),
                              child: SizedBox(
                                width: 44, height: 44,
                                child: Center(
                                  child: Icon(Icons.close, size: 24, color: C.textPrimary(context)))),
                          ),
                          ),
                        ])),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.xl - 2),
                          AnimatedEntrance(
                            index: 0,
                            child: Text(widget.product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 24, height: 24/24, fontWeight: FontWeight.bold, color: C.textPrimary(context))),
                          ),
                          const SizedBox(height: AppSpacing.sm + 2),
                          // For by-unit or by-bundle with quantity > 1, show total price prominently
                          if ((!_isByWeight && quantity > 1) || (_isByBundle && quantity > 1)) ...[
                            Text('₦${formatPrice(_totalPrice)}',
                              style: TextStyle(fontSize: 18, height: 24/16, fontWeight: FontWeight.bold, color: C.textPrimary(context))),
                            const SizedBox(height: 2),
                            if (_isByBundle && _selectedBundle != null) ...[
                              Text('${_selectedBundle!.name} × $quantity',
                                style: TextStyle(fontSize: 13, color: C.textPrimary(context).withValues(alpha: 0.5))),
                            ] else ...[
                              Text('₦${formatPrice(_effectivePrice)} × $quantity',
                                style: TextStyle(fontSize: 13, color: C.textPrimary(context).withValues(alpha: 0.5))),
                            ],
                          ] else ...[
                            Text('₦${formatPrice(_effectivePrice)}',
                              style: TextStyle(fontSize: 16, height: 24/16, fontWeight: FontWeight.bold, color: C.textPrimary(context))),
                          ],
                          if (_priceMultiplier != 1.0) ...[
                            const SizedBox(height: 2),
                            Text('Base price: ₦${widget.product.price}',
                              style: TextStyle(fontSize: 13, color: C.textPrimary(context).withValues(alpha: 0.5), decoration: TextDecoration.lineThrough)),
                          ],
                          // Show bulk discount hint for by-unit items (not bundles)
                          if (!_isByWeight && !_isByBundle && widget.product.bulkMultipliers != null) ...[
                            const SizedBox(height: 2),
                            Builder(builder: (context) {
                              final nextTier = _bestBulkTier;
                              if (nextTier != null) {
                                final pctOff = ((1 - nextTier.value) * 100).round();
                                return Text(
                                  'Buy ${nextTier.key}+ for $pctOff% off each',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.success));
                              } else if (_bulkMultiplier < 1.0) {
                                final pctOff = ((1 - _bulkMultiplier) * 100).round();
                                return Text(
                                  'Bulk discount applied: $pctOff% off',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.success));
                              }
                              return const SizedBox.shrink();
                            }),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          _buildStockBadge(),
                          const SizedBox(height: AppSpacing.sm + 2),
                          AnimatedEntrance(
                            index: 3,
                            child: Text(widget.product.description,
                            style: TextStyle(fontSize: 16, height: 24/16, fontWeight: FontWeight.normal, color: C.textPrimary(context))),
                          ),
                          const SizedBox(height: 30),
                          // Only show Size/Weight for by-weight products
                          if (_isByWeight) ...[
                            _optionSection(title: 'Size', selectedValue: selectedSize, expanded: sizeExpanded,
                              onTap: () => setState(() { sizeExpanded = !sizeExpanded; weightExpanded = false; }),
                              options: const ['Small', 'Medium', 'Large'],
                              onSelected: (v) => setState(() { selectedSize = v; sizeExpanded = false; })),
                            _optionSection(title: 'Weight', selectedValue: selectedWeight, expanded: weightExpanded,
                              onTap: () => setState(() { weightExpanded = !weightExpanded; sizeExpanded = false; }),
                              options: const ['1 kg', '2 kg', '5 kg', '10 kg'],
                              onSelected: (v) => setState(() { selectedWeight = v; weightExpanded = false; })),
                          ],
                          // Show bundle options for by-bundle products
                          if (_isByBundle && widget.product.bundles != null && widget.product.bundles!.isNotEmpty) ...[
                            _bundleSection(),
                          ],
                          // Show bulk quantity tiers for by-unit products
                          if (!_isByWeight && !_isByBundle && widget.product.bulkMultipliers != null && widget.product.bulkMultipliers!.isNotEmpty) ...[
                            _bulkQuantitySection(),
                          ],
                          SizedBox(height: screenWidth < 360 ? 60 : 85),
                          _quantitySelector(),
                          const SizedBox(height: AppSpacing.lg),
                          // Modern CTA button with price
                          AnimatedEntrance(
                            index: 5,
                            child: TapScale(
                              onTap: _addToBox,
                              child: Container(
                                width: double.infinity, height: 52,
                                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDark,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryDark.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.shopping_bag_outlined, size: 20, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Add to Box — ₦${formatPrice(_totalPrice)}',
                                      style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 35),
                        ])),
                  ])),
          ),
        ])),
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
          color: isSelected ? AppColors.primaryLight : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
            ? Border.all(color: AppColors.primary, width: 1.5)
            : Border.all(color: const Color(0xFFE0E0E0), width: 1),
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
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
