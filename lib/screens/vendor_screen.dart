import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/vendor_rating.dart';

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
  /// How much cover the app bar shows while it is expanded.
  static const double _expandedHeight = 220;

  /// Room for one 40 px chip row plus its padding, so the pinned row never
  /// jumps as it docks under the bar.
  static const double _chipsHeight = 56;

  final ScrollController _scroll = ScrollController();

  late bool isOpen;

  /// The chosen category, or null for "All". Storing null instead of an "ALL"
  /// sentinel means a vendor can never have a category that collides with it.
  String? selectedCategory;

  /// True once the cover has scrolled far enough that the bar is collapsed.
  bool _collapsed = false;

  bool get isFavorite => favoriteVendors.any((v) => v['name'] == widget.vendorName);

  /// The vendor's rating from the catalog, in the shared 84% / (21) format.
  double get _vendorRating => ratingPercentageFromLabel(
        MockVendors.find(widget.vendorName)?['percentage'] as String?,
      );

  int? get _vendorReviews => reviewCountFromLabel(
        MockVendors.find(widget.vendorName)?['reviews'] as String?,
      );

  /// "25-35 min · ₦500 delivery", built only from fields the vendor model has.
  ///
  /// Both halves are optional: an unknown time drops that part, a zero fee
  /// reads as free delivery, and an empty model leaves the row out entirely.
  String get _deliverySummary {
    // An unknown vendor has no facts to show, so the row is skipped rather
    // than claiming free delivery for a model that says nothing.
    if (MockVendors.find(widget.vendorName) == null) return '';
    final String time = MockVendors.deliveryTimeFor(widget.vendorName);
    final int fee = MockVendors.deliveryFeeFor(widget.vendorName);
    final List<String> parts = [
      if (time.isNotEmpty) time,
      if (fee > 0) '₦${formatPrice(fee)} delivery' else 'Free delivery',
    ];
    return parts.join(' · ');
  }

  @override
  void initState() {
    super.initState();
    isOpen = widget.initialOpen;
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Swaps the bar's title in once the cover is gone, so the vendor's name is
  /// always readable without leaving a hidden duplicate in the semantics tree
  /// while the cover is showing.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final double collapseAt =
        _expandedHeight - kToolbarHeight - MediaQuery.paddingOf(context).top;
    final bool collapsed = _scroll.offset > collapseAt;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  void _toggleFavorite() {
    final bool wasFavorite = isFavorite;
    setState(() {
      if (wasFavorite) {
        favoriteVendors.removeWhere((v) => v['name'] == widget.vendorName);
      } else {
        // Save the real rating: the favourites card used to render the
        // placeholder "0.0" saved here instead of the vendor's 84% / (21).
        favoriteVendors.add({
          'name': widget.vendorName,
          'image': widget.vendorCoverImage,
          'logo': MockVendors.logoFor(widget.vendorName),
          'rating':
              (MockVendors.find(widget.vendorName)?['percentage'] as String?) ??
                  '',
          'reviews':
              (MockVendors.find(widget.vendorName)?['reviews'] as String?) ?? '',
        });
      }
      persistFavorites();
    });
    showAppSnackBar(
      context,
      wasFavorite
          ? '${widget.vendorName} removed from favorites'
          : '${widget.vendorName} added to favorites',
    );
  }

  @override
  Widget build(BuildContext context) {
    final double hp = AppSizing.horizontalPadding(context);

    return Scaffold(
      backgroundColor: C.background(context),
      body: CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildVendorInfo(hp)),
          // The chips dock under the bar while the menu scrolls past them.
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedChipsHeader(
              extent: _chipsHeight,
              child: _buildCategoryChips(hp),
            ),
          ),
          SliverToBoxAdapter(child: _buildProductList(hp)),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: _expandedHeight,
      backgroundColor: C.background(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      // The buttons are the bar's own controls, so they stay put while the
      // cover collapses instead of scrolling away with it.
      leadingWidth: 60,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: _circleButton(
            context,
            icon: Icons.arrow_back,
            label: 'Back',
            onTap: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: _circleButton(
              context,
              icon: isFavorite ? Icons.favorite : Icons.favorite_border,
              label: isFavorite
                  ? 'Remove ${widget.vendorName} from favorites'
                  : 'Add ${widget.vendorName} to favorites',
              onTap: _toggleFavorite,
            ),
          ),
        ),
      ],
      // No title while the cover is showing: the name is right below it.
      title: _collapsed
          ? Text(
              widget.vendorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: C.textPrimary(context),
              ),
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _buildCover(context),
      ),
    );
  }

  /// A dark translucent disc with a white glyph, sized 48×48 so it meets the
  /// minimum tap target wherever it is placed.
  Widget _circleButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: C.surfaceDark(context).withValues(alpha: 0.7),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, size: 22, color: AppColors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.vendorCoverImage.isNotEmpty)
          SkeletonImage(
            imageUrl: widget.vendorCoverImage,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorWidget: _coverFallback(),
          )
        else
          _coverFallback(),
        // Dark at the top so the white controls stay legible on a bright photo,
        // dark at the bottom so the info below reads as a separate layer.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.black.withValues(alpha: 0.35),
                AppColors.transparent,
                AppColors.black.withValues(alpha: 0.45),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _coverFallback() => Container(
        color: C.shimmer(context),
        alignment: Alignment.center,
        child: Icon(Icons.storefront_outlined,
            color: C.textMuted(context), size: 50),
      );

  Widget _buildVendorInfo(double hp) {
    final String delivery = _deliverySummary;

    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.lg, hp, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(context),
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
                            ? C.successSoft(context)
                            : C.errorSoft(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOpen ? 'Open' : 'Closed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOpen
                              ? C.onSuccessSoft(context)
                              : C.error(context),
                        ),
                      ),
                    ),
                    // Rating: thumbs-up + percentage + review count, the same
                    // widget the cards use.
                    if (_vendorRating > 0) ...[
                      const SizedBox(width: 8),
                      VendorRating(
                        percentage: _vendorRating,
                        reviewCount: _vendorReviews,
                        iconSize: 14,
                        fontSize: 13,
                      ),
                    ],
                  ],
                ),
                // Every part of this line comes from the vendor model, so an
                // unknown time or fee simply drops out instead of showing a
                // placeholder.
                if (delivery.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    delivery,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: C.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The vendor's logo when the model has one, otherwise its initial on a
  /// brand tint — never the cover photo again, which is already above it.
  Widget _buildAvatar(BuildContext context) {
    final Widget fallback = Container(
      color: C.primaryTint(context),
      alignment: Alignment.center,
      child: Text(
        widget.vendorName.trim().isEmpty
            ? '?'
            : widget.vendorName.trim().substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: C.primary(context),
        ),
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: 56,
        height: 56,
        child: widget.vendorLogoImage.isNotEmpty
            ? SkeletonImage(
                imageUrl: widget.vendorLogoImage,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorWidget: fallback,
              )
            : fallback,
      ),
    );
  }

  Widget _buildCategoryChips(double hp) {
    final List<String?> entries = [null, ...widget.categories];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: hp),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final String? category = entries[index];
          final bool isSelected = selectedCategory == category;
          final String label = category ?? 'All';
          return Padding(
            padding: EdgeInsets.only(
              right: index == entries.length - 1 ? 0 : AppSpacing.sm,
            ),
            child: GestureDetector(
              onTap: () => setState(() => selectedCategory = category),
              child: Container(
                alignment: Alignment.center,
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? C.primary(context)
                      : C.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: C.primary(context).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? C.onPrimary(context)
                        : C.textPrimary(context),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductList(double hp) {
    final filteredProducts = widget.products.where((product) {
      if (selectedCategory != null &&
          product.category.toLowerCase() != selectedCategory!.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.lg, hp, 100),
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
            (product) => ProductCard(
              product: product,
              showVendorName: false,
              showDescription: true,
              showStockBadge: true,
              imageSize: 80,
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps the chip row docked under the app bar while the menu scrolls.
class _PinnedChipsHeader extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  const _PinnedChipsHeader({required this.extent, required this.child});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // A solid background, so the cards never show through the docked row.
    return Container(
      color: C.background(context),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedChipsHeader old) =>
      old.extent != extent || old.child != child;
}
