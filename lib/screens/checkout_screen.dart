import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../widgets/skeleton_loader.dart';
import 'order_success_screen.dart';
import 'location_screen.dart';
import 'address_management_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<VendorProduct> products;
  const CheckoutScreen({super.key, required this.products});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _showItems = false;

  @override
  Widget build(BuildContext context) {
    final List<VendorProduct> products = widget.products;
    const int deliveryFee = 1500;
    int subtotal = 0;
    for (final product in products) {
      subtotal += product.price;
    }
    final int total = subtotal + deliveryFee;
    final int itemCount = products.length;



    final double hp = AppSizing.horizontalPadding(context);

    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────
                    _buildHeader(hp),

                    // ── Your Box ────────────────────────────────
                    _buildBoxSection(hp, itemCount, products),

                    // ── Delivery Address ────────────────────────
                    _buildAddressSection(hp),

                    // ── Delivery Method ─────────────────────────
                    _buildDeliverySection(hp),

                    // ── Order Summary ───────────────────────────
                    _buildOrderSummary(hp, subtotal, deliveryFee, total),

                    const SizedBox(height: 24),

                    // ── Terms ───────────────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hp),
                      child: Text(
                        'By placing your order, you agree to our Terms & Conditions and Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: C.textMuted(context),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Place Order Button ──────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hp),
                      child: GestureDetector(
                        onTap: () {
                          // Snapshot each line item's price/image at checkout
                          // time and persist it to order history before the
                          // success screen takes over.
                          final orderNumber =
                              'GBX-${DateTime.now().millisecondsSinceEpoch % 100000}';
                          recordOrder(
                            orderNumber: orderNumber,
                            cartItems: products,
                            deliveryFee: deliveryFee,
                            deliveryAddress:
                                'No. 12 Gwarinpa Estate, Gwarinpa, Abuja, Nigeria',
                          );
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderSuccessScreen(
                                orderNumber: orderNumber,
                                deliveryAddress:
                                    'No. 12 Gwarinpa Estate, Gwarinpa, Abuja, Nigeria',
                                estimatedDelivery:
                                    'Today, 2:00 PM – 4:00 PM',
                                total: total,
                              ),
                            ),
                            (route) => false,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDark
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Place Order — ₦${formatPrice(total)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
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
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeader(double hp) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.lg, hp, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back, size: 24, color: C.textPrimary(context)),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Checkout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: C.textPrimary(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildBoxSection(
      double hp, int itemCount, List<VendorProduct> products) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.xxl, hp, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _showItems = !_showItems),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: C.primaryLight(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.shopping_bag_outlined, size: 16, color: C.primaryDark(context)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your Box',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: C.textPrimary(context),
                    ),
                  ),
                ),
                Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 13, color: C.textMuted(context)),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showItems
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: C.textMuted(context),
                ),
              ],
            ),
          ),

          // Expandable items list
          if (_showItems) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.surfaceLight(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: products.map((product) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SkeletonImage(
                            imageUrl: product.image,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            scrim: kProductImageScrim,
                            errorWidget: Container(
                              width: 40,
                              height: 40,
                              color: AppColors.shimmer,
                              child: const Icon(Icons.image_outlined,
                                  color: AppColors.grey500, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: C.textPrimary(context),
                            ),
                          ),
                        ),
                        Text(
                          '₦${formatPrice(product.price)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressSection(double hp) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.xxl, hp, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_on_outlined,
                    size: 16, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: C.textPrimary(context),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showAddressBottomSheet(context),
                child: Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Builder(
            builder: (ctx) {
              final addr = defaultAddress;
              return GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => const AddressManagementScreen()),
                  );
                  setState(() {});
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: C.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryDark.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: AppColors.primaryDark, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              addr?.address ?? 'No address saved',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: C.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              addr != null
                                  ? '${addr.label} address'
                                  : 'Tap to add a delivery address',
                              style: TextStyle(
                                fontSize: 12,
                                color: addr != null
                                    ? AppColors.grey600
                                    : AppColors.grey500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 20, color: AppColors.grey500),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection(double hp) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.xxl, hp, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    size: 16, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 10),
              Text(
                'Delivery',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: C.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delivery_dining,
                      size: 20, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Standard Delivery',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: C.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Estimated today, 2:00 PM – 4:00 PM',
                        style: TextStyle(
                          fontSize: 12,
                          color: C.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₦1,500',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(double hp, int subtotal, int deliveryFee, int total) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.xxl, hp, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_outlined,
                    size: 16, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 10),
              Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: C.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
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
            child: Column(
              children: [
                _buildSummaryRow('Subtotal', '₦${formatPrice(subtotal)}'),
                const SizedBox(height: 10),
                _buildSummaryRow('Delivery fee', '₦${formatPrice(deliveryFee)}'),
                const SizedBox(height: 12),
                Container(height: 1, color: AppColors.grey200),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: C.textPrimary(context),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₦${formatPrice(total)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.grey600),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: C.textPrimary(context),
          ),
        ),
      ],
    );
  }

  void _showAddressBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: C.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.primaryDark.withValues(alpha: 0.5),
                      width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined,
                        color: AppColors.primaryDark, size: 24),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gerald Odinaka',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: C.textPrimary(context),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '0803 123 4567',
                            style:
                                TextStyle(fontSize: 13, color: AppColors.grey700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'No. 12 Gwarinpa Estate, Gwarinpa\nAbuja, Nigeria',
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.grey700),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle,
                        color: AppColors.primaryDark, size: 22),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LocationScreen()),
                    );
                  },
                  icon: const Icon(Icons.add, color: AppColors.primaryDark),
                  label: Text(
                    'Add New Address',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
