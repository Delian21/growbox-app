import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/mock_data.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/skeleton_loader.dart';
import 'vendor_screen.dart';

class CategoryVendorsScreen extends StatelessWidget {
  final String category;
  const CategoryVendorsScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final String selectedCategory = category.replaceAll('\n', ' ').trim().toUpperCase();

    final List<Map<String, dynamic>> vendors =
        List<Map<String, dynamic>>.from(MockVendors.categoryVendors);

    final matchingVendors = vendors.where((vendor) {
      final List<String> vendorCategories = List<String>.from(vendor['categories']);
      return vendorCategories.contains(selectedCategory);
    }).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Custom header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xl - 2, AppSpacing.lg, 0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(
                      width: 40, height: 40,
                      child: Center(
                        child: Icon(Icons.chevron_left, size: 30,
                          color: C.textPrimary(context)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      category.replaceAll('\n', ' '),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: C.textPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Vendor list ────────────────────────────────────────
            Expanded(
              child: matchingVendors.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'No vendors found for this category.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.grey600,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, 40,
                      ),
                      itemCount: matchingVendors.length,
                      separatorBuilder: (_, _)
                          => const SizedBox(height: AppSpacing.xxl),
                      itemBuilder: (context, index) {
                        final vendor = matchingVendors[index];
                        return _categoryVendorCard(
                          context: context,
                          name: vendor['name'] as String,
                          image: vendor['image'] as String,
                          category: selectedCategory,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryVendorCard({
    required BuildContext context,
    required String name,
    required String image,
    required String category,
  }) {
    // Only show the products the vendor actually sells under this
    // category, and build the tabs from those products so every tab
    // has items.
    final products = MockVendors.productsForVendor(name, category);
    final tabCategories = {
      for (final p in products) p.category,
    }.toList();
    return TapFeedback(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorScreen(
            vendorName: name,
            vendorCoverImage: image,
            vendorLogoImage: image,
            initialOpen: true,
            categories: tabCategories,
            products: products,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.85,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: image.isNotEmpty
                  ? SkeletonImage(
                      imageUrl: image,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: _emptyImage(),
                    )
                  : _emptyImage(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: C.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyImage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.grey200,
      alignment: Alignment.center,
      child: const Icon(Icons.storefront_outlined, size: 48, color: AppColors.grey500),
    );
  }
}
