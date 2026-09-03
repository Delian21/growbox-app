import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/scaffold_with_nav.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import 'location_screen.dart';
import 'menu_screen.dart';
import 'vendor_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedAddress = defaultAddress?.address ?? 'Asokoro, Abuja';

  // Category icon mapping (built-in Flutter icons, no network dependency).
  static final Map<String, IconData> _categoryIcons = {
    'Grains': Icons.grain,
    'Fruits': Icons.apple,
    'Legumes': Icons.spa,
    'Vegetables': Icons.eco,
    'Tubers': Icons.grass,
    'Proteins': Icons.set_meal,
    'Herbs': Icons.local_florist,
  };

  // Category tint colors for visual distinction.
  static final Map<String, Color> _categoryColors = {
    'Grains': const Color(0xFF8D6E63),
    'Fruits': const Color(0xFFEF5350),
    'Legumes': const Color(0xFF66BB6A),
    'Vegetables': const Color(0xFF43A047),
    'Tubers': const Color(0xFF8D6E63),
    'Proteins': const Color(0xFFEF5350),
    'Herbs': const Color(0xFF66BB6A),
  };

  static const List<String> _categoryNames = [
    'Grains', 'Fruits', 'Vegetables', 'Legumes', 'Tubers', 'Proteins', 'Herbs',
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;
    final buyAgainItems = getBuyAgainItems();

    return ScaffoldWithNav(
      activeIndex: 0,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Address Bar ─────────────────────────────────────────
            _AddressBar(
              address: selectedAddress,
              onTap: () async {
                final result = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const LocationScreen()),
                );
                if (result != null && result.isNotEmpty && mounted) {
                  setState(() => selectedAddress = result);
                }
              },
            ),
            // ── Scrollable Content ──────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 600));
                  setState(() {});
                },
                color: AppColors.primaryDark,
                backgroundColor: C.surface(context),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      // ── Search Bar ──────────────────────────────
                      _SearchBar(onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.xxl),
                      // ── Category Chips ──────────────────────────
                      _buildCategoryChips(screenWidth),
                      // ── Promo Banner ────────────────────────────
                      _buildPromoBanner(screenWidth),
                      const SizedBox(height: AppSpacing.xxl),
                      // ── Buy Again ───────────────────────────────
                      if (buyAgainItems.isNotEmpty) ...[
                        SectionHeader(title: 'Order Again', actionText: 'See all', onAction: () {}),
                        _buildBuyAgainRow(buyAgainItems, screenWidth),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                      // ── Nearby Vendors ──────────────────────────
                      SectionHeader(
                        title: 'Nearby Vendors',
                        actionText: 'See all',
                        onAction: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MenuScreen()),
                        ),
                      ),
                      _buildVendorList(screenWidth),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SECTION BUILDERS
  Widget _buildCategoryChips(double screenWidth) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: _categoryNames.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final name = _categoryNames[index];
          final icon = _categoryIcons[name] ?? Icons.eco_outlined;
          final tint = _categoryColors[name] ?? AppColors.primaryDark;
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MenuScreen()),
            ),
            child: SizedBox(
              width: 70,
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: tint, size: 28),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
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
        },
      ),
    );
  }

  Widget _buildPromoBanner(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF2D6B22)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Free Delivery!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'On your first order over ₦10,000',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MenuScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Shop Now',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBuyAgainRow(List<VendorProduct> items, double screenWidth) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final product = items[index];
          return AnimatedEntrance(
            index: index,
            slideOffset: const Offset(0.06, 0),
            child: GestureDetector(
            onTap: () {
              context.read<CartNotifier>().add(product);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} added to box'),
                  backgroundColor: AppColors.primaryDark,
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
              );
            },
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                color: C.surface(context),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      // Pin the photo to a fixed 1:1 tile so every card crops
                      // to the same square regardless of the source image's
                      // aspect ratio (cover fills the tile either way).
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          // Fades the photo in instead of popping, and shows
                          // a skeleton tile while a bundled asset decodes.
                          child: SkeletonImage(
                            imageUrl: product.image,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            scrim: kProductImageScrim,
                            errorWidget: Container(
                              color: C.shimmer(context),
                              child: Center(
                                child: Icon(Icons.shopping_basket_outlined,
                                    color: C.textMuted(context), size: 28),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: C.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₦${formatPrice(product.price)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _buildVendorList(double screenWidth) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: MockVendors.vendors.length,
      itemBuilder: (context, index) {
        final vendor = MockVendors.vendors[index];
        final name = vendor['name'] as String;
        final image = vendor['image'] as String;
        final rating = vendor['rating'] as double;
        final percentage = vendor['percentage'] as String;
        final products = vendor['products'] as List<VendorProduct>;

        final deliveryTimes = ['25-35 min', '30-40 min', '20-30 min', '35-45 min', '25-40 min', '30-35 min'];
        final deliveryFees = ['₦500', '₦300', '₦800', '₦400', '₦500', '₦350'];
        final deliveryTime = deliveryTimes[index % deliveryTimes.length];
        final deliveryFee = deliveryFees[index % deliveryFees.length];

        return AnimatedEntrance(
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VendorScreen(
                    vendorName: name,
                    vendorCoverImage: image,
                    vendorLogoImage: image,
                    categories: vendor['categories'] as List<String>,
                    initialOpen: true,
                    products: products,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: C.surface(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Vendor image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 140,
                      child: SkeletonImage(
                        imageUrl: image,
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          color: C.shimmer(context),
                          child: Center(
                            child: Icon(Icons.storefront_outlined,
                                color: C.textMuted(context), size: 40),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Vendor info
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: C.textPrimary(context),
                                ),
                              ),
                            ),
                            if (percentage.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$percentage liked',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 14, color: C.textMuted(context)),
                            const SizedBox(width: 4),
                            Text(
                              deliveryTime,
                              style: TextStyle(
                                  fontSize: 12, color: C.textMuted(context)),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.delivery_dining,
                                size: 14, color: C.textMuted(context)),
                            const SizedBox(width: 4),
                            Text(
                              deliveryFee,
                              style: TextStyle(
                                  fontSize: 12, color: C.textMuted(context)),
                            ),
                            if (rating > 0) ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.star,
                                  size: 14, color: AppColors.gold),
                              const SizedBox(width: 4),
                              Text(
                                '${rating.round()}%',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.gold),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// REUSABLE COMPONENTS

class _AddressBar extends StatelessWidget {
  final String address;
  final VoidCallback onTap;
  const _AddressBar({required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                size: 20, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: C.textPrimary(context),
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down,
                size: 20, color: C.textPrimary(context)),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: C.surface(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: C.textMuted(context)),
            const SizedBox(width: 12),
            Text(
              'Search for produce...',
              style: TextStyle(
                fontSize: 15,
                color: C.textMuted(context),
              ),
            ),
            const Spacer(),
            const Icon(Icons.mic, size: 20, color: AppColors.primaryDark),
          ],
        ),
      ),
    );
  }
}
