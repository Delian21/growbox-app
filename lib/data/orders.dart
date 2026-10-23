import 'package:flutter/foundation.dart';

import 'app_state.dart';
import 'mock_data.dart';

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

/// Where an order is in its lifecycle, from placement to the doorstep.
enum OrderStatus {
  confirmed,
  packing,
  onTheWay,
  delivered,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  /// Human label used on chips and in the details screen.
  String get label => switch (this) {
        OrderStatus.confirmed => 'Confirmed',
        OrderStatus.packing => 'Packing',
        OrderStatus.onTheWay => 'On the way',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  /// Orders still moving are "active"; delivered and cancelled are "past".
  bool get isActive =>
      this == OrderStatus.confirmed ||
      this == OrderStatus.packing ||
      this == OrderStatus.onTheWay;

  /// Position on the confirmed → packing → on the way → delivered track.
  /// -1 for [OrderStatus.cancelled], which leaves the track entirely.
  int get stepIndex => switch (this) {
        OrderStatus.confirmed => 0,
        OrderStatus.packing => 1,
        OrderStatus.onTheWay => 2,
        OrderStatus.delivered => 3,
        OrderStatus.cancelled => -1,
      };

  /// The next state the demo "advance" action moves to, if any.
  OrderStatus? get nextActive => switch (this) {
        OrderStatus.confirmed => OrderStatus.packing,
        OrderStatus.packing => OrderStatus.onTheWay,
        OrderStatus.onTheWay => OrderStatus.delivered,
        OrderStatus.delivered => null,
        OrderStatus.cancelled => null,
      };
}

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// A single order as the UI sees it.
///
/// Deliberately plain data with no knowledge of where it came from: whether it
/// is served by [MockOrdersRepository] or a real HTTP backend, widgets only
/// consume this type.
class Order {
  final String id;
  final String vendorName;
  final OrderStatus status;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String deliveryAddress;
  final int deliveryFee;

  const Order({
    required this.id,
    required this.vendorName,
    required this.status,
    required this.createdAt,
    required this.items,
    this.deliveryAddress = '',
    this.deliveryFee = 0,
  });

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  int get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);
  int get total => subtotal + deliveryFee;

  bool get isActive => status.isActive;

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        vendorName: vendorName,
        status: status ?? this.status,
        createdAt: createdAt,
        items: items,
        deliveryAddress: deliveryAddress,
        deliveryFee: deliveryFee,
      );
}

// ---------------------------------------------------------------------------
// Repository contract
// ---------------------------------------------------------------------------

/// Source of orders.
///
/// The screens depend only on this interface, so replacing [MockOrdersRepository]
/// with a real implementation (REST, GraphQL, local database) is a one-line
/// change at the app's composition point and no widget changes.
abstract class OrdersRepository {
  /// All orders, newest first.
  Future<List<Order>> getOrders();

  /// Moves an order one step along its lifecycle. Demo-only: a real backend
  /// would not expose an arbitrary "advance" mutation to the client.
  Future<void> advanceStatus(String orderId);
}

// ---------------------------------------------------------------------------
// Mock implementation
// ---------------------------------------------------------------------------

/// Serves the app's existing mock order history ([storedOrders]) plus a couple
/// of recent active orders, so every status has something to show.
class MockOrdersRepository implements OrdersRepository {
  /// Status changes made by [advanceStatus], keyed by order id. Kept in memory
  /// for the session, which is enough for a demo and mirrors what a real
  /// backend would persist server-side.
  final Map<String, OrderStatus> _statusOverrides = {};

  static const String _demoAddress =
      'No. 12 Gwarinpa Estate, Gwarinpa, Abuja, Nigeria';

  @override
  Future<List<Order>> getOrders() async {
    // A real implementation would await the network here; the mock resolves on
    // the next microtask, so the loading state is still exercised.
    final orders = <Order>[
      ...storedOrders.map(_fromStoredOrder),
      ..._recentActiveOrders(),
    ];

    final resolved = [
      for (final order in orders)
        _statusOverrides.containsKey(order.id)
            ? order.copyWith(status: _statusOverrides[order.id])
            : order,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return List<Order>.unmodifiable(resolved);
  }

  @override
  Future<void> advanceStatus(String orderId) async {
    final orders = await getOrders();
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return;
    final next = orders[index].status.nextActive;
    if (next == null) return;
    _statusOverrides[orderId] = next;
  }

  /// Maps a persisted checkout record onto the UI model.
  static Order _fromStoredOrder(StoredOrder o) => Order(
        id: o.orderNumber,
        vendorName: _vendorLabel(o.items),
        status: _legacyStatus(o.status),
        createdAt: o.placedAt,
        items: o.items,
        deliveryAddress: o.deliveryAddress,
        deliveryFee: o.deliveryFee,
      );

  /// The legacy records store free-text statuses; they map onto the enum.
  static OrderStatus _legacyStatus(String status) => switch (status) {
        'Delivered' => OrderStatus.delivered,
        'Cancelled' => OrderStatus.cancelled,
        'Pending' => OrderStatus.packing,
        _ => OrderStatus.confirmed,
      };

  /// One vendor name, or "First +N" when a box spans several vendors.
  static String _vendorLabel(List<OrderItem> items) {
    final names = <String>{
      for (final item in items)
        if (item.vendorName.isNotEmpty) item.vendorName,
    };
    if (names.isEmpty) return 'GROWBOX';
    if (names.length == 1) return names.first;
    return '${names.first} +${names.length - 1}';
  }

  /// Two fresh active orders so "packing" and "on the way" are visible without
  /// waiting on a real delivery.
  static List<Order> _recentActiveOrders() {
    final now = DateTime.now();
    return [
      Order(
        id: 'GBX-10536',
        vendorName: 'Green Farm',
        status: OrderStatus.onTheWay,
        createdAt: now.subtract(const Duration(minutes: 18)),
        deliveryAddress: _demoAddress,
        deliveryFee: 500,
        items: [
          _demoItem('Rice', 'Green Farm'),
          _demoItem('Beans', 'Green Farm'),
        ],
      ),
      Order(
        id: 'GBX-10521',
        vendorName: 'Yummy Bunch',
        status: OrderStatus.packing,
        createdAt: now.subtract(const Duration(minutes: 55)),
        deliveryAddress: _demoAddress,
        deliveryFee: 500,
        items: [_demoItem('Tomatoes', 'Yummy Bunch', qty: 2)],
      ),
    ];
  }

  /// Snapshots the canonical catalog entry, like a real checkout would.
  static OrderItem _demoItem(String name, String vendorName, {int qty = 1}) {
    final product = MockProducts.find(name: name, vendorName: vendorName);
    return OrderItem(
      name: product?.name ?? name,
      vendorName: product?.vendorName ?? vendorName,
      category: product?.category ?? '',
      image: product?.image ?? '',
      price: product?.price ?? 0,
      quantity: qty,
    );
  }
}

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

/// Holds the loaded orders and notifies the UI when they change.
///
/// This is the single place the app talks to an [OrdersRepository]; swapping
/// the repository (or injecting a fake in a test) never touches a widget.
class OrdersStore extends ChangeNotifier {
  OrdersStore(this._repository);

  final OrdersRepository _repository;

  List<Order> _orders = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  /// Orders that have not been delivered or cancelled, newest first.
  List<Order> get activeOrders =>
      _orders.where((order) => order.isActive).toList();

  /// Delivered and cancelled orders, newest first.
  List<Order> get pastOrders =>
      _orders.where((order) => !order.isActive).toList();

  /// Newest in-flight order, or null when nothing is on its way.
  Order? get latestActiveOrder {
    final active = activeOrders;
    return active.isEmpty ? null : active.first;
  }

  /// Loads orders once; [force] refetches (used when opening the orders screen).
  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force) return;

    _isLoading = true;
    notifyListeners();
    try {
      _orders = await _repository.getOrders();
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Advances an order for the demo and republishes the list from the source.
  Future<void> advanceStatus(String orderId) async {
    await _repository.advanceStatus(orderId);
    _orders = await _repository.getOrders();
    notifyListeners();
  }
}

/// App-wide instance. `main()` warms it up before the first frame.
final OrdersStore ordersStore = OrdersStore(MockOrdersRepository());
