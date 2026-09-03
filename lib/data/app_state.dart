import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mock_data.dart';

// ---------------------------------------------------------------------------
// Cart – ChangeNotifier for Provider, persisted with shared_preferences
// ---------------------------------------------------------------------------

class CartNotifier extends ChangeNotifier {
  static const String _storageKey = 'cart_items_v1';

  final List<VendorProduct> _items = [];

  // Chains async writes so rapid mutations can't race on the prefs cache.
  Future<void> _pendingWrites = Future.value();

  CartNotifier() {
    _restore();
  }

  List<VendorProduct> get items => List.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  /// Total price in₦ (sum of all item prices).
  int get total => _items.fold(0, (sum, p) => sum + p.price);

  // ── Persistence ───────────────────────────────────────────────────

  /// Loads the previously stored cart (from a past app session).
  /// Best-effort: corrupt/unreadable storage simply starts empty.
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty || _items.isNotEmpty) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      _items.addAll(decoded.map(
        (e) => VendorProduct.fromJson(e as Map<String, dynamic>),
      ));
      notifyListeners();
    } catch (_) {
      // Ignore: an unreadable stored cart should never crash the app.
    }
  }

  /// Persists the current cart so it survives app restarts.
  void _save() {
    _pendingWrites = _pendingWrites.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _storageKey,
          jsonEncode(_items.map((p) => p.toJson()).toList()),
        );
      } catch (_) {
        // Persistence is best-effort; never break the in-memory cart.
      }
    });
  }

  void add(VendorProduct product) {
    _items.add(product);
    notifyListeners();
    _save();
  }

  void addAll(List<VendorProduct> products) {
    _items.addAll(products);
    notifyListeners();
    _save();
  }

  void remove(VendorProduct product) {
    _items.remove(product);
    notifyListeners();
    _save();
  }

  void removeAll(VendorProduct product) {
    _items.removeWhere((item) => item == product);
    notifyListeners();
    _save();
  }

  /// Remove a single instance of a product (for quantity decrement).
  bool removeOne(VendorProduct product) {
    final idx = _items.indexOf(product);
    if (idx == -1) return false;
    _items.removeAt(idx);
    notifyListeners();
    _save();
    return true;
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _save();
  }

  /// Count how many times a specific product appears.
  int countOf(VendorProduct product) {
    return _items.where((item) => item == product).length;
  }
}

// Shared favorites
final List<VendorProduct> favoriteProducts = [];
final List<Map<String, String>> favoriteVendors = [];

// ---------------------------------------------------------------------------
// Saved Delivery Addresses
// ---------------------------------------------------------------------------

class DeliveryAddress {
  final String id;
  String label; // e.g. 'Home', 'Office'
  String address;
  String? phone;
  bool isDefault;

  DeliveryAddress({
    required this.id,
    required this.label,
    required this.address,
    this.phone,
    this.isDefault = false,
  });
}

/// In-memory list of saved addresses, seeded with one default.
final List<DeliveryAddress> savedAddresses = [
  DeliveryAddress(
    id: 'addr_1',
    label: 'Home',
    address: 'Asokoro, Abuja',
    isDefault: true,
  ),
];

/// Returns the current default address, or null if none saved.
DeliveryAddress? get defaultAddress {
  try {
    return savedAddresses.firstWhere((a) => a.isDefault);
  } catch (_) {
    return savedAddresses.isNotEmpty ? savedAddresses.first : null;
  }
}

/// Add a new address. If [isDefault] is true, unsets the previous default.
void addAddress(DeliveryAddress addr) {
  if (addr.isDefault) {
    for (final a in savedAddresses) {
      a.isDefault = false;
    }
  }
  savedAddresses.add(addr);
  persistAddresses();
}

/// Remove an address by id.
void removeAddress(String id) {
  savedAddresses.removeWhere((a) => a.id == id);
  // If we removed the default, promote the first remaining address.
  if (savedAddresses.isNotEmpty && !savedAddresses.any((a) => a.isDefault)) {
    savedAddresses.first.isDefault = true;
  }
  persistAddresses();
}

/// Set an address as default by id.
void setDefaultAddress(String id) {
  for (final a in savedAddresses) {
    a.isDefault = a.id == id;
  }
  persistAddresses();
}

// ── Address persistence ────────────────────────────────────────────────────

DeliveryAddress deliveryAddressFromJson(Map<String, dynamic> json) =>
    DeliveryAddress(
      id: json['id'] as String,
      label: json['label'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> deliveryAddressToJson(DeliveryAddress a) => {
      'id': a.id,
      'label': a.label,
      'address': a.address,
      'phone': a.phone,
      'isDefault': a.isDefault,
    };

/// Persists the current saved addresses (best-effort, fire-and-forget).
void persistAddresses() {
  try {
    SharedPreferences.getInstance().then((prefs) => prefs.setString(
          'delivery_addresses_v1',
          jsonEncode(savedAddresses.map(deliveryAddressToJson).toList()),
        ));
  } catch (_) {}
}

/// Restores addresses from a previous session. If none were saved, the
/// seeded default address stays.
Future<void> restoreAddresses() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('delivery_addresses_v1');
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw) as List<dynamic>;
    savedAddresses
      ..clear()
      ..addAll(
          decoded.map((e) => deliveryAddressFromJson(e as Map<String, dynamic>)));
  } catch (_) {
    // Corrupt storage: keep the seeded default address.
  }
}

// ---------------------------------------------------------------------------
// Favorites (vendors) – persisted
// ---------------------------------------------------------------------------

/// Persists the current favorite vendors (best-effort, fire-and-forget).
void persistFavorites() {
  try {
    SharedPreferences.getInstance().then((prefs) => prefs.setString(
          'favorite_vendors_v1',
          jsonEncode(favoriteVendors),
        ));
  } catch (_) {}
}

/// Restores favorite vendors from a previous session.
Future<void> restoreFavorites() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('favorite_vendors_v1');
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw) as List<dynamic>;
    favoriteVendors
      ..clear()
      ..addAll(decoded.map((e) => Map<String, String>.from(e as Map)));
  } catch (_) {
    // Corrupt storage: start with no favorites.
  }
}

// ---------------------------------------------------------------------------
// Orders – snapshots taken at checkout, persisted so history survives
// ---------------------------------------------------------------------------

/// A single line on an order. [price] and [image] are **snapshots** taken at
/// checkout time, so a later catalog price/image change never rewrites past
/// orders.
class OrderItem {
  final String name;
  final String vendorName;
  final String category;
  final String image; // snapshot
  final int price; // snapshot, per unit at purchase time
  final int quantity;

  const OrderItem({
    required this.name,
    required this.vendorName,
    required this.category,
    required this.image,
    required this.price,
    required this.quantity,
  });

  int get lineTotal => price * quantity;

  Map<String, dynamic> toJson() => {
        'name': name,
        'vendorName': vendorName,
        'category': category,
        'image': image,
        'price': price,
        'quantity': quantity,
      };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        name: json['name'] as String,
        vendorName: json['vendorName'] as String? ?? '',
        category: json['category'] as String? ?? '',
        image: json['image'] as String? ?? '',
        price: json['price'] as int,
        quantity: json['quantity'] as int,
      );
}

/// A completed order. Immutable snapshot data; the live catalog is never
/// consulted when rendering history.
class StoredOrder {
  final String orderNumber; // e.g. 'GBX-10482' (no '#')
  final DateTime placedAt;
  final String status; // 'Order placed' | 'Delivered' | 'Cancelled' | 'Pending'
  final String deliveryAddress;
  final int deliveryFee;
  final List<OrderItem> items;

  const StoredOrder({
    required this.orderNumber,
    required this.placedAt,
    required this.status,
    required this.deliveryAddress,
    required this.deliveryFee,
    required this.items,
  });

  int get subtotal => items.fold(0, (s, i) => s + i.lineTotal);
  int get total => subtotal + deliveryFee;
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  String get category => switch (status) {
        'Delivered' => 'Completed',
        'Cancelled' => 'Cancelled',
        _ => 'Active', // 'Order placed' and 'Pending'
      };

  String get paymentStatus => status == 'Cancelled' ? 'Refunded' : 'Paid';

  Map<String, dynamic> toJson() => {
        'orderNumber': orderNumber,
        'placedAt': placedAt.toIso8601String(),
        'status': status,
        'deliveryAddress': deliveryAddress,
        'deliveryFee': deliveryFee,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory StoredOrder.fromJson(Map<String, dynamic> json) => StoredOrder(
        orderNumber: json['orderNumber'] as String,
        placedAt:
            DateTime.parse(json['placedAt'] as String),
        status: json['status'] as String? ?? 'Order placed',
        deliveryAddress: json['deliveryAddress'] as String? ?? '',
        deliveryFee: json['deliveryFee'] as int? ?? 0,
        items: (json['items'] as List<dynamic>)
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Order history: seeded with mock orders on first launch, then real orders
/// (recorded at checkout) are prepended and everything is persisted.
final List<StoredOrder> storedOrders = [];

String _mockOrderNumber(int n) => 'GBX-10${400 + n}';

/// Builds the default mock history (one per status) if none is stored.
void _seedStoredOrders() {
  if (storedOrders.isNotEmpty) return;
  final now = DateTime.now();
  const address =
      'No. 12 Gwarinpa Estate, Gwarinpa, Abuja, Nigeria';
  // Line items snapshot the canonical catalog product (price/image frozen at
  // seed time, like a real checkout would) — resolved by name so a catalog
  // rename/price change can never leave seeds pointing at stale copies.
  OrderItem item(String name, String vendor, [int qty = 1]) {
    final p = MockProducts.find(name: name, vendorName: vendor);
    if (p == null) {
      // Catalog drift guard: never crash seeding because of a rename.
      return OrderItem(
          name: name,
          vendorName: vendor,
          category: '',
          image: '',
          price: 0,
          quantity: qty);
    }
    return OrderItem(
        name: p.name,
        vendorName: p.vendorName,
        category: p.category,
        image: p.image,
        price: p.price,
        quantity: qty);
  }
  storedOrders.addAll([
    StoredOrder(
      orderNumber: _mockOrderNumber(82),
      placedAt: now.subtract(const Duration(days: 26)),
      status: 'Order placed',
      deliveryAddress: address,
      deliveryFee: 1500,
      items: [
        item('Rice', 'Green Farm', 2),
        item('Tomatoes', 'Yummy Bunch'),
        item('Fresh Vegetables', 'Real Green'),
      ],
    ),
    StoredOrder(
      orderNumber: _mockOrderNumber(31),
      placedAt: now.subtract(const Duration(days: 29)),
      status: 'Delivered',
      deliveryAddress: address,
      deliveryFee: 1500,
      items: [
        item('Fresh Apples', 'Heart of Red'),
        item('Beans', 'Green Farm'),
      ],
    ),
    StoredOrder(
      orderNumber: _mockOrderNumber(92),
      placedAt: now.subtract(const Duration(days: 31)),
      status: 'Cancelled',
      deliveryAddress: address,
      deliveryFee: 0,
      items: [item('Tomatoes', 'Yummy Bunch')],
    ),
    StoredOrder(
      orderNumber: _mockOrderNumber(75),
      placedAt: now.subtract(const Duration(days: 32)),
      status: 'Pending',
      deliveryAddress: address,
      deliveryFee: 1500,
      items: [
        item('Millet', 'Green Farm'),
        item('Fresh Vegetables', 'Real Green'),
      ],
    ),
  ]);
}

/// Restores order history; seeds mock orders when nothing is stored yet.
Future<void> restoreOrders() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('order_history_v1');
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      storedOrders
        ..clear()
        ..addAll(decoded
            .map((e) => StoredOrder.fromJson(e as Map<String, dynamic>)));
    } else {
      _seedStoredOrders();
      persistOrders();
    }
  } catch (_) {
    _seedStoredOrders();
  }
}

/// Persists order history (best-effort, fire-and-forget).
void persistOrders() {
  try {
    SharedPreferences.getInstance().then((prefs) => prefs.setString(
          'order_history_v1',
          jsonEncode(storedOrders.map((o) => o.toJson()).toList()),
        ));
  } catch (_) {}
}

StoredOrder? orderByNumber(String orderNumber) {
  try {
    return storedOrders.firstWhere((o) => o.orderNumber == orderNumber);
  } catch (_) {
    return null;
  }
}

/// Records a completed order from the current cart line items, snapshotting
/// each product's price and image at checkout time, then persists history.
StoredOrder recordOrder({
  required String orderNumber,
  required List<VendorProduct> cartItems,
  int deliveryFee = 0,
  String deliveryAddress = '',
  String status = 'Order placed',
}) {
  // Group duplicate cart entries (each entry is one unit) into one line item
  // per product while freezing the price/image seen at checkout.
  final grouped = <String, List<VendorProduct>>{};
  for (final p in cartItems) {
    grouped.putIfAbsent('${p.vendorName}\u0000${p.name}', () => []).add(p);
  }
  final items = grouped.values.map((list) {
    final p = list.first;
    return OrderItem(
      name: p.name,
      vendorName: p.vendorName,
      category: p.category,
      image: p.image,
      price: p.price,
      quantity: list.length,
    );
  }).toList();

  final order = StoredOrder(
    orderNumber: orderNumber.replaceAll('#', ''),
    placedAt: DateTime.now(),
    status: status,
    deliveryAddress: deliveryAddress,
    deliveryFee: deliveryFee,
    items: items,
  );
  storedOrders.insert(0, order); // newest first
  persistOrders();
  return order;
}

// ---------------------------------------------------------------------------
// Purchase History – tracks what the user has ordered for "Buy Again"
// ---------------------------------------------------------------------------

/// A single line item from a past order.
class PurchaseRecord {
  final VendorProduct product;
  final int quantity;
  final DateTime date;

  const PurchaseRecord({
    required this.product,
    required this.quantity,
    required this.date,
  });
}

/// In-memory purchase history (would be backed by a database in production).
final List<PurchaseRecord> purchaseHistory = [];

/// Seed some mock purchase history so the home screen has data to work with
/// immediately after launch.  In a real app this would come from the server.
void seedPurchaseHistory() {
  if (purchaseHistory.isNotEmpty) return; // already seeded

  final now = DateTime.now();

  // Resolve canonical catalog instances (never duplicate copies) so Buy Again
  // always reflects the current storefront product data.
  final allProducts = <VendorProduct>[
    MockProducts.find(name: 'Rice', vendorName: 'Green Farm')!,
    MockProducts.find(name: 'Millet', vendorName: 'Green Farm')!,
    MockProducts.find(name: 'Beans', vendorName: 'Green Farm')!,
    MockProducts.find(name: 'Tomatoes', vendorName: 'Yummy Bunch')!,
    MockProducts.find(name: 'Fresh Vegetables', vendorName: 'Real Green')!,
    MockProducts.find(name: 'Fresh Apples', vendorName: 'Heart of Red')!,
  ];

  // Simulate several past purchases at different dates
  purchaseHistory.addAll([
    PurchaseRecord(product: allProducts[0], quantity: 2, date: now.subtract(const Duration(days: 3))),
    PurchaseRecord(product: allProducts[0], quantity: 1, date: now.subtract(const Duration(days: 10))),
    PurchaseRecord(product: allProducts[2], quantity: 1, date: now.subtract(const Duration(days: 5))),
    PurchaseRecord(product: allProducts[3], quantity: 3, date: now.subtract(const Duration(days: 2))),
    PurchaseRecord(product: allProducts[3], quantity: 2, date: now.subtract(const Duration(days: 8))),
    PurchaseRecord(product: allProducts[4], quantity: 1, date: now.subtract(const Duration(days: 4))),
    PurchaseRecord(product: allProducts[5], quantity: 1, date: now.subtract(const Duration(days: 12))),
    PurchaseRecord(product: allProducts[1], quantity: 1, date: now.subtract(const Duration(days: 7))),
  ]);
}

/// Returns "Buy Again" items sorted by recency and frequency.
/// The most frequently + recently purchased items appear first.
List<VendorProduct> getBuyAgainItems() {
  if (purchaseHistory.isEmpty) return [];

  // Count purchases per product name and track the most recent date.
  final Map<String, int> frequency = {};
  final Map<String, DateTime> lastBought = {};
  final Map<String, VendorProduct> productLookup = {};

  for (final record in purchaseHistory) {
    final name = record.product.name;
    frequency[name] = (frequency[name] ?? 0) + record.quantity;
    productLookup[name] = record.product;
    if (lastBought[name] == null || record.date.isAfter(lastBought[name]!)) {
      lastBought[name] = record.date;
    }
  }

  final items = frequency.keys.toList();

  // Sort: most recently bought first, break ties by frequency (higher first).
  items.sort((a, b) {
    final dateCmp = lastBought[b]!.compareTo(lastBought[a]!);
    if (dateCmp != 0) return dateCmp;
    return frequency[b]!.compareTo(frequency[a]!);
  });

  return items.map((name) => productLookup[name]!).take(6).toList();
}

// ---------------------------------------------------------------------------
// Time-of-day personalisation
// ---------------------------------------------------------------------------

/// A set of product names that are relevant at a particular time of day.
class TimeSuggestion {
  final String greeting;
  final String subtitle;
  final List<String> suggestedCategories;
  final List<String> spotlightProducts;

  const TimeSuggestion({
    required this.greeting,
    required this.subtitle,
    required this.suggestedCategories,
    required this.spotlightProducts,
  });
}

/// Returns a personalised greeting and product suggestions based on the
/// current hour.
TimeSuggestion getTimeBasedSuggestion() {
  final hour = DateTime.now().hour;

  if (hour >= 5 && hour < 12) {
    // Morning – breakfast items
    return const TimeSuggestion(
      greeting: 'Good Morning ☀️',
      subtitle: 'Start your day with fresh produce',
      suggestedCategories: ['Grains', 'Fruits', 'Legumes'],
      spotlightProducts: ['Rice', 'Millet', 'Fresh Apples', 'Beans'],
    );
  } else if (hour >= 12 && hour < 17) {
    // Afternoon – lunch / cooking essentials
    return const TimeSuggestion(
      greeting: 'Good Afternoon 🌤',
      subtitle: 'Fresh picks for your afternoon meals',
      suggestedCategories: ['Vegetables', 'Proteins', 'Grains'],
      spotlightProducts: ['Tomatoes', 'Fresh Vegetables', 'Rice', 'Beans'],
    );
  } else if (hour >= 17 && hour < 21) {
    // Evening – dinner ingredients
    return const TimeSuggestion(
      greeting: 'Good Evening 🌅',
      subtitle: 'What\'s for dinner tonight?',
      suggestedCategories: ['Vegetables', 'Proteins', 'Herbs'],
      spotlightProducts: ['Fresh Vegetables', 'Tomatoes', 'Millet'],
    );
  } else {
    // Night – quick essentials / next-day planning
    return const TimeSuggestion(
      greeting: 'Good Night 🌙',
      subtitle: 'Plan tomorrow\'s fresh groceries',
      suggestedCategories: ['Grains', 'Vegetables', 'Fruits'],
      spotlightProducts: ['Rice', 'Fresh Vegetables', 'Fresh Apples'],
    );
  }
}

/// Returns the most-frequently-purchased category names, used to reorder
/// the home screen category chips based on the user's history.
List<String> getPersonalisedCategoryOrder() {
  if (purchaseHistory.isEmpty) {
    // Default order for new users.
    return const [
      'Grains and cereals',
      'Fruits',
      'Legumes and Pulses',
      'Vegetables',
      'Tuber and Roots',
      'Fresh Proteins',
      'Mushrooms',
      'Herbs and Spices',
      'Nuts and Seeds',
    ];
  }

  // Count purchases per top-level category.
  final Map<String, int> catCount = {};
  for (final record in purchaseHistory) {
    final cat = record.product.category;
    catCount[cat] = (catCount[cat] ?? 0) + record.quantity;
  }

  // Map internal category names to display names.
  const displayMap = {
    'GRAINS': 'Grains and cereals',
    'CEREALS': 'Grains and cereals',
    'LEGUMES': 'Legumes and Pulses',
    'FRUITS': 'Fruits',
    'VEGETABLES': 'Vegetables',
    'MEAT': 'Fresh Proteins',
    'FISH': 'Fresh Proteins',
  };

  // Aggregate by display name.
  final Map<String, int> displayCount = {};
  for (final entry in catCount.entries) {
    final display = displayMap[entry.key] ?? entry.key;
    displayCount[display] = (displayCount[display] ?? 0) + entry.value;
  }

  // Sort by purchase count descending.
  final sorted = displayCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final order = sorted.map((e) => e.key).toList();

  // Append any categories the user hasn't purchased yet.
  const allCategories = [
    'Grains and cereals',
    'Fruits',
    'Legumes and Pulses',
    'Vegetables',
    'Tuber and Roots',
    'Fresh Proteins',
    'Mushrooms',
    'Herbs and Spices',
    'Nuts and Seeds',
  ];
  for (final cat in allCategories) {
    if (!order.contains(cat)) order.add(cat);
  }

  return order;
}

/// Adds an item to the purchase history (called when an order is completed).
void recordPurchase(VendorProduct product, int quantity) {
  purchaseHistory.add(PurchaseRecord(
    product: product,
    quantity: quantity,
    date: DateTime.now(),
  ));
}

// ---------------------------------------------------------------------------
// Real-time Stock Levels
// ---------------------------------------------------------------------------

/// Stock status for a product.
enum StockStatus { inStock, lowStock, outOfStock }

/// Tracks real-time stock levels per product (keyed by 'vendorName:productName').
class StockTracker {
  StockTracker._();

  /// In-memory stock map: 'vendorName:productName' -> quantity remaining.
  static final Map<String, int> _stock = {};

  /// Low-stock threshold.
  static const int lowStockThreshold = 5;

  /// Initialize stock with mock data.
  static void seed() {
    if (_stock.isNotEmpty) return;
    // Green Farm products
    _stock['Green Farm:Rice'] = 45;
    _stock['Green Farm:Millet'] = 12;
    _stock['Green Farm:Maize'] = 30;
    _stock['Green Farm:Sorghum'] = 8;
    _stock['Green Farm:Beans'] = 3;
    _stock['Green Farm:Soybeans'] = 0;
    // Yummy Bunch
    _stock['Yummy Bunch:Tomatoes'] = 18;
    // Fresh off Flesh
    _stock['Fresh off Flesh:Fresh Produce'] = 7;
    // Heart of Red
    _stock['Heart of Red:Fresh Apples'] = 22;
    // Real Green
    _stock['Real Green:Fresh Vegetables'] = 2;
    _stock['Real Green:Potatoes'] = 9;
    // Cereals Greetings
    _stock['Cereals Greetings:Maize'] = 15;
    // Golden Oils
    _stock['Golden Oils:Palm Oil'] = 24;
    _stock['Golden Oils:Groundnut Oil'] = 5;
    _stock['Golden Oils:Vegetable Oil'] = 30;
  }

  /// Returns the quantity remaining for a product, or -1 if unknown.
  static int quantityFor(String vendorName, String productName) {
    return _stock['$vendorName:$productName'] ?? -1;
  }

  /// Returns the stock status for a product.
  static StockStatus statusFor(String vendorName, String productName) {
    final qty = quantityFor(vendorName, productName);
    if (qty == -1) return StockStatus.inStock; // unknown = assume in stock
    if (qty <= 0) return StockStatus.outOfStock;
    if (qty <= lowStockThreshold) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  /// Returns a human-readable label for the stock status.
  static String labelFor(String vendorName, String productName) {
    switch (statusFor(vendorName, productName)) {
      case StockStatus.outOfStock:
        return 'Out of Stock';
      case StockStatus.lowStock:
        final qty = quantityFor(vendorName, productName);
        return 'Only $qty left';
      case StockStatus.inStock:
        return 'In Stock';
    }
  }

  /// Whether the product can be added to cart.
  static bool isAvailable(String vendorName, String productName) {
    return statusFor(vendorName, productName) != StockStatus.outOfStock;
  }

  /// Attempt to decrement stock for a product. Returns true if successful.
  static bool decrement(String vendorName, String productName) {
    final key = '$vendorName:$productName';
    final qty = _stock[key];
    if (qty == null || qty <= 0) return false;
    _stock[key] = qty - 1;
    return true;
  }

  /// Restock a product (used when an order is cancelled).
  static void restock(String vendorName, String productName, int quantity) {
    final key = '$vendorName:$productName';
    _stock[key] = (_stock[key] ?? 0) + quantity;
  }

  /// Find a product by name pattern and decrement stock.
  /// Returns the vendor name if found and decremented, null otherwise.
  static String? findAndDecrementByName(String productName) {
    for (final entry in _stock.entries) {
      if (entry.key.endsWith(':$productName') && entry.value > 0) {
        final parts = entry.key.split(':');
        decrement(parts[0], parts[1]);
        return parts[0];
      }
    }
    return null;
  }
}
