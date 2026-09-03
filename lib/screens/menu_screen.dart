import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/skeleton_loader.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../widgets/voice_search_overlay.dart';
import 'category_vendors_screen.dart';
import 'vendor_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool vendorsOpen = true;
  String selectedProduceType = 'All Produce';
  String selectedSort = 'Sort by';
  String searchQuery = '';

  bool _matchesSearch(String vendorName, List<String> products) {
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      final matchesSearch = vendorName.toLowerCase().contains(query) ||
          products.any((product) => product.toLowerCase().contains(query));
      if (!matchesSearch) return false;
    }
    if (selectedProduceType != 'All Produce') {
      final type = selectedProduceType.toLowerCase();
      final hasMatchingProduce = products.any((product) {
        final productName = product.toLowerCase();
        switch (type) {
          case 'grains and cereals':
            return productName == 'rice' || productName == 'millet' || productName == 'maize' ||
                productName == 'sorghum' || productName == 'grains' || productName == 'cereals';
          case 'fruits':
            return productName.contains('fruit') || productName == 'tomatoes' || productName == 'fresh apples';
          case 'legumes and pulses':
            return productName == 'beans' || productName == 'soybeans' || productName == 'legumes';
          case 'vegetables':
            return productName == 'tomatoes' || productName == 'vegetables' || productName == 'fresh vegetables';
          case 'tuber and roots':
            return productName.contains('tuber') || productName.contains('root');
          case 'fresh proteins':
            return productName.contains('meat') || productName.contains('protein');
          case 'mushrooms':
            return productName.contains('mushroom');
          case 'herbs and spices':
            return productName.contains('herb') || productName.contains('spice');
          case 'nuts and seeds':
            return productName.contains('nut') || productName.contains('seed');
          default:
            return true;
        }
      });
      if (!hasMatchingProduce) return false;
    }
    return true;
  }

  Widget _networkImage(String url, {BoxFit fit = BoxFit.cover, BorderRadius? borderRadius}) {
    Widget image = SkeletonImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorWidget: Container(
        color: AppColors.shimmer,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: AppColors.grey500, size: 28),
      ),
    );
    if (borderRadius != null) image = ClipRRect(borderRadius: borderRadius, child: image);
    return image;
  }


  Widget _vendorCard({required String image, required String name, String? percentage, String? reviews, int animIndex = 0}) {
    return AnimatedEntrance(
      index: animIndex,
      child: Container(
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 3.15,
                child: _networkImage(image)),
              if (!vendorsOpen)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(0, 0, 0, 0.70),
                    ),
                    alignment: Alignment.center,
                    child: Text('Closed', style: TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w500, color: AppColors.white)))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: C.textPrimary(context)))),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      final existingIndex = favoriteVendors.indexWhere((f) => f['name'] == name);
                      if (existingIndex >= 0) {
                        favoriteVendors.removeAt(existingIndex);
                      } else {
                        favoriteVendors.add({'name': name, 'image': image,
                          'rating': percentage ?? '', 'reviews': reviews ?? ''});
                      }
                      persistFavorites();
                    });
                  },
                  child: Icon(
                    favoriteVendors.any((f) => f['name'] == name) ? Icons.favorite : Icons.favorite_border,
                    size: 22,
                    color: favoriteVendors.any((f) => f['name'] == name) ? AppColors.error : C.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          if (percentage != null && reviews != null && percentage.isNotEmpty && reviews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  const Icon(Icons.thumb_up_outlined, size: 16, color: AppColors.primaryDark),
                  const SizedBox(width: 6),
                  Text(percentage,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                  const SizedBox(width: 4),
                  Text(reviews,
                    style: TextStyle(fontSize: 13, color: C.textMuted(context))),
                ],
              ),
            ),
        ],
      ),
    ),
    );
  }




  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;

    return ScaffoldWithNav(
      activeIndex: 1,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPadding, AppSpacing.lg, horizontalPadding, AppSpacing.sm),
                      child: Text(
                        'Browse Produce',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: C.textPrimary(context),
                        ),
                      ),
                    ),
                    // ── Search bar ────────────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: C.surface(context),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          onChanged: (value) => setState(() => searchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search for produce...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: C.textMuted(context),
                            ),
                            prefixIcon: Icon(Icons.search, size: 20, color: C.textMuted(context)),
                            suffixIcon: IconButton(
                              onPressed: () async {
                                final intent = await showVoiceSearch(context);
                                if (intent != null && mounted) {
                                  setState(() => searchQuery = intent.productQuery);
                                }
                              },
                              icon: Icon(Icons.mic, size: 20, color: AppColors.primaryDark),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // ── Categories ──────────────────────────────
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        physics: const BouncingScrollPhysics(),
                        children: const [
                          _CategoryChip(icon: Icons.grain, label: 'Grains', color: Color(0xFF8D6E63)),
                          _CategoryChip(icon: Icons.apple, label: 'Fruits', color: Color(0xFFE53935)),
                          _CategoryChip(icon: Icons.emoji_food_beverage, label: 'Legumes', color: Color(0xFF66BB6A)),
                          _CategoryChip(icon: Icons.eco, label: 'Vegetables', color: Color(0xFF4CAF50)),
                          _CategoryChip(icon: Icons.set_meal, label: 'Proteins', color: Color(0xFFE53935)),
                          _CategoryChip(icon: Icons.local_florist, label: 'Herbs', color: Color(0xFF2E7D32)),
                        ],
                      ),
                    ),
                    // ── Filters ──────────────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PopupMenuButton<String>(
                            onSelected: (value) => setState(() => selectedProduceType = value),
                            offset: const Offset(0, 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            itemBuilder: (context) {
                              return ['All Produce', 'Grains and cereals', 'Fruits', 'Legumes and Pulses',
                                  'Vegetables', 'Tuber and Roots', 'Fresh Proteins', 'Mushrooms',
                                  'Herbs and Spices', 'Nuts and Seeds']
                                  .map((type) => PopupMenuItem(value: type, child: Text(type)))
                                  .toList();
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(selectedProduceType,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.textPrimary(context))),
                                const SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down, size: 18, color: C.textMuted(context)),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) => setState(() => selectedSort = value),
                            offset: const Offset(0, 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            itemBuilder: (context) => ['Sort by', 'Recommended', 'Price: Low to High',
                                'Price: High to Low', 'Highest Rated']
                                .map((type) => PopupMenuItem(value: type,
                                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [Text(type),
                                      if (selectedSort == type) const Icon(Icons.check, size: 20, color: AppColors.primaryDark)])))
                                .toList(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(selectedSort,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.textPrimary(context))),
                                const SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down, size: 18, color: C.textMuted(context)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 13),
                    // Vendors
                    Builder(
                      builder: (context) {
                        final vendors = List<Map<String, dynamic>>.from(MockVendors.vendors);
                        if (selectedSort == 'Price: Low to High') {
                          vendors.sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));
                        } else if (selectedSort == 'Price: High to Low') {
                          vendors.sort((a, b) => (b['price'] as double).compareTo(a['price'] as double));
                        } else if (selectedSort == 'Highest Rated') {
                          vendors.sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));
                        }
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: Column(
                            children: [
                              ...vendors.map((vendor) {
                                final String name = vendor['name'] as String;
                                final List<String> searchProducts = List<String>.from(vendor['searchProducts'] as List);
                                if (!_matchesSearch(name, searchProducts)) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (context) => VendorScreen(
                                        vendorName: name,
                                        vendorCoverImage: vendor['image'] as String,
                                        vendorLogoImage: vendor['image'] as String,
                                        initialOpen: vendorsOpen,
                                        categories: List<String>.from(vendor['categories'] as List),
                                        products: List<VendorProduct>.from(vendor['products'] as List)))),
                                    child: _vendorCard(
                                      image: vendor['image'] as String, name: name,
                                      percentage: vendor['percentage'] as String,
                                      reviews: vendor['reviews'] as String)),
                                );
                              }),
                              const SizedBox(height: 74),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Category chip widget ──────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CategoryChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => CategoryVendorsScreen(category: label.toUpperCase()),
        ));
      },
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: C.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
