import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/orders.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/bottom_nav.dart';
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
      AppRoutes.pushReplaceAll(context, AppRoutes.home);

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
                        _buildOrderNumberCard(context),
                        const SizedBox(height: AppSpacing.md),
                        _buildDeliveryCard(context),
                        const SizedBox(height: AppSpacing.md),
                        _buildSummaryCard(context),
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
    final named = vendor.isNotEmpty && vendor != 'GROWBOX';
    return named
        ? '$vendor has your order and will start packing it shortly.'
        : "Thank you for your order. We've received it and will begin processing it shortly.";
  }

  Widget _buildBadge(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width < 360 ? 84.0 : 96.0;

    return ScaleTransition(
      key: const ValueKey('successBadge'),
      scale: _scale,
      child: Container(
        width: size,
        height: size,
        // The app's existing success token rather than the primary green, so
        // the badge reads as an outcome and not as the brand's action colour.
        decoration: BoxDecoration(
          color: C.success(context),
          shape: BoxShape.circle,
        ),
        // There is no onSuccess token; onPrimary is the app's "ink on a strong
        // fill" colour and clears 3:1 on this green in both themes.
        child: Icon(
          Icons.check_rounded,
          size: size * 0.52,
          color: C.onPrimary(context),
        ),
      ),
    );
  }

  Widget _buildOrderNumberCard(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Copy order number',
      child: GestureDetector(
        onTap: _copyOrderNumber,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: C.surface(context),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: C.divider(context)),
          ),
          // Flexible on both texts, so a long number or a large text scale
          // shrinks the label instead of overflowing the row.
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Order number',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: C.textMuted(context),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Text(
                  orderNumberLabel(widget.order.id),
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: C.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.copy_rounded,
                size: 16,
                color: C.textMuted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: C.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, 'Delivering to'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _shortAddress(widget.order.deliveryAddress),
            style: AppTypography.bodyMedium.copyWith(
              height: 1.4,
              color: C.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _label(context, 'Estimated delivery'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatArrival(widget.order.eta),
            style: AppTypography.bodySmall.copyWith(
              color: C.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final order = widget.order;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: C.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, 'Order summary'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            order.vendorName,
            style: AppTypography.labelMedium.copyWith(
              color: C.textPrimary(context),
            ),
          ),
          Text(
            '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
            style: AppTypography.bodySmall.copyWith(
              color: C.textMuted(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _moneyRow(context, 'Subtotal', '₦${formatPrice(order.subtotal)}'),
          const SizedBox(height: AppSpacing.sm),
          _moneyRow(
            context,
            'Delivery',
            order.deliveryFee == 0
                ? 'Free'
                : '₦${formatPrice(order.deliveryFee)}',
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: C.divider(context)),
          const SizedBox(height: AppSpacing.md),
          // Bold total: the one number the payer needs to recognise.
          Row(
            children: [
              Text(
                'Total',
                style: AppTypography.labelLarge.copyWith(
                  color: C.textPrimary(context),
                ),
              ),
              const Spacer(),
              Text(
                '₦${formatPrice(order.total)}',
                style: AppTypography.labelLarge.copyWith(
                  color: C.textPrimary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(color: C.textMuted(context)),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: C.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text,
      style: AppTypography.labelSmall.copyWith(color: C.textMuted(context)),
    );
  }

  /// Drops a trailing country from a stored address ("…, Abuja, Nigeria").
  static String _shortAddress(String address) {
    final trimmed = address.replaceFirst(RegExp(r',\s*Nigeria\s*$'), '');
    return trimmed.isEmpty ? address : trimmed;
  }

  Widget _buildBar(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _trackDelivery,
            icon: const Icon(Icons.local_shipping_outlined, size: 20),
            label: Text(
              'Track delivery',
              style: AppTypography.labelLarge.copyWith(
                color: C.onPrimary(context),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.primary(context),
              foregroundColor: C.onPrimary(context),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _continueShopping,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: C.divider(context)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
            child: Text(
              'Continue shopping',
              style: AppTypography.labelMedium.copyWith(
                color: C.primary(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
