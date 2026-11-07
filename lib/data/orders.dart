import 'package:flutter/foundation.dart';

import 'app_state.dart';
import 'mock_data.dart';
import 'mock_backend.dart';
import 'payment_method.dart';

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

  /// The progress bars in the orders list, out of [progressSegmentsTotal].
  ///
  /// The list draws four bars for "confirmed → packing → on the way →
  /// delivered", while the delivery itself has five steps: picked up sits
  /// between packing and on the way, so it still belongs to the packing bar.
  int get progressSegments => switch (this) {
        OrderStatus.confirmed => 1,
        OrderStatus.packing => 2,
        OrderStatus.pickedUp => 2,
        OrderStatus.onTheWay => 3,
        OrderStatus.delivered => 4,
        OrderStatus.cancelled => 0,
      };

  /// How many bars the orders list draws.
  static const int progressSegmentsTotal = 4;

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
// Feedback
// ---------------------------------------------------------------------------

/// How the customer felt about a delivered order.
///
/// Vendors in this app are rated as "% liked", never on a 5-star scale, so the
/// feedback is a thumbs up / thumbs down. [skipped] is not an opinion: it only
/// records that the customer was asked and chose not to answer, which is what
/// keeps the prompt from appearing again.
enum OrderFeedback { liked, notGreat, skipped }

/// The chips offered when the customer says an order was not great. Optional
/// detail on top of the thumbs down, never required.
const List<String> orderFeedbackReasons = [
  'Late',
  'Wrong items',
  'Quality',
  'Packaging',
];

/// What the customer said about a delivered order.
///
/// Deliberately one value, [Order.rating]: null means "never asked", while
/// [OrderFeedback.skipped] means "asked and declined". The difference is what
/// makes the prompt appear exactly once.
class OrderRating {
  final OrderFeedback feedback;

  /// Chips the customer picked; only ever populated for [OrderFeedback.notGreat].
  final List<String> reasons;

  /// Free-text comment, or null when they left the field empty.
  final String? comment;

  const OrderRating({
    required this.feedback,
    this.reasons = const [],
    this.comment,
  });

  /// The customer answered the prompt (as opposed to dismissing it).
  bool get isRated => feedback != OrderFeedback.skipped;

  bool get liked => feedback == OrderFeedback.liked;

  /// `You liked it` / `Not great` — the one way the result is written.
  String get headline => switch (feedback) {
        OrderFeedback.liked => 'You liked it',
        OrderFeedback.notGreat => 'Not great',
        OrderFeedback.skipped => 'Feedback skipped',
      };

  Map<String, dynamic> toJson() => {
        'feedback': feedback.name,
        if (reasons.isNotEmpty) 'reasons': reasons,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
      };

  /// Unknown or missing feedback decodes as [OrderFeedback.skipped], so a
  /// record written by a newer build never re-opens the prompt.
  factory OrderRating.fromJson(Map<String, dynamic> json) => OrderRating(
        feedback: OrderFeedback.values.firstWhere(
          (value) => value.name == json['feedback'],
          orElse: () => OrderFeedback.skipped,
        ),
        reasons: (json['reasons'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        comment: json['comment'] as String?,
      );
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

  /// When each lifecycle step was reached, keyed by status.
  ///
  /// Only steps that have actually happened are present, and a missing time is
  /// not an error: the shared timeline falls back to [deliveryStepMinutes] plus
  /// the placement time, so a completed step still shows when it happened. A
  /// backend with an event log simply fills more entries.
  final Map<OrderStatus, DateTime> timestamps;

  /// When the delivery is expected, as promised at checkout.
  ///
  /// Null means the source never said; [eta] then falls back to the app's
  /// standard 30 minute delivery rather than the screens inventing a time.
  final DateTime? estimatedArrival;

  /// How the buyer chose to pay at checkout.
  ///
  /// Records that predate the choice default to "pay on delivery", which is
  /// the only method the app has ever been able to honour.
  final PaymentMethod paymentMethod;

  /// Free-text note the buyer left for the rider, or null when they skipped it.
  final String? riderNote;

  /// When the box arrived, or null while it hasn't.
  ///
  /// Mirrors [timestamps]`[OrderStatus.delivered]` for orders that carry an
  /// event log; it exists as its own field because the delivered card and the
  /// "Delivered at" headline read it without walking the log.
  final DateTime? deliveredAt;

  /// When the order was cancelled, if it was.
  final DateTime? cancelledAt;

  /// Why it was cancelled, or null when the source never said.
  final String? cancelReason;

  /// What the customer said about a delivered order, or null when they have
  /// not been asked. A [OrderFeedback.skipped] rating means asked-and-declined.
  final OrderRating? rating;

  const Order({
    required this.id,
    required this.vendorName,
    required this.status,
    required this.createdAt,
    required this.items,
    this.deliveryAddress = '',
    this.timestamps = const {},
    this.estimatedArrival,
    this.paymentMethod = PaymentMethod.payOnDelivery,
    this.riderNote,
    this.deliveredAt,
    this.cancelledAt,
    this.cancelReason,
    this.rating,
  });

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  /// Goods, delivery and total for this order, priced by the same calculator
  /// the cart and checkout use.
  ///
  /// Delivery is not stored on the order: it is the sum of each vendor's fee
  /// in the vendor model, so an order's receipt and the cart it came from can
  /// never quote different delivery charges.
  CartTotals get totals => CartTotals.forLines(
        items.map((item) =>
            (vendorName: item.vendorName, amount: item.lineTotal)),
      );

  int get subtotal => totals.subtotal;
  int get total => totals.total;

  /// Expected arrival: what the source said, or 30 minutes after placement.
  DateTime get eta =>
      estimatedArrival ?? createdAt.add(const Duration(minutes: 30));

  bool get isActive => status.isActive;

  /// Delivered, but the customer has not been asked how it was yet.
  ///
  /// A [OrderFeedback.skipped] rating counts as asked-and-answered, so it is
  /// not "awaiting" anything and must not re-open the prompt.
  bool get awaitsFeedback =>
      status == OrderStatus.delivered && rating == null;

  /// When the box arrived, falling back to the event log and then the promise.
  DateTime? get deliveredTime =>
      deliveredAt ?? timestamps[OrderStatus.delivered];

  /// Time [step] was reached, or null when it hasn't happened (or was never
  /// recorded).
  DateTime? timestampOf(OrderStatus step) => timestamps[step];

  Order copyWith({
    OrderStatus? status,
    Map<OrderStatus, DateTime>? timestamps,
    DateTime? estimatedArrival,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    String? cancelReason,
    OrderRating? rating,
  }) =>
      Order(
        id: id,
        vendorName: vendorName,
        status: status ?? this.status,
        createdAt: createdAt,
        items: items,
        deliveryAddress: deliveryAddress,
        timestamps: timestamps ?? this.timestamps,
        estimatedArrival: estimatedArrival ?? this.estimatedArrival,
        paymentMethod: paymentMethod,
        riderNote: riderNote,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        cancelReason: cancelReason ?? this.cancelReason,
        rating: rating ?? this.rating,
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

  /// Records the customer's thumbs up/down for a delivered order (or that
  /// they skipped the prompt). Real implementations post it to the backend;
  /// the vendor's "% liked" is then recomputed server-side.
  Future<void> rateOrder(String orderId, OrderRating rating);

  /// Cancels an order, optionally with a reason the customer will see.
  Future<void> cancelOrder(String orderId, {String? reason});

  /// Demo-only: pushes the promised arrival into the past, so "Running late"
  /// can be demonstrated without waiting.
  Future<void> makeLate(String orderId);
}

// ---------------------------------------------------------------------------
// Mapping a persisted checkout record
// ---------------------------------------------------------------------------

/// Minutes after placement at which a delivery reaches each step.
///
/// The mock event log uses it to stamp reached steps, and the shared timeline
/// falls back to it when a record predates its event log — so a completed step
/// always has a time to show instead of a bare "Done".
const Map<OrderStatus, int> deliveryStepMinutes = {
  OrderStatus.confirmed: 0,
  OrderStatus.packing: 5,
  OrderStatus.pickedUp: 9,
  OrderStatus.onTheWay: 12,
  OrderStatus.delivered: 30,
  OrderStatus.cancelled: 2,
};

/// The delivery's five steps, in order: the track every timeline draws.
///
/// Public because the shared timeline widget walks it too; there is exactly one
/// definition of what "a delivery" means.
const List<OrderStatus> orderTrack = [
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
  final timestamps = _timelineFor(status, o.placedAt, at);
  return Order(
    id: o.orderNumber,
    vendorName: vendorNameForItems(o.items),
    status: status,
    createdAt: o.placedAt,
    items: o.items,
    deliveryAddress: o.deliveryAddress,
    // The stored fee is legacy data: [Order.totals] prices delivery from the
    // vendor model, which is what every screen shows.
    timestamps: timestamps,
    // The checkout promise: a 30 minute delivery. A backend with a real ETA
    // fills this in from its own estimate.
    estimatedArrival: o.placedAt.add(const Duration(minutes: 30)),
    paymentMethod: o.paymentMethod,
    riderNote: o.riderNote,
    // The record's own stamp wins; a record written before the field existed
    // falls back to the event log, so the card always has a time to show.
    deliveredAt: o.deliveredAt ?? timestamps[OrderStatus.delivered],
    cancelledAt: o.cancelledAt ?? timestamps[OrderStatus.cancelled],
    cancelReason: o.cancelReason,
    rating: _ratingFromStored(o),
  );
}

/// The stored feedback, or null when the customer was never asked.
OrderRating? _ratingFromStored(StoredOrder o) {
  final feedback = o.feedback;
  if (feedback == null) return null;
  return OrderRating(
    feedback: OrderFeedback.values.firstWhere(
      (value) => value.name == feedback,
      orElse: () => OrderFeedback.skipped,
    ),
    reasons: o.feedbackReasons,
    comment: o.feedbackComment,
  );
}

/// An order-shaped snapshot of a checkout attempt that was never recorded.
///
/// The failure screen has to show what the attempt contained — vendor, items,
/// totals, address — but there is no stored order to read, because the write is
/// exactly what failed. This builds the same shape from the checkout draft, so
/// the screen prices it with [Order.totals] like every other order.
Order attemptedOrder({
  required String orderNumber,
  required List<OrderItem> items,
  required String deliveryAddress,
  PaymentMethod paymentMethod = PaymentMethod.payOnDelivery,
  DateTime? placedAt,
}) =>
    Order(
      id: orderNumber,
      vendorName: vendorNameForItems(items),
      status: OrderStatus.confirmed,
      createdAt: placedAt ?? DateTime.now(),
      items: items,
      deliveryAddress: deliveryAddress,
      paymentMethod: paymentMethod,
    );

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
String vendorNameForItems(List<OrderItem> items) {
  final names = <String>{
    for (final item in items)
      if (item.vendorName.isNotEmpty) item.vendorName,
  };
  if (names.isEmpty) return 'Growbox';
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
    final at = placedAt.add(Duration(minutes: deliveryStepMinutes[step] ?? 0));
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
    for (final step in orderTrack)
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

  /// Feedback left this session, keyed by order id. A [OrderFeedback.skipped]
  /// entry is what stops the prompt coming back.
  final Map<String, OrderRating> _ratings = {};

  /// Cancellation reasons supplied by the demo action, keyed by order id.
  final Map<String, String> _cancelReasons = {};

  /// Arrivals pushed into the past by [makeLate], keyed by order id.
  final Map<String, DateTime> _lateEtas = {};

  static const String _demoAddress =
      'No. 12 Gwarinpa Estate, Gwarinpa, Abuja, Nigeria';

  @override
  Future<List<Order>> getOrders() {
    // A real implementation would await the network here. The mock goes
    // through [MockBackend] instead: ~600ms of latency so the skeleton is
    // visible, a one-shot failure from the demo tools, and a 10s deadline.
    return MockBackend.run(() {
      final orders = <Order>[
        ...storedOrders.map((o) => orderFromStored(o, now: _now())),
        ...(_demoOrders ??= _buildDemoOrders()).map(_aged),
      ];

      final resolved = orders.map(_applyOverrides).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return List<Order>.unmodifiable(resolved);
    });
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

  @override
  Future<void> rateOrder(String orderId, OrderRating rating) async {
    _ratings[orderId] = rating;
  }

  /// Cancels and stamps the moment, so the tracking timeline and the
  /// "Cancelled" chip agree about when it happened.
  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    _statusOverrides[orderId] = OrderStatus.cancelled;
    (_timeOverrides[orderId] ??= {})[OrderStatus.cancelled] = _now();
    if (reason != null && reason.trim().isNotEmpty) {
      _cancelReasons[orderId] = reason.trim();
    }
  }

  /// Five minutes past the promise: late enough that every screen agrees it
  /// is late, close enough that "Running late" still reads as a wait.
  @override
  Future<void> makeLate(String orderId) async {
    _lateEtas[orderId] = _now().subtract(const Duration(minutes: 5));
  }

  /// Replays session-only changes over an order: the status ladder, feedback,
  /// the cancel reason and any pushed-back arrival.
  Order _applyOverrides(Order order) {
    final status = _statusOverrides[order.id];
    final times = _timeOverrides[order.id];
    final timestamps = times == null ? order.timestamps : {...order.timestamps, ...times};

    return order.copyWith(
      status: status,
      timestamps: timestamps,
      // The terminal stamps mirror the log, so every screen reads the same
      // moment whether it looks at the map or the field.
      deliveredAt: timestamps[OrderStatus.delivered],
      cancelledAt: timestamps[OrderStatus.cancelled],
      cancelReason: _cancelReasons[order.id],
      rating: _ratings[order.id],
      estimatedArrival: _lateEtas[order.id],
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
  /// Ages are 7 < 11 < 18 minutes, one step of [deliveryStepMinutes] apart, so each
  /// has reached its status but not the next one. The status is not authored
  /// here: [_aged] derives it from the age, so the ladder is a consequence of
  /// the placement times instead of a second copy of them.
  List<Order> _buildDemoOrders() {
    final now = _now();

    Order demo({
      required String id,
      required String vendorName,
      required Duration age,
      required List<OrderItem> items,
    }) {
      final placedAt = now.subtract(age);
      return Order(
        id: id,
        vendorName: vendorName,
        status: _stageReached(placedAt),
        createdAt: placedAt,
        deliveryAddress: _demoAddress,
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
        items: [
          _demoItem('Rice', 'Green Farm'),
          _demoItem('Beans', 'Green Farm'),
        ],
      ),
      demo(
        id: 'GBX-10528',
        vendorName: 'Real Green',
        age: const Duration(minutes: 11),
        items: [_demoItem('Fresh Vegetables', 'Real Green')],
      ),
      demo(
        id: 'GBX-10521',
        vendorName: 'Yummy Bunch',
        age: const Duration(minutes: 7),
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
    final timestamps = _timelineFor(status, order.createdAt, _now());
    return order.copyWith(
      status: status,
      timestamps: timestamps,
      deliveredAt: timestamps[OrderStatus.delivered],
    );
  }

  /// Furthest step a delivery placed at [placedAt] has reached by now.
  OrderStatus _stageReached(DateTime placedAt) {
    final minutes = _now().difference(placedAt).inMinutes;
    return orderTrack.lastWhere(
      (step) => minutes >= (deliveryStepMinutes[step] ?? 0),
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
  Object? _error;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  /// The last failure, cleared by the next successful load. Screens show it
  /// only while there is no earlier list to keep on screen.
  Object? get error => _error;

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

  /// Newest delivered order the customer has not answered about yet.
  ///
  /// Only orders with no rating at all qualify: a skipped one has an answer
  /// ("they declined") and must never be asked about again.
  Order? get latestAwaitingFeedback {
    for (final order in _orders) {
      if (order.status == OrderStatus.delivered && order.rating == null) {
        return order;
      }
    }
    return null;
  }

  /// Loads orders once; [force] refetches (used when opening the orders screen).
  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await _repository.getOrders();
      _hasLoaded = true;
    } catch (error) {
      // Recorded, not rethrown: the screen renders the failure, and a failed
      // refetch keeps the list it was already showing.
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Advances an order for the demo and republishes the list from the source.
  Future<void> advanceStatus(String orderId) =>
      _mutate(() => _repository.advanceStatus(orderId));

  /// Records the customer's feedback for a delivered order.
  Future<void> rate(String orderId, OrderRating rating) =>
      _mutate(() => _repository.rateOrder(orderId, rating));

  /// Cancels an order and refreshes, so it moves from Active to Past.
  Future<void> cancel(String orderId, {String? reason}) =>
      _mutate(() => _repository.cancelOrder(orderId, reason: reason));

  /// Demo-only: makes the order late, then republishes it.
  Future<void> makeLate(String orderId) =>
      _mutate(() => _repository.makeLate(orderId));

  /// Runs a write then republishes the list, keeping the previous list if
  /// either step fails (the screens show the error only when there is no
  /// earlier list to keep).
  Future<void> _mutate(Future<void> Function() change) async {
    try {
      await change();
      _orders = await _repository.getOrders();
      _error = null;
    } catch (error) {
      _error = error;
    }
    notifyListeners();
  }
}

/// App-wide instance. `main()` warms it up before the first frame.
final OrdersStore ordersStore = OrdersStore(MockOrdersRepository());
