import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/micro_interactions.dart';

/// Screen for managing saved delivery addresses.
///
/// Supports adding, editing, deleting, and setting a default address.
class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return ScaffoldWithNav(
      activeIndex: 3,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl - 2,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Icon(
                          Icons.chevron_left,
                          size: 30,
                          color: C.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'My Addresses',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: C.textPrimary(context),
                      ),
                    ),
                  ),
                  // Add button
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showAddEditSheet(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 22,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Address list ────────────────────────────────────────
            Expanded(
              child: savedAddresses.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        30,
                      ),
                      itemCount: savedAddresses.length,
                      separatorBuilder: (_, _)
                          => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        return _buildAddressCard(
                          context,
                          savedAddresses[index],
                          screenWidth,
                        );
                      },
                    ),
            ),

            // ── Add new address button ──────────────────────────────
            if (savedAddresses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: TapFeedback(
                  onTap: () => _showAddEditSheet(context),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primaryDark,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: const Center(
                      child: Text(
                        '+ Add New Address',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

          ],
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 64,
              color: AppColors.grey400,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No saved addresses',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: C.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Add a delivery address so we know where to bring your fresh produce.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.grey700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            TapFeedback(
              onTap: () => _showAddEditSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: const Text(
                  'Add Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Address card ──────────────────────────────────────────────────

  Widget _buildAddressCard(
    BuildContext context,
    DeliveryAddress addr,
    double screenWidth,
  ) {
    return TapFeedback(
      onTap: () => _showOptionsSheet(context, addr),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: C.surface(context),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: addr.isDefault
                ? AppColors.primaryDark
                : C.divider(context),
            width: addr.isDefault ? 1.5 : 0.5,
          ),
          boxShadow: addr.isDefault ? AppNeumorphic.primaryGlowShadows(context) : AppNeumorphic.cardShadows(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: addr.isDefault
                    ? AppColors.primaryLight
                    : C.surfaceLight(context),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(
                _iconForLabel(addr.label),
                size: 22,
                color: addr.isDefault
                    ? AppColors.primaryDark
                    : AppColors.grey700,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          addr.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: C.textPrimary(context),
                          ),
                        ),
                      ),
                      if (addr.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    addr.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.grey700,
                    ),
                  ),
                  if (addr.phone != null && addr.phone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      addr.phone!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.grey500,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'office':
        return Icons.work_outline;
      case 'gym':
        return Icons.fitness_center;
      case 'school':
        return Icons.school_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  // ── Options bottom sheet ──────────────────────────────────────────

  void _showOptionsSheet(BuildContext context, DeliveryAddress addr) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: C.surface(ctx),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          addr.label,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: C.textPrimary(ctx),
                          ),
                        ),
                      ),
                      if (addr.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    addr.address,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.grey700,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Set as default
                if (!addr.isDefault)
                  _buildOptionTile(
                    ctx,
                    icon: Icons.check_circle_outline,
                    label: 'Set as default',
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => setDefaultAddress(addr.id));
                    },
                  ),

                // Edit
                _buildOptionTile(
                  ctx,
                  icon: Icons.edit_outlined,
                  label: 'Edit address',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddEditSheet(context, address: addr);
                  },
                ),

                // Delete
                _buildOptionTile(
                  ctx,
                  icon: Icons.delete_outline,
                  label: 'Delete address',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context, addr);
                  },
                ),

                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22, color: color ?? C.textPrimary(ctx)),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color ?? C.textPrimary(ctx),
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  // ── Confirm delete dialog ─────────────────────────────────────────

  void _confirmDelete(BuildContext context, DeliveryAddress addr) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Delete address?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This will remove "${addr.label}" (${addr.address}) from your saved addresses.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => removeAddress(addr.id));
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Add / Edit bottom sheet ───────────────────────────────────────

  void _showAddEditSheet(BuildContext context, {DeliveryAddress? address}) {
    final isEditing = address != null;
    final labelController = TextEditingController(
      text: isEditing ? address.label : '',
    );
    final addressController = TextEditingController(
      text: isEditing ? address.address : '',
    );
    final phoneController = TextEditingController(
      text: isEditing ? (address.phone ?? '') : '',
    );
    String selectedLabel = isEditing ? address.label : 'Home';
    bool isDefault = isEditing ? address.isDefault : savedAddresses.isEmpty;

    final labelOptions = ['Home', 'Office', 'Gym', 'School', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.75,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: C.surface(ctx),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: AppColors.grey300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        isEditing ? 'Edit Address' : 'New Address',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: C.textPrimary(ctx),
                        ),
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Label chips
                            Text(
                              'Label',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: C.textSecondary(ctx),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: labelOptions.map((label) {
                                final isSelected = selectedLabel == label;
                                return GestureDetector(
                                  onTap: () => setSheetState(
                                    () => selectedLabel = label,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primaryLight
                                          : C.surfaceLight(ctx),
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.pill,
                                      ),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primaryDark
                                            : C.divider(ctx),
                                        width: isSelected ? 1.5 : 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _iconForLabel(label),
                                          size: 16,
                                          color: isSelected
                                              ? AppColors.primaryDark
                                              : AppColors.grey700,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isSelected
                                                ? AppColors.primaryDark
                                                : C.textPrimary(ctx),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: AppSpacing.lg),

                            // Address field
                            Text(
                              'Address',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: C.textSecondary(ctx),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: addressController,
                              maxLines: 2,
                              decoration: AppDecorations.inputDecoration(
                                hintText: 'Street, area, city...',
                                context: ctx,
                              ),
                            ),

                            const SizedBox(height: AppSpacing.lg),

                            // Phone field
                            Text(
                              'Phone (optional)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: C.textSecondary(ctx),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: AppDecorations.inputDecoration(
                                hintText: 'Contact number for delivery',
                                context: ctx,
                              ),
                            ),

                            const SizedBox(height: AppSpacing.lg),

                            // Default toggle
                            GestureDetector(
                              onTap: () =>
                                  setSheetState(() => isDefault = !isDefault),
                              child: Row(
                                children: [
                                  Icon(
                                    isDefault
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 22,
                                    color: isDefault
                                        ? AppColors.primaryDark
                                        : AppColors.grey500,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'Set as default address',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: C.textPrimary(ctx),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppSpacing.xxl),
                          ],
                        ),
                      ),
                    ),

                    // Save button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            final addrText =
                                addressController.text.trim();
                            if (addrText.isEmpty) return;

                            final label = selectedLabel == 'Other'
                                ? (labelController.text.trim().isEmpty
                                    ? 'Other'
                                    : labelController.text.trim())
                                : selectedLabel;

                            if (isEditing) {
                              setState(() {
                                address.label = label;
                                address.address = addrText;
                                address.phone =
                                    phoneController.text.trim().isEmpty
                                        ? null
                                        : phoneController.text.trim();
                                address.isDefault = isDefault;
                                if (isDefault) {
                                  setDefaultAddress(address.id);
                                }
                              });
                              persistAddresses();
                            } else {
                              final newAddr = DeliveryAddress(
                                id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
                                label: label,
                                address: addrText,
                                phone: phoneController.text.trim().isEmpty
                                    ? null
                                    : phoneController.text.trim(),
                                isDefault: isDefault,
                              );
                              setState(() => addAddress(newAddr));
                            }

                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                          ),
                          child: Text(
                            isEditing ? 'Update Address' : 'Save Address',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      labelController.dispose();
      addressController.dispose();
      phoneController.dispose();
    });
  }
}
