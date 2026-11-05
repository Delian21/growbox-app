import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../data/addresses.dart';
import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../data/orders.dart';
import '../data/payment_method.dart';
import '../widgets/saved_address_picker.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/pinned_bottom_bar.dart';
import '../widgets/app_button.dart';
import 'order_result_screens.dart';
import 'order_success_screen.dart';
import 'address_management_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';
import 'cookies_screen.dart';

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

/// One checkout attempt, as handed to [CheckoutScreen.placeOrder].
///
/// [orderNumber] is generated once per attempt and reused by every retry, so a
/// request that fails and is sent again can never be recorded twice under two
/// different numbers.
class CheckoutDraft {
  final String orderNumber;
  final List<VendorProduct> products;
  final int deliveryFee;
  final String deliveryAddress;
  final String? riderNote;
  final PaymentMethod paymentMethod;

  const CheckoutDraft({
    required this.orderNumber,
    required this.products,
    required this.deliveryFee,
    required this.deliveryAddress,
    required this.riderNote,
    required this.paymentMethod,
  });
}

class CheckoutScreen extends StatefulWidget {
  final List<VendorProduct> products;

  /// Test seam; defaults to the app-wide store.
  final AddressesStore? addressStore;

  /// Replaces the real submit, so a test can hold the request open, fail it or
  /// inspect what would be sent. Defaults to [recordOrder].
  final Future<StoredOrder> Function(CheckoutDraft draft)? placeOrder;

  const CheckoutScreen({
    super.key,
    required this.products,
    this.addressStore,
    this.placeOrder,
  });
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _showItems = false;

  /// The optional note for the rider. Empty text means "no note".
  final TextEditingController _riderNote = TextEditingController();

  /// The method shown as chosen. Only an available method can be picked, so in
  /// practice this stays [PaymentMethod.payOnDelivery].
  PaymentMethod _paymentMethod = PaymentMethod.payOnDelivery;

  /// True from the tap on "Place order" until the request resolves, so the
  /// button cannot be pressed a second time.
  bool _placing = false;

  /// The order number for this checkout attempt: built on the first tap and
  /// kept for every retry.
  String? _orderNumber;

  /// Tap targets inside the terms sentence. Created once and disposed with the
  /// screen, because a TextSpan recognizer is not managed by the framework.
  late final TapGestureRecognizer _termsLink;
  late final TapGestureRecognizer _privacyLink;
  late final TapGestureRecognizer _cookiesLink;

  AddressesStore get _addresses => widget.addressStore ?? addressesStore;

  @override
  void initState() {
    super.initState();
    _addresses.load();
    _termsLink = TapGestureRecognizer()..onTap = _openTerms;
    _privacyLink = TapGestureRecognizer()..onTap = _openPrivacy;
    _cookiesLink = TapGestureRecognizer()..onTap = _openCookies;
  }

  @override
  void dispose() {
    _riderNote.dispose();
    _termsLink.dispose();
    _privacyLink.dispose();
    _cookiesLink.dispose();
    super.dispose();
  }

  void _openTerms() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const TermsScreen()),
  );

  void _openPrivacy() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
  );

  void _openCookies() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CookiesScreen()),
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
    // rider cannot find the door, and an empty box is nothing to deliver, so
    // ordering stays disabled in both cases.
    final deliveryAddress = _addresses.selectedAddress;
    final canPlaceOrder =
        products.isNotEmpty &&
        deliveryAddress != null &&
        deliveryAddress.isComplete;

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
                _buildNoteSection(hp),
                _buildDeliverySection(hp),
                _buildPaymentSection(hp),
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
          child: Icon(
            Icons.image_outlined,
            size: size * 0.5,
            color: C.textMuted(context),
          ),
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
            style: AppTypography.bodyMedium.copyWith(
              color: C.textSecondary(context),
            ),
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
                      style: AppTypography.labelMedium.copyWith(
                        color: C.textPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$itemCount item${itemCount == 1 ? '' : 's'}',
                    style: AppTypography.bodySmall.copyWith(
                      color: C.textSecondary(context),
                    ),
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
                            style: AppTypography.bodyMedium.copyWith(
                              color: C.textPrimary(context),
                            ),
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
                Icon(
                  Icons.location_on_outlined,
                  color: C.primary(context),
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addr == null ? 'Choose location' : addr.label,
                        style: AppTypography.labelMedium.copyWith(
                          color: C.textPrimary(context),
                        ),
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
                          style: AppTypography.caption.copyWith(
                            color: C.textMuted(context),
                          ),
                        ),
                      ],
                      if (addr?.phone?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 2),
                        Text(
                          addr!.phone!.trim(),
                          style: AppTypography.caption.copyWith(
                            color: C.textMuted(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // A single "Change" action and a tappable card: the chevron that used
        // to sit on the right repeated it and looked like a third control.
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
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: C.accentOrange(context),
          ),
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
                  child: AppButton(
                    label: 'Add details',
                    variant: AppButtonVariant.text,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddressManagementScreen(editAddressId: addr.id),
                      ),
                    ),
                    height: 32,
                    radius: AppRadii.sm,
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
            Icon(
              Icons.local_shipping_outlined,
              size: 22,
              color: C.textPrimary(context),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Standard delivery',
                    style: AppTypography.labelMedium.copyWith(
                      color: C.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // The app's standard promise, worded the same way the
                    // confirmation and tracking screens word it.
                    formatArrival(
                      DateTime.now().add(const Duration(minutes: 30)),
                    ),
                    style: AppTypography.bodySmall.copyWith(
                      color: C.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Optional free text for the rider, sitting directly under the address card.
  ///
  /// Nothing here is required: an empty field is sent as a null note.
  Widget _buildNoteSection(double hp) {
    return _section(
      hp,
      _sectionTitle('Note for the rider'),
      _card(
        child: TextField(
          controller: _riderNote,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: AppTypography.bodyMedium.copyWith(
            color: C.textPrimary(context),
          ),
          cursorColor: C.primary(context),
          decoration: InputDecoration(
            isDense: true,
            // The word "optional" sits in the hint, so the heading stays a
            // heading and the field needs no extra label.
            hintText: 'Optional \u2014 gate code, landmark, or where to leave it',
            hintStyle: AppTypography.bodySmall.copyWith(
              color: C.textMuted(context),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  /// The payment choice: one working method, two listed but not yet wired up.
  Widget _buildPaymentSection(double hp) {
    return _section(
      hp,
      _sectionTitle('Payment method'),
      _card(
        child: Column(
          children: [
            for (final method in PaymentMethod.values)
              Padding(
                padding: EdgeInsets.only(
                  bottom: method == PaymentMethod.values.last
                      ? 0
                      : AppSpacing.md,
                ),
                child: _buildPaymentOption(method),
              ),
          ],
        ),
      ),
    );
  }

  /// One row of the payment list: a drawn radio, the label and its subtitle.
  ///
  /// Drawn rather than a [Radio] so the disabled rows can carry a reason and
  /// the whole row (not just the dot) is the tap target.
  Widget _buildPaymentOption(PaymentMethod method) {
    final available = method.isAvailable;
    final selected = _paymentMethod == method;
    final accent = C.primary(context);

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: available,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Null on a disabled row: it cannot become the choice.
        onTap: available ? () => setState(() => _paymentMethod = method) : null,
        child: Opacity(
          // Dimmed rather than hidden: the method exists, it just is not ready.
          opacity: available ? 1 : 0.55,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? accent : C.divider(context),
                    width: selected ? 2 : 1.5,
                  ),
                ),
                child: selected
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.label,
                      style: AppTypography.labelMedium.copyWith(
                        color: C.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      method.subtitle,
                      style: AppTypography.caption.copyWith(
                        color: C.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary(
    double hp,
    int subtotal,
    int deliveryFee,
    int total,
  ) {
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
          style: AppTypography.bodyMedium.copyWith(
            color: C.textSecondary(context),
          ),
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
                style: AppTypography.caption.copyWith(
                  color: C.textSecondary(context),
                ),
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
                text: ', ',
                style: AppTypography.caption.copyWith(
                  color: C.textSecondary(context),
                ),
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
                text: ' and ',
                style: AppTypography.caption.copyWith(
                  color: C.textSecondary(context),
                ),
              ),
              TextSpan(
                text: 'Cookies Policy',
                recognizer: _cookiesLink,
                style: AppTypography.caption.copyWith(
                  color: C.primary(context),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: C.primary(context),
                ),
              ),
              TextSpan(
                text: '.',
                style: AppTypography.caption.copyWith(
                  color: C.textSecondary(context),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          // Null disables the tap: no items or no complete address means no
          // order, and a request already in flight cannot be sent twice.
          onTap: canPlaceOrder && !_placing ? _placeOrder : null,
          child: Opacity(
            // The dimmed CTA says "not yet" without hiding the price or why
            // (the warning sits under the address).
            opacity: canPlaceOrder && !_placing ? 1 : 0.5,
            child: Container(
              width: double.infinity,
              height: AppSizing.buttonHeightLarge(context),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: C.primary(context),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              // The label is swapped for a spinner in place, so the button keeps
              // its size and the customer sees the tap landed.
              child: _placing
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: C.onPrimary(context),
                      ),
                    )
                  : Text(
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

  Future<void> _placeOrder() async {
    // Guarded by the CTA and defensive here: one order per tap, never without
    // something to carry or a street to carry it to.
    if (_placing) return;
    final products = widget.products;
    final deliveryAddress = _addresses.selectedAddress;
    if (products.isEmpty) return;
    if (deliveryAddress == null || !deliveryAddress.isComplete) return;

    final totals = CartTotals.forItems(products);
    // One number per checkout attempt: a retry after a failure reuses it, so
    // the same box can never be recorded twice under two ids.
    final orderNumber = _orderNumber ??=
        'GBX-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final note = _riderNote.text.trim();

    // Before the await, so the very next frame shows the spinner and further
    // taps find `_placing` true.
    setState(() => _placing = true);

    final draft = CheckoutDraft(
      orderNumber: orderNumber,
      products: products,
      deliveryFee: totals.deliveryFee,
      deliveryAddress: deliveryAddress.fullAddress,
      riderNote: note.isEmpty ? null : note,
      paymentMethod: _paymentMethod,
    );

    try {
      final recorded = await (widget.placeOrder ?? _submit)(draft);
      if (!mounted) return;
      // The box has been bought: the next visit to the cart starts empty. Only
      // on success — a failed attempt keeps every item for the retry.
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
    } catch (_) {
      if (!mounted) return;
      // The attempt itself, priced exactly as the order would have been: the
      // failure screen has no stored order to read because the write is what
      // failed, so it is handed the same snapshot the record would have held.
      final attempted = attemptedOrder(
        orderNumber: orderNumber,
        items: orderItemsFromCart(draft.products),
        deliveryAddress: draft.deliveryAddress,
        paymentMethod: draft.paymentMethod,
      );
      // Pushed, not replaced: "Try again" pops straight back to this very
      // screen, with the cart, the address, the note and the method intact.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderFailedScreen(order: attempted),
        ),
      );
      if (!mounted) return;
      // Back from the failure screen: the CTA is armed again.
      setState(() => _placing = false);
    }
  }

  /// The real submit: snapshots the order, exactly as before.
  ///
  /// A backend would await its own request here; the short delay keeps the
  /// button's progress state honest while it does.
  Future<StoredOrder> _submit(CheckoutDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return recordOrder(
      orderNumber: draft.orderNumber,
      cartItems: draft.products,
      deliveryFee: draft.deliveryFee,
      deliveryAddress: draft.deliveryAddress,
      riderNote: draft.riderNote,
      paymentMethod: draft.paymentMethod,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ADDRESS SHEET
  // ═══════════════════════════════════════════════════════════════════

  /// Selecting in the sheet closes it so the card behind is visible.
  Future<void> _selectFromSheet(
    BuildContext sheetContext,
    Address address,
  ) async {
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
                child: AppButton(
                  label: 'Add new address',
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
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  height: 48,
                  radius: AppRadii.md,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
