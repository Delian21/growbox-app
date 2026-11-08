import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/orders.dart';
import '../tabs.dart';
import '../theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/order_outcome.dart';
import '../widgets/pinned_bottom_bar.dart';
import 'delivery_tracking_screen.dart';

/// Confirmation shown once an order has been placed.
///
/// Every line here reads from [order], so the confirmation cannot drift from
/// what was actually recorded: the previous version had its own copies of the
/// total, the ETA and even the order number, and each had gone stale.
class OrderSuccessScreen extends StatefulWidget {
  final Order order;

  const OrderSuccessScreen({super.key, required this.order});

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // easeOutBack overshoots slightly, so the badge lands with a little weight.
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      // Respect the platform's "reduce motion" setting: the badge simply starts
      // at full size instead.
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _copyOrderNumber() async {
    await Clipboard.setData(
      ClipboardData(text: orderNumberLabel(widget.order.id)),
    );
    if (!mounted) return;
    showAppSnackBar(context, 'Order number copied');
  }

  void _trackDelivery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryTrackingScreen(order: widget.order),
      ),
    );
  }

  void _continueShopping() =>
      openTab(context, AppTab.home);

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hp = AppSizing.horizontalPadding(context);

    return PopScope(
      // Placing an order replaces the whole stack, so system back would leave
      // the app (or land nowhere). Home is the only sensible destination.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _continueShopping();
      },
      child: Scaffold(
        backgroundColor: C.background(context),
        body: SafeArea(
          child: BottomNavScope(
            // This route has no floating nav above it, so the pinned bar must
            // not reserve space for one.
            isVisible: false,
            child: ScreenWithPinnedBar(
              // Pushed after checkout: there is no bottom nav to clear.
              respectNav: false,
              body: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  hp,
                  AppSpacing.xxxl,
                  hp,
                  AppSpacing.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        _buildBadge(context),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Order placed!',
                          textAlign: TextAlign.center,
                          style: AppTypography.headingSmall.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: C.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          _bodyCopy,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            height: 1.5,
                            color: C.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        // The cards, the badge and the bar are shared with the
                        // pending and failed outcomes; see order_outcome.dart.
                        OrderNumberCard(
                          orderNumber: widget.order.id,
                          onTap: _copyOrderNumber,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OrderAddressCard(
                          address: widget.order.deliveryAddress,
                          eta: widget.order.eta,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OrderSummaryCard(order: widget.order),
                      ],
                    ),
                  ),
                ),
              ),
              bar: _buildBar(context),
            ),
          ),
        ),
      ),
    );
  }

  /// "{vendor} has your order…", or the neutral copy when the order has no
  /// vendor to name (an empty box, or a record whose lines carried no vendor).
  String get _bodyCopy {
    final vendor = widget.order.vendorName.trim();
    final named = vendor.isNotEmpty && vendor != 'Growbox';
    return named
        ? '$vendor has your order and will start packing it shortly.'
        : "Thank you for your order. We've received it and will begin processing it shortly.";
  }

  Widget _buildBadge(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width < 360 ? 84.0 : 96.0;

    return ScaleTransition(
      key: const ValueKey('successBadge'),
      scale: _scale,
      // The app's existing success token rather than the primary green, so the
      // badge reads as an outcome and not as the brand's action colour. There
      // is no onSuccess token; onPrimary is the app's "ink on a strong fill"
      // colour and clears 3:1 on this green in both themes.
      child: OutcomeBadge(
        icon: Icons.check_rounded,
        fill: C.success(context),
        iconColor: C.onPrimary(context),
        size: size,
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    return OrderActionBar(
      primaryLabel: 'Track delivery',
      onPrimary: _trackDelivery,
      primaryIcon: Icons.local_shipping_outlined,
      secondaryLabel: 'Continue shopping',
      onSecondary: _continueShopping,
    );
  }
}
