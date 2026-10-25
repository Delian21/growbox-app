import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/addresses.dart';
import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/screens/checkout_screen.dart';
import 'package:growbox/screens/privacy_policy_screen.dart';
import 'package:growbox/screens/terms_screen.dart';
import 'package:growbox/theme.dart';
import 'package:growbox/widgets/pinned_bottom_bar.dart';

/// WCAG 2.1 relative-luminance contrast ratio.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

VendorProduct _product(String name, int price, {String vendor = 'Green Farm'}) =>
    VendorProduct(
      image: '',
      name: name,
      description: name,
      price: price,
      category: 'GRAINS',
      vendorName: vendor,
    );

const _address = Address(
  id: 'a1',
  label: 'Home',
  street: 'No. 12 Gwarinpa Estate',
  area: 'Gwarinpa, Abuja',
);

/// Two units of Rice (Green Farm, ₦500 delivery) plus one Tomatoes (free
/// delivery): 5,600 goods + 500 delivery = 6,100 payable.
final _products = [
  _product('Rice', 2550),
  _product('Rice', 2550),
  _product('Tomatoes', 500, vendor: 'Yummy Bunch'),
];

Widget _harness(
  AddressesStore store, {
  Brightness brightness = Brightness.light,
}) {
  return ChangeNotifierProvider(
    create: (_) => CartNotifier()..addAll(_products),
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: brightness),
      home: CheckoutScreen(products: _products, addressStore: store),
    ),
  );
}

Future<AddressesStore> _storeWithAddress() async {
  final store = AddressesStore(LocalAddressRepository(account: () => 'test'));
  await store.load();
  await store.save(_address);
  return store;
}

Future<AddressesStore> _pumpCheckout(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  bool withAddress = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 1000);
  addTearDown(tester.view.reset);

  final store = withAddress
      ? await _storeWithAddress()
      : AddressesStore(LocalAddressRepository(account: () => 'test'));

  await tester.pumpWidget(_harness(store, brightness: brightness));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('title and section headings use the hierarchy scale',
      (tester) async {
    await _pumpCheckout(tester);

    final title = tester.widget<Text>(find.text('Checkout'));
    expect(title.style!.fontSize, 21);
    expect(title.style!.fontWeight, FontWeight.w600);

    for (final heading in [
      'Your Box',
      'Delivery Address',
      'Delivery',
      'Order Summary',
    ]) {
      final style = tester.widget<Text>(find.text(heading)).style!;
      expect(style.fontSize, inInclusiveRange(16, 18), reason: heading);
      expect(style.fontWeight, FontWeight.w600, reason: heading);
    }

    // The mint icon tiles above each section are gone.
    expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
    expect(find.byIcon(Icons.location_on_outlined), findsWidgets,
        reason: 'the address row keeps its pin, the heading does not');
    expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);
    expect(find.byIcon(Icons.receipt_outlined), findsNothing);
  });

  testWidgets('one card style: surface, border, no shadow', (tester) async {
    await _pumpCheckout(tester);
    final context = tester.element(find.byType(CheckoutScreen));

    BoxDecoration cardAround(Finder text) {
      final container = tester.widget<Container>(
        find.ancestor(of: text, matching: find.byType(Container)).first,
      );
      return container.decoration! as BoxDecoration;
    }

    for (final finder in [
      find.text('Rice × 2 · Green Farm'),
      find.text('Standard delivery'),
      find.text('Delivery fee'),
    ]) {
      final decoration = cardAround(finder);
      expect(decoration.color, C.surface(context));
      expect(decoration.boxShadow, isNull);
      expect(decoration.border, isNotNull);
      expect(
        (decoration.border! as Border).top.color,
        C.divider(context),
      );
      expect(decoration.borderRadius, BorderRadius.circular(AppRadii.md));
    }
  });

  testWidgets('the collapsed box summarises the first line and expands',
      (tester) async {
    await _pumpCheckout(tester);

    // Thumbnail + "Rice × 2 · Green Farm" + the item count.
    expect(find.text('Rice × 2 · Green Farm'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);

    // Collapsed: no line rows yet.
    expect(find.text('Rice × 2'), findsNothing);

    await tester.tap(find.text('Rice × 2 · Green Farm'));
    await tester.pumpAndSettle();

    expect(find.text('Rice × 2'), findsOneWidget);
    expect(find.text('Tomatoes × 1'), findsOneWidget);
    expect(find.text('₦5,100'), findsOneWidget); // Rice line total
    expect(find.text('₦500'), findsNWidgets(2)); // Tomatoes line + delivery fee
  });

  testWidgets('the single delivery option is an info row with no price',
      (tester) async {
    await _pumpCheckout(tester);

    expect(find.text('Standard delivery'), findsOneWidget);
    expect(find.textContaining(' · by '), findsOneWidget,
        reason: 'the ETA is the app\'s shared arrival format');
    // Fee lives only in Order Summary.
    expect(find.text('₦500'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('summary and CTA read in the ${brightness.name} theme',
        (tester) async {
      await _pumpCheckout(tester, brightness: brightness);
      final context = tester.element(find.byType(CheckoutScreen));
      final card = C.surface(context);

      final label = tester.widget<Text>(find.text('Subtotal'));
      expect(label.style!.color, C.textSecondary(context));
      expect(
        contrastRatio(label.style!.color!, card),
        greaterThanOrEqualTo(4.5),
        reason: 'summary labels in ${brightness.name}',
      );

      final totalLabel = tester.widget<Text>(find.text('Total'));
      expect(totalLabel.style!.fontWeight, FontWeight.w700);

      final totalValue = tester.widget<Text>(find.text('₦6,100'));
      expect(totalValue.style!.color, C.accentOrange(context));
      expect(
        contrastRatio(totalValue.style!.color!, card),
        greaterThanOrEqualTo(4.5),
        reason: 'total amount in ${brightness.name}',
      );

      // CTA: primary fill, on-primary label, no glow.
      final button = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Place order · ₦6,100'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = button.decoration! as BoxDecoration;
      expect(decoration.color, C.primary(context));
      expect(decoration.boxShadow, isNull);
      expect(
        tester.widget<Text>(find.text('Place order · ₦6,100')).style!.color,
        C.onPrimary(context),
      );

      // Terms sit in the bar above the button, readable on its surface.
      final terms = tester.widget<Text>(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.textSpan?.toPlainText().contains('Terms & Conditions') ??
                false)),
      ).textSpan! as TextSpan;
      final spans = terms.children!.cast<TextSpan>();
      for (final span in spans) {
        expect(
          contrastRatio(span.style!.color!, C.surface(context)),
          greaterThanOrEqualTo(4.5),
          reason: '"${span.text}" in ${brightness.name}',
        );
      }
      final termsSpan =
          spans.firstWhere((span) => span.text == 'Terms & Conditions');
      final privacySpan =
          spans.firstWhere((span) => span.text == 'Privacy Policy');
      for (final span in [termsSpan, privacySpan]) {
        expect(span.style!.color, C.primary(context));
        expect(span.style!.decoration, TextDecoration.underline);
        expect(span.recognizer, isNotNull);
      }
    });
  }

  testWidgets('the bar is pinned with a top divider and no nav strip',
      (tester) async {
    await _pumpCheckout(tester);
    final context = tester.element(find.byType(CheckoutScreen));

    final bar = tester.getRect(find.byKey(PinnedBottomBar.surfaceKey));
    expect(bar.bottom, closeTo(1000, 0.01),
        reason: 'no nav here: the bar meets the safe area');
    expect(bar.height, lessThan(220), reason: 'compact two-row bar');

    // The scroll viewport ends exactly where the bar starts, so content can
    // never hide underneath it.
    final scroll = tester.getRect(find.byType(SingleChildScrollView));
    expect(scroll.bottom, closeTo(bar.top, 0.01));

    final surface = tester.widget<Container>(
      find.byKey(PinnedBottomBar.surfaceKey),
    );
    final border = (surface.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, C.divider(context));
    expect(border.top.width, 1);

    // Terms are inside the bar, above the button.
    final terms = find.byWidgetPredicate((w) =>
        w is Text &&
        (w.textSpan?.toPlainText().contains('Terms & Conditions') ?? false));
    expect(tester.getRect(terms).top, greaterThan(bar.top));
    expect(
      tester.getRect(terms).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('Place order · ₦6,100')).top),
    );
  });

  testWidgets('terms links open the policy pages', (tester) async {
    await _pumpCheckout(tester);

    TextSpan spanFor(String label) {
      final text = tester.widget<Text>(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.textSpan?.toPlainText().contains('Terms & Conditions') ??
                false)),
      );
      final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
      return spans.firstWhere((span) => span.text == label);
    }

    (spanFor('Terms & Conditions').recognizer! as TapGestureRecognizer)
        .onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(TermsScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(TermsScreen))).pop();
    await tester.pumpAndSettle();

    (spanFor('Privacy Policy').recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
  });

  testWidgets('lays out on a small phone without overflowing',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);

    final store = await _storeWithAddress();
    await tester.pumpWidget(_harness(store));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Place order · ₦6,100'), findsOneWidget);
  });

  testWidgets('the CTA stays disabled until the address has a street',
      (tester) async {
    await _pumpCheckout(tester, withAddress: false);

    expect(find.text('Choose location'), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.text('Place order · ₦6,100'),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(opacity.opacity, lessThan(1));

    await tester.tap(find.textContaining('Place order'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsOneWidget,
        reason: 'an order cannot be placed without a delivery address');
  });
}
