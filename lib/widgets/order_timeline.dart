import 'package:flutter/material.dart';

import '../data/orders.dart';
import '../theme.dart';

/// The one status timeline: Confirmed → Packing → Picked up → On the way →
/// Delivered.
///
/// Order Details and Track Delivery used to draw their own, with different
/// step names, different marker styles and — on the details screen — a bare
/// "Done" where the pickup's time belonged. Both now render this, driven by
/// [status], so the same order cannot read as two different deliveries.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({
    super.key,
    required this.status,
    this.timestamps = const {},
    this.placedAt,
  });

  /// How far along the track the order is.
  final OrderStatus status;

  /// The order's event log: when each reached step happened.
  final Map<OrderStatus, DateTime> timestamps;

  /// When the order was placed. Used only to date a reached step that has no
  /// recorded event — see [_timeFor].
  final DateTime? placedAt;

  /// A completed step's time.
  ///
  /// The recorded event wins. A record with no event log at all (the legacy
  /// history, or a demo order) falls back to the delivery's own step ladder,
  /// capped at now, so a completed step always shows a time rather than a bare
  /// "Done". Only when there is no placement time either does it stay blank.
  DateTime? _timeFor(OrderStatus step) {
    final recorded = timestamps[step];
    if (recorded != null) return recorded;
    final base = placedAt;
    if (base == null) return null;
    final at = base.add(Duration(minutes: deliveryStepMinutes[step] ?? 0));
    final now = DateTime.now();
    return at.isAfter(now) ? now : at;
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = status == OrderStatus.cancelled;
    final track = orderTrack;

    /// A step behind the current one — or every step once the box has arrived.
    bool isDone(int index) {
      if (cancelled) return index == 0;
      if (status == OrderStatus.delivered) return true;
      return index < status.stepIndex;
    }

    bool isCurrent(int index) =>
        !cancelled && status != OrderStatus.delivered && index == status.stepIndex;

    final rows = <Widget>[];

    for (var i = 0; i < track.length; i++) {
      final step = track[i];
      final done = isDone(i);
      final current = isCurrent(i);
      // The segment below a dot belongs to the step it leads to, and only reads
      // as progress when both ends of it are complete.
      final connectsDone = done && i + 1 < track.length && isDone(i + 1);

      rows.add(
        _TimelineRow(
          title: step.label,
          state: done
              ? _StepState.done
              : current
                  ? _StepState.current
                  : _StepState.pending,
          at: done ? _timeFor(step) : null,
          isLast: i == track.length - 1 && !cancelled,
          connectorDone: connectsDone,
          icon: _iconFor(step),
          number: i + 1,
        ),
      );
    }

    if (cancelled) {
      rows.add(
        _TimelineRow(
          title: OrderStatus.cancelled.label,
          state: _StepState.cancelled,
          at: timestamps[OrderStatus.cancelled],
          isLast: true,
          connectorDone: false,
          icon: Icons.close,
          number: track.length + 1,
        ),
      );
    }

    return Container(
      key: const ValueKey('orderTimeline'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      decoration: BoxDecoration(
        color: C.surface(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: C.divider(context)),
      ),
      child: Column(children: rows),
    );
  }

  static IconData _iconFor(OrderStatus status) => switch (status) {
        OrderStatus.confirmed => Icons.receipt_long_outlined,
        OrderStatus.packing => Icons.inventory_2_outlined,
        OrderStatus.pickedUp => Icons.two_wheeler,
        OrderStatus.onTheWay => Icons.two_wheeler,
        OrderStatus.delivered => Icons.check_circle_outline,
        OrderStatus.cancelled => Icons.close,
      };
}

enum _StepState { done, current, pending, cancelled }

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.title,
    required this.state,
    required this.at,
    required this.isLast,
    required this.connectorDone,
    required this.icon,
    required this.number,
  });

  final String title;
  final _StepState state;

  /// When the step happened; only completed steps carry one.
  final DateTime? at;
  final bool isLast;

  /// Whether the connector below this row joins two completed steps.
  final bool connectorDone;
  final IconData icon;

  /// Shown inside a pending marker, so the remaining steps stay ordered.
  final int number;

  @override
  Widget build(BuildContext context) {
    final done = state == _StepState.done;
    final current = state == _StepState.current;
    final cancelled = state == _StepState.cancelled;

    // Pending rows use the muted token, which clears 4.5:1 on both backgrounds;
    // the requirement is at least 3:1, and this keeps them readable rather than
    // invisible.
    final titleColor = done || current || cancelled
        ? C.textPrimary(context)
        : C.textMuted(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Marker and connector ──────────────────────────────
          SizedBox(
            width: 28,
            child: Column(
              children: [
                _marker(context, done: done, current: current, cancelled: cancelled),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      // Primary only between two completed steps: a green line
                      // leading into a step that has not happened would claim
                      // progress the order does not have.
                      color: connectorDone
                          ? C.primary(context)
                          : C.divider(context),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // ── Title and time ────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 8 : AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 13,
                        fontWeight:
                            current ? FontWeight.w700 : FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _trailingLabel(),
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 12,
                      color: C.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The label on the right: a completed step's clock time, the current step's
  /// state, or nothing worth saying for a step that has not happened.
  String _trailingLabel() => switch (state) {
        _StepState.done => at == null ? 'Done' : formatOrderTime(at!),
        _StepState.current => 'In progress',
        _StepState.pending => 'Pending',
        _StepState.cancelled =>
          at == null ? '' : formatOrderTime(at!),
      };

  Widget _marker(
    BuildContext context, {
    required bool done,
    required bool current,
    required bool cancelled,
  }) {
    if (done) {
      return Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: C.primary(context),
          ),
          child: Icon(Icons.check, size: 14, color: C.onPrimary(context)),
        ),
      );
    }

    if (current) {
      // The step in progress carries its own icon and the bold title below it:
      // it is happening, not finished.
      return Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: C.primary(context),
          ),
          child: Icon(icon, size: 16, color: C.onPrimary(context)),
        ),
      );
    }

    if (cancelled) {
      return Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: C.errorBright(context),
          ),
          child: Icon(Icons.close, size: 14, color: C.onError(context)),
        ),
      );
    }

    // Pending: an empty ring with the step number, muted but readable.
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: C.textMuted(context), width: 1.5),
        ),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: C.textMuted(context),
            ),
          ),
        ),
      ),
    );
  }
}
