import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Delivery tracking status stages.
enum DeliveryStage {
  orderPlaced,
  riderAssigned,
  pickedUp,
  onTheWay,
  delivered,
}

/// A single stage in the delivery timeline.
class DeliveryStep {
  final DeliveryStage stage;
  final String title;
  final String subtitle;
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
class DeliveryTrackingScreen extends StatefulWidget {
  final String orderNumber;
  final String estimatedDelivery;
  final DeliveryStage initialStage;

    const DeliveryTrackingScreen({
    super.key,
    required this.orderNumber,
    this.estimatedDelivery = 'Today, 2:00 PM – 4:00 PM',
    this.initialStage = DeliveryStage.onTheWay,
  });

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen>
    with TickerProviderStateMixin {
  late DeliveryStage _currentStage;
  late DateTime _countdownTarget;
  Duration _remaining = Duration.zero;
  Timer? _countdownTimer;
  Timer? _stageTimer;

  // Animation controllers
  late AnimationController _riderPulseController;
  late AnimationController _routeAnimController;
  late AnimationController _dotPulseController;

  // Simulated rider position (0.0 = start, 1.0 = destination)
  double _riderProgress = 0.0;

  // Mock rider
  final DeliveryRider _rider =   DeliveryRider(
    name: 'Ibrahim K.',
    phone: '+234 812 345 6789',
    avatarUrl: '',
  );

  @override
  void initState() {
    super.initState();
    _currentStage = widget.initialStage;

    // Set countdown target: random time between 15 and 45 minutes from now
    _countdownTarget = DateTime.now().add(  Duration(minutes: 28));
    _startCountdown();

    // Rider pulse animation (breathing effect on the map dot)
    _riderPulseController = AnimationController(
      vsync: this,
      duration:   Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Route drawing animation
    _routeAnimController = AnimationController(
      vsync: this,
      duration:   Duration(milliseconds: 2000),
    )..forward();

    // Dot pulse
    _dotPulseController = AnimationController(
      vsync: this,
      duration:   Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Simulate rider movement
    _startRiderSimulation();

    // Simulate stage progression
    _startStageSimulation();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(  Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      final diff = _countdownTarget.difference(now);
      setState(() {
        _remaining = diff.isNegative ? Duration.zero : diff;
      });
      if (diff.isNegative) {
        timer.cancel();
        setState(() => _currentStage = DeliveryStage.delivered);
      }
    });
  }

  void _startRiderSimulation() {
    Timer.periodic(  Duration(milliseconds: 100), (timer) {
      if (!mounted || _currentStage == DeliveryStage.delivered) {
        timer.cancel();
        return;
      }
      setState(() {
        // Rider moves slowly toward destination
        if (_riderProgress < 0.85) {
          _riderProgress += 0.002;
          // Add slight randomness for realism
          _riderProgress += (Random().nextDouble() - 0.5) * 0.001;
          _riderProgress = _riderProgress.clamp(0.0, 0.85);
        }
      });
    });
  }

  void _startStageSimulation() {
    // Simulate the rider progressing through stages
    _stageTimer = Timer(  Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _currentStage = DeliveryStage.pickedUp);
      _stageTimer = Timer(  Duration(seconds: 12), () {
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
    _routeAnimController.dispose();
    _dotPulseController.dispose();
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
                physics:   BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hp, 0, hp, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Countdown timer
                    _buildCountdownCard(),
                      SizedBox(height: AppSpacing.xxl),
                    // Animated map
                    _buildAnimatedMap(screenWidth),
                      SizedBox(height: AppSpacing.xxl),
                    // Delivery timeline
                    _buildTimeline(),
                      SizedBox(height: AppSpacing.xxl),
                    // Rider card
                    _buildRiderCard(),
                      SizedBox(height: AppSpacing.xxl),
                    // Delivery details
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
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, 18, hp, 0),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child:   SizedBox(
              width: 40, height: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(Icons.chevron_left, size: 30, color: C.textPrimary(context)),
              ),
            ),
          ),
            Expanded(
            child: Text(
              'Track Delivery',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: C.textPrimary(context)),
            ),
          ),
            SizedBox(width: 40),
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
      padding:   EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: isDelivered ?   Color(0xFFF0FDF4) :   Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: isDelivered ? AppColors.success : AppColors.primaryDark.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isDelivered ? Icons.check_circle : Icons.local_shipping_outlined,
            size: 48,
            color: isDelivered ? AppColors.success : AppColors.primaryDark,
          ),
            SizedBox(height: AppSpacing.md),
          Text(
            isDelivered ? 'Delivered!' : 'Arriving in',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDelivered ? AppColors.success : AppColors.primaryDark,
            ),
          ),
            SizedBox(height: AppSpacing.sm),
          if (!isDelivered)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _countdownDigit(hours.toString().padLeft(2, '0')),
                Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: C.textPrimary(context))),
                _countdownDigit(minutes.toString().padLeft(2, '0')),
                Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: C.textPrimary(context))),
                _countdownDigit(seconds.toString().padLeft(2, '0')),
              ],
            ),
          if (!isDelivered) ...[
              SizedBox(height: AppSpacing.sm),
            Text(
              widget.estimatedDelivery,
              style: TextStyle(fontSize: 13, color: C.textSecondary(context)),
            ),
          ],
          if (isDelivered) ...[
              SizedBox(height: AppSpacing.sm),
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
      margin:   EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: C.divider(context)),
      ),
      child: Center(
        child: Text(
          value,
          style:   TextStyle(
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

    return Container(
      width: double.infinity,
      height: mapHeight,
      decoration: BoxDecoration(
        color:   Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: C.divider(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Stack(
          children: [
            // Map background with "streets"
            CustomPaint(
              size: Size.infinite,
              painter: _MapBackgroundPainter(),
            ),
            // Route line
            AnimatedBuilder(
              animation: _routeAnimController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _RoutePainter(progress: _routeAnimController.value),
                );
              },
            ),
            // Destination pin
            Positioned(
              right: 30,
              bottom: 40,
              child: Column(
                children: [
                  Container(
                    padding:   EdgeInsets.all(4),
                    decoration:   BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child:   Icon(Icons.location_on, size: 16, color: AppColors.white),
                  ),
                    SizedBox(height: 4),
                  Container(
                    padding:   EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: C.surface(context),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow:   [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Text('Your Address', style: TextStyle(fontSize: 8, color: C.textPrimary(context))),
                  ),
                ],
              ),
            ),
            // Vendor/pickup pin
            Positioned(
              left: 30,
              top: 40,
              child: Column(
                children: [
                  Container(
                    padding:   EdgeInsets.all(4),
                    decoration:   BoxDecoration(
                      color: AppColors.primaryDark,
                      shape: BoxShape.circle,
                    ),
                    child:   Icon(Icons.store, size: 16, color: AppColors.white),
                  ),
                    SizedBox(height: 4),
                  Container(
                    padding:   EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: C.surface(context),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow:   [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Text('Green Farm', style: TextStyle(fontSize: 8, color: C.textPrimary(context))),
                  ),
                ],
              ),
            ),
            // Rider dot (animated)
            if (_currentStage != DeliveryStage.delivered)
              AnimatedBuilder(
                animation: Listenable.merge([_routeAnimController, _riderPulseController]),
                builder: (context, _) {
                  // Calculate rider position along the route
                  final t = _riderProgress;
                  final rx = 30.0 + (screenWidth - 90) * t;
                  final ry = 40.0 + (mapHeight - 80) * sin(pi * t) * 0.6;

                  return Positioned(
                    left: rx - 12,
                    top: ry - 12,
                    child: Column(
                      children: [
                        // Pulse ring
                        Container(
                          width: 24 + 8 * _riderPulseController.value,
                          height: 24 + 8 * _riderPulseController.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryDark.withValues(alpha: 0.15),
                          ),
                        ),
                          SizedBox(height: 4),
                        Container(
                          padding:   EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child:   Text('Rider', style: TextStyle(fontSize: 8, color: C.surface(context), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            // Delivered check
            if (_currentStage == DeliveryStage.delivered)
                Positioned(
                right: 24,
                bottom: 36,
                child: Icon(Icons.check_circle, size: 32, color: AppColors.success),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DELIVERY TIMELINE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTimeline() {
    final steps = [
      DeliveryStep(
        stage: DeliveryStage.orderPlaced,
        title: 'Order Placed',
        subtitle: 'Your order has been confirmed',
      ),
      DeliveryStep(
        stage: DeliveryStage.riderAssigned,
        title: 'Rider Assigned',
        subtitle: '${_rider.name} is heading to pick up your order',
      ),
      DeliveryStep(
        stage: DeliveryStage.pickedUp,
        title: 'Picked Up',
        subtitle: 'Order picked up from Green Farm',
      ),
      DeliveryStep(
        stage: DeliveryStage.onTheWay,
        title: 'On the Way',
        subtitle: 'Rider is on the way to your location',
      ),
      DeliveryStep(
        stage: DeliveryStage.delivered,
        title: 'Delivered',
        subtitle: 'Order delivered to your address',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text('Delivery Status',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: C.textPrimary(context))),
          SizedBox(height: AppSpacing.md),
        ...List.generate(steps.length, (index) {
          final step = steps[index];
          final isCompleted = step.stage.index <= _currentStage.index;
          final isCurrent = step.stage == _currentStage;
          final isLast = index == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline indicator
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    // Circle
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted ? AppColors.primaryDark : AppColors.grey300,
                        border: isCurrent
                            ? Border.all(color: AppColors.primaryLight, width: 2)
                            : null,
                      ),
                      child: isCompleted
                          ?   Icon(Icons.check, size: 14, color: AppColors.white)
                          : Text(
                              '${index + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: isCompleted ? AppColors.white : AppColors.grey600,
                              ),
                            ),
                    ),
                    // Line
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 32,
                        color: isCompleted ? AppColors.primaryDark : AppColors.grey300,
                      ),
                  ],
                ),
              ),
                SizedBox(width: AppSpacing.md),
              // Content
              Expanded(
                child: Padding(
                  padding:   EdgeInsets.only(top: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w500,
                          color: isCompleted ? AppColors.black : AppColors.grey600,
                        ),
                      ),
                        SizedBox(height: 2),
                      Text(
                        step.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isCompleted ? AppColors.grey700 : AppColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RIDER CARD
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildRiderCard() {
    return Container(
      width: double.infinity,
      padding:   EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: C.surface(context),
        border: Border.all(color: C.divider(context)),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryDark, width: 2),
            ),
            child:   Icon(Icons.person, size: 28, color: AppColors.primaryDark),
          ),
            SizedBox(width: AppSpacing.md),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Rider', style: TextStyle(fontSize: 12, color: C.textSecondary(context))),
                  SizedBox(height: 2),
                Text(_rider.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
                  SizedBox(height: 2),
                Text(_rider.phone,
                  style: TextStyle(fontSize: 13, color: C.textSecondary(context))),
              ],
            ),
          ),
          // Call button
          Container(
            width: 44,
            height: 44,
            decoration:   BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child:   Icon(Icons.phone, size: 22, color: AppColors.primaryDark),
          ),
            SizedBox(width: AppSpacing.sm),
          // Message button
          Container(
            width: 44,
            height: 44,
            decoration:   BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child:   Icon(Icons.message, size: 22, color: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DELIVERY DETAILS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildDeliveryDetails() {
    return Container(
      width: double.infinity,
      padding:   EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: C.surface(context),
        border: Border.all(color: C.divider(context)),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text('Delivery Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: C.textPrimary(context))),
            SizedBox(height: AppSpacing.md),
          _detailRow(Icons.receipt_outlined, 'Order', '#${widget.orderNumber}'),
            SizedBox(height: AppSpacing.sm),
          _detailRow(Icons.location_on_outlined, 'Address', 'No. 12 Gwarinpa Estate, Abuja'),
            SizedBox(height: AppSpacing.sm),
          _detailRow(Icons.access_time, 'Est. Delivery', widget.estimatedDelivery),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: C.textSecondary(context)),
          SizedBox(width: AppSpacing.sm),
        Text('$label: ', style: TextStyle(fontSize: 13, color: C.textSecondary(context))),
        Expanded(child: Text(value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textPrimary(context)))),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ═══════════════════════════════════════════════════════════════════════

/// Draws a subtle grid pattern to simulate a map.
class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =   Color(0xFFC8E6C9)
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
      ..color =   Color(0xFFA5D6A7)
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Draws the delivery route from vendor to destination.
class _RoutePainter extends CustomPainter {
  final double progress;

  _RoutePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(42, 52);
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.15,
      size.width * 0.5,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.85,
      size.width - 42,
      size.height - 52,
    );

    // Dashed route behind
    final bgPaint = Paint()
      ..color = AppColors.primaryDark.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawPath(path, bgPaint);

    // Active route (animated)
    final activePaint = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final metrics = path.computeMetrics().first;
    final extractedPath = metrics.extractPath(0, metrics.length * progress);
    canvas.drawPath(extractedPath, activePaint);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
