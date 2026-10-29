import 'package:flutter/material.dart';

import '../theme.dart';

/// The one way the app writes a vendor rating: thumbs-up, "84%", "(21)".
///
/// Vendors are rated as the share of customers who liked them, not as a
/// 5-star score, so the star icon was describing the number wrongly — and each
/// screen used to pick its own format ("4.8", "84.0", "84%" without a count).
class VendorRating extends StatelessWidget {
  /// Share of customers who liked the vendor, 0–100.
  final double percentage;

  /// Number of reviews behind [percentage], or null when the source has none.
  final int? reviewCount;

  final double iconSize;
  final double fontSize;

  const VendorRating({
    super.key,
    required this.percentage,
    this.reviewCount,
    this.iconSize = 13,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.thumb_up_alt_rounded,
          size: iconSize,
          color: C.primary(context),
        ),
        const SizedBox(width: 3),
        Text(
          '${percentage.round()}%',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: C.primary(context),
          ),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: 3),
          Text(
            '($reviewCount)',
            style: TextStyle(
              fontSize: fontSize,
              color: C.textMuted(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// `84%` or `84.0` → 84.0; empty or unparsable → 0.
double ratingPercentageFromLabel(String? label) =>
    double.tryParse((label ?? '').replaceAll('%', '').trim()) ?? 0;

/// `(21)` → 21; empty or `No reviews` → null, so the count simply disappears.
int? reviewCountFromLabel(String? label) {
  final digits = RegExp(r'\d+').firstMatch(label ?? '')?.group(0);
  return digits == null ? null : int.tryParse(digits);
}
