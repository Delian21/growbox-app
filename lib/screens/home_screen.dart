import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/vendor_card.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../data/orders.dart';
import '../routes.dart';
import 'location_screen.dart';
import 'order_history_screen.dart';
import 'menu_screen.dart';
import 'vendor_screen.dart';
import 'category_vendors_screen.dart';

class HomeScreen extends StatefulWidget {
  /// Optional orders store (tests / alternative repositories). Defaults to the
  /// app-wide [ordersStore].
  final OrdersStore? store;

  const HomeScreen({super.key, this.store});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedAddress = defaultAddress?.address ?? 'Asokoro, Abuja';

  OrdersStore get _orders => widget.store ?? ordersStore;

  @override
  void initState() {
    super.initState();
    // Warm the orders store so the active-order banner is correct on the
    // first frame instead of popping in after the request resolves.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _orders.load();
    });
  }

  // Category icon mapping (built-in Flutter icons, no network dependency).
  static final Map<String, IconData> _categoryIcons = {
    'Grains': Icons.grain,
    'Fruits': Icons.apple,
    'Legumes': Icons.spa,
    'Vegetables': Icons.eco,
    'Tubers': Icons.grass,
    'Proteins': Icons.set_meal,
    'Herbs': Icons.local_florist,
    'Oils': Icons.oil_barrel,
  };

  // Category tint colors for visual distinction.
  static final Map<String, Color> _categoryColors = {
    'Grains': AppColors.categoryGrains,
    'Fruits': AppColors.categoryFruits,
    'Legumes': AppColors.categoryLegumes,
    'Vegetables': AppColors.categoryVegetables,
    'Tubers': AppColors.categoryTubers,
    'Proteins': AppColors.categoryProteins,
    'Herbs': AppColors.categoryHerbs,
    'Oils': AppColors.categoryOils,
  };

  static const List<String> _categoryNames = [
    'Grains', 'Fruits', 'Vegetables', 'Legumes', 'Tubers', 'Proteins', 'Herbs', 'Oils',
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
                color: AppColors.primary,
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
                      // Opens the Search tab (not a pushed copy of it), so the
                      // nav highlights Search and its field takes focus.
                      _SearchBar(
                        onTap: () => AppRoutes.pushReplaceAll(
                          context,
                          AppRoutes.search,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      // ── Category Chips ──────────────────────────
                      _buildCategoryChips(screenWidth),
                      // ── Promo Banner ────────────────────────────
                      _buildPromoBanner(screenWidth),
                      const SizedBox(height: AppSpacing.xxl),
                      // ── Active order ─────────────────────────────
                      ListenableBuilder(
                        listenable: _orders,
                        builder: (context, _) {
                          final active = _orders.latestActiveOrder;
                          if (active == null) return const SizedBox.shrink();
                          return _ActiveOrderBanner(
                            order: active,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OrderHistoryScreen(
                                  initialTab: OrdersTab.active,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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
                      // The list owns its bottom inset so the final card and
                      // the end-of-list note clear the floating nav bar.
                      _buildVendorList(screenWidth),
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
          final tint = _categoryColors[name] ?? AppColors.primary;
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CategoryVendorsScreen(category: name.toUpperCase()),
              ),
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
            colors: [AppColors.primary, AppColors.surfaceDark],
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
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'On your first order over ₦10,000',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.white.withValues(alpha: 0.85),
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
                        color: AppColors.white,
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
              color: AppColors.white.withValues(alpha: 0.3),
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
                  backgroundColor: AppColors.primary,
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
                    color: AppColors.black.withValues(alpha: 0.06),
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
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: C.accentOrange(context),
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
    final vendors = MockVendors.vendors;
    const deliveryTimes = [
      '25-35 min',
      '30-40 min',
      '20-30 min',
      '35-45 min',
      '25-40 min',
      '30-35 min',
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Clears the floating nav bar and closes the list off visually.
      padding: EdgeInsets.only(bottom: BottomNavMetrics.contentInset(context)),
      itemCount: vendors.length + 1,
      itemBuilder: (context, index) {
        if (index == vendors.length) return const _EndOfList();

        final vendor = vendors[index];
        final name = vendor['name'] as String;
        final image = vendor['image'] as String;
        final categories = vendor['categories'] as List<String>;
        final products = vendor['products'] as List<VendorProduct>;
        final rating = vendor['rating'] as double;
        final deliveryFee = (vendor['deliveryFee'] as int?) ?? 0;
        final deliveryTime = deliveryTimes[index % deliveryTimes.length];

        return AnimatedEntrance(
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: VendorCard(
              name: name,
              image: image,
              categories: categories,
              deliveryTime: deliveryTime,
              ratingPercentage: rating,
              deliveryFee: deliveryFee,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VendorScreen(
                    vendorName: name,
                    vendorCoverImage: image,
                    vendorLogoImage: image,
                    categories: categories,
                    initialOpen: true,
                    products: products,
                  ),
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
// END OF LIST

/// Closes the vendor feed so the scroll doesn't end on a bare card.
class _EndOfList extends StatelessWidget {
  const _EndOfList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline,
              size: 18, color: C.textMuted(context)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "That's every vendor nearby — more joining soon.",
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: C.textMuted(context)),
          ),
        ],
      ),
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
        // Solid, then a hairline rule: the feed scrolls immediately below
        // this bar, so without them images appeared to slide under a floating
        // transparent header.
        decoration: BoxDecoration(
          color: C.surface(context),
          border: Border(
            bottom: BorderSide(color: C.divider(context), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                size: 20, color: AppColors.primary),
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
              color: AppColors.black.withValues(alpha: 0.06),
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
            const Icon(Icons.mic, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ACTIVE ORDER BANNER

/// Slim strip above "Order Again" that tracks the newest in-flight order.
/// Hidden entirely when nothing is being delivered.
class _ActiveOrderBanner extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _ActiveOrderBanner({required this.order, required this.onTap});

  static String _message(OrderStatus status) => switch (status) {
        OrderStatus.confirmed => "Order confirmed — we're getting it ready",
        OrderStatus.packing => 'Your order is being packed',
        OrderStatus.onTheWay => 'Your order is on the way',
        OrderStatus.delivered => 'Your order has been delivered',
        OrderStatus.cancelled => 'Your order was cancelled',
      };

  static IconData _icon(OrderStatus status) => switch (status) {
        OrderStatus.confirmed => Icons.receipt_long_outlined,
        OrderStatus.packing => Icons.inventory_2_outlined,
        OrderStatus.onTheWay => Icons.local_shipping_outlined,
        OrderStatus.delivered => Icons.check_circle_outline,
        OrderStatus.cancelled => Icons.cancel_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: C.primaryTint(context),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Row(
            children: [
              Icon(_icon(order.status), size: 18, color: C.primary(context)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _message(order.status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: C.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: C.textMuted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
