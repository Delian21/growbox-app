import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../data/orders.dart';
import '../theme.dart';
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
  static const String _fallbackAddress =
      'No. 12 Gwarinpa Estate, Gwarinpa, Abuja, Nigeria';

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
        OrderStatus.packing => C.accentOrange(context),
        OrderStatus.onTheWay => C.accentOrange(context),
        OrderStatus.delivered => C.success(context),
        OrderStatus.cancelled => C.errorBright(context),
      };

  static IconData _statusIcon(OrderStatus status) => switch (status) {
        OrderStatus.confirmed => Icons.receipt_long_outlined,
        OrderStatus.packing => Icons.inventory_2_outlined,
        OrderStatus.onTheWay => Icons.local_shipping_outlined,
        OrderStatus.delivered => Icons.check_circle_outline,
        OrderStatus.cancelled => Icons.cancel_outlined,
      };

  /// Mock checkout charges up front, so the only refund case is a cancellation.
  /// A real backend would send a payment status alongside the order.
  static String _paymentStatus(Order order) =>
      order.status == OrderStatus.cancelled ? 'Refunded' : 'Paid';

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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (skipped == 0) {
      _showSnack(
        '$added item${added == 1 ? '' : 's'} added to your box',
        C.success(context),
      );
    } else if (added == 0) {
      _showSnack('All items are out of stock', C.error(context));
    } else {
      _showSnack('$added added, $skipped out of stock', C.warning(context));
    }
  }

  void _showSnack(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: background,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    ));
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
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hp, AppSpacing.lg, hp, 0),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Icon(
                          Icons.arrow_back,
                          size: 24,
                          color: C.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Order Details',
                      textAlign: TextAlign.center,
                      style: AppTypography.title
                          .copyWith(color: C.textPrimary(context)),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
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
                    _OrderTimeline(order: order),

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
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.25),
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
            child: Icon(_statusIcon(order.status), size: 24, color: statusColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.id}',
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
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              order.status.label,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
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
    final address =
        order.deliveryAddress.isEmpty ? _fallbackAddress : order.deliveryAddress;

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
    final isPaid = paymentStatus == 'Paid';

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
              color: isPaid ? C.primaryTint(context) : C.surfaceLight(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPaid ? Icons.check_circle_outline : Icons.replay_outlined,
              size: 20,
              color: isPaid ? C.primary(context) : C.textMuted(context),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              isPaid ? 'Payment successful' : 'Payment refunded',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: C.textPrimary(context),
              ),
            ),
          ),
          Text(
            paymentStatus,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: isPaid ? C.success(context) : C.textMuted(context),
            ),
          ),
        ],
      ),
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
            order.deliveryFee == 0
                ? 'Free'
                : '₦${formatPrice(order.deliveryFee)}',
            valueColor:
                order.deliveryFee == 0 ? C.primary(context) : null,
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
          builder: (_) => DeliveryTrackingScreen(
            orderNumber: order.id,
            estimatedDelivery: 'Today, 2:00 PM – 4:00 PM',
          ),
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

// ═══════════════════════════════════════════════════════════════════════
// STATUS TIMELINE
// ═══════════════════════════════════════════════════════════════════════

enum _StepState { done, current, upcoming, cancelled }

/// The four lifecycle steps with the time each was reached.
///
/// A cancelled order stops at "Confirmed" and gains a final cancelled row, so
/// the track never pretends the delivery progressed further than it did.
class _OrderTimeline extends StatelessWidget {
  final Order order;

  const _OrderTimeline({required this.order});

  static const List<OrderStatus> _track = [
    OrderStatus.confirmed,
    OrderStatus.packing,
    OrderStatus.onTheWay,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == OrderStatus.cancelled;
    final currentIndex = cancelled ? -1 : order.status.stepIndex;

    final steps = <(OrderStatus, _StepState)>[];
    for (var i = 0; i < _track.length; i++) {
      final status = _track[i];
      final state = cancelled
          ? (i == 0 ? _StepState.done : _StepState.upcoming)
          : i < currentIndex
              ? _StepState.done
              : i == currentIndex
                  ? _StepState.current
                  : _StepState.upcoming;
      steps.add((status, state));
    }
    if (cancelled) {
      steps.add((OrderStatus.cancelled, _StepState.cancelled));
    }

    return Container(
      key: const ValueKey('orderTimeline'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      decoration: AppNeumorphic.cardDecoration(
        radius: AppRadii.md,
        context: context,
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              status: steps[i].$1,
              state: steps[i].$2,
              at: order.timestampOf(steps[i].$1),
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final OrderStatus status;
  final _StepState state;
  final DateTime? at;
  final bool isLast;

  const _TimelineRow({
    required this.status,
    required this.state,
    required this.at,
    required this.isLast,
  });

  static String _trailingLabel(_StepState state, DateTime? at) {
    switch (state) {
      case _StepState.done:
        return at == null ? 'Done' : formatOrderTime(at);
      case _StepState.current:
        return at == null ? 'In progress' : 'In progress · ${formatOrderTime(at)}';
      case _StepState.cancelled:
        // The row is already labelled "Cancelled"; only the time adds anything.
        return at == null ? '' : formatOrderTime(at);
      case _StepState.upcoming:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = state == _StepState.done;
    final current = state == _StepState.current;
    final isCancelled = state == _StepState.cancelled;

    final markerColor = isCancelled
        ? C.errorBright(context)
        : done
            ? C.primary(context)
            : current
                ? C.accentOrange(context)
                : C.divider(context);

    final labelColor = state == _StepState.upcoming
        ? C.textMuted(context)
        : C.textPrimary(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Marker and connector ─────────────────────────────
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: done || isCancelled
                        ? markerColor
                        : AppColors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: markerColor,
                      width: current ? 2 : 1.5,
                    ),
                  ),
                  child: done
                      ? Icon(
                          Icons.check,
                          size: 12,
                          color: C.background(context),
                        )
                      : isCancelled
                          ? Icon(
                              Icons.close,
                              size: 12,
                              color: C.background(context),
                            )
                          : current
                              ? Center(
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: markerColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: done
                          ? C.primary(context)
                          : C.divider(context),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // ── Label and time ───────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 8 : AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      status.label,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 13,
                        fontWeight:
                            current ? FontWeight.w700 : FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _trailingLabel(state, at),
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 12,
                      color: C.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
