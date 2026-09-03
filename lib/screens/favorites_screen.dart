import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/skeleton_loader.dart';
import '../data/mock_data.dart';
import 'vendor_screen.dart';

class FavoritesScreen extends StatefulWidget {
    const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, String>> get favorites => favoriteVendors;

  void _removeFavorite(int index) {
    setState(() => favorites.removeAt(index));
    persistFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final hp = AppSizing.horizontalPadding(context);

    return ScaffoldWithNav(
      activeIndex: 3,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hp, AppSpacing.lg, hp, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back,
                        size: 24, color: C.textPrimary(context)),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Favorites',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: C.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 24),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            // ── Favorites List ──────────────────────────────────
            Expanded(
              child: favorites.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(hp, 0, hp, 30),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child:   Icon(
              Icons.favorite_border,
              size: 48,
              color: AppColors.primaryDark,
            ),
          ),
            SizedBox(height: AppSpacing.xxl),
          Text(
            'No favorites yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: C.textPrimary(context),
            ),
          ),
            SizedBox(height: AppSpacing.sm),
          Text(
            'Tap the heart icon on a vendor\nto add them to your favorites',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: C.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(
      {required int index, required Map<String, String> favorite}) {
    final String name = favorite['name'] ?? 'Vendor';
    final String image = favorite['image'] ?? '';
    final String rating = favorite['rating'] ?? '';
    final String reviews = favorite['reviews'] ?? '';

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
                  vendorLogoImage: vendor['image'] as String,
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
                color: Colors.black.withValues(alpha: 0.06),
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
                    if (rating.isNotEmpty || reviews.isNotEmpty) ...[
                        SizedBox(height: 6),
                      Row(
                        children: [
                            Icon(Icons.star,
                              size: 14, color: AppColors.gold),
                            SizedBox(width: 4),
                          if (rating.isNotEmpty)
                            Text(
                              rating,
                              style:   TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.gold,
                              ),
                            ),
                          if (reviews.isNotEmpty) ...[
                              SizedBox(width: 4),
                            Text(
                              reviews,
                              style:   TextStyle(
                                fontSize: 12,
                                color: C.textMuted(context),
                              ),
                            ),
                          ],
                        ],
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
