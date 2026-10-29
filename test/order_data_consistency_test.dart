import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/data/orders.dart';
import 'package:growbox/widgets/vendor_rating.dart';

OrderItem _item(String name, String vendor, int price, {int qty = 1}) =>
    OrderItem(
      name: name,
      vendorName: vendor,
      category: 'GRAINS',
      image: '',
      price: price,
      quantity: qty,
    );

Order _order(List<OrderItem> items) => Order(
      id: 'GBX-1',
      vendorName: 'Green Farm',
      status: OrderStatus.confirmed,
      createdAt: DateTime(2026, 10, 29, 12),
      items: items,
    );

void main() {
  group('order progress', () {
    test('each status fills the bars the delivery has actually reached', () {
      expect(OrderStatus.confirmed.progressSegments, 1);
      expect(OrderStatus.packing.progressSegments, 2);
      // Between packing and on the way: the packing bar is still the last one
      // reached, never all four.
      expect(OrderStatus.pickedUp.progressSegments, 2);
      expect(OrderStatus.onTheWay.progressSegments, 3);
      expect(OrderStatus.delivered.progressSegments, 4);
      expect(OrderStatus.cancelled.progressSegments, 0);
    });
  });

  group('one total calculator', () {
    test('an order prices delivery from the vendor model, not a stored fee', () {
      final order = _order([
        _item('Rice', 'Green Farm', 2550, qty: 2),
        _item('Beans', 'Green Farm', 3200),
      ]);

      expect(MockVendors.deliveryFeeFor('Green Farm'), 500);
      expect(order.subtotal, 8300);
      expect(order.totals.deliveryFee, 500);
      expect(order.total, 8800);
    });

    test('a two-vendor order agrees with the cart calculation', () {
      final lines = _order([
        _item('Rice', 'Green Farm', 2550),
        _item('Beans', 'Green Farm', 3200),
      ]);
      final products = [
        MockProducts.find(name: 'Rice', vendorName: 'Green Farm')!,
        MockProducts.find(name: 'Beans', vendorName: 'Green Farm')!,
      ];
      final cart = CartTotals.forItems(products);

      expect(lines.subtotal, cart.subtotal);
      expect(lines.totals.deliveryFee, cart.deliveryFee);
      expect(lines.total, cart.total);

      // Each vendor delivers their own produce, so the fee is the sum of the
      // fees of every vendor in the box.
      final mixed = CartTotals.forLines(const [
        (vendorName: 'Green Farm', amount: 2550),
        (vendorName: 'Yummy Bunch', amount: 500),
      ]);
      expect(mixed.deliveryFee,
          MockVendors.deliveryFeeFor('Green Farm') +
              MockVendors.deliveryFeeFor('Yummy Bunch'));
      expect(mixed.total, mixed.subtotal + mixed.deliveryFee);
    });
  });

  group('vendor rating', () {
    test('labels parse into one percentage and one review count', () {
      expect(ratingPercentageFromLabel('84%'), 84);
      expect(ratingPercentageFromLabel('84.0'), 84);
      expect(ratingPercentageFromLabel(''), 0);
      expect(reviewCountFromLabel('(21)'), 21);
      expect(reviewCountFromLabel('No reviews'), isNull);
    });

    testWidgets('renders a thumb, the percentage and the count',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(
          body: VendorRating(percentage: 84, reviewCount: 21),
        ),
      ));

      expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
      expect(find.text('84%'), findsOneWidget);
      expect(find.text('(21)'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });
  });

  group('catalog categories', () {
    test('the butcher is browsed as proteins, never under Fruits', () {
      final categories = MockVendors.topLevelCategoriesFor('Fresh off Flesh');

      expect(categories, contains('PROTEINS'));
      expect(categories, isNot(contains('FRUITS')));
      expect(
        MockVendors.productsForVendor('Fresh off Flesh', 'FRUITS'),
        isEmpty,
      );
    });
  });
}
