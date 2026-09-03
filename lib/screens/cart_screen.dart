import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/skeleton_loader.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import 'home_screen.dart';
import 'checkout_screen.dart';
import 'order_history_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    return ScaffoldWithNav(
      activeIndex: 2,
      child: SafeArea(
        bottom: false,
        child: cart.isEmpty ? _emptyCart() : _filledCart(cart),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // EMPTY STATE
  Widget _emptyCart() {
    final hp = AppSizing.horizontalPadding(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.xxl, hp, 30),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 56,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Your box is empty',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: C.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Browse our fresh produce and add items to your box',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: C.textMuted(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          // Browse button
          GestureDetector(
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => HomeScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Browse Produce',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Order history link
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OrderHistoryScreen()),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 18, color: C.textMuted(context)),
                const SizedBox(width: 8),
                Text(
                  'View order history',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: C.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final int total = cart.total;
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
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.storefront_outlined,
                              size: 14, color: AppColors.primaryDark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          vendorName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: C.textPrimary(context),
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
        // ── Checkout Bar ────────────────────────────────────────
        _buildCheckoutBar(total),
      ],
    );
  }

  Widget _buildCartItem(VendorProduct product, int quantity) {
    final stockStatus = StockTracker.statusFor(product.vendorName, product.name);
    final isOutOfStock = stockStatus == StockStatus.outOfStock;

    return Dismissible(
      key: Key('${product.name}_${product.vendorName}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        context.read<CartNotifier>().removeAll(product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} removed from cart'),
            action: SnackBarAction(
              label: 'Undo',
              textColor: AppColors.primaryDark,
              onPressed: () {
                setState(() {
                  for (int i = 0; i < quantity; i++) {
                    context.read<CartNotifier>().add(product);
                  }
                });
              },
            ),
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(12),
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
                    '₦${formatPrice(product.price)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  if (stockStatus != StockStatus.inStock) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOutOfStock ? 'Out of stock' : 'Low stock',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isOutOfStock
                              ? AppColors.error
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Quantity controls
            Column(
              children: [
                // Delete button
                GestureDetector(
                  onTap: () => context.read<CartNotifier>().removeAll(product),
                  child: Icon(Icons.close,
                      size: 18, color: C.textMuted(context)),
                ),
                const SizedBox(height: 8),
                // Quantity selector
                Container(
                  decoration: BoxDecoration(
                    color: C.surfaceLight(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          context.read<CartNotifier>().removeOne(product);
                        }),
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          child: Icon(Icons.remove, size: 16, color: C.textPrimary(context)),
                        ),
                      ),
                      Container(
                        width: 32,
                        alignment: Alignment.center,
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: isOutOfStock
                            ? null
                            : () => setState(() {
                                if (StockTracker.decrement(
                                    product.vendorName, product.name)) {
                                  context.read<CartNotifier>().add(product);
                                }
                              }),
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? C.surfaceLighter(context)
                                : C.primaryLight(context),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Icon(Icons.add,
                              size: 16,
                              color: isOutOfStock
                                  ? C.textMuted(context)
                                  : C.primaryDark(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutBar(int total) {
    final hp = AppSizing.horizontalPadding(context);
    return Container(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.md, hp, AppSpacing.md),
      decoration: BoxDecoration(
        color: C.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 12,
                    color: C.textMuted(context),
                  ),
                ),
                Text(
                  '₦${formatPrice(total)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: C.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Checkout button
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CheckoutScreen(
                    products: List<VendorProduct>.from(context.read<CartNotifier>().items),
                  ),
                ),
              ),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Checkout',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
