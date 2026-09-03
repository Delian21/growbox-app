import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'placeholder_images.dart';

// ============================================================
// DATA MODELS
// ============================================================

/// Pricing type determines which multipliers apply to a product.
/// - byWeight: Size and Weight multipliers apply (rice, beans, etc.)
/// - byUnit: Sold per piece, may have bulk quantity discounts (plantains, eggs, etc.)
/// - byBundle: Sold in fixed-price bundles (crate of 30 tomatoes, tray of eggs, etc.)
enum PricingType { byWeight, byUnit, byBundle }

/// A fixed-price bundle option for byBundle products.
class ProductBundle {
  final String name;       // e.g. 'Small Tray', 'Crate'
  final int quantity;      // e.g. 10, 30
  final int price;         // e.g. 3500, 7500

  const ProductBundle({
    required this.name,
    required this.quantity,
    required this.price,
  });  /// Per-unit price within this bundle.
  int get unitPrice => (price / quantity).round();

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'price': price,
      };

  factory ProductBundle.fromJson(Map<String, dynamic> json) => ProductBundle(
        name: json['name'] as String,
        quantity: json['quantity'] as int,
        price: json['price'] as int,
      );
}




class VendorProduct {
  final String image;
  final String name;
  final String description;
  final int price;
  final String category;
  final String vendorName;
  final PricingType pricingType;
  /// Bulk quantity discounts for byUnit items.
  /// Keys are minimum quantity thresholds, values are price multipliers.
  /// Example: {5: 0.95, 10: 0.90} means buy 5+ for 5% off, 10+ for 10% off.
  final Map<int, double>? bulkMultipliers;
  /// Fixed-price bundles for byBundle items.
  /// Example: [ProductBundle(name: 'Crate', quantity: 30, price: 7500)]
  final List<ProductBundle>? bundles;

  const VendorProduct({
    required this.image,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.vendorName,
    this.pricingType = PricingType.byWeight,
    this.bulkMultipliers,
    this.bundles,
  });

  /// Serializes this product so cart items can survive app restarts.
  Map<String, dynamic> toJson() => {
        'image': image,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'vendorName': vendorName,
        'pricingType': pricingType.name,
        if (bulkMultipliers != null)
          'bulkMultipliers': bulkMultipliers!.entries
              .map((e) => [e.key, e.value])
              .toList(),
        if (bundles != null)
          'bundles': bundles!.map((b) => b.toJson()).toList(),
      };

  factory VendorProduct.fromJson(Map<String, dynamic> json) => VendorProduct(
        image: json['image'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        price: json['price'] as int,
        category: json['category'] as String,
        vendorName: json['vendorName'] as String,
        pricingType: PricingType.values.firstWhere(
          (t) => t.name == json['pricingType'],
          orElse: () => PricingType.byWeight,
        ),
        bulkMultipliers: json['bulkMultipliers'] == null
            ? null
            : {
                for (final entry
                    in (json['bulkMultipliers'] as List<dynamic>))
                  (entry as List<dynamic>)[0] as int: (entry[1] as num).toDouble(),
              },
        bundles: json['bundles'] == null
            ? null
            : (json['bundles'] as List<dynamic>)
                .map((b) => ProductBundle.fromJson(b as Map<String, dynamic>))
                .toList(),
      );

  /// Value equality: two products are the same if their serialized form
  /// matches. This keeps quantity semantics (duplicates of the same product)
  /// intact when cart items are restored from storage as fresh instances.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VendorProduct &&
          jsonEncode(toJson()) == jsonEncode(other.toJson()));

  @override
  int get hashCode =>
      Object.hash(image, name, price, category, vendorName);
}

/// Signed-in customer profile. Persisted with shared_preferences so it
/// survives app restarts; every setter writes through automatically.
class CustomerData {
  static const String _storageKey = 'customer_profile_v1';

  static String? _name;
  static String? _email;
  static String? _phone;

  static String? get name => _name;
  static String? get email => _email;
  static String? get phone => _phone;

  static set name(String? value) {
    _name = value;
    _save();
  }

  static set email(String? value) {
    _email = value;
    _save();
  }

  static set phone(String? value) {
    _phone = value;
    _save();
  }

  static void clear() {
    _name = null;
    _email = null;
    _phone = null;
    _save();
  }

  /// Loads the profile stored by a previous session (best-effort).
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _name = map['name'] as String?;
      _email = map['email'] as String?;
      _phone = map['phone'] as String?;
    } catch (_) {
      // Unreadable stored profile should never crash startup.
    }
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({'name': _name, 'email': _email, 'phone': _phone}),
      );
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}

// ============================================================
// MOCK VENDOR DATA
// ============================================================

class MockVendors {
  static List<Map<String, dynamic>> get vendors => [
    {
      'name': 'Green Farm',
      'image': PlaceholderImages.greenFarm,
      'logo': PlaceholderImages.greenFarmLogo,
      'percentage': '84%',
      'reviews': '(21)',
      'price': 2550.0,
      'rating': 84.0,
      'searchProducts': [
        'Rice',
        'Millet',
        'Maize',
        'Sorghum',
        'Beans',
        'Soybeans',
        'Grains',
        'Cereals',
        'Legumes',
      ],
      'categories': ['Grains', 'Cereals', 'Legumes'],
      'products': [
        VendorProduct(
          image: PlaceholderImages.rice,
          name: 'Rice',
          description: 'Quality rice grains sourced from trusted farmers',
          price: 2550,
          category: 'GRAINS',
          vendorName: 'Green Farm',
        ),
        VendorProduct(
          image: PlaceholderImages.millet,
          name: 'Millet',
          description: 'Fresh and nutritious millet grains',
          price: 2550,
          category: 'GRAINS',
          vendorName: 'Green Farm',
        ),
        VendorProduct(
          image: PlaceholderImages.maize,
          name: 'Maize',
          description: 'Fresh quality maize grains',
          price: 2550,
          category: 'CEREALS',
          vendorName: 'Green Farm',
        ),
        VendorProduct(
          image: PlaceholderImages.sorghum,
          name: 'Sorghum',
          description: 'Quality sorghum grains',
          price: 2550,
          category: 'CEREALS',
          vendorName: 'Green Farm',
        ),
        VendorProduct(
          image: PlaceholderImages.beans,
          name: 'Beans',
          description: 'Quality beans sourced from trusted farmers',
          price: 3200,
          category: 'LEGUMES',
          vendorName: 'Green Farm',
        ),
        VendorProduct(
          image: PlaceholderImages.soybeans,
          name: 'Soybeans',
          description: 'Fresh and nutritious soybeans',
          price: 3000,
          category: 'LEGUMES',
          vendorName: 'Green Farm',
        ),
      ],
    },
    {
      'name': 'Yummy Bunch',
      'image': PlaceholderImages.yummyBunch,
      'logo': PlaceholderImages.yummyBunchLogo,
      'percentage': '',
      'reviews': '',
      'price': 2500.0,
      'rating': 0.0,
      'searchProducts': ['Tomatoes', 'Fruits', 'Vegetables'],
      'categories': ['Fruits', 'Vegetables'],
      'products': [
        VendorProduct(
          image: PlaceholderImages.tomatoes,
          name: 'Tomatoes',
          description: 'Fresh tomatoes sold per piece',
          price: 500,
          category: 'VEGETABLES',
          vendorName: 'Yummy Bunch',
          pricingType: PricingType.byUnit,
          bulkMultipliers: {5: 0.95, 10: 0.90, 20: 0.85},
        ),
        VendorProduct(
          image: PlaceholderImages.tomatoesCrate,
          name: 'Tomatoes (Crate)',
          description: 'Fresh tomatoes sold in bulk crates — perfect for parties, events, or resellers',
          price: 7500,
          category: 'VEGETABLES',
          vendorName: 'Yummy Bunch',
          pricingType: PricingType.byBundle,
          bundles: [
            ProductBundle(name: 'Small Crate', quantity: 15, price: 3800),
            ProductBundle(name: 'Crate', quantity: 30, price: 7500),
            ProductBundle(name: 'Mega Crate', quantity: 60, price: 13500),
          ],
        ),
      ],
    },
    {
      'name': 'Fresh off Flesh',
      'image': PlaceholderImages.freshOffFlesh,
      'logo': PlaceholderImages.freshOffFleshLogo,
      'percentage': '92%',
      'reviews': '(12)',
      'price': 3000.0,
      'rating': 92.0,
      'searchProducts': ['Fresh Produce', 'Fruits', 'Meat', 'Vegetables'],
      'categories': ['Fruits', 'Vegetables', 'Meat'],
      'products': [
        VendorProduct(
          image: PlaceholderImages.freshProtein,
          name: 'Fresh Produce',
          description: 'Fresh quality produce',
          price: 3000,
          category: 'FRUITS',
          vendorName: 'Fresh off Flesh',
          pricingType: PricingType.byWeight,
        ),
        VendorProduct(
          image: PlaceholderImages.chicken,
          name: 'Chicken',
          description: 'Fresh chicken',
          price: 4000,
          category: 'POULTRY',
          vendorName: 'Fresh off Flesh',
        ),
        VendorProduct(
          image: PlaceholderImages.fish,
          name: 'Fish',
          description: 'Fresh fish',
          price: 3800,
          category: 'FISH',
          vendorName: 'Fresh off Flesh',
        ),
      ],
    },
    {
      'name': 'Heart of Red',
      'image': PlaceholderImages.heartOfRed,
      'logo': PlaceholderImages.heartOfRedLogo,
      'percentage': '100%',
      'reviews': '(54)',
      'price': 3500.0,
      'rating': 100.0,
      'searchProducts': ['Fresh Apples', 'Fruits', 'Vegetables'],
      'categories': ['Fruits', 'Vegetables'],
      'products': [
        VendorProduct(
          image: PlaceholderImages.freshApples,
          name: 'Fresh Apples',
          description: 'Fresh quality apples sold per piece',
          price: 350,
          category: 'FRUITS',
          vendorName: 'Heart of Red',
          pricingType: PricingType.byUnit,
          bulkMultipliers: {10: 0.95, 20: 0.90, 50: 0.85},
        ),
        VendorProduct(
          image: PlaceholderImages.oranges,
          name: 'Oranges',
          description: 'Fresh juicy oranges',
          price: 300,
          category: 'FRUITS',
          vendorName: 'Heart of Red',
          pricingType: PricingType.byUnit,
          bulkMultipliers: {10: 0.95, 20: 0.90},
        ),
        VendorProduct(
          image: PlaceholderImages.bananas,
          name: 'Bananas',
          description: 'Fresh bananas',
          price: 250,
          category: 'FRUITS',
          vendorName: 'Heart of Red',
          pricingType: PricingType.byUnit,
          bulkMultipliers: {10: 0.95, 20: 0.90},
        ),
        VendorProduct(
          image: PlaceholderImages.eggsTray,
          name: 'Eggs (Tray)',
          description: 'Fresh farm eggs sold in trays — great for bakeries and large households',
          price: 4500,
          category: 'FRUITS',
          vendorName: 'Heart of Red',
          pricingType: PricingType.byBundle,
          bundles: [
            ProductBundle(name: 'Half Tray', quantity: 15, price: 2400),
            ProductBundle(name: 'Full Tray', quantity: 30, price: 4500),
            ProductBundle(name: 'Double Tray', quantity: 60, price: 8400),
          ],
        ),
      ],
    },
    {
      'name': 'Real Green',
      'image': PlaceholderImages.realGreen,
      'logo': PlaceholderImages.realGreenLogo,
      'percentage': '',
      'reviews': '',
      'price': 2800.0,
      'rating': 0.0,
      'searchProducts': ['Fresh Vegetables', 'Vegetables', 'Fruits', 'Herbs'],
      'categories': ['Vegetables', 'Fruits', 'Herbs'],
      'products': [
        VendorProduct(
          image: PlaceholderImages.freshVegetables,
          name: 'Fresh Vegetables',
          description: 'Fresh quality vegetables',
          price: 2800,
          category: 'VEGETABLES',
          vendorName: 'Real Green',
          pricingType: PricingType.byWeight,
        ),
        VendorProduct(
          image: PlaceholderImages.peppers,
          name: 'Peppers',
          description: 'Fresh hot peppers',
          price: 1500,
          category: 'VEGETABLES',
          vendorName: 'Real Green',
          pricingType: PricingType.byWeight,
        ),
        VendorProduct(
          image: PlaceholderImages.onions,
          name: 'Onions',
          description: 'Fresh onions',
          price: 1200,
          category: 'VEGETABLES',
          vendorName: 'Real Green',
          pricingType: PricingType.byWeight,
        ),
        VendorProduct(
          image: PlaceholderImages.cabbage,
          name: 'Cabbage',
          description: 'Fresh cabbage',
          price: 800,
          category: 'VEGETABLES',
          vendorName: 'Real Green',
          pricingType: PricingType.byWeight,
        ),
      ],
    },
    {
      'name': 'Cereals Greetings',
      'image': PlaceholderImages.cerealsGreetings,
      'logo': PlaceholderImages.cerealsGreetingsLogo,
      'percentage': '',
      'reviews': '',
      'price': 2700.0,
      'rating': 0.0,
      'searchProducts': ['Maize', 'Grains', 'Cereals', 'Legumes'],
      'categories': ['Grains', 'Cereals', 'Legumes'],
      'products': [
        VendorProduct(
          image: PlaceholderImages.maize,
          name: 'Maize',
          description: 'Quality maize grains',
          price: 2700,
          category: 'CEREALS',
          vendorName: 'Cereals Greetings',
        ),
        VendorProduct(
          image: PlaceholderImages.rice,
          name: 'Rice',
          description: 'Quality rice',
          price: 2550,
          category: 'GRAINS',
          vendorName: 'Cereals Greetings',
        ),
        VendorProduct(
          image: PlaceholderImages.millet,
          name: 'Millet',
          description: 'Fresh millet',
          price: 2400,
          category: 'GRAINS',
          vendorName: 'Cereals Greetings',
        ),
      ],
    },
  ];

  /// Returns vendor products for a given vendor name and category.
  /// Filters from the single source-of-truth [vendors] list.
  static List<VendorProduct> productsForVendor(
    String vendorName,
    String category,
  ) {
    final vendor = vendors.firstWhere(
      (v) => v['name'] == vendorName,
      orElse: () => {},
    );
    if (vendor.isEmpty) return [];
    final products = (vendor['products'] as List<VendorProduct>?) ?? [];
    if (category.isEmpty) return products;
    return products.where((p) => p.category == category).toList();
  }

  /// Returns sub-categories for a given top-level category
  static List<String> categoriesForVendor(String category) {
    switch (category) {
      case 'GRAINS AND CEREALS':
        return const ['Grains', 'Cereals', 'Legumes'];
      case 'FRUITS':
        return const ['Fruits', 'Vegetables'];
      case 'VEGETABLES':
        return const ['Vegetables', 'Fruits', 'Herbs'];
      case 'FRESH PROTEINS':
        return const ['Meat', 'Fish', 'Poultry'];
      default:
        return const ['Fruits', 'Vegetables'];
    }
  }

  /// Vendor list for CategoryVendorsScreen
  static List<Map<String, dynamic>> get categoryVendors => [
    {
      'name': 'Green Farm',
      'image': PlaceholderImages.greenFarm,
      'categories': ['GRAINS AND CEREALS'],
    },
    {
      'name': 'Yummy Bunch',
      'image': PlaceholderImages.yummyBunch,
      'categories': ['FRUITS'],
    },
    {
      'name': 'Fresh off Flesh',
      'image': PlaceholderImages.freshOffFlesh,
      'categories': ['FRESH PROTEINS'],
    },
    {
      'name': 'Heart of Red',
      'image': PlaceholderImages.heartOfRed,
      'categories': ['FRUITS'],
    },
    {
      'name': 'Real Green',
      'image': PlaceholderImages.realGreen,
      'categories': ['VEGETABLES'],
    },
    {
      'name': 'Cereals Greetings',
      'image': PlaceholderImages.cerealsGreetings,
      'categories': ['GRAINS AND CEREALS'],
    },
  ];
}

// ---------------------------------------------------------------------------
// Canonical product catalog — a flat, queryable view over MockVendors.
//
// Anything that needs "the same product the storefront shows" (Buy Again
// seeds, mock-order items, Reorder) should resolve through [MockProducts]
// instead of constructing duplicate VendorProduct copies, so a single catalog
// entry can never drift from its copies.
// ---------------------------------------------------------------------------

class MockProducts {
  MockProducts._();

  /// Every product currently offered across all vendors.
  static final List<VendorProduct> all = [
    for (final vendor in MockVendors.vendors) ...(vendor['products'] as List<VendorProduct>),
  ];

  /// Resolves the canonical instance for a product.
  ///
  /// Matches on [vendorName] + [name] when both are given; with only a name
  /// it matches when exactly one vendor sells it (otherwise null).
  static VendorProduct? find({
    String? name,
    String? vendorName,
  }) {
    if (name == null) return null;
    final matches = all.where((p) {
      if (p.name != name) return false;
      if (vendorName != null && p.vendorName != vendorName) return false;
      return true;
    }).toList();
    if (matches.length != 1) return null;
    return matches.single;
  }
}

// ============================================================
// MOCK NOTIFICATION DATA
// ============================================================

class MockNotifications {
  static const List<Map<String, String>> notifications = [
    {
      'title': 'Order Delivered',
      'message': 'Your order ORD-001 has been delivered.',
      'time': '2 hours ago',
    },
    {
      'title': 'New Vendor',
      'message': 'Check out Cereals Greetings for fresh cereals!',
      'time': '1 day ago',
    },
    {
      'title': 'Promotion',
      'message': 'Get 10% off on your next order from Green Farm.',
      'time': '3 days ago',
    },
  ];
}

// ============================================================
// MOCK FAQ DATA
// ============================================================

class MockFAQs {
  static const List<Map<String, String>> faqs = [
    {
      'question': 'How do I place an order?',
      'answer':
          'Browse the menu, select products from your preferred vendor, add them to your box, and proceed to checkout.',
    },
    {
      'question': 'How do I track my order?',
      'answer':
          'Go to your order history in the cart section to view the status of all your orders.',
    },
    {
      'question': 'Can I cancel an order?',
      'answer':
          'You can cancel an order that is still in pending status from the order details screen.',
    },
    {
      'question': 'How do I contact a vendor?',
      'answer':
          'Navigate to the vendor page and use the contact options provided.',
    },
    {
      'question': 'What payment methods are accepted?',
      'answer':
          'We accept mobile money, bank transfers, and card payments.',
    },
  ];
}
