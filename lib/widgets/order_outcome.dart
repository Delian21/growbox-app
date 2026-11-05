import 'package:flutter/material.dart';

import '../data/orders.dart';
import '../theme.dart';
import 'app_button.dart';

/// The pieces every order outcome screen is built from.
///
/// Order placed, Order pending and Order failed used to carry a copy of the
/// same layout each, which is how one of them ended up quoting a delivery
/// window and a total that no order had ever had. Sharing the chrome means a
/// screen can only show what it is handed: the number, the address the customer
/// chose and the totals priced from the items.

/// The circle at the top of an outcome screen.
class OutcomeBadge extends StatelessWidget {
  const OutcomeBadge({
    super.key,
    required this.icon,
    required this.fill,
    required this.iconColor,
    this.size = 96,
  });

  final IconData icon;
  final Color fill;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.52, color: iconColor),
    );
  }
}

/// A card shell: surface fill, hairline outline, the app's medium radius.
class OutcomeCard extends StatelessWidget {
  const OutcomeCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: C.divider(context)),
      ),
      child: child,
    );
  }
}

/// The order number, formatted the one way the app writes it.
///
/// Tappable only when [onTap] is supplied, so the copy affordance (and its
/// screen-reader label) never appears on a screen that cannot copy.
class OrderNumberCard extends StatelessWidget {
  const OrderNumberCard({super.key, required this.orderNumber, this.onTap});

  /// The stored id, with or without a leading `#`.
  final String orderNumber;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: onTap == null ? null : 'Copy order number',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: OutcomeCard(
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
                  orderNumberLabel(orderNumber),
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: C.textPrimary(context),
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: C.textMuted(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the box is going, and — only when there is one — when it should
/// arrive.
///
/// A failed attempt has no estimate, so it passes no [eta] and the card simply
/// omits the second line instead of inventing a delivery window.
class OrderAddressCard extends StatelessWidget {
  const OrderAddressCard({super.key, required this.address, this.eta});

  final String address;
  final DateTime? eta;

  @override
  Widget build(BuildContext context) {
    return OutcomeCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, 'Delivering to'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            shortDeliveryAddress(address),
            style: AppTypography.bodyMedium.copyWith(
              height: 1.4,
              color: C.textPrimary(context),
            ),
          ),
          if (eta != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _label(context, 'Estimated delivery'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatArrival(eta!),
              style: AppTypography.bodySmall.copyWith(
                color: C.textPrimary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: AppTypography.labelSmall.copyWith(color: C.textMuted(context)),
      );
}

/// What is in the box and what it costs, priced by [Order.totals].
///
/// [showPayment] is false on the pending and failed screens: payment is only
/// worth stating once an order exists to pay for.
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.order,
    this.showPayment = true,
  });

  final Order order;
  final bool showPayment;

  @override
  Widget build(BuildContext context) {
    return OutcomeCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order summary',
            style: AppTypography.labelSmall.copyWith(
              color: C.textMuted(context),
            ),
          ),
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
            order.totals.deliveryFee == 0
                ? 'Free'
                : '₦${formatPrice(order.totals.deliveryFee)}',
          ),
          if (showPayment) ...[
            const SizedBox(height: AppSpacing.sm),
            _moneyRow(context, 'Payment', order.paymentMethod.label),
          ],
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: C.divider(context)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                'Total',
                style: AppTypography.labelLarge.copyWith(
                  color: C.textPrimary(context),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  '₦${formatPrice(order.total)}',
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    color: C.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A label/value line that shrinks instead of overflowing: both sides are
  /// flexible, so a long method name on a narrow phone ellipsises like the
  /// order-number card does.
  Widget _moneyRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
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
            value,
            maxLines: 1,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: C.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// One primary and one secondary action, stacked in the pinned bar.
///
/// The primary is always the way forward for the outcome (track, view, retry);
/// the secondary is always leaving it (shop, box).
class OrderActionBar extends StatelessWidget {
  const OrderActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.primaryIcon,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final IconData? primaryIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: AppButton(
            label: primaryLabel,
            onPressed: onPrimary,
            icon: primaryIcon,
            expand: true,
            height: 52,
            radius: AppRadii.pill,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: AppButton(
            label: secondaryLabel,
            onPressed: onSecondary,
            variant: AppButtonVariant.secondary,
            expand: true,
            height: 52,
            radius: AppRadii.pill,
          ),
        ),
      ],
    );
  }
}

/// Drops a trailing country from a stored address ("…, Abuja, Nigeria").
///
/// Stored addresses carry the country because the address form does; a
/// confirmation card does not need to repeat it.
String shortDeliveryAddress(String address) {
  final trimmed = address.replaceFirst(RegExp(r',\s*Nigeria\s*$'), '').trim();
  return trimmed.isEmpty ? address : trimmed;
}
