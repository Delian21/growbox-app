import 'package:flutter/material.dart';

import '../theme.dart';

/// One vendor category, as shown in the Home chip rail and the Browse screen.
///
/// The label is also the value used by [CategoryVendorsScreen] and the
/// produce filter, so both screens stay in step.
class VendorCategory {
  final String label;
  final IconData icon;
  final Color color;

  const VendorCategory({
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// The single category list for the whole app.
///
/// Home and Browse used to keep their own copies: Browse was missing "Tubers"
/// and used a coffee cup for Legumes. Both now read this list, so the labels,
/// icons and tints cannot drift apart again.
const List<VendorCategory> kCategories = [
  VendorCategory(
    label: 'Grains',
    icon: Icons.grain,
    color: AppColors.categoryGrains,
  ),
  VendorCategory(
    label: 'Fruits',
    icon: Icons.apple,
    color: AppColors.categoryFruits,
  ),
  VendorCategory(
    label: 'Vegetables',
    icon: Icons.eco,
    color: AppColors.categoryVegetables,
  ),
  VendorCategory(
    label: 'Legumes',
    // Sprout/leaf rather than the old coffee cup.
    icon: Icons.spa,
    color: AppColors.categoryLegumes,
  ),
  VendorCategory(
    label: 'Tubers',
    icon: Icons.grass,
    color: AppColors.categoryTubers,
  ),
  VendorCategory(
    label: 'Proteins',
    icon: Icons.set_meal,
    color: AppColors.categoryProteins,
  ),
  VendorCategory(
    label: 'Herbs',
    icon: Icons.local_florist,
    color: AppColors.categoryHerbs,
  ),
  VendorCategory(
    label: 'Oils',
    icon: Icons.oil_barrel,
    color: AppColors.categoryOils,
  ),
];
