import 'package:flutter/material.dart';

import '../data/addresses.dart';
import '../theme.dart';

/// A compact, selectable list of saved delivery addresses.
///
/// Shared by the checkout and "Where should we deliver?" sheets so both offer
/// exactly the same choices, read from the same [AddressesStore].
class SavedAddressPicker extends StatelessWidget {
  const SavedAddressPicker({
    super.key,
    required this.addresses,
    required this.selectedId,
    required this.onSelect,
    this.emptyMessage = 'No delivery address yet',
    this.emptyHint = 'Add one so we know where to bring your produce.',
  });

  final List<Address> addresses;
  final String? selectedId;
  final ValueChanged<Address> onSelect;
  final String emptyMessage;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    if (addresses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: C.surfaceLight(context),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: C.divider(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emptyMessage,
              style: AppTypography.labelMedium
                  .copyWith(color: C.textPrimary(context)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              emptyHint,
              style: AppTypography.bodySmall.copyWith(color: C.textMuted(context)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final address in addresses) ...[
          _AddressOption(
            address: address,
            selected: address.id == selectedId,
            onTap: () => onSelect(address),
          ),
          if (address != addresses.last) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? C.primaryTint(context) : C.surface(context),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? C.primary(context) : C.divider(context),
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 20,
                color: C.primary(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.label,
                      style: AppTypography.labelMedium
                          .copyWith(color: C.textPrimary(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.fullAddress.isEmpty
                          ? 'No street or area yet'
                          : address.fullAddress,
                      style: AppTypography.bodySmall
                          .copyWith(color: C.textSecondary(context)),
                    ),
                    if (address.landmark?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Near ${address.landmark!.trim()}',
                        style: AppTypography.caption
                            .copyWith(color: C.textMuted(context)),
                      ),
                    ],
                    if (address.phone?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Text(
                        address.phone!.trim(),
                        style: AppTypography.caption
                            .copyWith(color: C.textMuted(context)),
                      ),
                    ],
                    if (!address.isComplete) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Add a street address',
                        style: AppTypography.caption.copyWith(
                          color: C.accentOrange(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 22,
                color: selected ? C.primary(context) : C.textMuted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
