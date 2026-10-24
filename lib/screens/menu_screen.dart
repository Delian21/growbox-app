import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/bottom_nav.dart';
import '../data/app_state.dart';
import '../data/categories.dart';
import '../data/mock_data.dart';
import '../widgets/vendor_card.dart';
import '../widgets/voice_search_overlay.dart';
import 'category_vendors_screen.dart';
import 'vendor_screen.dart';

class MenuScreen extends StatefulWidget {
  /// Heading above the search field.
  ///
  /// "Browse Produce" for the catalog entry point; the Home feed's Nearby
  /// Vendors "See all" passes "Nearby Vendors", because the same list is a
  /// vendor directory there, not a produce browse.
  final String title;

  /// Label of the "no produce filter" option, so the filter row also matches
  /// what the screen is showing.
  final String allFilterLabel;

  const MenuScreen({
    super.key,
    this.title = 'Browse Produce',
    this.allFilterLabel = 'All Produce',
  });
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool vendorsOpen = true;
  late String selectedProduceType = widget.allFilterLabel;
  String selectedSort = 'Sort by';
  String searchQuery = '';

  /// Adds or removes a vendor from the shared favourites list.
  void _toggleFavorite(String name, Map<String, dynamic> vendor) {
    setState(() {
      final index = favoriteVendors.indexWhere((f) => f['name'] == name);
      if (index >= 0) {
        favoriteVendors.removeAt(index);
      } else {
        favoriteVendors.add({
          'name': name,
          'image': vendor['image'] as String,
          'rating': vendor['percentage'] as String? ?? '',
          'reviews': vendor['reviews'] as String? ?? '',
        });
      }
    });
    persistFavorites();
  }

  bool _matchesSearch(String vendorName, List<String> products) {
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      final matchesSearch = vendorName.toLowerCase().contains(query) ||
          products.any((product) => product.toLowerCase().contains(query));
      if (!matchesSearch) return false;
    }
    if (selectedProduceType != widget.allFilterLabel) {
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
          case 'oils':
            return productName.contains('oil');
          default:
            return true;
        }
      });
      if (!hasMatchingProduce) return false;
    }
    return true;
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
                // Clears the floating nav bar.
                padding: EdgeInsets.only(
                  bottom: BottomNavMetrics.contentInset(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPadding, AppSpacing.lg, horizontalPadding, AppSpacing.sm),
                      child: Text(
                        widget.title,
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
                              color: AppColors.black.withValues(alpha: 0.05),
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
                              icon: Icon(Icons.mic,
                                  size: 20, color: C.primary(context)),
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
                        // Same shared list as the Home rail — including Tubers,
                        // which this screen used to omit.
                        children: [
                          for (final category in kCategories)
                            _CategoryChip(
                              icon: category.icon,
                              label: category.label,
                              color: category.color,
                            ),
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
                              return [widget.allFilterLabel, 'Grains and cereals', 'Fruits', 'Legumes and Pulses',
                                  'Vegetables', 'Tuber and Roots', 'Fresh Proteins', 'Mushrooms',
                                  'Herbs and Spices', 'Nuts and Seeds', 'Oils']
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
                                      if (selectedSort == type) Icon(Icons.check, size: 20, color: C.primary(context))])))
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
                                  // The same card Home uses: image ratio,
                                  // delivery time/fee, rating pill (or "New"),
                                  // with the favourite heart overlaid here.
                                  child: VendorCard(
                                    name: name,
                                    image: vendor['image'] as String,
                                    categories: List<String>.from(
                                        vendor['categories'] as List),
                                    deliveryTime:
                                        vendor['deliveryTime'] as String,
                                    ratingPercentage:
                                        vendor['rating'] as double,
                                    deliveryFee: vendor['deliveryFee'] as int,
                                    isFavorite: favoriteVendors
                                        .any((f) => f['name'] == name),
                                    onFavoriteToggle: () =>
                                        _toggleFavorite(name, vendor),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VendorScreen(
                                          vendorName: name,
                                          vendorCoverImage:
                                              vendor['image'] as String,
                                          vendorLogoImage:
                                              vendor['image'] as String,
                                          initialOpen: vendorsOpen,
                                          categories: List<String>.from(
                                              vendor['categories'] as List),
                                          products: List<VendorProduct>.from(
                                              vendor['products'] as List),
                                        ),
                                      ),
                                    ),
                                  ),
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
