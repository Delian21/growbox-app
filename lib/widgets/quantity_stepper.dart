import 'package:flutter/material.dart';

import '../theme.dart';

/// One 44×44 stepper key: neutral surface and a text-coloured glyph, so "−"
/// and "+" read as the same control.
///
/// Shared by the cart, the vendor's product cards and the product page, so a
/// quantity always looks and behaves the same wherever it is changed.
class StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticLabel;

  const StepperButton({
    super.key,
    required this.icon,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? C.surfaceLight(context) : C.surfaceLighter(context),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? C.textPrimary(context) : C.textMuted(context),
        ),
      ),
    );

    if (semanticLabel == null) return button;
    return Semantics(button: true, label: semanticLabel, child: button);
  }
}

/// A −/count/+ stepper.
///
/// At one unit the minus slot shows a trash instead, so removing the last unit
/// is the same gesture as removing any other; pass [onDelete] to make that
/// removal final. Without [onDelete] the slot stays a disabled minus, which is
/// what a screen editing an unsaved quantity wants.
class QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback? onDelete;
  final VoidCallback? onIncrement;

  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onDecrement,
    this.onDelete,
    this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    // At one unit the slot becomes the delete control where a delete exists,
    // and a disabled minus where it does not (an unsaved quantity cannot go
    // below one).
    final Widget decrement;
    if (quantity > 1) {
      decrement = StepperButton(
        icon: Icons.remove,
        onTap: onDecrement,
        semanticLabel: 'Remove one',
      );
    } else if (onDelete != null) {
      decrement = StepperButton(
        icon: Icons.delete_outline,
        onTap: onDelete,
        semanticLabel: 'Remove from box',
      );
    } else {
      decrement = const StepperButton(
        icon: Icons.remove,
        enabled: false,
        semanticLabel: 'Minimum quantity is one',
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        decrement,
        SizedBox(
          width: 32,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: C.textPrimary(context),
            ),
          ),
        ),
        StepperButton(
          icon: Icons.add,
          enabled: onIncrement != null,
          onTap: onIncrement,
          semanticLabel: 'Add one',
        ),
      ],
    );
  }
}
