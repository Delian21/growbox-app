import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../data/orders.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/animated_entrance.dart';
import 'order_details_screen.dart';

/// Which half of the orders list is showing.
enum OrdersTab { active, past }

/// Orders screen: in-flight deliveries under "Active", everything finished
/// (delivered or cancelled) under "Past".
///
/// All data comes from an [OrdersRepository] via [OrdersStore]; nothing here
/// knows that the orders are currently mocked.
class OrderHistoryScreen extends StatefulWidget {
  final OrdersTab initialTab;

  /// Optional store for tests / alternative repositories. Falls back to the
  /// app-wide [ordersStore].
  final OrdersStore? store;

  const OrderHistoryScreen({
    super.key,
    this.initialTab = OrdersTab.active,
    this.store,
  });

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  static const String _fallbackAddress =
      'No. 12 Gwarinpa Estate, Gwarinpa, Abuja, Nigeria';

  late OrdersTab _tab = widget.initialTab;

  OrdersStore get _store => widget.store ?? ordersStore;

  @override
  void initState() {
    super.initState();
    // Refetch on open, the way a screen backed by a server would. Deferred a
    // frame because the store notifies synchronously about its loading state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _store.load(force: true);
    });
  }

  // ── Formatting ──────────────────────────────────────────────────────────

  static Color _statusColor(BuildContext context, OrderStatus status) =>
      switch (status) {
        OrderStatus.confirmed => C.primary(context),
        OrderStatus.packing => C.accentOrange(context),
        OrderStatus.onTheWay => C.accentOrange(context),
        OrderStatus.delivered => C.success(context),
        OrderStatus.cancelled => C.error(context),
      };

  // ── Actions ─────────────────────────────────────────────────────────────

  void _openDetails(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(
          orderNumber: '#${order.id}',
          date: _formatOrderDate(order.createdAt),
          status: order.status.label,
          statusColor: _statusColor(context, order.status),
          paymentStatus:
              order.status == OrderStatus.cancelled ? 'Refunded' : 'Paid',
          deliveryAddress: order.deliveryAddress.isEmpty
              ? _fallbackAddress
              : order.deliveryAddress,
          subtotal: order.subtotal,
          deliveryFee: order.deliveryFee,
          total: order.total,
          products: order.items,
        ),
      ),
    );
  }

  /// Adds every line of [order] back to the box, respecting live stock.
  void _reorder(Order order) {
    final cart = context.read<CartNotifier>();
    int added = 0;
    int skipped = 0;

    for (final line in order.items) {
      // Rebuild a catalog product from the order snapshot so the cart works
      // with normal products even if the catalog changed since.
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
    setState(() {});
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

  void _startShopping() {
    // Same hand-off the bottom nav uses for a tab switch.
    AppRoutes.pushReplaceAll(context, AppRoutes.home);
  }

  // ── Build ───────────────────────────────────────────────────────────────

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
                      'Your Orders',
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
            // ── Active / Past tabs ──────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hp),
              child: _OrdersTabBar(
                selected: _tab,
                onChanged: (tab) => setState(() => _tab = tab),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // ── Orders ──────────────────────────────────────────
            Expanded(
              child: ListenableBuilder(
                listenable: _store,
                builder: (context, _) => _buildOrders(hp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrders(double hp) {
    final isActiveTab = _tab == OrdersTab.active;
    final orders = isActiveTab ? _store.activeOrders : _store.pastOrders;

    // First load only: refetches keep the previous list on screen.
    if (_store.isLoading && !_store.hasLoaded) {
      return Center(
        child: CircularProgressIndicator(color: C.primary(context)),
      );
    }

    if (orders.isEmpty) {
      return _OrdersEmptyState(
        isActiveTab: isActiveTab,
        onStartShopping: isActiveTab ? _startShopping : null,
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hp, 0, hp, AppSpacing.xxxl),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return AnimatedEntrance(
          index: index,
          child: _OrderCard(
            order: order,
            active: isActiveTab,
            statusColor: _statusColor(context, order.status),
            onOpen: () => _openDetails(order),
            onReorder: isActiveTab ? null : () => _reorder(order),
            onAdvance: isActiveTab
                ? () => _store.advanceStatus(order.id)
                : null,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SHARED FORMATTING
// ═══════════════════════════════════════════════════════════════════════

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatOrderDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year}';

// ═══════════════════════════════════════════════════════════════════════
// TABS
// ═══════════════════════════════════════════════════════════════════════

class _OrdersTabBar extends StatelessWidget {
  final OrdersTab selected;
  final ValueChanged<OrdersTab> onChanged;

  const _OrdersTabBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: C.surfaceLight(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          _buildTab(context, OrdersTab.active, 'Active'),
          _buildTab(context, OrdersTab.past, 'Past'),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, OrdersTab tab, String label) {
    final isSelected = tab == selected;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? C.primary(context) : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? C.onPrimary(context)
                  : C.textMuted(context),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════

class _OrdersEmptyState extends StatelessWidget {
  final bool isActiveTab;
  final VoidCallback? onStartShopping;

  const _OrdersEmptyState({
    required this.isActiveTab,
    this.onStartShopping,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: C.primaryTint(context).withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActiveTab
                    ? Icons.receipt_long_outlined
                    : Icons.history_rounded,
                size: 44,
                color: C.primary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              isActiveTab ? 'No active orders' : 'No past orders',
              style: AppTypography.labelLarge
                  .copyWith(color: C.textPrimary(context)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isActiveTab
                  ? 'Orders on their way will show up here.'
                  : 'Delivered and cancelled orders live here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: C.textMuted(context),
              ),
            ),
            if (onStartShopping != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              GestureDetector(
                onTap: onStartShopping,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: C.primary(context),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    'Start shopping',
                    style: AppTypography.labelMedium.copyWith(
                      color: C.onPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ORDER CARD
// ═══════════════════════════════════════════════════════════════════════

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool active;
  final Color statusColor;
  final VoidCallback onOpen;
  final VoidCallback? onReorder;
  final VoidCallback? onAdvance;

  const _OrderCard({
    required this.order,
    required this.active,
    required this.statusColor,
    required this.onOpen,
    this.onReorder,
    this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final itemLabel =
        '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: AppNeumorphic.cardDecoration(
          radius: AppRadii.md,
          context: context,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Vendor + status ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.vendorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: C.textPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusChip(label: order.status.label, color: statusColor),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // ── Items, date, total ───────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 14,
                  color: C.textMuted(context),
                ),
                const SizedBox(width: 6),
                Text(
                  itemLabel,
                  style: AppTypography.bodySmall
                      .copyWith(color: C.textMuted(context)),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: C.textMuted(context),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _formatOrderDate(order.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall
                        .copyWith(color: C.textMuted(context)),
                  ),
                ),
                const Spacer(),
                Text(
                  '₦${formatPrice(order.total)}',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: C.textPrimary(context),
                  ),
                ),
              ],
            ),
            // ── Progress (active only) ───────────────────────────
            if (active) ...[
              const SizedBox(height: AppSpacing.md),
              _OrderProgress(status: order.status),
            ],
            // ── Reorder (past only) ──────────────────────────────
            if (onReorder != null) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onReorder,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: C.primaryTint(context),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.replay,
                          size: 15,
                          color: C.primary(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Reorder',
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: C.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            // ── Demo-only status control ─────────────────────────
            if (kDebugMode && active && onAdvance != null) ...[
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAdvance,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: C.divider(context), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fast_forward,
                        size: 13,
                        color: C.textMuted(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Advance status',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: C.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PIECES
// ═══════════════════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Four segments: confirmed → packing → on the way → delivered.
class _OrderProgress extends StatelessWidget {
  final OrderStatus status;

  const _OrderProgress({required this.status});

  static const int _steps = 4;

  @override
  Widget build(BuildContext context) {
    final reached = status.stepIndex;
    return Semantics(
      label: 'Order progress: ${status.label}',
      child: Row(
        key: const ValueKey('orderProgress'),
        children: [
          for (int step = 0; step < _steps; step++) ...[
            if (step > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: step <= reached
                      ? C.primary(context)
                      : C.divider(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
