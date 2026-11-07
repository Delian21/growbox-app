import 'package:flutter/material.dart';

import '../theme.dart';

/// Pill for a category rail: the vendor menu filter and the "browse by
/// category" row on the empty search screen.
///
/// One widget keeps both rails the same height, radius and weight, so a
/// category looks identical wherever it is offered.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        selected ? C.onPrimary(context) : C.textPrimary(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? C.primary(context) : C.surface(context),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: C.primary(context).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
