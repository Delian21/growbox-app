import 'package:flutter/material.dart';

import '../theme.dart';
import 'bottom_nav.dart';

/// Shows the app's one snackbar style.
///
/// The defaults are the reason this exists: the old per-screen snackbars used a
/// dark green fill with dark green text (invisible in dark mode) and sat in the
/// strip the floating nav occupies. This version paints an elevated surface,
/// uses the primary text token, floats above the nav, and never queues behind
/// a previous message.
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

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      // Elevated surface, one step lighter than the page in both themes.
      backgroundColor: C.surface(context),
      duration: const Duration(seconds: 2),
      // Clears the floating pill (height + margin + gesture inset) plus a
      // small gap, so the bar never overlaps the nav. [bottomOffset] adds the
      // height of a pinned action bar for screens that have one above the pill.
      margin: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        BottomNavMetrics.reserved(context) + 8 + bottomOffset,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(color: C.divider(context)),
      ),
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle,
            size: 20,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: C.textPrimary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      action: actionLabel == null || onAction == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: accent,
              onPressed: onAction,
            ),
    ),
  );
}
