import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../data/addresses.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../data/orders.dart';
import '../widgets/saved_address_picker.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/pinned_bottom_bar.dart';
import 'order_success_screen.dart';
import 'address_management_screen.dart';
import 'faq_screen.dart';
import 'privacy_screen.dart';

/// One line in the box: a product and how many of it are in the cart.
///
/// The cart stores one entry per unit, so the checkout groups them for display
/// instead of repeating "Rice" three times.
class _BoxLine {
  final VendorProduct product;
  final int quantity;

  const _BoxLine(this.product, this.quantity);

  int get total => product.price * quantity;
}

class CheckoutScreen extends StatefulWidget {
  final List<VendorProduct> products;

  /// Test seam; defaults to the app-wide store.
  final AddressesStore? addressStore;

  const CheckoutScreen({
    super.key,
    required this.products,
    this.addressStore,
  });
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _showItems = false;

  /// Tap targets inside the terms sentence. Created once and disposed with the
  /// screen, because a TextSpan recognizer is not managed by the framework.
  late final TapGestureRecognizer _termsLink;
  late final TapGestureRecognizer _privacyLink;

  AddressesStore get _addresses => widget.addressStore ?? addressesStore;

  @override
  void initState() {
    super.initState();
    _addresses.load();
    _termsLink = TapGestureRecognizer()..onTap = _openTerms;
    _privacyLink = TapGestureRecognizer()..onTap = _openPrivacy;
  }

  @override
  void dispose() {
    _termsLink.dispose();
    _privacyLink.dispose();
    super.dispose();
  }

  void _openTerms() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FAQScreen()),
      );

  void _openPrivacy() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManagePrivacyScreen()),
      );

  @override
  Widget build(BuildContext context) {
    // The delivery address can change from the sheet on this very screen, so
    // the card and the CTA's enabled state follow the store.
    return ListenableBuilder(
      listenable: _addresses,
      builder: (context, _) => _buildCheckout(context),
    );
  }

  Widget _buildCheckout(BuildContext context) {
    final List<VendorProduct> products = widget.products;
    // Same calculation as the cart bar: goods + one delivery charge per vendor.
    final totals = CartTotals.forItems(products);
    final int deliveryFee = totals.deliveryFee;
    final int subtotal = totals.subtotal;
    final int total = totals.total;
    final lines = _groupedLines(products);

    // The address checkout will snapshot onto the order. Without a street the
    // rider cannot find the door, so ordering stays disabled.
    final deliveryAddress = _addresses.selectedAddress;
    final canPlaceOrder =
        deliveryAddress != null && deliveryAddress.isComplete;

    final double hp = AppSizing.horizontalPadding(context);

    return Scaffold(
      backgroundColor: C.background(context),
      // SafeArea wraps both the scroll area and the bar, so the bar clears the
      // gesture inset without double padding.
      body: SafeArea(
        child: ScreenWithPinnedBar(
          // No bottom navigation on checkout: the bar sits on the screen's own
          // safe area instead of floating above a nav pill.
          respectNav: false,
          bar: _buildBottomBar(context, total, canPlaceOrder),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(hp),
                _buildBoxSection(hp, lines, products.length),
                _buildAddressSection(hp),
                _buildDeliverySection(hp),
                _buildOrderSummary(hp, subtotal, deliveryFee, total),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SECTION BUILDERS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeader(double hp) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.md, hp, 0),
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
                child: Icon(Icons.arrow_back,
                    size: 24, color: C.textPrimary(context)),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Checkout',
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: C.textPrimary(context),
              ),
            ),
          ),
          // Balances the back button so the title is optically centred.
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// Section heading: plain 17px semibold text — no icon tile.
  Widget _sectionTitle(String title) => Text(
        title,
        style: AppTypography.title.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: C.textPrimary(context),
        ),
      );

  /// The one card every section uses: surface fill, 12px radius, 16px padding,
  /// 1px divider border, no shadow.
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: C.divider(context), width: 1),
      ),
      child: child,
    );
  }

  /// Section shell: heading, a consistent gap, then its card.
  Widget _section(double hp, Widget heading, Widget card) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hp, AppSpacing.xxl, hp, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: AppSpacing.md),
          card,
        ],
      ),
    );
  }

  /// Cart entries grouped into one line per product, in first-seen order.
  List<_BoxLine> _groupedLines(List<VendorProduct> products) {
    final order = <String>[];
    final quantities = <String, int>{};
    final productsByKey = <String, VendorProduct>{};
    for (final product in products) {
      final key = '${product.vendorName}\u0000${product.name}';
      if (!quantities.containsKey(key)) {
        order.add(key);
        productsByKey[key] = product;
      }
      quantities[key] = (quantities[key] ?? 0) + 1;
    }
    return [
      for (final key in order) _BoxLine(productsByKey[key]!, quantities[key]!),
    ];
  }

  Widget _thumbnail(String image, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SkeletonImage(
        imageUrl: image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        scrim: kProductImageScrim,
        errorWidget: Container(
          width: size,
          height: size,
          color: C.surfaceLight(context),
          child: Icon(Icons.image_outlined,
              size: size * 0.5, color: C.textMuted(context)),
        ),
      ),
    );
  }

  Widget _buildBoxSection(double hp, List<_BoxLine> lines, int itemCount) {
    // Defensive: checkout is only reachable with items, but never index into an
    // empty box.
    if (lines.isEmpty) {
      return _section(
        hp,
        _sectionTitle('Your Box'),
        _card(
          child: Text(
            'Your box is empty',
            style: AppTypography.bodyMedium
                .copyWith(color: C.textSecondary(context)),
          ),
        ),
      );
    }

    final first = lines.first;
    // "Rice × 2 · Green Farm": what is in the box, without opening it.
    final summary =
        '${first.product.name} × ${first.quantity} · ${first.product.vendorName}';

    return _section(
      hp,
      _sectionTitle('Your Box'),
      _card(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showItems = !_showItems),
          child: Column(
            children: [
              Row(
                children: [
                  _thumbnail(first.product.image, 40),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium
                          .copyWith(color: C.textPrimary(context)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'}',
                    style: AppTypography.bodySmall
                        .copyWith(color: C.textSecondary(context)),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    _showItems
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: C.textSecondary(context),
                  ),
                ],
              ),
              if (_showItems) ...[
                const SizedBox(height: AppSpacing.md),
                Container(height: 1, color: C.divider(context)),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Row(
                      children: [
                        _thumbnail(line.product.image, 32),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            '${line.product.name} × ${line.quantity}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium
                                .copyWith(color: C.textPrimary(context)),
                          ),
                        ),
                        Text(
                          '₦${formatPrice(line.total)}',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: C.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressSection(double hp) {
    return _section(
      hp,
      Row(
        children: [
          Expanded(child: _sectionTitle('Delivery Address')),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showAddressBottomSheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Text(
                'Change',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: C.primary(context),
                ),
              ),
            ),
          ),
        ],
      ),
      _buildAddressCard(context),
    );
  }

  /// The selected delivery address, or an explicit "choose one" card.
  Widget _buildAddressCard(BuildContext context) {
    final addr = _addresses.selectedAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _showAddressBottomSheet(context),
          child: _card(
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    color: C.primary(context), size: 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addr == null ? 'Choose location' : addr.label,
                        style: AppTypography.labelMedium
                            .copyWith(color: C.textPrimary(context)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        addr == null
                            ? 'Add a delivery address to check out'
                            : addr.fullAddress,
                        style: AppTypography.bodySmall.copyWith(
                          height: 1.4,
                          color: C.textSecondary(context),
                        ),
                      ),
                      if (addr?.landmark?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Near ${addr!.landmark!.trim()}',
                          style: AppTypography.caption
                              .copyWith(color: C.textMuted(context)),
                        ),
                      ],
                      if (addr?.phone?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 2),
                        Text(
                          addr!.phone!.trim(),
                          style: AppTypography.caption
                              .copyWith(color: C.textMuted(context)),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: C.textMuted(context)),
              ],
            ),
          ),
        ),
        // An address with only an area cannot be delivered to: say why the
        // order button is disabled and offer the one-tap fix.
        if (addr != null && !addr.isComplete) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildStreetWarning(context, addr),
        ],
      ],
    );
  }

  Widget _buildStreetWarning(BuildContext context, Address addr) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18, color: C.accentOrange(context)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add your street address so the rider can find you',
                  style: AppTypography.bodySmall.copyWith(
                    height: 1.4,
                    color: C.textPrimary(context),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddressManagementScreen(editAddressId: addr.id),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Add details',
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: C.primary(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection(double hp) {
    // Only one delivery option exists, so it is an information row rather than
    // a choice — and the fee is stated once, in Order Summary.
    return _section(
      hp,
      _sectionTitle('Delivery'),
      _card(
        child: Row(
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 22, color: C.textPrimary(context)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Standard delivery',
                    style: AppTypography.labelMedium
                        .copyWith(color: C.textPrimary(context)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // The app's standard promise, worded the same way the
                    // confirmation and tracking screens word it.
                    formatArrival(DateTime.now().add(
                      const Duration(minutes: 30),
                    )),
                    style: AppTypography.bodySmall
                        .copyWith(color: C.textSecondary(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(
      double hp, int subtotal, int deliveryFee, int total) {
    return _section(
      hp,
      _sectionTitle('Order Summary'),
      _card(
        child: Column(
          children: [
            _buildSummaryRow('Subtotal', '₦${formatPrice(subtotal)}'),
            const SizedBox(height: AppSpacing.md),
            // Matches the cart bar, which also calls a zero fee "Free".
            _buildSummaryRow(
              'Delivery fee',
              deliveryFee == 0 ? 'Free' : '₦${formatPrice(deliveryFee)}',
            ),
            const SizedBox(height: AppSpacing.md),
            Container(height: 1, color: C.divider(context)),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text(
                  'Total',
                  style: AppTypography.labelLarge.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: C.textPrimary(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '₦${formatPrice(total)}',
                  style: AppTypography.title.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: C.accentOrange(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          // Secondary, not muted: 6.9:1 on the page and 8.9:1 on a dark card.
          style: AppTypography.bodyMedium
              .copyWith(color: C.textSecondary(context)),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: C.textPrimary(context),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PINNED BAR
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBottomBar(BuildContext context, int total, bool canPlaceOrder) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'By placing your order, you agree to our ',
                style: AppTypography.caption
                    .copyWith(color: C.textSecondary(context)),
              ),
              TextSpan(
                text: 'Terms & Conditions',
                recognizer: _termsLink,
                style: AppTypography.caption.copyWith(
                  color: C.primary(context),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: C.primary(context),
                ),
              ),
              TextSpan(
                text: ' and ',
                style: AppTypography.caption
                    .copyWith(color: C.textSecondary(context)),
              ),
              TextSpan(
                text: 'Privacy Policy',
                recognizer: _privacyLink,
                style: AppTypography.caption.copyWith(
                  color: C.primary(context),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: C.primary(context),
                ),
              ),
              TextSpan(
                text: '.',
                style: AppTypography.caption
                    .copyWith(color: C.textSecondary(context)),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          // Null disables the tap: no complete address, no order.
          onTap: canPlaceOrder ? _placeOrder : null,
          child: Opacity(
            // The dimmed CTA says "not yet" without hiding the price or why
            // (the warning sits under the address).
            opacity: canPlaceOrder ? 1 : 0.5,
            child: Container(
              width: double.infinity,
              height: AppSizing.buttonHeightLarge(context),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: C.primary(context),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                'Place order · ₦${formatPrice(total)}',
                style: AppTypography.labelLarge.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: C.onPrimary(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PLACING THE ORDER
  // ═══════════════════════════════════════════════════════════════════

  void _placeOrder() {
    final products = widget.products;
    final deliveryAddress = _addresses.selectedAddress;
    // Guarded by the CTA, and defensive here: an order never carries a blank
    // address.
    if (deliveryAddress == null || !deliveryAddress.isComplete) return;

    final deliveryFee = CartTotals.forItems(products).deliveryFee;
    final orderNumber =
        'GBX-${DateTime.now().millisecondsSinceEpoch % 100000}';
    // Snapshot each line item's price/image and the address at checkout time,
    // so later edits never rewrite this order.
    final recorded = recordOrder(
      orderNumber: orderNumber,
      cartItems: products,
      deliveryFee: deliveryFee,
      deliveryAddress: deliveryAddress.fullAddress,
    );
    // The box has been bought: the next visit to the cart starts empty.
    context.read<CartNotifier>().clear();
    // Republish orders so the home banner and the orders screen pick up the
    // order that was just placed.
    ordersStore.load(force: true);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        // The confirmation reads from the recorded order, not from copies of
        // its numbers.
        builder: (_) => OrderSuccessScreen(order: orderFromStored(recorded)),
      ),
      (route) => false,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ADDRESS SHEET
  // ═══════════════════════════════════════════════════════════════════

  /// Selecting in the sheet closes it so the card behind is visible.
  Future<void> _selectFromSheet(
      BuildContext sheetContext, Address address) async {
    await _addresses.select(address.id);
    if (sheetContext.mounted) Navigator.pop(sheetContext);
  }

  void _showAddressBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.surfaceLighter(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _sectionTitle('Delivery Address'),
              const SizedBox(height: AppSpacing.xxl),
              // The same saved addresses the rest of the app reads, so this
              // sheet can never show a place that is not in storage.
              ListenableBuilder(
                listenable: _addresses,
                builder: (context, _) => SavedAddressPicker(
                  addresses: _addresses.addresses,
                  selectedId: _addresses.selectedAddress?.id,
                  onSelect: (address) => _selectFromSheet(context, address),
                  emptyHint:
                      'Add one now so the rider knows where to bring your box.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const AddressManagementScreen(startAdding: true),
                      ),
                    );
                  },
                  icon: Icon(Icons.add, color: C.primary(context)),
                  label: Text(
                    'Add New Address',
                    style: AppTypography.labelMedium
                        .copyWith(color: C.primary(context)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: C.primary(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
