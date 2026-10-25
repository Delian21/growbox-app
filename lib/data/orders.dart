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
  pickedUp,
  onTheWay,
  delivered,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  /// Human label used on chips and in the details screen.
  String get label => switch (this) {
        OrderStatus.confirmed => 'Confirmed',
        OrderStatus.packing => 'Packing',
        OrderStatus.pickedUp => 'Picked up',
        OrderStatus.onTheWay => 'On the way',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  /// Orders still moving are "active"; delivered and cancelled are "past".
  bool get isActive =>
      this == OrderStatus.confirmed ||
      this == OrderStatus.packing ||
      this == OrderStatus.pickedUp ||
      this == OrderStatus.onTheWay;

  /// Position on the confirmed → packing → picked up → on the way → delivered
  /// track. -1 for [OrderStatus.cancelled], which leaves the track entirely.
  int get stepIndex => switch (this) {
        OrderStatus.confirmed => 0,
        OrderStatus.packing => 1,
        OrderStatus.pickedUp => 2,
        OrderStatus.onTheWay => 3,
        OrderStatus.delivered => 4,
        OrderStatus.cancelled => -1,
      };

  /// The next state the demo "advance" action moves to, if any.
  OrderStatus? get nextActive => switch (this) {
        OrderStatus.confirmed => OrderStatus.packing,
        OrderStatus.packing => OrderStatus.pickedUp,
        OrderStatus.pickedUp => OrderStatus.onTheWay,
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

  /// When each lifecycle step was reached, keyed by status.
  ///
  /// Only steps that have actually happened are present, and a missing time is
  /// not an error: the details screen falls back to a plain "Done"/"Pending"
  /// label. A backend with an event log simply fills more entries.
  final Map<OrderStatus, DateTime> timestamps;

  /// When the delivery is expected, as promised at checkout.
  ///
  /// Null means the source never said; [eta] then falls back to the app's
  /// standard 30 minute delivery rather than the screens inventing a time.
  final DateTime? estimatedArrival;

  const Order({
    required this.id,
    required this.vendorName,
    required this.status,
    required this.createdAt,
    required this.items,
    this.deliveryAddress = '',
    this.deliveryFee = 0,
    this.timestamps = const {},
    this.estimatedArrival,
  });

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  int get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);
  int get total => subtotal + deliveryFee;

  /// Expected arrival: what the source said, or 30 minutes after placement.
  DateTime get eta =>
      estimatedArrival ?? createdAt.add(const Duration(minutes: 30));

  bool get isActive => status.isActive;

  /// Time [step] was reached, or null when it hasn't happened (or was never
  /// recorded).
  DateTime? timestampOf(OrderStatus step) => timestamps[step];

  Order copyWith({
    OrderStatus? status,
    Map<OrderStatus, DateTime>? timestamps,
  }) =>
      Order(
        id: id,
        vendorName: vendorName,
        status: status ?? this.status,
        createdAt: createdAt,
        items: items,
        deliveryAddress: deliveryAddress,
        deliveryFee: deliveryFee,
        timestamps: timestamps ?? this.timestamps,
        estimatedArrival: estimatedArrival,
      );
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `Oct 24, 2026` — shared by the orders list and the details screen.
String formatOrderDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// `3:42 PM`, 12-hour clock without a leading zero.
String formatOrderTime(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// `#GBX-10482` — the one way the app writes an order number.
///
/// Every screen used to build its own: the confirmation screen prefixed the
/// stored id with `#`, while the tracking screen was handed a bare `10482` and
/// produced a different number for the same order.
String orderNumberLabel(String id) => '#${id.replaceAll('#', '')}';

/// `About 30 min · by 5:05 PM` — the one way the app writes an arrival.
///
/// [now] is injectable so tests and the demo clock do not depend on the wall
/// clock. An arrival that has already passed reads as "Any minute now" instead
/// of claiming a negative wait.
String formatArrival(DateTime arrival, {DateTime? now}) {
  final remaining = arrival.difference(now ?? DateTime.now()).inMinutes;
  final wait = remaining <= 1 ? 'Any minute now' : 'About $remaining min';
  return '$wait · by ${formatOrderTime(arrival)}';
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
// Mapping a persisted checkout record
// ---------------------------------------------------------------------------

/// Minutes after placement at which a delivery reaches each step.
const Map<OrderStatus, int> _stepMinutes = {
  OrderStatus.confirmed: 0,
  OrderStatus.packing: 5,
  OrderStatus.pickedUp: 9,
  OrderStatus.onTheWay: 12,
  OrderStatus.delivered: 30,
  OrderStatus.cancelled: 2,
};

const List<OrderStatus> _track = [
  OrderStatus.confirmed,
  OrderStatus.packing,
  OrderStatus.pickedUp,
  OrderStatus.onTheWay,
  OrderStatus.delivered,
];

/// How long a legacy in-flight record may stay in flight.
///
/// A delivery is a same-day affair, so a record this old that still claims to
/// be "Order placed" or "Pending" is history, not a live order: the seeded
/// history contains exactly such records, and trusting them put a month-old
/// card in Active and kept the home banner alive forever.
const Duration _staleInFlight = Duration(hours: 24);

/// Maps a persisted checkout record onto the UI model.
///
/// Shared by the repository's history and by checkout's confirmation screen, so
/// the two can never disagree about the same order. [now] is injectable for the
/// demo clock.
Order orderFromStored(StoredOrder o, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final status = _statusForStored(o, at);
  return Order(
    id: o.orderNumber,
    vendorName: _vendorLabel(o.items),
    status: status,
    createdAt: o.placedAt,
    items: o.items,
    deliveryAddress: o.deliveryAddress,
    deliveryFee: o.deliveryFee,
    timestamps: _timelineFor(status, o.placedAt, at),
    // The checkout promise: a 30 minute delivery. A backend with a real ETA
    // fills this in from its own estimate.
    estimatedArrival: o.placedAt.add(const Duration(minutes: 30)),
  );
}

/// Status of a legacy record, with stale in-flight records retired.
///
/// Records carry no event log, so a completed delivery is the only terminal
/// state the record itself supports; the alternative would be dropping the
/// order from both tabs. A record that is genuinely recent keeps its live
/// status, so a just-checked-out order still lands in Active.
OrderStatus _statusForStored(StoredOrder o, DateTime now) {
  final status = _legacyStatus(o.status);
  if (!status.isActive) return status;
  return now.difference(o.placedAt) > _staleInFlight
      ? OrderStatus.delivered
      : status;
}

/// The legacy records store free-text statuses; they map onto the enum.
OrderStatus _legacyStatus(String status) => switch (status) {
      'Delivered' => OrderStatus.delivered,
      'Cancelled' => OrderStatus.cancelled,
      'Pending' => OrderStatus.packing,
      _ => OrderStatus.confirmed,
    };

/// One vendor name, or "First +N" when a box spans several vendors.
String _vendorLabel(List<OrderItem> items) {
  final names = <String>{
    for (final item in items)
      if (item.vendorName.isNotEmpty) item.vendorName,
  };
  if (names.isEmpty) return 'GROWBOX';
  if (names.length == 1) return names.first;
  return '${names.first} +${names.length - 1}';
}

/// Mock event log: each reached step is stamped a fixed number of minutes after
/// placement, capped at [now] so no step is ever dated in the future. A backend
/// that returns real events makes this unnecessary.
Map<OrderStatus, DateTime> _timelineFor(
  OrderStatus status,
  DateTime placedAt,
  DateTime now,
) {
  DateTime stamp(OrderStatus step) {
    final at = placedAt.add(Duration(minutes: _stepMinutes[step] ?? 0));
    return at.isAfter(now) ? now : at;
  }

  if (status == OrderStatus.cancelled) {
    return {
      OrderStatus.confirmed: stamp(OrderStatus.confirmed),
      OrderStatus.cancelled: stamp(OrderStatus.cancelled),
    };
  }

  // Delivered is the last step on the track, so `<=` covers everything reached
  // on the way to it.
  return {
    for (final step in _track)
      if (step.stepIndex <= status.stepIndex) step: stamp(step),
  };
}

// ---------------------------------------------------------------------------
// Mock implementation
// ---------------------------------------------------------------------------

/// Serves the app's existing mock order history ([storedOrders]) plus a few
/// demo deliveries, so every in-flight status has something to show.
class MockOrdersRepository implements OrdersRepository {
  /// [clock] exists so a test can move time forward and watch the demo
  /// deliveries age; the app leaves it at the wall clock.
  MockOrdersRepository({DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  /// Status changes made by [advanceStatus], keyed by order id. Kept in memory
  /// for the session, which is enough for a demo and mirrors what a real
  /// backend would persist server-side.
  final Map<String, OrderStatus> _statusOverrides = {};

  /// When the overridden status was reached, keyed by order id.
  final Map<String, Map<OrderStatus, DateTime>> _timeOverrides = {};

  static const String _demoAddress =
      'No. 12 Gwarinpa Estate, Gwarinpa, Abuja, Nigeria';

  @override
  Future<List<Order>> getOrders() async {
    // A real implementation would await the network here; the mock resolves on
    // the next microtask, so the loading state is still exercised.
    final orders = <Order>[
      ...storedOrders.map((o) => orderFromStored(o, now: _now())),
      ...(_demoOrders ??= _buildDemoOrders()).map(_aged),
    ];

    final resolved = orders.map(_applyOverrides).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
    // Stamp the transition so the details timeline moves with the status.
    (_timeOverrides[orderId] ??= {})[next] = _now();
  }

  /// Replays session-only status changes over a stored order.
  Order _applyOverrides(Order order) {
    final status = _statusOverrides[order.id];
    final times = _timeOverrides[order.id];
    if (status == null && times == null) return order;
    return order.copyWith(
      status: status,
      timestamps: {...order.timestamps, ...?times},
    );
  }

  /// The demo deliveries, placed once and then left to age.
  ///
  /// They used to be re-stamped relative to now on every fetch, which pinned
  /// their ages at 7/11/18 minutes forever: nothing ever delivered, the home
  /// banner never cleared and Active could never empty. Built on the first
  /// fetch and cached, so they move like real orders.
  List<Order>? _demoOrders;

  /// Three deliveries so "packing", "picked up" and "on the way" are each
  /// visible without the debug button or a real checkout.
  ///
  /// Ages are 7 < 11 < 18 minutes, one step of [_stepMinutes] apart, so each
  /// has reached its status but not the next one. The status is not authored
  /// here: [_aged] derives it from the age, so the ladder is a consequence of
  /// the placement times instead of a second copy of them.
  List<Order> _buildDemoOrders() {
    final now = _now();

    Order demo({
      required String id,
      required String vendorName,
      required Duration age,
      required int deliveryFee,
      required List<OrderItem> items,
    }) {
      final placedAt = now.subtract(age);
      return Order(
        id: id,
        vendorName: vendorName,
        status: _stageReached(placedAt),
        createdAt: placedAt,
        deliveryAddress: _demoAddress,
        deliveryFee: deliveryFee,
        // Filled in by [_aged] from the status above.
        timestamps: const {},
        items: items,
        estimatedArrival: placedAt.add(const Duration(minutes: 30)),
      );
    }

    return [
      demo(
        id: 'GBX-10536',
        vendorName: 'Green Farm',
        age: const Duration(minutes: 18),
        deliveryFee: 500,
        items: [
          _demoItem('Rice', 'Green Farm'),
          _demoItem('Beans', 'Green Farm'),
        ],
      ),
      demo(
        id: 'GBX-10528',
        vendorName: 'Real Green',
        age: const Duration(minutes: 11),
        deliveryFee: 800,
        items: [_demoItem('Fresh Vegetables', 'Real Green')],
      ),
      demo(
        id: 'GBX-10521',
        vendorName: 'Yummy Bunch',
        age: const Duration(minutes: 7),
        deliveryFee: 500,
        items: [_demoItem('Tomatoes', 'Yummy Bunch', qty: 2)],
      ),
    ];
  }

  /// A demo delivery as it stands right now.
  ///
  /// Status and timeline come from the placement time, so the demo advances on
  /// its own — packing at 5 minutes, picked up at 9, on the way at 12,
  /// delivered at 30 — and once every demo has been delivered Active is
  /// genuinely empty.
  Order _aged(Order order) {
    final status = _stageReached(order.createdAt);
    return order.copyWith(
      status: status,
      timestamps: _timelineFor(status, order.createdAt, _now()),
    );
  }

  /// Furthest step a delivery placed at [placedAt] has reached by now.
  OrderStatus _stageReached(DateTime placedAt) {
    final minutes = _now().difference(placedAt).inMinutes;
    return _track.lastWhere(
      (step) => minutes >= (_stepMinutes[step] ?? 0),
      orElse: () => OrderStatus.confirmed,
    );
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
