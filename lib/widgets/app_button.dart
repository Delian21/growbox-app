import 'package:flutter/material.dart';

import '../theme.dart';

enum AppButtonVariant { primary, secondary, text, destructive }

/// Shared button chrome for primary, outlined, text and destructive actions.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.width,
    this.height,
    this.radius = AppRadii.md,
    this.foregroundColorOverride,
    this.backgroundColorOverride,
    this.expand = false,
    this.child,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final double? width;
  final double? height;
  final double radius;
  final Color? foregroundColorOverride;
  final Color? backgroundColorOverride;
  final bool expand;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final isDestructive = variant == AppButtonVariant.destructive;
    final isFilled = variant == AppButtonVariant.primary || isDestructive;
    final buttonHeight = height ?? (isFilled ? 52.0 : 44.0);
    final fill = isDestructive ? C.error(context) : C.primary(context);
    final foreground = isDestructive ? C.onError(context) : C.onPrimary(context);
    final content = child ?? _buildLabel(context, disabled, foreground);
    final buttonContent = disabled ? _mutedChild(context, content) : content;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    late final Widget button;
    switch (variant) {
      case AppButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            elevation: 0,
            minimumSize: Size(0, buttonHeight),
            backgroundColor: disabled
                ? C.surfaceVariant(context)
                : backgroundColorOverride ?? C.surface(context),
            foregroundColor: disabled
                ? C.textMuted(context)
                : foregroundColorOverride ?? C.primary(context),
            side: BorderSide(
              color: disabled ? C.divider(context) : C.primary(context),
            ),
            shape: shape,
          ),
          child: buttonContent,
        );
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size(0, buttonHeight),
            foregroundColor: disabled
                ? C.textMuted(context)
                : foregroundColorOverride ?? C.primary(context),
            backgroundColor: disabled
                ? C.surfaceVariant(context)
                : AppColors.transparent,
            shape: shape,
          ),
          child: buttonContent,
        );
      case AppButtonVariant.primary:
      case AppButtonVariant.destructive:
        button = ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            minimumSize: Size(0, buttonHeight),
            backgroundColor: disabled
                ? C.surfaceVariant(context)
                : backgroundColorOverride ?? fill,
            disabledBackgroundColor: C.surfaceVariant(context),
            foregroundColor: disabled
                ? C.textMuted(context)
                : foregroundColorOverride ?? foreground,
            disabledForegroundColor: C.textMuted(context),
            shape: shape,
          ),
          child: buttonContent,
        );
    }

    Widget result = button;
    if (expand) result = SizedBox(width: double.infinity, child: result);
    if (width != null || height != null) {
      result = SizedBox(width: width, height: height, child: result);
    }
    return result;
  }

  Widget _mutedChild(BuildContext context, Widget child) {
    return IconTheme(
      data: IconThemeData(color: C.textMuted(context)),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: C.textMuted(context)),
        child: child,
      ),
    );
  }

  Widget _buildLabel(BuildContext context, bool disabled, Color foreground) {
    final isTextLike = variant == AppButtonVariant.text ||
        variant == AppButtonVariant.secondary;
    final color = disabled
        ? C.textMuted(context)
        : foregroundColorOverride ??
            (isTextLike ? C.primary(context) : foreground);
    final labelWidget = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
    if (icon == null) return labelWidget;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.sm),
        labelWidget,
      ],
    );
  }
}
