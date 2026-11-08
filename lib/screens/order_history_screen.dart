import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/mock_backend.dart';
import '../data/mock_data.dart';
import '../data/orders.dart';
import '../tabs.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/load_error_view.dart';
import '../widgets/order_rating_sheet.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/status_view.dart';
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
        OrderStatus.packing => C.warning(context),
        OrderStatus.pickedUp => C.warning(context),
        OrderStatus.onTheWay => C.warning(context),
        OrderStatus.delivered => C.success(context),
        OrderStatus.cancelled => C.error(context),
      };

  // ── Actions ─────────────────────────────────────────────────────────────

  void _openDetails(Order order) {
    // The details screen is driven by the order itself; handing it the store
    // lets the timeline follow status changes made while it is open.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(order: order, store: _store),
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
    if (skipped == 0) {
      showAppSnackBar(
        context,
        '$added item${added == 1 ? '' : 's'} added to your box',
        actionLabel: 'View box',
        onAction: () => openTab(context, AppTab.cart),
      );
    } else if (added == 0) {
      showAppSnackBar(context, 'All items are out of stock', isError: true);
    } else {
      showAppSnackBar(context, '$added added, $skipped out of stock',
          isError: true);
    }
    setState(() {});
  }

  void _startShopping() {
    // Same hand-off the bottom nav uses for a tab switch.
    openTab(context, AppTab.home);
  }

  /// Asks how the delivery went and records the answer on the order.
  ///
  /// The sheet always resolves (a swipe-away is a skip), so the prompt cannot
  /// come back on this order either way.
  Future<void> _rate(Order order) async {
    final rating = await showOrderRatingSheet(
      context,
      vendorName: order.vendorName,
    );
    if (!mounted) return;
    await _store.rate(order.id, rating);
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
            const AppHeader(title: 'Your Orders'),
            const SizedBox(height: AppSpacing.md),
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
      return _buildSkeletons(hp, isActiveTab);
    }

    // The first request failed, so there is no list to keep: the list's slot
    // becomes the shared error state and its retry refetches.
    if (_store.error != null && !_store.hasLoaded) {
      return LoadErrorView(
        title: "Couldn't load orders",
        onRetry: () => _store.load(force: true),
      );
    }

    if (orders.isEmpty) {
      return _OrdersEmptyState(
        isActiveTab: isActiveTab,
        onStartShopping: _startShopping,
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
            onRate: isActiveTab ? null : () => _rate(order),
            // Demo-only mutations, all of which need a live order to act on.
            onAdvance:
                isActiveTab ? () => _store.advanceStatus(order.id) : null,
            onCancel: isActiveTab
                ? () => _store.cancel(order.id, reason: 'Cancelled by you')
                : null,
            onMakeLate: isActiveTab
                ? () => _store.makeLate(order.id)
                : null,
          ),
        );
      },
    );
  }

  /// Skeleton orders: one per row, at the card's exact padding and height.
  Widget _buildSkeletons(double hp, bool isActiveTab) {
    return Shimmer(
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(hp, 0, hp, AppSpacing.xxxl),
        itemCount: 4,
        itemBuilder: (context, index) => _OrderCardSkeleton(active: isActiveTab),
      ),
    );
  }
}

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
  final VoidCallback onStartShopping;

  const _OrdersEmptyState({
    required this.isActiveTab,
    required this.onStartShopping,
  });

  @override
  Widget build(BuildContext context) {
    // Both tabs end in the same place: the shop. The old past tab had no
    // action at all, so a brand-new customer who opened "Past" was stuck.
    return StatusView(
      icon: isActiveTab ? Icons.receipt_long_outlined : Icons.history_rounded,
      title: isActiveTab ? 'No active orders' : 'No past orders yet',
      message: isActiveTab
          ? 'Orders on their way will show up here.'
          : 'Your finished orders will show up here.',
      primaryLabel: 'Start shopping',
      onPrimary: onStartShopping,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ORDER CARD
// ═══════════════════════════════════════════════════════════════════════

/// Placeholder for an [_OrderCard]: same margin, padding and row heights, with
/// the progress strip on Active and the Reorder pill on Past, so the list does
/// not shift when the orders arrive.
class _OrderCardSkeleton extends StatelessWidget {
  final bool active;

  const _OrderCardSkeleton({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vendor name + status chip.
          const Row(
            children: [
              Expanded(child: SkeletonBox(height: 18)),
              SizedBox(width: AppSpacing.sm),
              SkeletonBox(width: 64, height: 22, radius: AppRadii.pill),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Items, date, total.
          const Row(
            children: [
              SkeletonBox(width: 56, height: 16),
              SizedBox(width: 10),
              SkeletonBox(width: 88, height: 16),
              Spacer(),
              SkeletonBox(width: 56, height: 16),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (active)
            // The four-segment progress strip.
            const SkeletonBox(height: 4, radius: 2)
          else
            // The Reorder pill.
            const SkeletonBox(width: 84, height: 31, radius: AppRadii.sm),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool active;
  final Color statusColor;
  final VoidCallback onOpen;
  final VoidCallback? onReorder;
  final VoidCallback? onRate;
  final VoidCallback? onAdvance;
  final VoidCallback? onCancel;
  final VoidCallback? onMakeLate;

  const _OrderCard({
    required this.order,
    required this.active,
    required this.statusColor,
    required this.onOpen,
    this.onReorder,
    this.onRate,
    this.onAdvance,
    this.onCancel,
    this.onMakeLate,
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
                    formatOrderDate(order.createdAt),
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
            // ── Rating (past, delivered) ─────────────────────────
            // Asked until answered; the answer (including a skip) replaces
            // the button for good.
            if (!active && order.status == OrderStatus.delivered) ...[
              const SizedBox(height: AppSpacing.md),
              if (order.rating == null && onRate != null)
                _FeedbackAction(label: 'Rate', onTap: onRate!)
              else if (order.rating != null)
                OrderRatingResult(rating: order.rating!),
            ],
            // ── Demo-only status controls ────────────────────────
            if (kDemoTools && active && onAdvance != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _DemoAction(
                    icon: Icons.fast_forward,
                    label: 'Advance status',
                    onTap: onAdvance!,
                  ),
                  if (onCancel != null)
                    _DemoAction(
                      icon: Icons.cancel_outlined,
                      label: 'Cancel order',
                      onTap: onCancel!,
                    ),
                  if (onMakeLate != null)
                    _DemoAction(
                      icon: Icons.schedule,
                      label: 'Make late',
                      onTap: onMakeLate!,
                    ),
                ],
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

/// The quiet pill a demo mutation is offered as.
///
/// Outlined and muted on purpose: these are not product actions, and a
/// released build does not compile them in at all ([kDemoTools]).
class _DemoAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DemoAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: C.divider(context), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: C.textMuted(context)),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: C.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Rate" pill on a delivered order nobody has asked about yet.
///
/// Filled rather than outlined: rating is a real action the customer can take,
/// not a demo affordance.
class _FeedbackAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FeedbackAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: C.primary(context),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.thumb_up_alt_outlined,
              size: 15,
              color: C.onPrimary(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: C.onPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: switch (color) {
          _ when color == C.primary(context) => C.primaryTint(context),
          _ when color == C.warning(context) => C.warningSoft(context),
          _ when color == C.success(context) => C.successSoft(context),
          _ when color == C.error(context) => C.errorSoft(context),
          _ => C.surfaceLighter(context),
        },
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: switch (color) {
            _ when color == C.primary(context) => C.textPrimary(context),
            _ when color == C.warning(context) => C.onWarningSoft(context),
            _ when color == C.success(context) => C.onSuccessSoft(context),
            _ when color == C.error(context) => C.onErrorSoft(context),
            _ => C.textPrimary(context),
          },
        ),
      ),
    );
  }
}

/// Four segments: confirmed → packing → on the way → delivered.
class _OrderProgress extends StatelessWidget {
  final OrderStatus status;

  const _OrderProgress({required this.status});

  static const int _steps = OrderStatusX.progressSegmentsTotal;

  @override
  Widget build(BuildContext context) {
    // Filled bars come from the status itself, not from its position on the
    // five-step track: "on the way" is the third of four bars (it used to
    // fill all four because its index is 3).
    final reached = status.progressSegments;
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
                  color: step < reached
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
