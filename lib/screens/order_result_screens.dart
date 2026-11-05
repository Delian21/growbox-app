import 'package:flutter/material.dart';

import '../data/orders.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/order_outcome.dart';
import '../widgets/pinned_bottom_bar.dart';
import 'order_details_screen.dart';

/// Shown while an order is still being confirmed.
///
/// Nothing in the app navigates here today: checkout records the order itself
/// and goes straight to the confirmation, so this is the screen an
/// acknowledgement-first backend would use. It is rebuilt on the same layout as
/// the other outcomes, so wiring it up later is a one-line change rather than a
/// redesign.
class OrderPendingScreen extends StatelessWidget {
  /// The attempt being confirmed. Every line on the screen is read from it.
  final Order order;

  const OrderPendingScreen({super.key, required this.order});

  void _viewOrder(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
    );
  }

  void _continueShopping(BuildContext context) =>
      AppRoutes.pushReplaceAll(context, AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    final vendor = order.vendorName.trim();

    return _OutcomeLayout(
      // A clock on the brand tint: the order is waiting, not wrong.
      icon: Icons.schedule_rounded,
      badgeFill: C.primaryTint(context),
      badgeIconColor: C.primary(context),
      title: 'Confirming your order',
      body: vendor.isEmpty
          ? "We're confirming your order. This only takes a moment."
          : "We're confirming your order with $vendor.",
      order: order,
      bar: OrderActionBar(
        primaryLabel: 'View order',
        onPrimary: () => _viewOrder(context),
        secondaryLabel: 'Continue shopping',
        onSecondary: () => _continueShopping(context),
      ),
    );
  }
}

/// Shown when checkout could not record the order.
///
/// Contract with checkout: it pushes this screen and awaits it, so "Try again"
/// only has to pop — the checkout underneath still holds the cart, the address,
/// the note and the payment choice, and reuses its order id for the retry.
class OrderFailedScreen extends StatelessWidget {
  /// The attempt, priced and labelled exactly as the order would have been.
  final Order order;

  const OrderFailedScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return _OutcomeLayout(
      icon: Icons.error_outline_rounded,
      badgeFill: C.errorSoft(context),
      badgeIconColor: C.errorBright(context),
      title: "We couldn't place your order",
      // Nothing about payment: the only method is pay on delivery, so nobody
      // was charged and nothing needs unwinding.
      body: 'Something went wrong on our side. '
          'Your box is safe, so you can try again.',
      order: order,
      bar: OrderActionBar(
        // Pops back to the checkout that pushed this screen, state intact.
        primaryLabel: 'Try again',
        onPrimary: () => Navigator.pop(context),
        // The box is still in the cart, so "back to box" goes there rather than
        // duplicating the retry.
        secondaryLabel: 'Back to box',
        onSecondary: () => AppRoutes.pushReplaceAll(context, AppRoutes.cart),
      ),
    );
  }
}

/// The shared skeleton of an outcome screen: badge, headline, one line of
/// context, then the order's own facts and a pinned bar.
///
/// Identical to the confirmation's layout on purpose — an outcome screen is the
/// same page with a different badge, and keeping them the same means the user
/// only has to read one layout.
class _OutcomeLayout extends StatelessWidget {
  final IconData icon;
  final Color badgeFill;
  final Color badgeIconColor;
  final String title;
  final String body;
  final Order order;
  final Widget bar;

  const _OutcomeLayout({
    required this.icon,
    required this.badgeFill,
    required this.badgeIconColor,
    required this.title,
    required this.body,
    required this.order,
    required this.bar,
  });

  @override
  Widget build(BuildContext context) {
    final hp = AppSizing.horizontalPadding(context);
    final badgeSize = MediaQuery.sizeOf(context).width < 360 ? 84.0 : 96.0;

    return Scaffold(
      backgroundColor: C.background(context),
      body: SafeArea(
        child: BottomNavScope(
          // These routes sit above the tab bar and own the whole screen.
          isVisible: false,
          child: ScreenWithPinnedBar(
            // Pushed after checkout: there is no nav to clear.
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
                      OutcomeBadge(
                        icon: icon,
                        fill: badgeFill,
                        iconColor: badgeIconColor,
                        size: badgeSize,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTypography.headingSmall.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: C.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          height: 1.5,
                          color: C.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      // Copying is only offered once there is a recorded order
                      // to copy; a failed attempt's id is not a receipt.
                      OrderNumberCard(orderNumber: order.id),
                      const SizedBox(height: AppSpacing.md),
                      // No ETA: neither outcome has a promised arrival yet.
                      OrderAddressCard(address: order.deliveryAddress),
                      const SizedBox(height: AppSpacing.md),
                      // Payment is left out: it is only meaningful for an order
                      // that exists and will be paid for on arrival.
                      OrderSummaryCard(order: order, showPayment: false),
                    ],
                  ),
                ),
              ),
            ),
            bar: bar,
          ),
        ),
      ),
    );
  }
}
