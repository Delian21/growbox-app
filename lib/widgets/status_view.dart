import 'package:flutter/material.dart';

import '../theme.dart';
import 'app_button.dart';

/// The app's one empty / error state.
///
/// Every screen that can have "nothing to show" renders this instead of
/// hand-rolling its own icon circle, title, body and button, so the type
/// scale, colour contrast and tap targets cannot drift apart again.
///
/// Layout: a brand-green tinted disc, a title and one short message wrapped in
/// a single semantics node, then up to two full-width [AppButton]s. The text
/// column is capped at [_maxTextWidth] so a long word never sits alone on the
/// last line, and nothing here draws a shadow or glow.
class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  })  : assert(
          (primaryLabel == null) == (onPrimary == null),
          'primaryLabel and onPrimary are used together',
        ),
        assert(
          (secondaryLabel == null) == (onSecondary == null),
          'secondaryLabel and onSecondary are used together',
        );

  /// Glyph in the disc. Picked by the caller so each state reads differently.
  final IconData icon;

  /// One line naming the state, e.g. "No favorites yet".
  final String title;

  /// One sentence saying what goes here or what to do next.
  final String message;

  /// Filled action, or null when the state has no primary action.
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// Quiet text action under the primary one, or null for none.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// The message measure. 280px holds every message in the app in two lines
  /// with no orphaned word, and still fits a 320dp phone with its padding.
  static const double _maxTextWidth = 280;

  @override
  Widget build(BuildContext context) {
    final brand = C.primary(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxTextWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 12% of the brand green rather than the fixed primaryTint: on
              // the dark page the dark-green tint vanishes, while a low-alpha
              // brand wash stays a visible disc around the bright icon.
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: brand),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // One node: screen readers announce "title. message" as a unit
              // instead of two unrelated fragments with a pause between them.
              Semantics(
                container: true,
                label: '$title. $message',
                excludeSemantics: true,
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: C.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // textSecondary is 6.9:1 on the light page and 8.9:1 on
                    // the dark one, so the message clears 4.5:1 in both.
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 14,
                        height: 1.5,
                        color: C.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (primaryLabel != null) ...[
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: primaryLabel!,
                  onPressed: onPrimary,
                  height: 48,
                  expand: true,
                ),
              ],
              if (secondaryLabel != null) ...[
                const SizedBox(height: AppSpacing.xs),
                AppButton(
                  label: secondaryLabel!,
                  onPressed: onSecondary,
                  variant: AppButtonVariant.text,
                  height: 48,
                  expand: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
