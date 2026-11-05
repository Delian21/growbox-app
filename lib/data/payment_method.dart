/// How an order will be paid for, chosen at checkout.
///
/// Only [payOnDelivery] is wired up: there is no card entry, gateway or
/// webhook anywhere in the app, so the other two are listed but cannot be
/// selected yet.
enum PaymentMethod {
  payOnDelivery('Pay on delivery', 'Have the cash ready for the rider'),
  card('Card', 'Coming soon'),
  bankTransfer('Bank transfer', 'Coming soon');

  const PaymentMethod(this.label, this.subtitle);

  /// What the option is called in the UI.
  final String label;

  /// The line under the label: a description for a working option, or the
  /// reason a listed one cannot be picked.
  final String subtitle;

  /// Whether this option can actually be chosen today.
  bool get isAvailable => this == PaymentMethod.payOnDelivery;

  /// Stable id for persistence, so renaming a value never rewrites history.
  String get id => name;

  /// Reads a persisted id; anything unknown (or a legacy record that predates
  /// payment methods) falls back to the only option that ever worked.
  static PaymentMethod fromId(String? id) => values.firstWhere(
    (method) => method.id == id,
    orElse: () => PaymentMethod.payOnDelivery,
  );
}
