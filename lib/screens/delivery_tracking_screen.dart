import 'dart:async';

import 'package:flutter/material.dart';

import '../data/orders.dart';
import '../theme.dart';
import '../widgets/app_snack_bar.dart';

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

/// A single stage in the delivery timeline.
class DeliveryStep {
  final DeliveryStage stage;
  final String title;
  final String subtitle;

  /// When the step was reached. Null for steps that have not happened, and the
  /// UI then simply omits the time line.
  final DateTime? completedAt;

  DeliveryStep({
    required this.stage,
    required this.title,
    required this.subtitle,
    this.completedAt,
  });
}

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

  const DeliveryTrackingScreen({
    super.key,
    this.order,
    this.orderNumber,
    this.initialStage,
  }) : assert(
          order != null || orderNumber != null,
          'DeliveryTrackingScreen needs an order or an order number',
        );

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen>
    with SingleTickerProviderStateMixin {
  /// Demo timeline: minutes after placement at which each stage is reached.
  /// Only used when no [Order] was supplied; a real order overrides it with its
  /// own timestamps. A step with no time simply renders without one.
  static const Map<DeliveryStage, int> _stepMinutes = {
    DeliveryStage.orderPlaced: 0,
    DeliveryStage.riderAssigned: 4,
    DeliveryStage.pickedUp: 9,
    DeliveryStage.onTheWay: 14,
    DeliveryStage.delivered: 45,
  };

  late DeliveryStage _currentStage;
  late DateTime _countdownTarget;
  late DateTime _placedAt;
  late String _orderNumber;
  Duration _remaining = Duration.zero;

  /// The arrival promise, written the one way the app writes arrivals.
  String get _etaLabel => formatArrival(_countdownTarget);
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
    _countdownTarget =
        order?.eta ?? DateTime.now().add(const Duration(minutes: 28));
    _startCountdown();

    _riderPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Only the demo invents progress; a real order only moves when the order
    // itself does.
    if (_isDemo) _startStageSimulation();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      final diff = _countdownTarget.difference(now);
      setState(() {
        _remaining = diff.isNegative ? Duration.zero : diff;
      });
      if (diff.isNegative) {
        timer.cancel();
        // Never overwrite a real order's status with a clock running out.
        if (_isDemo) {
          setState(() => _currentStage = DeliveryStage.delivered);
        }
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
            _buildHeader(hp),
            // ── Scrollable content ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hp, AppSpacing.xl, hp, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCountdownCard(),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildAnimatedMap(screenWidth),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildTimeline(),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildRiderCard(),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildDeliveryDetails(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHeader(double hp) {
    return Container(
      // Solid page colour plus a hairline: scrolled cards slide under the
      // header instead of showing through it.
      decoration: BoxDecoration(
        color: C.background(context),
        border: Border(bottom: BorderSide(color: C.divider(context))),
      ),
      // The 48 px back box starts one glyph-width left of the content gutter,
      // so its chevron lines up with the cards below.
      padding: EdgeInsets.fromLTRB(hp - 12, AppSpacing.sm, hp - 12, AppSpacing.sm),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(
                    Icons.chevron_left,
                    size: 28,
                    color: C.textPrimary(context),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Track Delivery',
              textAlign: TextAlign.center,
              // Standard app bar title: page titles elsewhere are 20 px bold;
              // this sits a touch larger and lighter at w600.
              style: AppTypography.title.copyWith(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: C.textPrimary(context),
              ),
            ),
          ),
          // Balances the back button so the title stays optically centred.
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COUNTDOWN CARD
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildCountdownCard() {
    final isDelivered = _currentStage == DeliveryStage.delivered;
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

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
            isDelivered ? Icons.check_circle : Icons.local_shipping_outlined,
            size: 48,
            color: isDelivered ? C.success(context) : C.primary(context),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isDelivered ? 'Delivered!' : 'Arriving in',
            // Primary green clears 4.5:1 on the soft panel in both themes.
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: C.primary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!isDelivered)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _countdownDigit(hours.toString().padLeft(2, '0')),
                Text(':',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: C.textPrimary(context))),
                _countdownDigit(minutes.toString().padLeft(2, '0')),
                Text(':',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: C.textPrimary(context))),
                _countdownDigit(seconds.toString().padLeft(2, '0')),
              ],
            ),
          if (!isDelivered) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _etaLabel,
              style: TextStyle(fontSize: 13, color: C.textSecondary(context)),
            ),
          ],
          if (isDelivered) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your order has been delivered successfully',
              style: TextStyle(fontSize: 13, color: C.textSecondary(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _countdownDigit(String value) {
    return Container(
      width: 52,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: C.divider(context)),
      ),
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: C.textPrimary(context),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ANIMATED MAP
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAnimatedMap(double screenWidth) {
    final mapHeight = (screenWidth * 0.55).clamp(200.0, 300.0);
    final isDelivered = _currentStage == DeliveryStage.delivered;

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
                      end: _currentStage.routeProgress,
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
    final current = _currentStage;

    /// A step is done when it sits before the current one — or when it *is* the
    /// final step and the order has arrived. The current step is in progress,
    /// not done.
    bool isReached(DeliveryStage stage) =>
        stage.index < current.index ||
        (stage == DeliveryStage.delivered &&
            current == DeliveryStage.delivered);

    /// When [stage] happened: the order's own event time when there is an
    /// order, otherwise the demo clock. Pending steps carry no time either way,
    /// and a step whose event the order never recorded stays blank.
    DateTime? timeFor(DeliveryStage stage) {
      if (!isReached(stage)) return null;
      final order = widget.order;
      if (order == null) {
        return _placedAt.add(Duration(minutes: _stepMinutes[stage] ?? 0));
      }
      return order.timestampOf(statusForDeliveryStage(stage));
    }

    DeliveryStep step(
      DeliveryStage stage,
      String title,
      String subtitle,
    ) =>
        DeliveryStep(
          stage: stage,
          title: title,
          subtitle: subtitle,
          completedAt: timeFor(stage),
        );

    final steps = [
      step(DeliveryStage.orderPlaced, 'Order Placed',
          'Your order has been confirmed'),
      step(DeliveryStage.riderAssigned, 'Rider Assigned',
          '${_rider.name} is heading to pick up your order'),
      step(DeliveryStage.pickedUp, 'Picked Up',
          'Order picked up from Green Farm'),
      step(DeliveryStage.onTheWay, 'On the Way',
          'Rider is on the way to your location'),
      step(DeliveryStage.delivered, 'Delivered',
          'Order delivered to your address'),
    ];

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
        ...List.generate(steps.length, (index) {
          final step = steps[index];
          final reached = isReached(step.stage);
          final isCurrent = !reached && step.stage == current;
          final isLast = index == steps.length - 1;
          // The segment below a dot belongs to the step it leads to.
          final leadsToReached = !isLast && isReached(steps[index + 1].stage);

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Timeline rail: dot, then the connector that fills the row.
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      _timelineDot(
                        number: index + 1,
                        reached: reached,
                        isCurrent: isCurrent,
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: leadsToReached
                                ? C.primary(context)
                                : C.textMuted(context).withValues(alpha: 0.4),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: isCurrent ? 1 : 2,
                      bottom: isLast ? 0 : AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : reached
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                            // Pending steps stay readable (~4.7:1 on light,
                            // ~6.4:1 on dark) instead of near-invisible grey.
                            color: reached
                                ? C.textPrimary(context)
                                : C.textMuted(context),
                          ),
                        ),
                        if (reached && step.completedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              formatOrderTime(step.completedAt!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: C.textMuted(context),
                              ),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          step.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: reached
                                ? C.textSecondary(context)
                                : C.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _timelineDot({
    required int number,
    required bool reached,
    required bool isCurrent,
  }) {
    if (reached) {
      return Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: C.primary(context),
          ),
          child: Center(
            child: Icon(Icons.check, size: 15, color: C.onPrimary(context)),
          ),
        ),
      );
    }

    if (isCurrent) {
      // The step in progress carries a vehicle, not a check: it is happening,
      // not done. It is also slightly larger than the dots around it.
      return Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: C.primary(context),
          ),
          child: Center(
            child: Icon(
              Icons.two_wheeler,
              size: 18,
              color: C.onPrimary(context),
            ),
          ),
        ),
      );
    }

    // Pending: outlined circle with the step number centred in both axes.
    return Center(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: C.textMuted(context), width: 1.5),
        ),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: C.textMuted(context),
            ),
          ),
        ),
      ),
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
          _detailRow(Icons.location_on_outlined, 'Address',
              'No. 12 Gwarinpa Estate, Abuja'),
          const SizedBox(height: AppSpacing.sm),
          _detailRow(Icons.access_time, 'Est. Delivery', _etaLabel),
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
