import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/addresses.dart';
import '../widgets/scaffold_with_nav.dart';
import '../widgets/pinned_bottom_bar.dart';
import '../widgets/micro_interactions.dart';

/// Screen for managing saved delivery addresses.
///
/// Adds, edits, deletes and selects the address orders are delivered to.
/// Everything is read from [AddressesStore], so Home, checkout and this screen
/// can never disagree about the saved addresses or the current selection.
class AddressManagementScreen extends StatefulWidget {
  /// Opens the new-address sheet as soon as the screen appears.
  final bool startAdding;

  /// Opens the edit sheet for this address as soon as the screen appears.
  /// Used by checkout's "Add details" when a street line is missing.
  final String? editAddressId;

  /// Test seam; defaults to the app-wide store.
  final AddressesStore? store;

  const AddressManagementScreen({
    super.key,
    this.startAdding = false,
    this.editAddressId,
    this.store,
  });

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  AddressesStore get _store => widget.store ?? addressesStore;

  @override
  void initState() {
    super.initState();
    _store.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.startAdding) {
        _showAddEditSheet(context);
        return;
      }
      final editId = widget.editAddressId;
      if (editId == null) return;
      for (final address in _store.addresses) {
        if (address.id == editId) {
          _showAddEditSheet(context, address: address);
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final content = _buildContent(context);

        return ScaffoldWithNav(
          activeIndex: 3,
          // The pinned bar covers the strip above the pill.
          fadeContent: false,
          child: SafeArea(
            bottom: false,
            // The add button is pinned above the nav, so the list just takes
            // the space that is left. The empty state has no bar of its own.
            child: _store.addresses.isEmpty
                ? content
                : ScreenWithPinnedBar(
                    body: content,
                    bar: _buildAddButton(context),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
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
                    color: C.primaryTint(context),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 22,
                    color: C.primary(context),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // ── Address list ────────────────────────────────────────
        Expanded(
          child: _store.addresses.isEmpty
              ? _buildEmptyState(context)
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  itemCount: _store.addresses.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    return _buildAddressCard(
                      context,
                      _store.addresses[index],
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Contents of the pinned bar; its surface, divider and nav offset come from
  /// [PinnedBottomBar].
  Widget _buildAddButton(BuildContext context) {
    return TapFeedback(
      onTap: () => _showAddEditSheet(context),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(
            color: C.primary(context),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Center(
          child: Text(
            '+ Add New Address',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: C.primary(context),
            ),
          ),
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
            Text(
              'Add a delivery address so we know where to bring your fresh produce.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: C.textMuted(context),
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
                  color: C.primaryTint(context),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  'Add Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: C.primary(context),
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

  Widget _buildAddressCard(BuildContext context, Address addr) {
    final selected = addr.id == _store.selectedAddress?.id;

    return TapFeedback(
      onTap: () => _showOptionsSheet(context, addr),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: C.surface(context),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: selected ? C.primary(context) : C.divider(context),
            width: selected ? 1.5 : 0.5,
          ),
          boxShadow: selected
              ? AppNeumorphic.primaryGlowShadows(context)
              : AppNeumorphic.cardShadows(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? C.primaryTint(context) : C.surfaceLight(context),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(
                _iconForLabel(addr.label),
                size: 22,
                color: selected ? C.primary(context) : C.textSecondary(context),
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
                      if (selected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: C.primaryTint(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Delivering here',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: C.primary(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // An address without a street cannot be delivered to; say so
                  // here instead of only at checkout.
                  if (!addr.isComplete) ...[
                    Text(
                      'Add a street address',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: C.accentOrange(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    addr.fullAddress.isEmpty
                        ? 'No address details yet'
                        : addr.fullAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: C.textSecondary(context),
                    ),
                  ),
                  if (addr.landmark?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Near ${addr.landmark!.trim()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: C.textMuted(context),
                      ),
                    ),
                  ],
                  if (addr.phone?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      addr.phone!.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        color: C.textMuted(context),
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
              color: C.textMuted(context),
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

  void _showOptionsSheet(BuildContext context, Address addr) {
    final selected = addr.id == _store.selectedAddress?.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
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
                      if (selected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: C.primaryTint(ctx),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Delivering here',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: C.primary(ctx),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    addr.fullAddress.isEmpty ? 'No address details yet' : addr.fullAddress,
                    style: TextStyle(
                      fontSize: 13,
                      color: C.textSecondary(ctx),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Choose this address for checkout
                if (!selected)
                  _buildOptionTile(
                    ctx,
                    icon: Icons.check_circle_outline,
                    label: 'Deliver here',
                    onTap: () async {
                      final navigator = Navigator.of(ctx);
                      await _store.select(addr.id);
                      navigator.pop();
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
                  color: C.errorBright(ctx),
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

  void _confirmDelete(BuildContext context, Address addr) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Delete address?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This will remove "${addr.label}" (${addr.fullAddress}) from your '
            'saved addresses.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // The store moves the selection to another saved address, or
                // clears it — it never falls back to a placeholder.
                _store.delete(addr.id);
              },
              child: Text(
                'Delete',
                style: TextStyle(color: C.errorBright(context)),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Add / Edit bottom sheet ───────────────────────────────────────

  void _showAddEditSheet(BuildContext context, {Address? address}) {
    final isEditing = address != null;
    final labelController = TextEditingController(
      text: isEditing ? address.label : '',
    );
    final streetController = TextEditingController(
      text: isEditing ? address.street : '',
    );
    final areaController = TextEditingController(
      text: isEditing ? address.area : '',
    );
    final landmarkController = TextEditingController(
      text: isEditing ? (address.landmark ?? '') : '',
    );
    final phoneController = TextEditingController(
      text: isEditing ? (address.phone ?? '') : '',
    );
    String selectedLabel = isEditing ? address.label : 'Home';
    // A new address is delivered to by default when nothing is selected yet.
    bool deliverHere = isEditing
        ? address.id == _store.selectedAddress?.id
        : _store.selectedAddress == null;

    final labelOptions = ['Home', 'Office', 'Gym', 'School', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: Container(
                  height: MediaQuery.of(ctx).size.height * 0.8,
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
                                            ? C.primaryTint(ctx)
                                            : C.surfaceLight(ctx),
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.pill,
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? C.primary(ctx)
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
                                                ? C.primary(ctx)
                                                : C.textSecondary(ctx),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? C.primary(ctx)
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

                              // Street line — the part the rider needs
                              _fieldLabel(ctx, 'Street address'),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: streetController,
                                decoration: AppDecorations.inputDecoration(
                                  hintText: 'House number and street',
                                  context: ctx,
                                ),
                              ),

                              const SizedBox(height: AppSpacing.lg),

                              _fieldLabel(ctx, 'Area'),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: areaController,
                                decoration: AppDecorations.inputDecoration(
                                  hintText: 'Area, city (e.g. Gwarinpa, Abuja)',
                                  context: ctx,
                                ),
                              ),

                              const SizedBox(height: AppSpacing.lg),

                              _fieldLabel(ctx, 'Landmark (optional)'),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: landmarkController,
                                decoration: AppDecorations.inputDecoration(
                                  hintText: 'Gate, bus stop or nearby place',
                                  context: ctx,
                                ),
                              ),

                              const SizedBox(height: AppSpacing.lg),

                              _fieldLabel(ctx, 'Phone (optional)'),
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

                              // Deliver here toggle
                              GestureDetector(
                                onTap: () => setSheetState(
                                    () => deliverHere = !deliverHere),
                                child: Row(
                                  children: [
                                    Icon(
                                      deliverHere
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      size: 22,
                                      color: deliverHere
                                          ? C.primary(ctx)
                                          : C.textMuted(ctx),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        'Deliver to this address',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: C.textPrimary(ctx),
                                        ),
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
                            onPressed: () async {
                              final street = streetController.text.trim();
                              final area = areaController.text.trim();
                              if (street.isEmpty && area.isEmpty) return;

                              final label = selectedLabel == 'Other'
                                  ? (labelController.text.trim().isEmpty
                                      ? 'Other'
                                      : labelController.text.trim())
                                  : selectedLabel;

                              final landmark = landmarkController.text.trim();
                              final phone = phoneController.text.trim();
                              final saved = Address(
                                id: isEditing
                                    ? address.id
                                    : 'addr_${DateTime.now().millisecondsSinceEpoch}',
                                label: label,
                                street: street,
                                area: area,
                                landmark: landmark.isEmpty ? null : landmark,
                                phone: phone.isEmpty ? null : phone,
                              );

                              final navigator = Navigator.of(ctx);
                              await _store.save(saved);
                              if (deliverHere) await _store.select(saved.id);
                              navigator.pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.pill),
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
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      labelController.dispose();
      streetController.dispose();
      areaController.dispose();
      landmarkController.dispose();
      phoneController.dispose();
    });
  }

  Widget _fieldLabel(BuildContext ctx, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: C.textSecondary(ctx),
        ),
      );
}
