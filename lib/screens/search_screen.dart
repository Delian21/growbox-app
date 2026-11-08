import 'dart:async';

import '../widgets/product_card.dart';
import 'package:flutter/material.dart';
import '../widgets/animated_entrance.dart';
import '../theme.dart';
import '../data/categories.dart';
import '../data/catalog_repository.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/root_shell.dart';
import '../tabs.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/micro_interactions.dart';
import '../data/mock_data.dart';
import '../widgets/category_chip.dart';
import '../widgets/load_error_view.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/status_view.dart';
import 'category_vendors_screen.dart';
import 'vendor_screen.dart';
import '../widgets/vendor_rating.dart';
import '../widgets/voice_search_button.dart';
import '../services/speech_service.dart';
import '../services/speech_to_text_service.dart';
import '../services/voice_search_session.dart';
import '../routes.dart';

/// In-memory recent search history (resets on app restart).
final List<String> recentSearches = [];

class SearchScreen extends StatefulWidget {
  /// Pre-fills the field and shows that query's settled result on the first
  /// frame. Only the demo state gallery passes it; the app never does, and the
  /// default (null) keeps the interactive behaviour unchanged.
  final String? initialQuery;

  /// The speech engine. Defaults to the platform implementation; tests (and the
  /// gallery) pass a fake so no platform channel is involved.
  final SpeechService? speechService;

  const SearchScreen({super.key, this.initialQuery, this.speechService});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with WidgetsBindingObserver, RouteAware {
  final TextEditingController searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Fires once the user stops typing, so a half-typed word is never reported
  /// as a failed search.
  Timer? _typingTimer;

  /// True once a search has actually run for the current text: Enter, a
  /// suggestion, a voice result, or a pause in typing. Only a settled query
  /// can show the no-results state.
  bool _querySettled = false;

  static const Duration _typingPause = Duration(milliseconds: 400);

  /// The focus request this screen has already acted on, so the listener does
  /// not re-focus on every unrelated tab change.
  late int _seenFocusRequest;

  /// Owns the microphone: partials, the 1.2 s silence stop and the failure
  /// message. Created in initState because it survives re-renders.
  late final VoiceSearchSession _voice;

  /// The catalogue behind the results, fetched once so typing filters a list
  /// in memory instead of re-requesting on every keystroke.
  List<Map<String, dynamic>> _vendors = const [];
  bool _catalogLoading = true;
  bool _catalogFailed = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog(showLoading: false);

    // A cold start mounts every tab at once (that is what keeps their state),
    // so Search must not grab the keyboard before it is the visible tab.
    _seenFocusRequest = tabNavigator.searchFocusRequest;
    tabNavigator.addListener(_onTabRequest);
    WidgetsBinding.instance.addObserver(this);

    _voice = VoiceSearchSession(
      speech: widget.speechService ?? platformSpeechService,
      // Live partials go straight into the field — the customer watches their
      // words appear instead of waiting for a result screen.
      onPartial: (text) {
        searchController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _onQueryChanged(text);
      },
      // Silence or a final submits immediately, with the catalogue's wording
      // when the transcript is close to it.
      onSubmit: (query) {
        searchController.text = query;
        _submitSearch(query);
      },
    );
    // Initialise once, on first open, so the mic can be drawn as unavailable
    // before anyone taps it.
    _voice.prepare();

    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      searchController.text = initial;
      // A pre-filled query has already been submitted, so its result is shown
      // straight away instead of being held behind the typing pause.
      _querySettled = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Don't pop the keyboard over a state that was opened to be looked at.
      if (initial != null && initial.isNotEmpty) return;
      // Standalone (gallery, tests) always behaves as the active screen.
      if (RootShellScope.isInside(context) &&
          tabNavigator.tab != AppTab.search) {
        return;
      }
      _focusNode.requestFocus();
    });
  }

  /// Subscribes for "something was pushed on top of me".
  ///
  /// Disposal is not enough: opening a vendor page leaves this screen mounted
  /// underneath, and the recogniser would keep the microphone for the life of
  /// that page.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => _voice.cancel();

  /// The microphone must never stay on when the customer leaves the screen.
  /// App pause is the case the system cannot handle for us: Android and iOS
  /// keep the recogniser running until it is told otherwise.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _voice.cancel();
  }

  /// The Home search bar asks for the field whenever it switches tabs, so a
  /// second tap on it re-opens the keyboard even though the screen never
  /// unmounted.
  void _onTabRequest() {
    // Switching to another tab is a route change as far as the mic is
    // concerned: drop the session instead of listening in the background.
    if (tabNavigator.tab != AppTab.search && _voice.isListening) {
      _voice.cancel();
    }
    if (tabNavigator.searchFocusRequest == _seenFocusRequest) return;
    _seenFocusRequest = tabNavigator.searchFocusRequest;
    // After the frame that makes Search the visible tab: asking for focus while
    // the screen is still the offstage child is a no-op the keyboard never
    // recovers from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  /// Fetches the catalogue for search. A failure replaces the results area
  /// with the shared error state; retrying runs this again.
  Future<void> _loadCatalog({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _catalogLoading = true;
        _catalogFailed = false;
      });
    }
    try {
      final vendors = await catalogRepository.getVendors();
      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _catalogLoading = false;
        _catalogFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalogLoading = false;
        _catalogFailed = true;
      });
    }
  }

  @override
  void dispose() {
    tabNavigator.removeListener(_onTabRequest);
    WidgetsBinding.instance.removeObserver(this);
    _voice.dispose();
    _typingTimer?.cancel();
    searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void clearSearch() {
    _typingTimer?.cancel();
    _querySettled = false;
    searchController.clear();
    setState(() {});
  }

  /// Any keystroke invalidates the previous search: results keep updating
  /// live, but the "nothing matched" panel waits for [_typingPause] of quiet
  /// (or an explicit submit) before it may appear.
  void _onQueryChanged(String value) {
    _typingTimer?.cancel();
    setState(() => _querySettled = false);
    if (value.trim().isEmpty) return;
    _typingTimer = Timer(_typingPause, () {
      if (!mounted) return;
      setState(() => _querySettled = true);
    });
  }

  String get query => searchController.text.trim().toLowerCase();

  // ── Search logic ──────────────────────────────────────────────────────
  List<VendorProduct> get _allProducts {
    final List<VendorProduct> products = [];
    for (final vendor in _vendors) {
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
    return _vendors.where((v) {
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
    _typingTimer?.cancel();
    recentSearches.remove(q);
    recentSearches.insert(0, q);
    if (recentSearches.length > 10) recentSearches.removeLast();
    setState(() => _querySettled = true);
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
                    // Back from a tab root goes to Home, it does not pop the
                    // shell (which is the first route and would leave the app).
                    onTap: () => tabNavigator.select(AppTab.home),
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
                  onChanged: _onQueryChanged,
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
                        // Drives the field directly: partials rewrite the text,
                        // silence or a final submits. Hidden when the device
                        // has no speech recognition, with the status line below
                        // saying why.
                        VoiceSearchButton(session: _voice),
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
            // "Listening…", a retry after silence, or why voice is unavailable.
            // Outside the TextField so it is not squeezed into the suffix icon.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: VoiceSearchStatus(session: _voice),
            ),
            // ── Body ──────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildBody(screenWidth, screenHeight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body: loading, failure, idle, results ────────────────────────────
  Widget _buildBody(double screenWidth, double screenHeight) {
    // First request (or a retry) in flight: show the results' shape.
    if (_catalogLoading) return _buildSkeletons();

    if (_catalogFailed) {
      return LoadErrorView(
        title: "Couldn't load results",
        onRetry: () => _loadCatalog(),
      );
    }

    if (!_hasQuery) return _buildIdleState(screenWidth, screenHeight);
    if (_hasResults) return _buildResults(screenWidth);
    // Nothing is drawn until the query settles, so no "No results" flash
    // mid-word.
    return _querySettled ? _buildNoResults() : const SizedBox.shrink();
  }

  /// Skeleton results: six rows, each the height of the ProductCard it becomes.
  Widget _buildSkeletons() {
    return Shimmer(
      child: ListView(
        padding: EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: BottomNavMetrics.contentInset(context),
        ),
        children: [
          for (var i = 0; i < 6; i++) const ProductCardSkeleton(),
        ],
      ),
    );
  }

  // ── Idle state (no query yet) ───────────────────────────────────────
  Widget _buildIdleState(double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      // Clears the floating nav bar.
      padding: EdgeInsets.only(bottom: BottomNavMetrics.contentInset(context)),
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
                  child: Text('Clear all',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: C.primary(context))),
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
          Text('Search for products, vendors on Growbox.',
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
  Widget _buildNoResults() {
    // Echo what was typed, not the lower-cased query used for matching.
    final typed = searchController.text.trim();
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          top: 30,
          bottom: BottomNavMetrics.contentInset(context),
        ),
        child: Column(
          children: [
            StatusView(
              icon: Icons.search_off,
              title: "No results for '$typed'",
              message: 'Check the spelling or try a broader word.',
              primaryLabel: 'Clear search',
              onPrimary: clearSearch,
            ),
            _buildCategoryRail(),
          ],
        ),
      ),
    );
  }

  /// "Or browse by category": the same chips as the vendor menu filter, from
  /// the same list Home browses, so a dead end still has a way forward.
  Widget _buildCategoryRail() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        children: [
          Text(
            'Or browse by category',
            style: AppTypography.labelMedium
                .copyWith(color: C.textSecondary(context)),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: kCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final category = kCategories[index];
                return CategoryChip(
                  label: category.label,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryVendorsScreen(
                        category: category.label.toUpperCase(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Results ────────────────────────────────────────────────────────
  Widget _buildResults(double screenWidth) {
    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: BottomNavMetrics.contentInset(context),
      ),
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
    // Same format as every other vendor surface: thumbs-up, "84%", "(21)".
    final double rating = vendor['rating'] as double? ?? 0;
    final int? reviewCount = reviewCountFromLabel(vendor['reviews'] as String?);
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
                    // Through the shared image widget so a failed photo keeps
                    // its 48x48 slot and shows the storefront, not a broken
                    // icon.
                    ? SkeletonImage(
                        imageUrl: image,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          color: C.primaryTint(context),
                          child: Icon(Icons.storefront_outlined,
                              color: C.primary(context), size: 24)))
                    : Container(
                        color: C.primaryTint(context),
                        child: Icon(Icons.storefront_outlined,
                            color: C.primary(context), size: 24)),
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
                if (rating > 0)
                  VendorRating(
                    percentage: rating,
                    reviewCount: reviewCount,
                    iconSize: 14,
                    fontSize: 13,
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
