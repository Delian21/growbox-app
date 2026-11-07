import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../widgets/app_header.dart';
import '../widgets/skeleton_loader.dart';
import '../data/mock_data.dart';
import '../widgets/vendor_rating.dart';
import '../widgets/status_view.dart';
import '../routes.dart';
import 'vendor_screen.dart';

class FavoritesScreen extends StatefulWidget {
  /// A favourites list to render instead of the saved one. Only the demo state
  /// gallery passes it, so an empty state can be shown without clearing (and
  /// persisting over) the customer's real favourites.
  final List<Map<String, String>>? favorites;

  const FavoritesScreen({super.key, this.favorites});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, String>> get favorites =>
      widget.favorites ?? favoriteVendors;

  void _removeFavorite(int index) {
    setState(() => favorites.removeAt(index));
    // A gallery list is a copy: removing from it must not rewrite storage.
    if (widget.favorites == null) persistFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final hp = AppSizing.horizontalPadding(context);

    // Pushed from Home/Profile: no bottom nav here.
    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(title: 'Favorites'),
            // ── Favorites List ──────────────────────────────────
            Expanded(
              child: favorites.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        hp,
                        AppSpacing.md,
                        hp,
                        AppSpacing.xxl,
                      ),
                      itemCount: favorites.length,
                      itemBuilder: (context, index) {
                        final favorite = favorites[index];
                        return _buildFavoriteCard(
                            index: index, favorite: favorite);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return StatusView(
      icon: Icons.favorite_border,
      title: 'No favorites yet',
      message: 'Tap the heart on a vendor to save it here.',
      // Same tab hand-off the bottom nav uses, so Home is the live tab and
      // not a second Home stacked on this screen.
      primaryLabel: 'Browse vendors',
      onPrimary: () => AppRoutes.pushReplaceAll(context, AppRoutes.home),
    );
  }

  Widget _buildFavoriteCard(
      {required int index, required Map<String, String> favorite}) {
    final String name = favorite['name'] ?? 'Vendor';
    final String image = favorite['image'] ?? '';
    // Favourites store the vendor's own labels; parse them into the shared
    // rating format instead of printing the raw string (which used to render
    // the placeholder "0.0" saved by the vendor page).
    final double rating = ratingPercentageFromLabel(favorite['rating']);
    final int? reviewCount = reviewCountFromLabel(favorite['reviews']);

    return Padding(
      padding:   EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        onTap: () {
          final vendorData = MockVendors.vendors
              .where((v) => v['name'] == name)
              .toList();
          if (vendorData.isNotEmpty) {
            final vendor = vendorData.first;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VendorScreen(
                  vendorName: vendor['name'] as String,
                  vendorCoverImage: vendor['image'] as String,
                  // Saved favourites carry the logo; older entries without one
                  // fall back to the monogram.
                  vendorLogoImage: (vendor['logo'] as String?) ?? '',
                  categories:
                      List<String>.from(vendor['categories'] as List),
                  products:
                      List<VendorProduct>.from(vendor['products'] as List),
                ),
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: C.surface(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset:   Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:   BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 140,
                      child: image.isNotEmpty
                          ? SkeletonImage(
                              imageUrl: image,
                              width: double.infinity,
                              height: 140,
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                color: AppColors.shimmer,
                                child: Center(
                                  child: Icon(Icons.storefront_outlined,
                                      color: C.textMuted(context), size: 40),
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.shimmer,
                              child:   Center(
                                child: Icon(Icons.storefront_outlined,
                                    color: C.textMuted(context), size: 40),
                              ),
                            ),
                    ),
                  ),
                  // Remove button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => _removeFavorite(index),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration:   BoxDecoration(
                          color: C.surface(context),
                          shape: BoxShape.circle,
                        ),
                        child:   Icon(Icons.favorite,
                            size: 20, color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ),
              // Vendor info
              Padding(
                padding:   EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: C.textPrimary(context),
                      ),
                    ),
                    if (rating > 0) ...[
                        SizedBox(height: 6),
                      VendorRating(
                        percentage: rating,
                        reviewCount: reviewCount,
                        iconSize: 14,
                        fontSize: 13,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
