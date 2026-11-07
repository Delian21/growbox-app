import 'package:flutter/material.dart';

import '../data/orders.dart';
import '../theme.dart';
import 'app_button.dart';

/// Asks how a delivered order went and returns the answer.
///
/// Vendors are rated as the share of customers who liked them, so the question
/// is thumbs up / thumbs down rather than stars: "Liked it" maps to a like and
/// "Not great" to a dislike, with optional chips and a comment explaining why.
///
/// Resolves to [OrderRating] in every case, including a swipe-away: closing the
/// sheet is the same answer as "Skip", because the customer was asked and the
/// prompt must not come back either way. Nothing is saved here — the caller
/// records it, so the same sheet works from the orders list and from tracking.
Future<OrderRating> showOrderRatingSheet(
  BuildContext context, {
  required String vendorName,
}) async {
  final result = await showModalBottomSheet<OrderRating>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _OrderRatingSheet(vendorName: vendorName),
  );
  return result ?? const OrderRating(feedback: OrderFeedback.skipped);
}

class _OrderRatingSheet extends StatefulWidget {
  const _OrderRatingSheet({required this.vendorName});

  final String vendorName;

  @override
  State<_OrderRatingSheet> createState() => _OrderRatingSheetState();
}

class _OrderRatingSheetState extends State<_OrderRatingSheet> {
  /// Null until the customer picks a thumb; the send button stays disabled
  /// so an empty sheet can never post a rating with no answer.
  OrderFeedback? _feedback;

  /// Chips, only meaningful for "Not great", so switching back to "Liked it"
  /// clears them instead of sending reasons with a like.
  final Set<String> _reasons = {};

  final TextEditingController _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _choose(OrderFeedback feedback) {
    setState(() {
      _feedback = feedback;
      if (feedback != OrderFeedback.notGreat) _reasons.clear();
    });
  }

  void _submit() {
    final feedback = _feedback;
    if (feedback == null) return;
    final comment = _comment.text.trim();
    Navigator.pop(
      context,
      OrderRating(
        feedback: feedback,
        reasons: feedback == OrderFeedback.notGreat
            ? (orderFeedbackReasons.where(_reasons.contains).toList())
            : const [],
        comment: comment.isEmpty ? null : comment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // Lifts the sheet above the keyboard while the comment is typed.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle: the sheet is dismissible, so it says so.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.surfaceLighter(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Did you enjoy your order from ${widget.vendorName}?',
                style: AppTypography.labelLarge.copyWith(
                  fontSize: 18,
                  height: 1.35,
                  color: C.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your answer helps other customers pick a vendor.',
                style: AppTypography.bodySmall.copyWith(
                  color: C.textSecondary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _ThumbOption(
                      icon: Icons.thumb_up_alt_rounded,
                      label: 'Liked it',
                      selected: _feedback == OrderFeedback.liked,
                      onTap: () => _choose(OrderFeedback.liked),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ThumbOption(
                      icon: Icons.thumb_down_alt_rounded,
                      label: 'Not great',
                      selected: _feedback == OrderFeedback.notGreat,
                      onTap: () => _choose(OrderFeedback.notGreat),
                    ),
                  ),
                ],
              ),
              // The follow-up only exists for a thumbs down: a happy customer
              // has nothing to explain, and asking anyway reads as fishing.
              if (_feedback == OrderFeedback.notGreat) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'What went wrong? (optional)',
                  style: AppTypography.labelSmall.copyWith(
                    color: C.textSecondary(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final reason in orderFeedbackReasons)
                      _FeedbackChip(
                        label: reason,
                        selected: _reasons.contains(reason),
                        onTap: () => setState(() {
                          if (!_reasons.remove(reason)) _reasons.add(reason);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _comment,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  style: AppTypography.bodyMedium.copyWith(
                    color: C.textPrimary(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Anything else we should know?',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: C.textMuted(context),
                    ),
                    filled: true,
                    fillColor: C.surfaceLight(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: BorderSide(color: C.divider(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: BorderSide(color: C.divider(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: BorderSide(color: C.primary(context)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: AppButton(
                  label: 'Send feedback',
                  // Disabled until a thumb is chosen: "Send" with no answer
                  // would post an empty rating and hide the prompt for good.
                  onPressed: _feedback == null ? null : _submit,
                  expand: true,
                  height: 48,
                  radius: AppRadii.pill,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: AppButton(
                  label: 'Skip',
                  // Skipping is an answer too: it is recorded so the question
                  // never reappears, without counting as a like or dislike.
                  onPressed: () => Navigator.pop(
                    context,
                    const OrderRating(feedback: OrderFeedback.skipped),
                  ),
                  variant: AppButtonVariant.text,
                  expand: true,
                  height: 48,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two thumbs. A filled primary pill when chosen, so the picked
/// answer is obvious without relying on colour alone (the icon carries it).
class _ThumbOption extends StatelessWidget {
  const _ThumbOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? C.onPrimary(context) : C.textPrimary(context);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? C.primary(context) : C.surfaceLight(context),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? C.primary(context) : C.divider(context),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: foreground),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A reason chip: toggles on tap and shows a check when selected, so the
/// state does not depend on the fill colour alone.
class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? C.onPrimary(context) : C.textPrimary(context);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? C.primary(context) : C.surfaceLight(context),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? C.primary(context) : C.divider(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check, size: 14, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 12,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The saved answer, as one quiet line: "You liked it" or "Not great · Late".
///
/// Shared by the past-orders card and the tracking screen so a rating reads the
/// same wherever it is shown.
class OrderRatingResult extends StatelessWidget {
  const OrderRatingResult({super.key, required this.rating});

  final OrderRating rating;

  @override
  Widget build(BuildContext context) {
    final liked = rating.liked;
    final color = liked ? C.success(context) : C.error(context);
    final reasons = rating.reasons.join(', ');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          liked ? Icons.thumb_up_alt_rounded : Icons.thumb_down_alt_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            reasons.isEmpty ? rating.headline : '${rating.headline} · $reasons',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: C.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}
