import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/addresses.dart';
import '../data/app_state.dart';
import '../data/build_info.dart';
import '../data/mock_backend.dart';
import '../data/mock_data.dart';
import '../data/orders.dart';
import '../data/placeholder_images.dart';
import '../services/connectivity.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/order_rating_sheet.dart';
import '../widgets/skeleton_loader.dart';
import 'address_management_screen.dart';
import 'cart_screen.dart';
import 'checkout_screen.dart';
import 'delivery_tracking_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'order_history_screen.dart';
import 'order_result_screens.dart';
import 'search_screen.dart';
import 'vendor_screen.dart';

/// Every empty, loading and terminal state the app has, each one the *real*
/// widget with fake inputs.
///
/// Nothing here re-implements a screen: the gallery only chooses which
/// existing screen to push and what to hand it, which is why a state can never
/// look different here from how it looks in the app. Demo-only — the entry
/// point is inside the `kDemoTools` branch of Profile, so a normal release
/// build has neither the section nor this file's code.
class StateGalleryScreen extends StatefulWidget {
  const StateGalleryScreen({super.key});

  @override
  State<StateGalleryScreen> createState() => _StateGalleryScreenState();
}

class _StateGalleryScreenState extends State<StateGalleryScreen> {
  ThemeNotifier? _theme;

  /// The appearance the app had before the gallery took it over, put back on
  /// the way out so browsing states never changes the customer's theme.
  ThemeMode? _before;

  bool _captured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Captured once, not per rebuild: the toggle itself triggers this.
    if (_captured) return;
    _captured = true;
    _theme = ThemeProvider.of(context);
    _before = _theme!.value;
  }

  @override
  void dispose() {
    // Set directly rather than through select(): a preview must not be
    // persisted as the customer's appearance choice.
    final theme = _theme;
    if (theme != null && _before != null) theme.value = _before!;
    super.dispose();
  }

  void _setDark(bool dark) {
    _theme?.value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  void _open(WidgetBuilder builder) {
    Navigator.push(context, MaterialPageRoute(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'State gallery', showDivider: true),
            // Light/dark at the top: every state below is opened with the
            // app's real theme, so both modes get the same widgets.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: C.surfaceLight(context),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  children: [
                    _ThemeOption(
                      label: 'Light',
                      icon: Icons.light_mode_outlined,
                      selected: !dark,
                      onTap: () => _setDark(false),
                    ),
                    _ThemeOption(
                      label: 'Dark',
                      icon: Icons.dark_mode_outlined,
                      selected: dark,
                      onTap: () => _setDark(true),
                    ),
                  ],
                ),
              ),
            ),
            // What a tester is running, one tap from the clipboard: a bug
            // report without the build id is a bug report nobody can place.
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: _BuildBadge(),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxxl,
                ),
                children: [
                  _section(context, 'Empty states'),
                  _row(
                    context,
                    'Empty cart',
                    'Your box is empty',
                    () => _open(
                      (_) => ChangeNotifierProvider(
                        create: (_) => CartNotifier(),
                        child: const CartScreen(),
                      ),
                    ),
                  ),
                  _row(
                    context,
                    'No active orders',
                    'Nothing on its way right now',
                    () => _open(
                      (_) => OrderHistoryScreen(
                        store: OrdersStore(_EmptyOrdersRepository()),
                      ),
                    ),
                  ),
                  _row(
                    context,
                    'Past orders empty',
                    'No past orders yet',
                    () => _open(
                      (_) => OrderHistoryScreen(
                        store: OrdersStore(_EmptyOrdersRepository()),
                        initialTab: OrdersTab.past,
                      ),
                    ),
                  ),
                  _row(
                    context,
                    'Search with no results',
                    "No results for 'dragonfruit'",
                    () => _open(
                      (_) => const SearchScreen(initialQuery: 'dragonfruit'),
                    ),
                  ),
                  _row(
                    context,
                    'Favorites empty',
                    'No favorites yet',
                    () => _open(
                      (_) => const FavoritesScreen(favorites: []),
                    ),
                  ),
                  _row(
                    context,
                    'Notifications empty',
                    "You're all caught up",
                    () => _open(
                      (_) => const NotificationsScreen(notifications: []),
                    ),
                  ),
                  _row(
                    context,
                    'Addresses empty',
                    'No saved addresses',
                    () => _open(
                      (_) => AddressManagementScreen(
                        store: AddressesStore(_EmptyAddressRepository()),
                      ),
                    ),
                  ),
                  _row(
                    context,
                    'Vendor menu empty',
                    'A vendor with no products',
                    () => _open(
                      (_) => VendorScreen(
                        vendorName: 'Green Farm',
                        vendorCoverImage: PlaceholderImages.greenFarm,
                        vendorLogoImage: PlaceholderImages.greenFarmLogo,
                        categories: const [],
                        products: const [],
                      ),
                    ),
                  ),
                  _section(context, 'Loading and failure'),
                  // Each row arms exactly one failure, so the screen fails the
                  // way a dropped request makes it fail and its "Try again"
                  // then succeeds — the real error state, retry included.
                  _row(
                    context,
                    'Home feed load error',
                    "Couldn't load vendors, on the real Home",
                    () {
                      MockBackend.failNextRequest();
                      _open(
                        (_) => ChangeNotifierProvider(
                          create: (_) => CartNotifier(),
                          child: const HomeScreen(),
                        ),
                      );
                    },
                  ),
                  _row(
                    context,
                    'Search results load error',
                    "Couldn't load results",
                    () {
                      MockBackend.failNextRequest();
                      _open((_) => const SearchScreen(initialQuery: 'rice'));
                    },
                  ),
                  _row(
                    context,
                    'Vendor menu load error',
                    "Couldn't load this menu",
                    () {
                      MockBackend.failNextRequest();
                      _open(
                        (_) => VendorScreen(
                          vendorName: 'Green Farm',
                          vendorCoverImage: PlaceholderImages.greenFarm,
                          vendorLogoImage: PlaceholderImages.greenFarmLogo,
                          categories: const ['GRAINS'],
                          products: const [_galleryProduct],
                        ),
                      );
                    },
                  ),
                  _row(
                    context,
                    'Orders load error',
                    "Couldn't load orders",
                    () => _open(
                      (_) => OrderHistoryScreen(
                        store: OrdersStore(_FailingOrdersRepository()),
                      ),
                    ),
                  ),
                  _row(
                    context,
                    'Offline banner',
                    'The real banner, from the real store',
                    () => _open((_) => const _OfflineBannerPage()),
                  ),
                  _row(
                    context,
                    'Checkout offline',
                    'Place order disabled, box untouched',
                    () => _open((_) => const _CheckoutOfflinePage()),
                  ),
                  _row(
                    context,
                    'Skeleton lists',
                    'Vendor and product cards while loading',
                    () => _open((_) => const _SkeletonPage()),
                  ),
                  _section(context, 'Order outcomes'),
                  _row(
                    context,
                    'Delivered + rating sheet',
                    'Arrival card, then the feedback sheet',
                    () => _open(
                      (_) => _DeliveredWithRatingPage(order: _deliveredOrder()),
                    ),
                  ),
                  _row(
                    context,
                    'Cancelled order',
                    'Status view with reorder and support',
                    () => _open(
                      (_) => DeliveryTrackingScreen(order: _cancelledOrder()),
                    ),
                  ),
                  _row(
                    context,
                    'Running late',
                    'Past the promised arrival',
                    () => _open(
                      (_) => DeliveryTrackingScreen(order: _lateOrder()),
                    ),
                  ),
                  _row(
                    context,
                    'Order placement failure',
                    "We couldn't place your order",
                    () => _open(
                      (_) => OrderFailedScreen(order: _failedOrder()),
                    ),
                  ),
                  _row(
                    context,
                    'Order pending',
                    'Confirming your order',
                    () => _open(
                      (_) => OrderPendingScreen(order: _failedOrder()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: C.textMuted(context),
          ),
        ),
      );

  Widget _row(
    BuildContext context,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: C.surface(context),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: C.divider(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: C.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: C.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: C.textMuted(context),
                ),
              ],
            ),
          ),
        ),
      );
}

/// One half of the appearance toggle.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? C.onPrimary(context) : C.textMuted(context);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? C.primary(context) : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The build the tester is holding, with a copy button.
///
/// Reported verbatim, because "latest" is not verifiable: the label carries
/// the version and the id the build was made with.
class _BuildBadge extends StatelessWidget {
  const _BuildBadge();

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: kBuildLabel));
    if (!context.mounted) return;
    showAppSnackBar(context, 'Build id copied');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: C.divider(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.tag, size: 15, color: C.textMuted(context)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              kBuildLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: C.textSecondary(context),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy build id',
            visualDensity: VisualDensity.compact,
            onPressed: () => _copy(context),
            icon: Icon(
              Icons.copy_rounded,
              size: 17,
              color: C.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scaffold for the states that are a widget rather than a whole screen.
class _GalleryPage extends StatelessWidget {
  const _GalleryPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(title: title, showDivider: true),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Shows the real offline banner by flipping the real connectivity store.
///
/// The banner lives above the navigator (in `main`'s builder), so simulating
/// offline here is exactly what losing the network does — no second copy of
/// the banner, and no preview-only layout.
class _OfflineBannerPage extends StatefulWidget {
  const _OfflineBannerPage();

  @override
  State<_OfflineBannerPage> createState() => _OfflineBannerPageState();
}

class _OfflineBannerPageState extends State<_OfflineBannerPage> {
  @override
  void initState() {
    super.initState();
    // Armed after the route is on screen, so the banner animates in as it
    // would in the app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) connectivityStore.setSimulatedOffline(true);
    });
  }

  @override
  void dispose() {
    // Never leave the app stuck offline because a gallery page was open.
    connectivityStore.setSimulatedOffline(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GalleryPage(
      title: 'Offline banner',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            'The app is marked offline. The banner above is the real '
            'OfflineBannerHost from main(); go back and it returns online.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: C.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// The real checkout, with the store offline, so the disabled CTA and its
/// "You're offline" label can be looked at without turning off Wi-Fi.
class _CheckoutOfflinePage extends StatefulWidget {
  const _CheckoutOfflinePage();

  @override
  State<_CheckoutOfflinePage> createState() => _CheckoutOfflinePageState();
}

class _CheckoutOfflinePageState extends State<_CheckoutOfflinePage> {
  final CartNotifier _cart = CartNotifier()
    ..addAll(const [_galleryProduct, _galleryProduct]);

  final AddressesStore _addresses =
      AddressesStore(_GalleryAddressRepository());

  @override
  void initState() {
    super.initState();
    // Armed after the first frame so the CTA is seen changing to offline.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) connectivityStore.setSimulatedOffline(true);
    });
  }

  @override
  void dispose() {
    // Never leave the app marked offline because a gallery page was open.
    connectivityStore.setSimulatedOffline(false);
    _cart.dispose();
    _addresses.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: _cart,
        child: CheckoutScreen(
          products: _cart.items,
          addressStore: _addresses,
        ),
      );
}

/// The shared skeleton widgets, at their real sizes.
class _SkeletonPage extends StatelessWidget {
  const _SkeletonPage();

  @override
  Widget build(BuildContext context) {
    return _GalleryPage(
      title: 'Skeleton lists',
      child: Shimmer(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            VendorCardSkeleton(),
            SizedBox(height: AppSpacing.xxl),
            ProductCardSkeleton(),
            ProductCardSkeleton(),
            ProductCardSkeleton(imageSize: 80, showDescription: true),
          ],
        ),
      ),
    );
  }
}

/// The delivered tracking screen with the feedback sheet opened over it.
///
/// The sheet is the production one; it is opened a frame later so it slides up
/// over a screen that has already laid out its arrival card.
class _DeliveredWithRatingPage extends StatefulWidget {
  const _DeliveredWithRatingPage({required this.order});

  final Order order;

  @override
  State<_DeliveredWithRatingPage> createState() =>
      _DeliveredWithRatingPageState();
}

class _DeliveredWithRatingPageState extends State<_DeliveredWithRatingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showOrderRatingSheet(context, vendorName: widget.order.vendorName);
    });
  }

  @override
  Widget build(BuildContext context) =>
      DeliveryTrackingScreen(order: widget.order);
}

// ---------------------------------------------------------------------------
// Mock inputs
// ---------------------------------------------------------------------------

const OrderItem _demoLine = OrderItem(
  name: 'Rice',
  vendorName: 'Green Farm',
  category: 'GRAINS',
  image: 'assets/images/rice.jpg',
  price: 2550,
  quantity: 2,
);

const String _demoAddress = 'No. 12 Gwarinpa Estate, Gwarinpa, Abuja, Nigeria';

/// One product line for the screens that need contents rather than a model.
const VendorProduct _galleryProduct = VendorProduct(
  image: 'assets/images/rice.jpg',
  name: 'Rice',
  description: 'Long grain rice',
  price: 2550,
  category: 'GRAINS',
  vendorName: 'Green Farm',
);

/// A complete address, so checkout's only blocker is the connection.
const Address _galleryAddressValue = Address(
  id: 'state-gallery-1',
  label: 'Home',
  street: 'No. 12 Gwarinpa Estate',
  area: 'Gwarinpa, Abuja',
);

Order _demoOrder({
  required String id,
  required OrderStatus status,
  Map<OrderStatus, DateTime> timestamps = const {},
  DateTime? estimatedArrival,
  DateTime? deliveredAt,
  DateTime? cancelledAt,
  String? cancelReason,
  String? riderNote,
}) =>
    Order(
      id: id,
      vendorName: 'Green Farm',
      status: status,
      createdAt: DateTime(2026, 10, 25, 10, 12),
      items: const [_demoLine],
      deliveryAddress: _demoAddress,
      timestamps: timestamps,
      estimatedArrival: estimatedArrival,
      deliveredAt: deliveredAt,
      cancelledAt: cancelledAt,
      cancelReason: cancelReason,
      riderNote: riderNote,
    );

Order _deliveredOrder() => _demoOrder(
      id: 'GBX-9001',
      status: OrderStatus.delivered,
      deliveredAt: DateTime(2026, 10, 25, 11, 42),
      timestamps: {
        OrderStatus.confirmed: DateTime(2026, 10, 25, 10, 12),
        OrderStatus.packing: DateTime(2026, 10, 25, 10, 16),
        OrderStatus.pickedUp: DateTime(2026, 10, 25, 10, 22),
        OrderStatus.onTheWay: DateTime(2026, 10, 25, 10, 26),
        OrderStatus.delivered: DateTime(2026, 10, 25, 11, 42),
      },
    );

Order _cancelledOrder() => _demoOrder(
      id: 'GBX-9002',
      status: OrderStatus.cancelled,
      cancelReason: 'Ordered by mistake',
      cancelledAt: DateTime(2026, 10, 25, 10, 15),
      timestamps: {
        OrderStatus.confirmed: DateTime(2026, 10, 25, 10, 12),
        OrderStatus.cancelled: DateTime(2026, 10, 25, 10, 15),
      },
    );

Order _lateOrder() {
  final now = DateTime.now();
  return _demoOrder(
    id: 'GBX-9003',
    status: OrderStatus.onTheWay,
    // Five minutes past the promise: the arrival card reads "Running late".
    estimatedArrival: now.subtract(const Duration(minutes: 5)),
    timestamps: {
      OrderStatus.confirmed: now.subtract(const Duration(minutes: 35)),
      OrderStatus.packing: now.subtract(const Duration(minutes: 30)),
      OrderStatus.pickedUp: now.subtract(const Duration(minutes: 25)),
      OrderStatus.onTheWay: now.subtract(const Duration(minutes: 20)),
    },
  );
}

/// An attempt that was never recorded: the failure and pending screens both
/// price it from the same snapshot the order would have had.
Order _failedOrder() => attemptedOrder(
      orderNumber: 'GBX-9004',
      items: const [_demoLine],
      deliveryAddress: _demoAddress,
    );

/// No orders at all — the shape of a brand-new install.
class _EmptyOrdersRepository implements OrdersRepository {
  @override
  Future<List<Order>> getOrders() async => const [];

  @override
  Future<void> advanceStatus(String orderId) async {}

  @override
  Future<void> rateOrder(String orderId, OrderRating rating) async {}

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}

  @override
  Future<void> makeLate(String orderId) async {}
}

/// A first request that always fails: the orders list's error state, without
/// arming a one-shot failure that a retry would then consume.
class _FailingOrdersRepository implements OrdersRepository {
  @override
  Future<List<Order>> getOrders() async => throw const MockNetworkException();

  @override
  Future<void> advanceStatus(String orderId) async {}

  @override
  Future<void> rateOrder(String orderId, OrderRating rating) async {}

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}

  @override
  Future<void> makeLate(String orderId) async {}
}

/// One complete address already selected, held in memory.
class _GalleryAddressRepository implements AddressRepository {
  @override
  String get accountKey => 'state-gallery';

  @override
  Future<List<Address>> getAddresses() async => const [_galleryAddressValue];

  @override
  Future<Address?> getSelectedAddress() async => _galleryAddressValue;

  @override
  Future<void> selectAddress(String id) async {}

  @override
  Future<void> saveAddress(Address address) async {}

  @override
  Future<void> deleteAddress(String addressId) async {}
}

/// No saved addresses, without touching the device's real ones.
class _EmptyAddressRepository implements AddressRepository {
  @override
  String get accountKey => 'state-gallery';

  @override
  Future<List<Address>> getAddresses() async => const [];

  @override
  Future<Address?> getSelectedAddress() async => null;

  @override
  Future<void> selectAddress(String id) async {}

  @override
  Future<void> saveAddress(Address address) async {}

  @override
  Future<void> deleteAddress(String addressId) async {}
}
