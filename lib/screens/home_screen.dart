import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/vendor_card.dart';
import '../widgets/load_error_view.dart';
import '../widgets/order_rating_sheet.dart';
import '../data/addresses.dart';
import '../data/app_state.dart';
import '../data/catalog_repository.dart';
import '../data/categories.dart';
import '../data/mock_data.dart';
import '../data/orders.dart';
import '../tabs.dart';
import 'edit_profile_screen.dart';
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
  /// Storage key for an explicit dismissal of the profile nudge.
  static const String _nudgeDismissedKey = 'profile_nudge_dismissed';

  /// Hidden for good once the customer taps the X (see [_dismissNudge]).
  bool _nudgeDismissed = false;

  /// Storage key holding the ids of orders whose rating prompt was dismissed,
  /// so "Rate your order" is shown once and never again.
  static const String _ratingPromptDismissedKey = 'rating_prompt_dismissed';

  /// Order ids whose rating banner the customer has closed.
  final Set<String> _ratingPromptDismissed = {};

  /// The feed is fetched, not read straight from [MockVendors], so it has a
  /// real loading state, a real failure state and a retry.
  List<Map<String, dynamic>> _vendors = const [];
  bool _vendorsLoading = true;
  bool _vendorsFailed = false;

  OrdersStore get _orders => widget.store ?? ordersStore;

  /// True while the customer has no name or no email — the same condition the
  /// profile card prompts on.
  bool get _profileIsIncomplete =>
      (CustomerData.name?.trim().isEmpty ?? true) ||
      (CustomerData.email?.trim().isEmpty ?? true);

  /// The profile lives in globals rather than a notifier, so repaint on return
  /// so the nudge disappears as soon as the details are saved.
  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // Fills the feed; the first frame shows skeletons, not an empty section.
    _loadVendors(keepContent: true);
    // Warm the orders store so the active-order banner is correct on the
    // first frame instead of popping in after the request resolves.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _orders.load();
    });
    // The header reads the selected address; make sure it is hydrated even if
    // this screen is the first thing a test (or a deep link) opens.
    addressesStore.load();
    _restoreNudgeDismissal();
    _restoreRatingPromptDismissals();
  }

  /// Restores the orders whose rating banner was dismissed in an earlier
  /// session, so the prompt really is shown once.
  Future<void> _restoreRatingPromptDismissals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_ratingPromptDismissedKey) ?? const [];
      if (mounted && ids.isNotEmpty) {
        setState(() => _ratingPromptDismissed.addAll(ids));
      }
    } catch (_) {
      // Best effort: the banner simply stays until it is dismissed again.
    }
  }

  /// Hides the rating banner for [orderId] now and remembers the choice.
  Future<void> _dismissRatingPrompt(String orderId) async {
    setState(() => _ratingPromptDismissed.add(orderId));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _ratingPromptDismissedKey,
        _ratingPromptDismissed.toList(),
      );
    } catch (_) {
      // Still hidden for this session even if persistence fails.
    }
  }

  /// Opens the rating sheet for the delivered order in the banner.
  Future<void> _rateOrder(Order order) async {
    final rating = await showOrderRatingSheet(
      context,
      vendorName: order.vendorName,
    );
    if (!mounted) return;
    await _orders.rate(order.id, rating);
  }

  /// Fetches the vendor feed.
  ///
  /// [keepContent] is the pull-to-refresh path: the current cards stay up while
  /// the request runs, and a failure shows the snackbar instead of replacing
  /// them with an error.
  Future<void> _loadVendors({bool keepContent = false}) async {
    if (!keepContent) {
      setState(() {
        _vendorsLoading = true;
        _vendorsFailed = false;
      });
    }
    try {
      final vendors = await catalogRepository.getVendors();
      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _vendorsLoading = false;
        _vendorsFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      final bool hadContent = _vendors.isNotEmpty;
      setState(() {
        _vendorsLoading = false;
        // Nothing to keep means the section itself becomes the error state.
        _vendorsFailed = !hadContent;
      });
      if (keepContent && hadContent) {
        showAppSnackBar(
          context,
          "Couldn't refresh vendors. Check your connection and try again.",
          isError: true,
        );
      }
    }
  }

  /// Restores a dismissal made in an earlier session.
  Future<void> _restoreNudgeDismissal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(_nudgeDismissedKey) ?? false;
      if (mounted && dismissed != _nudgeDismissed) {
        setState(() => _nudgeDismissed = dismissed);
      }
    } catch (_) {
      // Best effort: the nudge simply stays visible.
    }
  }

  /// Hides the nudge now and remembers the choice.
  Future<void> _dismissNudge() async {
    setState(() => _nudgeDismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_nudgeDismissedKey, true);
    } catch (_) {
      // Still hidden for this session even if persistence fails.
    }
  }


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
            ListenableBuilder(
              listenable: addressesStore,
              builder: (context, _) {
                final selected = addressesStore.selectedAddress;
                // No fake default: without a saved address the header asks for
                // one instead of naming a place the rider was never told about.
                final label = (selected == null || selected.summary.isEmpty)
                    ? 'Choose location'
                    : selected.summary;
                return _AddressBar(
                  address: label,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LocationScreen()),
                  ),
                );
              },
            ),
            // ── Scrollable Content ──────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadVendors(keepContent: true),
                color: C.primary(context),
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
                        // A tab switch, not a push: Search is the second tab
                        // of the shell, so Back from it returns to Home and the
                        // field is focused as if the bar had been tapped.
                        onTap: () => openTab(
                          context,
                          AppTab.search,
                          focusSearchField: true,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      // ── Category Chips ──────────────────────────
                      _buildCategoryChips(screenWidth),
                      // ── Promo Banner ────────────────────────────
                      _buildPromoBanner(screenWidth),
                      const SizedBox(height: AppSpacing.xxl),
                      // ── Active order ─────────────────────────────
                      // First, because a live delivery outranks a profile tip.
                      ListenableBuilder(
                        listenable: _orders,
                        builder: (context, _) {
                          final active = _orders.latestActiveOrder;
                          if (active != null) {
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
                          }

                          // Nothing in flight: the banner's other job is to
                          // ask about the last delivery once. A dismissed or
                          // answered order never returns to it, and a
                          // cancelled order has nothing to ask.
                          final unrated = _orders.latestAwaitingFeedback;
                          if (unrated == null ||
                              _ratingPromptDismissed.contains(unrated.id)) {
                            return const SizedBox.shrink();
                          }
                          return _ActiveOrderBanner(
                            order: unrated,
                            onTap: () => _rateOrder(unrated),
                            onDismiss: () => _dismissRatingPrompt(unrated.id),
                          );
                        },
                      ),
                      // ── Profile nudge ────────────────────────────
                      if (_profileIsIncomplete && !_nudgeDismissed)
                        _ProfileNudge(
                          onTap: _openEditProfile,
                          onDismiss: _dismissNudge,
                        ),
                      // ── Buy Again ───────────────────────────────
                      if (buyAgainItems.isNotEmpty) ...[
                        SectionHeader(
                          title: 'Order Again',
                          actionText: 'See all',
                          // Past is where the orders you can reorder live.
                          onAction: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OrderHistoryScreen(
                                initialTab: OrdersTab.past,
                              ),
                            ),
                          ),
                        ),
                        _buildBuyAgainRow(buyAgainItems, screenWidth),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                      // ── Nearby Vendors ──────────────────────────
                      SectionHeader(
                        title: 'Nearby Vendors',
                        actionText: 'See all',
                        onAction: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MenuScreen(
                              // Same list, but it is a vendor list here — not
                              // a produce browse — so the heading and the
                              // "no filter" label say so.
                              title: 'Nearby Vendors',
                              allFilterLabel: 'All Vendors',
                            ),
                          ),
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
        itemCount: kCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          // Shared list: the Browse screen shows the same labels and icons.
          final category = kCategories[index];
          final name = category.label;
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
                      color: category.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(category.icon, color: category.color, size: 28),
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
    // Theme-aware pair: deep greens in dark mode, where the lifted primary
    // would leave the banner's white text at ~1.9:1.
    final List<Color> gradient = C.promoGradient(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
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
                      child: Text(
                        'Shop Now',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          // On a white pill, so the fixed brand green (10.6:1)
                          // rather than the theme's lifted dark-mode primary.
                          color: AppColors.brand,
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
              showAppSnackBar(
                context,
                '${product.name} added to box',
                actionLabel: 'View box',
                onAction: () => openTab(context, AppTab.cart),
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
                            // Two lines: long names (e.g. "Fresh Tomatoes
                            // (Crate)") stay readable instead of clipping.
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.15,
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
    // ── Loading: three cards at the real card's exact height ──────
    if (_vendorsLoading) {
      return Shimmer(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            BottomNavMetrics.contentInset(context),
          ),
          child: Column(
            children: [
              for (var i = 0; i < 3; i++)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: VendorCardSkeleton(),
                ),
            ],
          ),
        ),
      );
    }

    // ── Failed: just this section, so the rest of Home stays ──────
    if (_vendorsFailed) {
      return Padding(
        padding: EdgeInsets.only(bottom: BottomNavMetrics.contentInset(context)),
        child: LoadErrorView(
          title: "Couldn't load vendors",
          onRetry: () => _loadVendors(),
        ),
      );
    }

    final vendors = _vendors;

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
        // Stored with the vendor now, so Browse shows the same estimate.
        final deliveryTime = vendor['deliveryTime'] as String;

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
                    vendorLogoImage: MockVendors.logoFor(name),
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
            Icon(Icons.location_on_outlined,
                size: 20, color: C.primary(context)),
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
            Icon(Icons.mic, size: 20, color: C.primary(context)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PROFILE NUDGE

/// Slim prompt for customers who never added a name or an email.
///
/// Deliberately styled like the active-order banner so the feed reads as one
/// family of strips; it is removed from the tree as soon as the profile is
/// complete.
class _ProfileNudge extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _ProfileNudge({required this.onTap, required this.onDismiss});

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
          key: const ValueKey('profileNudge'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: C.surface(context),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: C.accentOrange(context).withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: C.accentOrange(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add your name and email',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: C.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'So vendors know who they are delivering to',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 12,
                        color: C.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              // X rather than a chevron: the whole card already opens the
              // editor, so the trailing control's job is dismissal.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(Icons.close,
                        size: 18, color: C.textMuted(context)),
                  ),
                ),
              ),
            ],
          ),
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

  /// Supplied only for the rating prompt, which the customer can close.
  final VoidCallback? onDismiss;

  const _ActiveOrderBanner({
    required this.order,
    required this.onTap,
    this.onDismiss,
  });

  /// Status line.
  ///
  /// Named by vendor where the vendor is the subject, dropped where the order
  /// is: "Your order is on the way" needs no name. Delivered is the rating
  /// prompt, because that is the one thing left to do with a delivered order.
  String get _message => switch (order.status) {
        OrderStatus.confirmed => '${order.vendorName} confirmed your order',
        OrderStatus.packing => '${order.vendorName} is packing your order',
        OrderStatus.pickedUp =>
          'Your order from ${order.vendorName} has been picked up',
        OrderStatus.onTheWay => 'Your order is on the way',
        OrderStatus.delivered => 'Rate your order from ${order.vendorName}',
        // Never rendered: a cancelled order is neither active nor awaiting
        // feedback, so it cannot become the banner's source.
        OrderStatus.cancelled =>
          'Your order from ${order.vendorName} was cancelled',
      };

  static IconData _icon(OrderStatus status) => switch (status) {
        OrderStatus.confirmed => Icons.receipt_long_outlined,
        OrderStatus.packing => Icons.inventory_2_outlined,
        OrderStatus.pickedUp => Icons.two_wheeler_outlined,
        OrderStatus.onTheWay => Icons.local_shipping_outlined,
        OrderStatus.delivered => Icons.thumb_up_alt_outlined,
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
              // Two lines: a vendor name plus a status line used to truncate
              // mid-word on a 320dp phone. Two lines fit every status without
              // growing the strip for the short ones.
              Expanded(
                child: Text(
                  _message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: C.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (onDismiss == null)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: C.textMuted(context),
                )
              else
                // Closing the prompt must not also open it: its own 44px
                // target, separate from the banner's tap.
                Semantics(
                  button: true,
                  label: 'Dismiss rating prompt',
                  child: GestureDetector(
                    onTap: onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: C.textMuted(context),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
