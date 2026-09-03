import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../widgets/skeleton_loader.dart';
import 'delivery_tracking_screen.dart';

class OrderDetailsScreen extends StatelessWidget {
  final String orderNumber;
  final String date;
  final String status;
  final Color statusColor;
  final String deliveryAddress;
  final int subtotal;
  final int deliveryFee;
  final int total;
  /// Line items with price/image frozen at checkout time.
  final List<OrderItem> products;
  final String paymentStatus;

  const OrderDetailsScreen({
    super.key,
    required this.orderNumber,
    required this.date,
    required this.status,
    required this.statusColor,
    required this.deliveryAddress,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.products,
    required this.paymentStatus,
  });


  @override
  Widget build(BuildContext context) {
    final hp = AppSizing.horizontalPadding(context);

    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
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
                        'Order Details',
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
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hp, 0, hp, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Order Status Card ────────────────────────
                    _buildStatusCard(context),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Order Items ──────────────────────────────
                    _buildSectionTitle(context, 'Order Items'),
                    const SizedBox(height: AppSpacing.md),
                    ...products.map((product) => _buildProductCard(context, product)),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Delivery Information ─────────────────────
                    _buildSectionTitle(context, 'Delivery'),
                    const SizedBox(height: AppSpacing.md),
                    _buildDeliveryCard(context),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Payment Status ───────────────────────────
                    _buildSectionTitle(context, 'Payment'),
                    const SizedBox(height: AppSpacing.md),
                    _buildPaymentCard(context),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Order Summary ────────────────────────────
                    _buildSectionTitle(context, 'Summary'),
                    const SizedBox(height: AppSpacing.md),
                    _buildSummaryCard(context),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Action Buttons ───────────────────────────
                    if (status == 'Order placed' || status == 'Pending')
                      _buildTrackButton(context),
                    if (status == 'Order placed' || status == 'Pending')
                      const SizedBox(height: AppSpacing.md),
                    if (status == 'Delivered' || status == 'Order placed')
                      _buildReorderButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: C.textPrimary(context),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              status == 'Delivered'
                  ? Icons.check_circle_outline
                  : status == 'Cancelled'
                      ? Icons.cancel_outlined
                      : status == 'Pending'
                          ? Icons.access_time
                          : Icons.receipt_long_outlined,
              size: 24,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: C.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Placed on $date',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, OrderItem product) {
    final name = product.name;
    final quantity = product.quantity;
    final price = product.price;
    final image = product.image;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
              width: 56,
              height: 56,
              child: image.isNotEmpty
                  ? SkeletonImage(
                      imageUrl: image,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      scrim: kProductImageScrim,
                      errorWidget: Container(
                        color: AppColors.primaryLight,
                        child: const Icon(Icons.eco_outlined,
                            color: AppColors.primaryDark, size: 24),
                      ),
                    )
                  : Container(
                      color: AppColors.primaryLight,
                      child: const Icon(Icons.eco_outlined,
                          color: AppColors.primaryDark, size: 24),
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
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: C.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: $quantity',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          // Price
          Text(
            '₦${formatPrice(price)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(BuildContext context) {
    return Container(
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
            child: const Icon(Icons.location_on_outlined,
                size: 20, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: C.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deliveryAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context) {
    final isPaid = paymentStatus == 'Paid';
    final isPending = paymentStatus == 'Pending';

    return Container(
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
              color: isPaid
                  ? const Color(0xFFDCFCE7)
                  : isPending
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPaid
                  ? Icons.check_circle_outline
                  : isPending
                      ? Icons.access_time
                      : Icons.cancel_outlined,
              size: 20,
              color: isPaid
                  ? AppColors.success
                  : isPending
                      ? const Color(0xFFB45309)
                      : AppColors.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPaid
                  ? 'Payment successful'
                  : isPending
                      ? 'Payment pending'
                      : 'Payment refunded',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: C.textPrimary(context),
              ),
            ),
          ),
          Text(
            paymentStatus,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPaid
                  ? AppColors.success
                  : isPending
                      ? const Color(0xFFB45309)
                      : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
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
           _buildSummaryRow(context, 'Subtotal', '₦${formatPrice(subtotal)}'),
          const SizedBox(height: 10),
           _buildSummaryRow(context, 'Delivery fee', '₦${formatPrice(deliveryFee)}'),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.grey200),
          const SizedBox(height: 12),
           _buildSummaryRow(context, 'Total', '₦${formatPrice(total)}', bold: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: bold ? AppColors.black : AppColors.grey600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: bold ? AppColors.primaryDark : AppColors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildTrackButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeliveryTrackingScreen(
            orderNumber: orderNumber.replaceAll('#', ''),
            estimatedDelivery: 'Today, 2:00 PM – 4:00 PM',
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.local_shipping_outlined, size: 20, color: Colors.white),
            SizedBox(width: 10),
            Text('Track Delivery', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        int added = 0;
        int skipped = 0;
        for (final p in products) {
          for (int j = 0; j < p.quantity; j++) {
            final productName = p.name;
            final vendorName =
                StockTracker.findAndDecrementByName(productName);
            if (vendorName != null) {
              context.read<CartNotifier>().add(VendorProduct(
                image: p.image,
                name: productName,
                description: productName,
                price: p.price,
                category: p.category,
                vendorName: vendorName,
              ));
              added++;
            } else {
              skipped++;
            }
          }
        }
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (skipped == 0 && added > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('$added item${added == 1 ? '' : 's'} added to your box'),
            backgroundColor: AppColors.primaryDark,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm)),
          ));
        } else if (added == 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Items are out of stock'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm)),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$added added, $skipped out of stock'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm)),
          ));
        }
      },
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.replay, size: 20, color: AppColors.primaryDark),
            SizedBox(width: 10),
            Text(
              'Reorder All Items',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
