import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../data/orders.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/order_timeline.dart';
import '../widgets/skeleton_loader.dart';
import 'delivery_tracking_screen.dart';

/// Full view of one [Order].
///
/// Everything on this screen — vendor, items, totals, payment state, which
/// actions are offered and the status timeline — is read from the order itself.
/// Passing a [OrdersStore] makes it follow live status changes (such as the
/// demo "advance status" action) instead of the snapshot it was opened with.
class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  /// Optional source of newer versions of [order]. Without it the screen is a
  /// pure render of the order it was given, which is what a real API response
  /// would look like.
  final OrdersStore? store;

  const OrderDetailsScreen({
    super.key,
    required this.order,
    this.store,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  @override
  void initState() {
    super.initState();
    widget.store?.addListener(_onStoreChanged);
  }

  @override
  void didUpdateWidget(covariant OrderDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store?.removeListener(_onStoreChanged);
      widget.store?.addListener(_onStoreChanged);
    }
  }

  @override
  void dispose() {
    widget.store?.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  /// The freshest version of the order the screen knows about.
  Order get _order {
    final store = widget.store;
    if (store == null) return widget.order;
    for (final order in store.orders) {
      if (order.id == widget.order.id) return order;
    }
    return widget.order;
  }

  static Color _statusColor(BuildContext context, OrderStatus status) =>
      switch (status) {
        OrderStatus.confirmed => C.primary(context),
        OrderStatus.packing => C.warning(context),
        OrderStatus.pickedUp => C.warning(context),
        OrderStatus.onTheWay => C.warning(context),
        OrderStatus.delivered => C.success(context),
        OrderStatus.cancelled => C.errorBright(context),
      };

  static Color _statusTint(BuildContext context, OrderStatus status) =>
      switch (status) {
        OrderStatus.confirmed => C.primaryTint(context),
        OrderStatus.packing || OrderStatus.pickedUp || OrderStatus.onTheWay =>
          C.warningSoft(context),
        OrderStatus.delivered => C.successSoft(context),
        OrderStatus.cancelled => C.errorSoft(context),
      };

  static Color _statusForeground(BuildContext context, OrderStatus status) =>
      switch (status) {
        OrderStatus.confirmed => C.textPrimary(context),
        OrderStatus.packing || OrderStatus.pickedUp || OrderStatus.onTheWay =>
          C.onWarningSoft(context),
        OrderStatus.delivered => C.onSuccessSoft(context),
        OrderStatus.cancelled => C.onErrorSoft(context),
      };

  static IconData _statusIcon(OrderStatus status) => switch (status) {
        OrderStatus.confirmed => Icons.receipt_long_outlined,
        OrderStatus.packing => Icons.inventory_2_outlined,
        OrderStatus.pickedUp => Icons.two_wheeler_outlined,
        OrderStatus.onTheWay => Icons.local_shipping_outlined,
        OrderStatus.delivered => Icons.check_circle_outline,
        OrderStatus.cancelled => Icons.cancel_outlined,
      };

  /// How the payment reads for this order.
  ///
  /// Pay on delivery collects nothing up front, so an active order says so and
  /// only a delivered one reads "Paid" — by then the rider has been paid. A
  /// cancelled order under this method moves no money at all, so it never says
  /// "Refunded": that wording is reserved for a cancellation after a real
  /// charge, which no method the app offers can produce yet.
  static String _paymentStatus(Order order) => switch (order.status) {
        OrderStatus.cancelled => 'Nothing charged',
        OrderStatus.delivered => 'Paid',
        _ => order.paymentMethod.label, // "Pay on delivery"
      };

  static String _paymentHeadline(Order order) => switch (order.status) {
        OrderStatus.cancelled => 'Order cancelled',
        OrderStatus.delivered => 'Payment successful',
        _ => 'Payment on delivery',
      };

  // ── Reorder ─────────────────────────────────────────────────────────────

  void _reorder(Order order) {
    final cart = context.read<CartNotifier>();
    int added = 0;
    int skipped = 0;

    for (final line in order.items) {
      // Rebuild a catalog product from the order snapshot so reordering works
      // even if the catalog has changed since the order was placed.
      final product = VendorProduct(
        image: line.image,
        name: line.name,
        description: line.name,
        price: line.price,
        category: line.category,
        vendorName: line.vendorName,
      );
      for (int unit = 0; unit < line.quantity; unit++) {
        if (StockTracker.isAvailable(line.vendorName, line.name)) {
          StockTracker.decrement(line.vendorName, line.name);
          cart.add(product);
          added++;
        } else {
          skipped++;
        }
      }
    }

    if (!mounted) return;
    if (skipped == 0) {
      showAppSnackBar(
        context,
        '$added item${added == 1 ? '' : 's'} added to your box',
        actionLabel: 'View box',
        onAction: () => AppRoutes.pushReplaceAll(context, AppRoutes.cart),
      );
    } else if (added == 0) {
      showAppSnackBar(context, 'All items are out of stock', isError: true);
    } else {
      showAppSnackBar(context, '$added added, $skipped out of stock',
          isError: true);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final hp = AppSizing.horizontalPadding(context);
    final statusColor = _statusColor(context, order.status);

    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'Order Details'),
            const SizedBox(height: AppSpacing.md),
            // ── Content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hp, 0, hp, AppSpacing.xxxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Order ────────────────────────────────────
                    _buildOrderCard(context, order, statusColor),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Status timeline ──────────────────────────
                    _buildSectionTitle(context, 'Status'),
                    const SizedBox(height: AppSpacing.md),
                    // The same widget Track Delivery draws: one definition of
                    // the steps, their names and their times.
                    OrderTimeline(
                      status: order.status,
                      timestamps: order.timestamps,
                      placedAt: order.createdAt,
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Items ────────────────────────────────────
                    _buildSectionTitle(context, 'Order Items'),
                    const SizedBox(height: AppSpacing.md),
                    ...order.items.map(
                      (item) => _buildProductCard(context, item),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Delivery ─────────────────────────────────
                    _buildSectionTitle(context, 'Delivery'),
                    const SizedBox(height: AppSpacing.md),
                    _buildDeliveryCard(context, order),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Payment ──────────────────────────────────
                    _buildSectionTitle(context, 'Payment'),
                    const SizedBox(height: AppSpacing.md),
                    _buildPaymentCard(context, order),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Summary ──────────────────────────────────
                    _buildSectionTitle(context, 'Summary'),
                    const SizedBox(height: AppSpacing.md),
                    _buildSummaryCard(context, order),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Actions ──────────────────────────────────
                    if (order.isActive)
                      _buildTrackButton(context, order)
                    else
                      _buildReorderButton(context, order),
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
      style: AppTypography.labelLarge.copyWith(
        fontSize: 15,
        color: C.textPrimary(context),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    Order order,
    Color statusColor,
  ) {
    final itemLabel =
        '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}';
    final placed = order.timestampOf(OrderStatus.confirmed) ?? order.createdAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: C.divider(context),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _statusTint(context, order.status),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _statusIcon(order.status),
              size: 24,
              color: _statusForeground(context, order.status),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderNumberLabel(order.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: C.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${order.vendorName} · $itemLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall
                      .copyWith(color: C.textMuted(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Placed ${formatOrderDate(placed)} at ${formatOrderTime(placed)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 12,
                    color: C.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusTint(context, order.status),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              order.status.label,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _statusForeground(context, order.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, OrderItem product) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppNeumorphic.cardDecoration(
        radius: AppRadii.md,
        context: context,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: SizedBox(
              width: 56,
              height: 56,
              child: product.image.isNotEmpty
                  ? SkeletonImage(
                      imageUrl: product.image,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      scrim: kProductImageScrim,
                      errorWidget: _itemPlaceholder(context),
                    )
                  : _itemPlaceholder(context),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: C.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.quantity} × ₦${formatPrice(product.price)}',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 12,
                    color: C.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '₦${formatPrice(product.lineTotal)}',
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: C.accentOrange(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemPlaceholder(BuildContext context) {
    return Container(
      color: C.primaryTint(context),
      child: Icon(
        Icons.eco_outlined,
        color: C.primary(context),
        size: 24,
      ),
    );
  }

  Widget _buildDeliveryCard(BuildContext context, Order order) {
    // The address snapshot taken when the order was placed. A record without
    // one says so instead of naming a place the customer never entered.
    final address = order.deliveryAddress.trim().isEmpty
        ? 'Not provided'
        : order.deliveryAddress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppNeumorphic.cardDecoration(
        radius: AppRadii.md,
        context: context,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: C.primaryTint(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.location_on_outlined,
              size: 20,
              color: C.primary(context),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Address',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: C.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall
                      .copyWith(color: C.textMuted(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, Order order) {
    final paymentStatus = _paymentStatus(order);
    final settled = paymentStatus == 'Paid';
    final cancelled = order.status == OrderStatus.cancelled;
    final note = order.riderNote?.trim() ?? '';

    // A check only once money has actually moved; a live pay-on-delivery order
    // carries the payment glyph instead, and a cancelled one neither.
    final icon = settled
        ? Icons.check_circle_outline
        : cancelled
            ? Icons.cancel_outlined
            : Icons.payments_outlined;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppNeumorphic.cardDecoration(
        radius: AppRadii.md,
        context: context,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: C.primaryTint(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: C.primary(context)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  _paymentHeadline(order),
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: C.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  paymentStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        settled ? C.success(context) : C.textMuted(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: C.divider(context)),
          const SizedBox(height: AppSpacing.md),
          // How it will be paid, and the note the rider needs to find the door.
          _buildSummaryRow(
            context,
            'Method',
            order.paymentMethod.label,
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildNoteRow(context, note),
          ],
        ],
      ),
    );
  }

  /// The rider note, wrapping instead of ellipsising: a gate code that ends in
  /// "…" is worse than useless.
  Widget _buildNoteRow(BuildContext context, String note) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note for rider',
          style: AppTypography.bodySmall.copyWith(
            color: C.textMuted(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          note,
          style: AppTypography.bodySmall.copyWith(
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: C.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, Order order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppNeumorphic.cardDecoration(
        radius: AppRadii.md,
        context: context,
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            context,
            'Subtotal',
            '₦${formatPrice(order.subtotal)}',
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            context,
            'Delivery fee',
            order.totals.deliveryFee == 0
                ? 'Free'
                : '₦${formatPrice(order.totals.deliveryFee)}',
            valueColor:
                order.totals.deliveryFee == 0 ? C.primary(context) : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: C.divider(context)),
          const SizedBox(height: AppSpacing.md),
          _buildSummaryRow(
            context,
            'Total',
            '₦${formatPrice(order.total)}',
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: bold ? C.textPrimary(context) : C.textMuted(context),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? C.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackButton(BuildContext context, Order order) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          // The order drives the stage, the step times, the ETA and the
          // order number; there is nothing left to hand over by hand.
          builder: (_) => DeliveryTrackingScreen(order: order),
        ),
      ),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: C.primary(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 20,
              color: C.onPrimary(context),
            ),
            const SizedBox(width: 10),
            Text(
              'Track Delivery',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: C.onPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderButton(BuildContext context, Order order) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _reorder(order),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: C.primaryTint(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.replay, size: 20, color: C.primary(context)),
            const SizedBox(width: 10),
            Text(
              'Reorder All Items',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: C.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
