import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/pinned_bottom_bar.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/status_view.dart';
import '../widgets/skeleton_loader.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../tabs.dart';
import 'checkout_screen.dart';
import 'order_history_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  /// Gap between the floating checkout bar and the nav pill.
  static const double _barGap = 10;

  /// Measures the bar's contents so a snackbar can clear it even when the
  /// summary wraps to more lines (large text scales).
  final GlobalKey _barContentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    // The bar summarises the box: goods + one delivery charge per vendor.
    // Shared with the checkout screen so both show the same payable total.
    final totals = CartTotals.forItems(cart.items);
    return ScaffoldWithNav(
      activeIndex: 2,
      // The pinned bar covers the strip above the pill, so the content fade has
      // nothing left to hide there.
      fadeContent: false,
      child: SafeArea(
        bottom: false,
        // The bar clears the floating nav itself; the cart list simply gets the
        // space that is left above it.
        child: cart.isEmpty
            ? _emptyCart()
            : ScreenWithPinnedBar(
                // 10px of air above the pill, the pill's own radius and a
                // floating surface, so the bar reads as the layer above it.
                gap: _barGap,
                radius: BottomNavMetrics.barHeight / 2,
                horizontalInset: BottomNavMetrics.barHorizontalPadding,
                body: _filledCart(cart),
                bar: KeyedSubtree(
                  key: _barContentKey,
                  child: _buildCheckoutBar(
                    subtotal: totals.subtotal,
                    deliveryFee: totals.deliveryFee,
                    total: totals.total,
                  ),
                ),
              ),
      ),
    );
  }

  /// "25-35 min · ₦500 delivery", straight from the vendor model.
  String _vendorMeta(String vendorName) {
    final time = MockVendors.deliveryTimeFor(vendorName);
    final fee = MockVendors.deliveryFeeFor(vendorName);
    final delivery = fee == 0 ? 'Free delivery' : '₦${formatPrice(fee)} delivery';
    return time.isEmpty ? delivery : '$time · $delivery';
  }

  // ═══════════════════════════════════════════════════════════════════
  // EMPTY STATE
  Widget _emptyCart() {
    final hp = AppSizing.horizontalPadding(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        hp,
        AppSpacing.huge,
        hp,
        BottomNavMetrics.contentInset(context),
      ),
      // Same disc, type scale and 48dp buttons as every other empty screen.
      child: StatusView(
        icon: Icons.shopping_bag_outlined,
        title: 'Your box is empty',
        message: 'Browse our fresh produce and add items to your box',
        primaryLabel: 'Browse produce',
        // Home is the first tab of the shell this screen lives in, so this
        // switches tabs instead of replacing the route — the box stays mounted
        // with its state, and Back still has somewhere to go.
        onPrimary: () => tabNavigator.select(AppTab.home),
        // The order-history link used to be a bare tappable row; as the
        // secondary action it now has a full 48dp target.
        secondaryLabel: 'View order history',
        onSecondary: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderHistoryScreen()),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // FILLED CART
  Widget _filledCart(CartNotifier cart) {
    final hp = AppSizing.horizontalPadding(context);
    final Map<String, List<VendorProduct>> groupedProducts = {};
    for (final product in cart.items) {
      groupedProducts.putIfAbsent(product.vendorName, () => []).add(product);
    }
    final itemCount = cart.length;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(hp, AppSpacing.lg, hp, AppSpacing.md),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back, size: 24, color: C.textPrimary(context)),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Your Box',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: C.textPrimary(context),
                    ),
                  ),
                ),
              ),
              Text(
                '$itemCount item${itemCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 13,
                  color: C.textMuted(context),
                ),
              ),
            ],
          ),
        ),
        // ── Items List ──────────────────────────────────────────
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(hp, 0, hp, AppSpacing.xxl),
            children: groupedProducts.entries.map((entry) {
              final String vendorName = entry.key;
              final List<VendorProduct> vendorProducts = entry.value;
              final List<VendorProduct> uniqueProducts = [];
              for (final product in vendorProducts) {
                if (!uniqueProducts.contains(product)) {
                  uniqueProducts.add(product);
                }
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vendor header
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: C.primaryTint(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.storefront_outlined,
                              size: 14, color: C.primary(context)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vendorName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: C.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _vendorMeta(vendorName),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: C.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Products
                  ...uniqueProducts.map((product) {
                    final int quantity = vendorProducts
                        .where((item) => item == product)
                        .length;
                    return _buildCartItem(product, quantity);
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Removes the whole line and offers Undo, which puts every copy back at the
  /// position the line occupied before it was removed.
  void _removeItem(VendorProduct product, int quantity) {
    final cart = context.read<CartNotifier>();
    final index = cart.items.indexOf(product);
    if (index < 0) return;
    cart.removeAll(product);
    // The bar is content + its own vertical padding + the 1px hairline border
    // on each edge; clearing all of that plus the gap keeps the snackbar above
    // the bar instead of on top of the total.
    final barContentHeight =
        (_barContentKey.currentContext?.size?.height ?? 0) +
            AppSpacing.md * 2 +
            2 +
            _barGap;
    showAppSnackBar(
      context,
      '${product.name} removed from cart',
      actionLabel: 'Undo',
      // Otherwise the bar covers the snackbar it just triggered.
      bottomOffset: barContentHeight,
      onAction: () {
        if (!mounted) return;
        final restore = context.read<CartNotifier>();
        for (var copy = 0; copy < quantity; copy++) {
          restore.insertAt(index + copy, product);
        }
      },
    );
  }

  Widget _buildCartItem(VendorProduct product, int quantity) {
    final stockStatus = StockTracker.statusFor(product.vendorName, product.name);
    final isOutOfStock = stockStatus == StockStatus.outOfStock;

    return Dismissible(
      key: Key('${product.name}_${product.vendorName}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeItem(product, quantity),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.white, size: 24),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(12),
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
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 72,
                child: SkeletonImage(
                  imageUrl: product.image,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  scrim: kProductImageScrim,
                  errorWidget: Container(
                    color: C.shimmer(context),
                    child: Icon(Icons.image_outlined,
                        color: C.textMuted(context), size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: C.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.unit == null
                        ? '₦${formatPrice(product.price)}'
                        : '₦${formatPrice(product.price)} / ${product.unit}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: C.accentOrange(context),
                    ),
                  ),
                  if (quantity > 1) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$quantity x ₦${formatPrice(product.price)} = '
                      '₦${formatPrice(product.price * quantity)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: C.textMuted(context),
                      ),
                    ),
                  ],
                  if (stockStatus != StockStatus.inStock) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? C.errorSoft(context)
                            : C.warningSoft(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOutOfStock ? 'Out of stock' : 'Low stock',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isOutOfStock
                              ? C.onErrorSoft(context)
                              : C.onWarningSoft(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Quantity controls. At one unit the minus slot becomes the
            // delete control, so there is no separate X to hunt for.
            QuantityStepper(
              quantity: quantity,
              onDelete: () => _removeItem(product, quantity),
              onDecrement: () => setState(() {
                context.read<CartNotifier>().removeOne(product);
              }),
              onIncrement: isOutOfStock
                  ? null
                  : () => setState(() {
                        if (StockTracker.decrement(
                            product.vendorName, product.name)) {
                          context.read<CartNotifier>().add(product);
                        }
                      }),
            ),
          ],
        ),
      ),
    );
  }

  /// Contents of the pinned checkout bar; its surface, radius and nav offset
  /// come from [PinnedBottomBar].
  Widget _buildCheckoutBar({
    required int subtotal,
    required int deliveryFee,
    required int total,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Compact summary: goods, delivery, payable.
        Expanded(
          flex: 5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _summaryRow('Subtotal', '₦${formatPrice(subtotal)}'),
              _summaryRow(
                'Delivery',
                deliveryFee == 0 ? 'Free' : '₦${formatPrice(deliveryFee)}',
              ),
              _summaryRow('Total', '₦${formatPrice(total)}', emphasize: true),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // The loudest thing on the screen: brand fill, on-primary content.
        Expanded(
          flex: 4,
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CheckoutScreen(
                  products:
                      List<VendorProduct>.from(context.read<CartNotifier>().items),
                ),
              ),
            ),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: C.primary(context),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              // Scales down rather than overflowing on narrow phones.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Checkout',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: C.onPrimary(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward,
                        size: 18, color: C.onPrimary(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// One "label … amount" line; [emphasize] marks the payable total.
  Widget _summaryRow(String label, String amount, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: emphasize ? 13 : 12,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
                color: emphasize ? C.textPrimary(context) : C.textMuted(context),
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: emphasize ? 14 : 12,
              fontWeight: emphasize ? FontWeight.bold : FontWeight.w500,
              color: C.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
