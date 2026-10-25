import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'bottom_nav.dart';

/// Widest the bar is allowed to get, so it stays a bite-sized toast on a wide
/// browser window instead of a full-width strip.
const double _maxSnackBarWidth = 360;

/// Short messages vanish quickly; a message with an action stays long enough to
/// read and tap it.
const Duration _plainDuration = Duration(milliseconds: 2500);
const Duration _actionDuration = Duration(milliseconds: 4000);

/// Minimum height of the message row, so the text is vertically centred in a
/// bar that has no action button.
const double _contentMinHeight = 40;

/// Shows the app's one snackbar style.
///
/// The defaults are the reason this exists: the old per-screen snackbars used a
/// dark green fill with dark green text (invisible in dark mode) and sat in the
/// strip the floating nav occupies. This version paints an elevated surface,
/// uses the primary text token, floats above the nav, and never queues behind
/// a previous message.
///
/// It also fixes two SnackBar behaviours that made the old bar unusable: a bar
/// with an action never auto-dismissed (`persist` defaults to `action != null`),
/// and its default padding plus a wrapped action made it ~200 px tall.
///
/// [isError] only swaps the leading icon and its colour; the surface and text
/// stay identical so the bar reads the same everywhere.
void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  bool isError = false,
  double bottomOffset = 0,
}) {
  final messenger = ScaffoldMessenger.of(context);
  // Replace rather than queue: two quick taps should show the newest message,
  // not replay the one before it.
  messenger.hideCurrentSnackBar();

  final accent = isError ? C.errorBright(context) : C.primary(context);
  final hasAction = actionLabel != null && onAction != null;
  final duration = hasAction ? _actionDuration : _plainDuration;

  // `width` can't be combined with `margin`, and the margin is what lifts the
  // bar over the nav. So the side inset does the constraining instead: on a
  // wide window it centres a 360-wide bar, on a phone it falls back to the
  // regular 16 px page gutter. Measured from the messenger, not the caller,
  // because that is the MediaQuery the SnackBar itself lays out against.
  final screenWidth = MediaQuery.sizeOf(messenger.context).width;
  final sideInset =
      math.max(AppSpacing.lg, (screenWidth - _maxSnackBarWidth) / 2);

  // Filled in below: the safety timer can only fire after the bar exists, so
  // it closes through this handle rather than a captured controller.
  VoidCallback? dismiss;

  final controller = messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      // Elevated surface, one step lighter than the page in both themes.
      backgroundColor: C.surface(context),
      // Without this, a bar that has an action never dismisses itself:
      // ScaffoldMessenger defaults `persist` to `action != null`.
      persist: false,
      duration: duration,
      // Clears the floating pill (height + margin + gesture inset) plus a
      // small gap, so the bar never overlaps the nav. [bottomOffset] adds the
      // height of a pinned action bar for screens that have one above the pill.
      margin: EdgeInsets.fromLTRB(
        sideInset,
        0,
        sideInset,
        BottomNavMetrics.reserved(context) + 8 + bottomOffset,
      ),
      // Keep the action on the message's row instead of letting it wrap onto a
      // second line, which is what doubled the bar's height.
      actionOverflowThreshold: 1.0,
      // The default content padding (14 px top and bottom) is what made the
      // old bar so tall. The action button is 48 px on its own, so 4 px keeps
      // the total at 56 px with an action and 48 px without one.
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      shape: RoundedRectangleBorder(
        // Same pill radius as the floating nav.
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: C.divider(context)),
      ),
      // Swipe the toast down to get rid of it.
      dismissDirection: DismissDirection.down,
      content: _AutoDismiss(
        duration: duration,
        onTimeout: () => dismiss?.call(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _contentMinHeight),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: AppSpacing.md),
              // One line with an ellipsis, so a long message can't reflow the
              // bar into two lines.
              Expanded(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: C.textPrimary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      action: hasAction
          ? SnackBarAction(
              label: actionLabel,
              // C.primary reaches 4.5:1 on this surface in both themes.
              textColor: accent,
              onPressed: onAction,
            )
          : null,
    ),
  );

  dismiss = controller.close;
}

/// Safety net for the bar's own dismissal timer.
///
/// With "accessible navigation" on (screen readers and some system settings)
/// Flutter shows the snackbar but never starts its dismissal timer, so it
/// would stay on screen forever. This closes it once [duration] has passed, and
/// stops watching the moment the bar is gone.
///
/// The timer lives in a widget rather than beside `showSnackBar` on purpose:
/// it is then cancelled by disposal, so widening an unrelated screen's test
/// can't leave a stray timer pending.
class _AutoDismiss extends StatefulWidget {
  const _AutoDismiss({
    required this.duration,
    required this.onTimeout,
    required this.child,
  });

  final Duration duration;
  final VoidCallback onTimeout;
  final Widget child;

  @override
  State<_AutoDismiss> createState() => _AutoDismissState();
}

class _AutoDismissState extends State<_AutoDismiss> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Fires only if the bar is still on screen; closing it disposes this state
    // and cancels the timer, as does any other dismissal (tap, swipe, replace).
    _timer = Timer(widget.duration, () {
      if (mounted) widget.onTimeout();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
