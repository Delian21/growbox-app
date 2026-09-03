import '../widgets/product_card.dart';
import 'package:flutter/material.dart';
import '../widgets/animated_entrance.dart';
import '../theme.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/micro_interactions.dart';
import '../data/mock_data.dart';
import 'vendor_screen.dart';
import '../widgets/voice_search_overlay.dart';

/// In-memory recent search history (resets on app restart).
final List<String> recentSearches = [];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void clearSearch() {
    searchController.clear();
    setState(() {});
  }

  String get query => searchController.text.trim().toLowerCase();

  // ── Search logic ──────────────────────────────────────────────────────
  List<VendorProduct> get _allProducts {
    final List<VendorProduct> products = [];
    for (final vendor in MockVendors.vendors) {
      final vendorProducts = vendor['products'] as List<VendorProduct>;
      products.addAll(vendorProducts);
    }
    return products;
  }

  List<VendorProduct> get _matchedProducts {
    if (query.isEmpty) return [];
    return _allProducts.where((p) {
      return p.name.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query) ||
          p.vendorName.toLowerCase().contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _matchedVendors {
    return MockVendors.vendors.where((v) {
      final name = (v['name'] as String).toLowerCase();
      if (name.contains(query)) return true;
      final searchProducts = List<String>.from(v['searchProducts'] ?? []);
      return searchProducts.any((sp) => sp.toLowerCase().contains(query));
    }).toList();
  }

  bool get _hasResults => _matchedProducts.isNotEmpty || _matchedVendors.isNotEmpty;
  bool get _hasQuery => query.isNotEmpty;

  void _submitSearch(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    recentSearches.remove(q);
    recentSearches.insert(0, q);
    if (recentSearches.length > 10) recentSearches.removeLast();
    setState(() {});
  }

  void _removeRecentSearch(String item) {
    recentSearches.remove(item);
    setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width;
    final double screenHeight = mediaQuery.size.height;
    final double horizontalPadding = screenWidth < 360 ? 16 : 21;
    final double topPadding = screenHeight < 650 ? 24 : 50;
    final double bottomHeaderPadding = screenHeight < 650 ? 14 : 20;

    return ScaffoldWithNav(
      activeIndex: 1,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding, topPadding, horizontalPadding, bottomHeaderPadding,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 40, height: 40,
                      child: Center(child: Icon(Icons.arrow_back, size: 24, color: C.textPrimary(context))),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text('Search', overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                  ),
                ],
              ),
            ),
            // ── Search field ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: SizedBox(
                width: double.infinity,
                child: TextField(
                  controller: searchController,
                  focusNode: _focusNode,
                  onChanged: (value) => setState(() {}),
                  onSubmitted: _submitSearch,
                  textInputAction: TextInputAction.search,
                  textCapitalization: TextCapitalization.none,
                  decoration: InputDecoration(
                    hintText: 'Search products, vendors',
                    hintStyle: TextStyle(fontSize: 15, color: C.textMuted(context)),
                    prefixIcon: Icon(Icons.search, color: C.textPrimary(context)),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (searchController.text.isNotEmpty)
                          IconButton(onPressed: clearSearch, splashRadius: 22,
                            icon: Icon(Icons.close, color: C.textPrimary(context))),
                        IconButton(
                          onPressed: () async {
                            final intent = await showVoiceSearch(context);
                            if (intent != null && mounted) {
                              searchController.text = intent.productQuery;
                              _submitSearch(intent.productQuery);
                            }
                          },
                          splashRadius: 22,
                          icon: const Icon(Icons.mic, color: AppColors.primaryDark)),
                      ],
                    ),
                    filled: true,
                    fillColor: C.surfaceLight(context),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            // ── Body ──────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: !_hasQuery
                    ? _buildIdleState(screenWidth, screenHeight)
                    : !_hasResults
                        ? _buildNoResults(screenWidth)
                        : _buildResults(screenWidth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Idle state (no query yet) ───────────────────────────────────────
  Widget _buildIdleState(double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight < 650 ? 22 : 30),
          // Recent searches
          if (recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent searches',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                TapFeedback(
                  onTap: () { recentSearches.clear(); setState(() {}); },
                  child: const Text('Clear all',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primaryDark)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: recentSearches.map((term) {
                return GestureDetector(
                  onTap: () {
                    searchController.text = term;
                    _submitSearch(term);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: C.surface(context),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: C.divider(context), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 14, color: C.textMuted(context)),
                        const SizedBox(width: 6),
                        Text(term, style: TextStyle(fontSize: 13, color: C.textPrimary(context))),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeRecentSearch(term),
                          child: Icon(Icons.close, size: 14, color: C.textMuted(context)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
          // Idle prompt
          Text('Start searching',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
          const SizedBox(height: AppSpacing.sm + 2),
          Text('Search for products, vendors on GROWBOX.',
            softWrap: true,
            style: TextStyle(fontSize: 15, height: 1.5, color: C.textMuted(context))),
          const SizedBox(height: AppSpacing.xxxl),
          // Popular / suggested searches
          Text('Popular',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
          const SizedBox(height: AppSpacing.md),
          _buildSuggestionChip('Rice'),
          _buildSuggestionChip('Tomatoes'),
          _buildSuggestionChip('Fresh Vegetables'),
          _buildSuggestionChip('Maize'),
          _buildSuggestionChip('Fresh Apples'),
          _buildSuggestionChip('Beans'),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TapFeedback(
        onTap: () {
          searchController.text = label;
          _submitSearch(label);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: C.surface(context),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              Icon(Icons.trending_up, size: 18, color: C.textMuted(context)),
              const SizedBox(width: AppSpacing.md),
              Text(label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.textPrimary(context))),
            ],
          ),
        ),
      ),
    );
  }

  // ── No results ─────────────────────────────────────────────────────
  Widget _buildNoResults(double screenWidth) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: screenWidth < 360 ? 50 : 60, color: C.textMuted(context)),
            const SizedBox(height: AppSpacing.lg),
            Text('No results found',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('No products or vendors match "$query". Try a different search.',
                textAlign: TextAlign.center, softWrap: true,
                style: TextStyle(fontSize: 14, height: 1.5, color: C.textMuted(context))),
            ),
          ],
        ),
      ),
    );
  }

  // ── Results ────────────────────────────────────────────────────────
  Widget _buildResults(double screenWidth) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: 100),
      children: [
        if (_matchedProducts.isNotEmpty) ...[
          Text('${_matchedProducts.length} product${_matchedProducts.length == 1 ? '' : 's'} found',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: C.textMuted(context))),
          ..._matchedProducts.asMap().entries.map((entry) => AnimatedEntrance(index: entry.key, child: ProductCard(product: entry.value, showVendorName: true))),
          const SizedBox(height: AppSpacing.xxl),
        ],
        if (_matchedVendors.isNotEmpty) ...[
          Text('${_matchedVendors.length} vendor${_matchedVendors.length == 1 ? '' : 's'} found',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: C.textMuted(context))),
          ..._matchedVendors.map((vendor) => _buildVendorCard(vendor, screenWidth)),
        ],
      ],
    );
  }

  // ── Product card ──────────────────────────────────────────────────

  // ── Vendor card ───────────────────────────────────────────────────
  Widget _buildVendorCard(Map<String, dynamic> vendor, double screenWidth) {
    final String name = vendor['name'] as String;
    final String image = vendor['image'] as String? ?? '';
    final String percentage = vendor['percentage'] as String? ?? '';
    final String reviews = vendor['reviews'] as String? ?? '';
    final List<String> categories = List<String>.from(vendor['categories'] ?? []);
    final List<VendorProduct> products = List<VendorProduct>.from(vendor['products'] ?? []);
    final int productCount = products.length;

    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => VendorScreen(
          vendorName: name,
          vendorCoverImage: image,
          vendorLogoImage: image,
          categories: categories,
          products: products,
        ))),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(12),
        decoration: AppNeumorphic.cardDecoration(radius: AppRadii.md, context: context),
        child: Row(
          children: [
            // Vendor avatar
            ClipOval(
              child: SizedBox(
                width: 48, height: 48,
                child: image.isNotEmpty
                    ? Image.asset(image, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.primaryLight,
                          child: const Icon(Icons.storefront_outlined, color: AppColors.primaryDark, size: 24)))
                    : Container(
                        color: AppColors.primaryLight,
                        child: const Icon(Icons.storefront_outlined, color: AppColors.primaryDark, size: 24)),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                  const SizedBox(height: 2),
                  Text(
                    categories.map((c) => c[0].toUpperCase() + c.substring(1).toLowerCase()).join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: C.textMuted(context)),
                  ),
                ],
              ),
            ),
            // Rating + product count
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (percentage.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 14, color: AppColors.gold),
                      const SizedBox(width: 2),
                      Text(percentage,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                      if (reviews.isNotEmpty)
                        Text(reviews,
                          style: TextStyle(fontSize: 11, color: C.textMuted(context))),
                    ],
                  ),
                const SizedBox(height: 2),
                Text('$productCount product${productCount == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: C.textMuted(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
