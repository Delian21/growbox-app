import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../data/orders.dart';
import '../tabs.dart';
import '../theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_header.dart';
import '../widgets/order_rating_sheet.dart';
import '../widgets/order_timeline.dart';
import '../widgets/status_view.dart';
import 'faq_screen.dart';

/// Delivery tracking status stages.
enum DeliveryStage {
  orderPlaced,
  riderAssigned,
  pickedUp,
  onTheWay,
  delivered,
}

extension DeliveryStageX on DeliveryStage {
  /// How far along the route the rider is at this stage (0 = vendor,
  /// 1 = destination). The marker rides the painted path at this point, so it
  /// can never drift off the road.
  double get routeProgress => switch (this) {
        DeliveryStage.orderPlaced => 0.04,
        DeliveryStage.riderAssigned => 0.12,
        DeliveryStage.pickedUp => 0.32,
        DeliveryStage.onTheWay => 0.60,
        DeliveryStage.delivered => 1.0,
      };
}

/// Maps an order's lifecycle onto this screen's delivery stages.
///
/// The order's track and the screen's stages line up one-to-one, so every step
/// can carry the order's own timestamp.
DeliveryStage stageForOrderStatus(OrderStatus status) => switch (status) {
      OrderStatus.confirmed => DeliveryStage.orderPlaced,
      OrderStatus.packing => DeliveryStage.riderAssigned,
      OrderStatus.pickedUp => DeliveryStage.pickedUp,
      OrderStatus.onTheWay => DeliveryStage.onTheWay,
      OrderStatus.delivered => DeliveryStage.delivered,
      // Tracking is only offered for active orders; a cancelled one is treated
      // as never having left the vendor rather than as progress.
      OrderStatus.cancelled => DeliveryStage.orderPlaced,
    };

/// The order event a stage's timestamp comes from.
OrderStatus statusForDeliveryStage(DeliveryStage stage) => switch (stage) {
      DeliveryStage.orderPlaced => OrderStatus.confirmed,
      DeliveryStage.riderAssigned => OrderStatus.packing,
      DeliveryStage.pickedUp => OrderStatus.pickedUp,
      DeliveryStage.onTheWay => OrderStatus.onTheWay,
      DeliveryStage.delivered => OrderStatus.delivered,
    };

/// Mock rider data for the delivery.
class DeliveryRider {
  final String name;
  final String phone;
  final String avatarUrl;

  DeliveryRider({
    required this.name,
    required this.phone,
    required this.avatarUrl,
  });
}

/// Delivery tracking screen with live countdown, animated map, and rider info.
///
/// Pass the real [order] whenever one exists: its status picks the current step
/// and its [Order.timestamps] supply each step's time. The screen then shows the
/// order's truth instead of animating through stages on its own.
///
/// Only callers that have no [Order] yet (tests) fall back to [orderNumber]
/// plus a demo timeline. The ETA always comes from [Order.eta], so this screen
/// and the confirmation screen quote the same arrival time.
class DeliveryTrackingScreen extends StatefulWidget {
  /// The order being tracked. Authoritative when present.
  final Order? order;

  /// Used when [order] is null; a real order supplies its own id.
  final String? orderNumber;

  /// Demo-only starting stage, used when [order] is null.
  final DeliveryStage? initialStage;

  /// Optional source of newer versions of [order], so the screen follows an
  /// order that is cancelled or delivered while it is open. Falls back to the
  /// app-wide store.
  final OrdersStore? store;

  const DeliveryTrackingScreen({
    super.key,
    this.order,
    this.orderNumber,
    this.initialStage,
    this.store,
  }) : assert(
          order != null || orderNumber != null,
          'DeliveryTrackingScreen needs an order or an order number',
        );

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen>
    with SingleTickerProviderStateMixin {
  late DeliveryStage _currentStage;

  /// The promised arrival: the order's own ETA, or the demo's 28 minutes.
  late DateTime _eta;
  late DateTime _placedAt;
  late String _orderNumber;

  Timer? _countdownTimer;
  Timer? _stageTimer;

  /// True when nothing real is driving the screen and the demo timeline runs.
  bool get _isDemo => widget.order == null;

  /// Breathing halo behind the rider marker.
  late AnimationController _riderPulseController;

  // Mock rider
  final DeliveryRider _rider = DeliveryRider(
    name: 'Ibrahim K.',
    phone: '+234 812 345 6789',
    avatarUrl: '',
  );

  @override
  void initState() {
    super.initState();

    final order = widget.order;
    // A real order decides where the delivery actually is; the demo stage is
    // only a stand-in when there is nothing to read.
    _currentStage = order != null
        ? stageForOrderStatus(order.status)
        : widget.initialStage ?? DeliveryStage.onTheWay;
    _orderNumber = order?.id ?? widget.orderNumber ?? '—';
    _placedAt = order?.createdAt ??
        DateTime.now().subtract(const Duration(minutes: 47));

    // A real order carries its promised arrival; the demo counts down 28
    // minutes from opening.
    _eta = order?.eta ?? DateTime.now().add(const Duration(minutes: 28));
    _startArrivalClock();

    _riderPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Runs only when there is a rider to pulse; see [_syncRiderPulse].
    _syncRiderPulse();

    // Only the demo invents progress; a real order only moves when the order
    // itself does.
    if (_isDemo) _startStageSimulation();

    // A real order is live data: subscribe so a cancellation (or the delivery
    // landing) repaints this screen instead of leaving a stale route on it.
    if (widget.order != null) _store.addListener(_onStoreChanged);
  }

  OrdersStore get _store => widget.store ?? ordersStore;

  void _onStoreChanged() {
    if (!mounted) return;
    setState(_syncRiderPulse);
  }

  /// The breathing halo only exists while a rider is on the map.
  ///
  /// Delivered and cancelled hide the map, so the controller stops too: an
  /// animation nobody can see would keep the device awake and every
  /// `pumpAndSettle` waiting forever.
  void _syncRiderPulse() {
    final visible = !_isDelivered && !_isCancelled;
    if (visible && !_riderPulseController.isAnimating) {
      _riderPulseController.repeat(reverse: true);
    } else if (!visible && _riderPulseController.isAnimating) {
      _riderPulseController.stop();
    }
  }

  /// The freshest version of the order this screen knows about.
  Order? get _order {
    final base = widget.order;
    if (base == null) return null;
    for (final order in _store.orders) {
      if (order.id == base.id) return order;
    }
    return base;
  }

  /// The stage to show: the order's own status wins whenever there is one, and
  /// the demo timer only drives the case with no order to read.
  DeliveryStage get _stage {
    final order = _order;
    return order == null ? _currentStage : stageForOrderStatus(order.status);
  }

  bool get _isCancelled => _order?.status == OrderStatus.cancelled;

  bool get _isDelivered => _stage == DeliveryStage.delivered;

  /// Ticks once a minute: the arrival card counts whole minutes, so a
  /// per-second timer would repaint sixty times to say nothing new.
  void _startArrivalClock() {
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      // A demo delivery completes when its window closes. A real order only
      // moves when the order itself does, so it just re-reads the clock.
      if (_isDemo && DateTime.now().isAfter(_eta)) {
        setState(() {
          _currentStage = DeliveryStage.delivered;
          _syncRiderPulse();
        });
      } else {
        setState(() {});
      }
    });
  }

  void _startStageSimulation() {
    // Simulate the rider progressing through stages
    _stageTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _currentStage = DeliveryStage.pickedUp);
      _stageTimer = Timer(const Duration(seconds: 12), () {
        if (!mounted) return;
        setState(() => _currentStage = DeliveryStage.onTheWay);
      });
    });
  }

  @override
  void dispose() {
    if (widget.order != null) _store.removeListener(_onStoreChanged);
    _countdownTimer?.cancel();
    _stageTimer?.cancel();
    _riderPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hp = screenWidth < 360 ? 16.0 : screenWidth < 600 ? 22.0 : 40.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            _buildHeader(),
            // ── Scrollable content ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hp, AppSpacing.xl, hp, 30),
                child: _buildBody(screenWidth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The scrollable content, which depends on how the order ended.
  ///
  /// Cancelled replaces the whole delivery story with the one thing left to
  /// do (reorder, or talk to someone); delivered keeps the completed timeline
  /// but drops the live route and rider, because there is nothing left to
  /// track and nobody left to call.
  Widget _buildBody(double screenWidth) {
    if (_isCancelled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusView(
            icon: Icons.cancel_outlined,
            title: 'Order cancelled',
            // The recorded reason when there is one; otherwise a plain
            // statement, never an invented excuse.
            message: (_order?.cancelReason?.trim().isNotEmpty ?? false)
                ? _order!.cancelReason!.trim()
                : 'This order was cancelled. Nothing was charged.',
            primaryLabel: 'Reorder',
            onPrimary: _reorder,
            secondaryLabel: 'Contact support',
            onSecondary: _openHelp,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTimeline(),
          const SizedBox(height: AppSpacing.xxl),
          _buildDeliveryDetails(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Arrival, then where the box is, then who is carrying it, then how
        // far it has come, then the reference details.
        _buildArrivalCard(),
        const SizedBox(height: AppSpacing.xxl),
        if (_isDelivered)
          // Delivered: ask how it went instead of drawing a route that has
          // already been travelled.
          _buildFeedbackCard()
        else ...[
          // A static illustration of the route, not live GPS: the marker is
          // placed from the order's status and nothing is read from the
          // device's location.
          _buildAnimatedMap(screenWidth),
          const SizedBox(height: AppSpacing.xxl),
          _buildRiderCard(),
        ],
        const SizedBox(height: AppSpacing.xxl),
        _buildTimeline(),
        const SizedBox(height: AppSpacing.xxl),
        _buildDeliveryDetails(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FEEDBACK
  // ═══════════════════════════════════════════════════════════════════════

  /// "How was your order?" — the prompt while unrated, the answer afterwards.
  ///
  /// The card never disappears once answered, so the customer can see what
  /// they said; a skipped prompt shows the skip rather than asking again.
  Widget _buildFeedbackCard() {
    final rating = _order?.rating;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: C.surface(context),
        border: Border.all(color: C.divider(context)),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How was your order?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: C.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (rating == null)
            Text(
              'A thumbs up or down helps other customers choose a vendor.',
              style: AppTypography.bodySmall.copyWith(
                color: C.textSecondary(context),
              ),
            )
          else
            // Saved answer: the same line the past-orders card shows.
            OrderRatingResult(rating: rating),
          if (rating == null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: AppButton(
                label: 'Rate your order',
                onPressed: _rate,
                variant: AppButtonVariant.secondary,
                expand: true,
                height: 48,
                radius: AppRadii.pill,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Asks, then saves the answer (including a skip) on the order.
  Future<void> _rate() async {
    final order = _order;
    if (order == null) return;
    final rating = await showOrderRatingSheet(
      context,
      vendorName: order.vendorName,
    );
    if (!mounted) return;
    await _store.rate(order.id, rating);
  }

  /// Puts every line back in the box, respecting live stock.
  ///
  /// Same behaviour as the orders list's reorder, because "Reorder" has to
  /// mean the same thing wherever it is offered.
  void _reorder() {
    final order = _order;
    if (order == null) return;
    final cart = context.read<CartNotifier>();
    int added = 0;
    int skipped = 0;

    for (final line in order.items) {
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
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    // Solid background and a permanent hairline: the map and cards scroll
    // under this header, so it needs the divider at all times.
    return const AppHeader(title: 'Track Delivery', showDivider: true);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ARRIVAL CARD
  // ═══════════════════════════════════════════════════════════════════════

  /// Minutes left, rounded up: "11 min" instead of a seconds clock nobody can
  /// read and that would repaint every tick.
  int get _minutesLeft =>
      (_eta.difference(DateTime.now()).inSeconds / 60).ceil();

  /// Past the promise and still not delivered.
  bool get _isLate =>
      !_isDelivered && !_isCancelled && DateTime.now().isAfter(_eta);

  /// The headline: the wait, the arrival, lateness or completion.
  ///
  /// Never zero and never negative — the last minute reads "Arriving now"
  /// rather than counting down to a number the delivery cannot honour.
  String get _arrivalHeadline {
    // The delivered card states the fact with its time instead of a bare
    // "Delivered!": the customer wants to know when the box arrived.
    if (_isDelivered) return 'Delivered at ${formatOrderTime(_deliveredAt)}';
    if (_isLate) return 'Running late';
    if (_eta.difference(DateTime.now()).inSeconds < 60) return 'Arriving now';
    return '$_minutesLeft min';
  }

  /// The line under the headline: when the box is due, written the one way the
  /// app writes a time.
  /// When the box actually arrived: the order's own stamp, or the promised
  /// arrival for the demo timeline, which has no order behind it.
  DateTime get _deliveredAt => _order?.deliveredTime ?? _eta;

  String get _arrivalDetail {
    if (_isDelivered) {
      return 'Your order has been delivered successfully';
    }
    final by = formatOrderTime(_eta);
    return _isLate ? 'It was due by $by' : 'Arriving by $by';
  }

  void _openHelp() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FAQScreen()),
      );

  Widget _buildArrivalCard() {
    final isDelivered = _isDelivered;
    final late = !isDelivered && !_isCancelled && _isLate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        // Mint on light, deep green on dark — never the raw light token.
        color: C.successSoft(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: C.primary(context).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            isDelivered
                ? Icons.check_circle
                : late
                    ? Icons.schedule
                    : Icons.local_shipping_outlined,
            size: 40,
            color: late
                ? C.errorBright(context)
                : isDelivered
                    ? C.success(context)
                    : C.primary(context),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _arrivalHeadline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w700,
              // Primary green clears 4.5:1 on the soft panel in both themes;
              // the lateness colour is the app's readable destructive red.
              color: late ? C.errorBright(context) : C.primary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _arrivalDetail,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: C.textSecondary(context)),
          ),
          if (late) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Need help?',
              onPressed: _openHelp,
              variant: AppButtonVariant.text,
              height: 44,
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ANIMATED MAP
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAnimatedMap(double screenWidth) {
    final mapHeight = (screenWidth * 0.55).clamp(200.0, 300.0);
    final isDelivered = _isDelivered;

    return Container(
      width: double.infinity,
      height: mapHeight,
      decoration: BoxDecoration(
        color: C.primaryTint(context).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: C.divider(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, mapHeight);
            final route = _RouteGeometry.forSize(size);

            return Stack(
              children: [
                // Streets.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapBackgroundPainter(
                      streetColor:
                          C.primaryTint(context).withValues(alpha: 0.45),
                      roadColor: C.primaryTint(context).withValues(alpha: 0.8),
                    ),
                  ),
                ),
                // Route + rider, painted before the pins so both ends tuck under
                // the markers instead of stopping short of them.
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: _stage.routeProgress,
                    ),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, _) => Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RoutePainter(
                              route: route,
                              travelled: progress,
                              travelledColor: C.primary(context),
                              remainingColor:
                                  C.textMuted(context).withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        if (!isDelivered) _riderMarker(route.pointAt(progress)),
                      ],
                    ),
                  ),
                ),
                // Pickup pin.
                _mapPin(
                  center: route.start,
                  fill: C.primary(context),
                  iconColor: C.onPrimary(context),
                  icon: Icons.store,
                  label: 'Green Farm',
                ),
                // Destination pin; it turns into a check once delivered.
                _mapPin(
                  center: route.end,
                  fill: isDelivered ? C.success(context) : C.error(context),
                  iconColor: isDelivered
                      ? C.onPrimary(context)
                      : C.onError(context),
                  icon: isDelivered ? Icons.check : Icons.location_on,
                  label: isDelivered ? 'Delivered' : 'Your Address',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// A marker circle centred on [center] with its label hanging underneath.
  ///
  /// Circle and label are placed separately on purpose: a single Column would
  /// centre the circle on the label's width, which is what pushed the route
  /// line off the vendor marker.
  Widget _mapPin({
    required Offset center,
    required Color fill,
    required Color iconColor,
    required IconData icon,
    required String label,
  }) {
    const double dot = 28;

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: center.dx - dot / 2,
            top: center.dy - dot / 2,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: Center(child: Icon(icon, size: 16, color: iconColor)),
            ),
          ),
          // Below the dot, so the label never sits on the end of the route: the
          // line terminates at the dot's centre and is covered by the dot.
          Positioned(
            left: center.dx - 52,
            width: 104,
            top: center.dy + dot / 2 + 6,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: C.surface(context),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: C.divider(context)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: C.textPrimary(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Solid primary marker with a scooter, sitting on the route at [at].
  Widget _riderMarker(Offset at) {
    return Positioned(
      left: at.dx - 22,
      top: at.dy - 22,
      child: Semantics(
        label: 'Rider ${_rider.name}',
        child: AnimatedBuilder(
          animation: _riderPulseController,
          builder: (context, _) {
            final ring = 34 + 10 * _riderPulseController.value;
            return SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: ring,
                    height: ring,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: C.primary(context).withValues(alpha: 0.16),
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: C.primary(context),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.two_wheeler,
                        size: 18,
                        // White on the deep green, near-black on the lifted
                        // green, so the scooter is legible in both themes.
                        color: C.onPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DELIVERY TIMELINE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Status',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: C.textPrimary(context),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // The same widget Order Details renders. A real order brings its own
        // event log; the demo only has a placement time, so the shared timeline
        // dates the steps from the delivery's ladder.
        OrderTimeline(
          // The order's own status, so a cancellation ends the track with a
          // "Cancelled" row exactly as Order Details draws it.
          status: _order?.status ?? statusForDeliveryStage(_stage),
          timestamps: widget.order?.timestamps ?? const {},
          placedAt: _placedAt,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RIDER CARD
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildRiderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: C.surface(context),
        border: Border.all(color: C.divider(context)),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          // Initials monogram instead of a generic person glyph.
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: C.primaryTint(context),
              shape: BoxShape.circle,
              border: Border.all(color: C.primary(context), width: 2),
            ),
            child: Center(
              child: Text(
                _initials(_rider.name),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: C.primary(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Info — name only; the phone number is kept for the call action and
          // never printed.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Rider',
                  style: TextStyle(
                    fontSize: 12,
                    color: C.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _rider.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: C.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          _riderAction(
            icon: Icons.phone,
            label: 'Call rider',
            onTap: () => showAppSnackBar(context, 'Calling ${_rider.name}…'),
          ),
          const SizedBox(width: AppSpacing.sm),
          _riderAction(
            icon: Icons.message_outlined,
            label: 'Message rider',
            onTap: () =>
                showAppSnackBar(context, 'Opening a message to ${_rider.name}…'),
          ),
        ],
      ),
    );
  }

  /// 48x48 tappable, with the action named for screen readers.
  Widget _riderAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: C.primaryTint(context),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: Icon(icon, size: 22, color: C.primary(context))),
          ),
        ),
      ),
    );
  }

  /// "Ibrahim K." → "IK".
  String _initials(String name) {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return '$first$last'.toUpperCase();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DELIVERY DETAILS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildDeliveryDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: C.surface(context),
        border: Border.all(color: C.divider(context)),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: C.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _detailRow(
              Icons.receipt_outlined, 'Order', orderNumberLabel(_orderNumber)),
          const SizedBox(height: AppSpacing.sm),
          // The address captured when the order was placed, not the customer's
          // current saved address: editing an address must not move an order
          // that is already on its way.
          _detailRow(
              Icons.location_on_outlined,
              'Address',
              (widget.order?.deliveryAddress.trim().isNotEmpty ?? false)
                  ? widget.order!.deliveryAddress
                  : 'Not provided'),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: C.textSecondary(context)),
        const SizedBox(width: AppSpacing.sm),
        Text('$label: ',
            style: TextStyle(fontSize: 13, color: C.textSecondary(context))),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: C.textPrimary(context))),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ROUTE GEOMETRY
// ═══════════════════════════════════════════════════════════════════════

/// The one curve the map draws and the rider travels.
///
/// Both the painter and the marker ask this for their geometry, so the line and
/// the scooter cannot disagree about where the road is.
class _RouteGeometry {
  _RouteGeometry({required this.start, required this.end})
      : path = _buildPath(start, end);

  final Offset start;
  final Offset end;
  final Path path;

  /// Pins sit at fixed offsets that keep their labels inside the map box.
  factory _RouteGeometry.forSize(Size size) => _RouteGeometry(
        start: const Offset(58, 54),
        end: Offset(size.width - 62, size.height - 74),
      );

  static Path _buildPath(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    // Horizontal tangents at both ends: the line leaves the vendor heading
    // into the map and arrives at the door from the side, like a road.
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + dx * 0.35,
        start.dy,
        end.dx - dx * 0.35,
        end.dy,
        end.dx,
        end.dy,
      );
  }

  /// Point at [t] (0..1) along the curve.
  Offset pointAt(double t) {
    final metrics = path.computeMetrics().first;
    final tangent = metrics.getTangentForOffset(metrics.length * t.clamp(0.0, 1.0));
    return tangent?.position ?? start;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════

/// Draws a subtle grid pattern to simulate a map.
class _MapBackgroundPainter extends CustomPainter {
  _MapBackgroundPainter({required this.streetColor, required this.roadColor});

  final Color streetColor;
  final Color roadColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = streetColor
      ..strokeWidth = 0.5;

    // Horizontal lines (streets)
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Vertical lines (streets)
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Some thicker "main roads"
    final mainRoadPaint = Paint()
      ..color = roadColor
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, size.height * 0.3),
      Offset(size.width, size.height * 0.3),
      mainRoadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.5, size.height),
      mainRoadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.7),
      mainRoadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.25, 0),
      Offset(size.width * 0.25, size.height),
      mainRoadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, 0),
      Offset(size.width * 0.75, size.height),
      mainRoadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MapBackgroundPainter oldDelegate) =>
      oldDelegate.streetColor != streetColor || oldDelegate.roadColor != roadColor;
}

/// Draws the delivery route from vendor to destination.
class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.route,
    required this.travelled,
    required this.travelledColor,
    required this.remainingColor,
  });

  final _RouteGeometry route;

  /// How much of the route is behind the rider, 0..1.
  final double travelled;
  final Color travelledColor;
  final Color remainingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = route.path.computeMetrics().first;

    // The full road first, so the unwalked part still reads as a route.
    final remainingPaint = Paint()
      ..color = remainingColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(metrics.extractPath(0, metrics.length), remainingPaint);

    if (travelled <= 0) return;

    final travelledPaint = Paint()
      ..color = travelledColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      metrics.extractPath(0, metrics.length * travelled.clamp(0.0, 1.0)),
      travelledPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.travelled != travelled ||
      oldDelegate.route != route ||
      oldDelegate.travelledColor != travelledColor ||
      oldDelegate.remainingColor != remainingColor;
}
