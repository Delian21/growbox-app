import 'package:flutter_test/flutter_test.dart';
import 'package:growbox/data/mock_data.dart';

/// Guards the invariant the browse screen depends on: each category chip
/// (Grains, Fruits, Legumes, Vegetables, Proteins, Herbs, Oils) must map to
/// at least one vendor, and every vendor shown under a chip must sell at
/// least one product in that category — otherwise the chip lands on the
/// "No vendors found" empty screen.
void main() {
  test('every browse category chip maps to vendors with matching products',
      () {
    const chips = [
      'GRAINS',
      'FRUITS',
      'LEGUMES',
      'TUBERS',
      'VEGETABLES',
      'PROTEINS',
      'HERBS',
      'OILS',
    ];

    for (final chip in chips) {
      final vendors = MockVendors.categoryVendors
          .where((v) => (v['categories'] as List).contains(chip))
          .toList();

      expect(vendors, isNotEmpty, reason: 'no vendors found for $chip');

      for (final vendor in vendors) {
        final products =
            MockVendors.productsForVendor(vendor['name'] as String, chip);
        expect(products, isNotEmpty,
            reason: '${vendor['name']} has no products in $chip');
      }
    }
  });

  test('every product category is covered by a browse bucket', () {
    final covered =
        MockVendors.browseCategoryBuckets.values.expand((e) => e).toSet();

    for (final vendor in MockVendors.vendors) {
      for (final product in vendor['products'] as List<VendorProduct>) {
        expect(covered.contains(product.category), isTrue,
            reason:
                '${product.name} has uncategorised category ${product.category}');
      }
    }
  });

  test('category vendors are derived from real vendor products', () {
    // Green Farm sells grains/cereals and legumes; Real Green herbs;
    // Golden Oils only oils.
    final byName = <String, List<String>>{
      for (final v in MockVendors.categoryVendors)
        v['name'] as String: (v['categories'] as List).cast<String>(),
    };

    expect(byName['Green Farm'], containsAll(['GRAINS', 'LEGUMES']));
    expect(byName['Golden Oils'], ['OILS']);
    expect(byName['Real Green'], containsAll(['HERBS', 'TUBERS']));

    // The oils vendor exists and its products carry the OILS category.
    final goldenOils = MockVendors.vendors
        .firstWhere((v) => v['name'] == 'Golden Oils');
    final products = goldenOils['products'] as List<VendorProduct>;
    expect(products, isNotEmpty);
    expect(products.map((p) => p.category).toSet(), {'OILS'});
  });
}
