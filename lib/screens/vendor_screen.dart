import '../widgets/product_card.dart';
import '../widgets/skeleton_loader.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';

class VendorScreen extends StatefulWidget {
  final String vendorName;
  final String vendorCoverImage;
  final String vendorLogoImage;
  final List<String> categories;
  final bool initialOpen;
  final List<VendorProduct> products;

  const VendorScreen({
    super.key,
    required this.vendorName,
    required this.vendorCoverImage,
    required this.vendorLogoImage,
    required this.categories,
    this.initialOpen = true,
    required this.products,
  });

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
  late bool isOpen;
  String selectedCategory = 'ALL';
  bool showVendorSearch = false;
  String vendorSearchQuery = '';

  bool get isFavorite => favoriteVendors.any((v) => v['name'] == widget.vendorName);

  @override
  void initState() {
    super.initState();
    isOpen = widget.initialOpen;
  }

  void _toggleFavorite() {
    final bool wasFavorite = isFavorite;
    setState(() {
      if (wasFavorite) {
        favoriteVendors.removeWhere((v) => v['name'] == widget.vendorName);
      } else {
        favoriteVendors.add({
          'name': widget.vendorName,
          'image': widget.vendorCoverImage,
          'logo': widget.vendorLogoImage,
          'rating': '0.0',
          'reviews': 'No reviews',
        });
      }
      persistFavorites();
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(wasFavorite
          ? '${widget.vendorName} removed from favorites'
          : '${widget.vendorName} added to favorites'),
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double hp = AppSizing.horizontalPadding(context);

    return Scaffold(
      backgroundColor: C.background(context),
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
                    // ── Cover Image ──────────────────────────────
                    _buildCoverImage(screenWidth),

                    // ── Vendor Info ──────────────────────────────
                    _buildVendorInfo(hp),

                    // ── Category Tabs ────────────────────────────
                    _buildCategoryTabs(screenWidth),

                    const SizedBox(height: AppSpacing.sm),

                    // ── Products ─────────────────────────────────
                    _buildProductList(hp, screenWidth),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(double screenWidth) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        children: [
          // Cover image
          Positioned.fill(
            child: widget.vendorCoverImage.isNotEmpty
                ? SkeletonImage(
                    imageUrl: widget.vendorCoverImage,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: C.shimmer(context),
                      child: Center(
                        child: Icon(Icons.storefront_outlined,
                            color: C.textMuted(context), size: 50),
                      ),
                    ),
                  )
                : Container(
                    color: C.shimmer(context),
                    child: Center(
                      child: Icon(Icons.storefront_outlined,
                          color: C.textMuted(context), size: 50),
                    ),
                  ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Back button
          Positioned(
            left: 12,
            top: MediaQuery.paddingOf(context).top + 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back,
                    size: 20, color: Colors.black),
              ),
            ),
          ),
          // Favorite button
          Positioned(
            right: 12,
            top: MediaQuery.paddingOf(context).top + 12,
            child: GestureDetector(
              onTap: _toggleFavorite,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: isFavorite ? AppColors.error : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorInfo(double hp) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.lg, hp, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Vendor logo
              ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: widget.vendorLogoImage.isNotEmpty
                      ? SkeletonImage(
                          imageUrl: widget.vendorLogoImage,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: AppColors.primaryLight,
                            child: const Icon(Icons.storefront_outlined,
                                color: AppColors.primaryDark, size: 28),
                          ),
                        )
                      : Container(
                          color: AppColors.primaryLight,
                          child: const Icon(Icons.storefront_outlined,
                              color: AppColors.primaryDark, size: 28),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.vendorName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: C.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Open/Closed badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOpen
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Rating
                        if (widget.products.isNotEmpty) ...[
                          const Icon(Icons.star,
                              size: 14, color: AppColors.gold),
                          const SizedBox(width: 4),
                          Text(
                            '4.8',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: C.textPrimary(context),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(21)',
                            style: TextStyle(
                            fontSize: 12,
                            color: C.textMuted(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: widget.categories.length + 1,
          itemBuilder: (context, index) {
            final category =
                index == 0 ? 'ALL' : widget.categories[index - 1].toUpperCase();
            final bool isSelected = selectedCategory == category;
            return Padding(
              padding: EdgeInsets.only(
                right: index == widget.categories.length
                    ? AppSpacing.lg
                    : AppSpacing.sm,
              ),
              child: GestureDetector(
                onTap: () => setState(() => selectedCategory = category),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryDark
                        : C.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primaryDark.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : C.textPrimary(context),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductList(double hp, double screenWidth) {
    final filteredProducts = widget.products.where((product) {
      final bool matchesCategory = selectedCategory == 'ALL' ||
          product.category.toUpperCase() == selectedCategory.toUpperCase();
      if (!matchesCategory) return false;
      if (vendorSearchQuery.trim().isEmpty) return true;
      final String query = vendorSearchQuery.trim().toLowerCase();
      return product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.lg, hp, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${filteredProducts.length} item${filteredProducts.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: C.textMuted(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...filteredProducts.map(
            (product) => ProductCard(product: product, showVendorName: false, showDescription: true, showStockBadge: true, imageSize: 80),
          ),
        ],
      ),
    );
  }

}
