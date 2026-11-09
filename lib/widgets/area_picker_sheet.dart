import 'package:flutter/material.dart';

import '../data/service_areas.dart';
import '../theme.dart';
import 'app_button.dart';

/// A browsing area the picker settled on.
///
/// [id] is the curated [ServiceArea.id] when the customer picked a listed
/// area, and null when they chose to browse with text they typed instead.
class AreaPick {
  const AreaPick({required this.label, this.id});

  final String label;
  final String? id;
}

/// Opens the searchable list of areas the nearby vendors serve.
///
/// Returns null when the sheet is dismissed without a choice. The caller owns
/// persistence so the sheet stays a pure view.
Future<AreaPick?> showAreaPickerSheet(
  BuildContext context, {
  String? currentAreaId,
  List<String> recentAreaIds = const <String>[],
}) {
  return showModalBottomSheet<AreaPick>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.transparent,
    builder: (_) => AreaPickerSheet(
      currentAreaId: currentAreaId,
      recentAreaIds: recentAreaIds,
    ),
  );
}

/// Searchable, two-level-in-one list of servable areas.
///
/// The LGA is shown as context on each row rather than as a step to drill into:
/// a customer knows "Gwarinpa", not "AMAC", and the whole point is to stop
/// typing. Searching matches the area, its aliases and its LGA, so "wuse" and
/// "AMAC" both work from the same field.
class AreaPickerSheet extends StatefulWidget {
  const AreaPickerSheet({
    super.key,
    this.currentAreaId,
    this.recentAreaIds = const <String>[],
  });

  final String? currentAreaId;
  final List<String> recentAreaIds;

  @override
  State<AreaPickerSheet> createState() => _AreaPickerSheetState();
}

class _AreaPickerSheetState extends State<AreaPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(ServiceArea area) => Navigator.of(context).pop(
        AreaPick(label: area.label, id: area.id),
      );

  /// Browsing with text that is not on the list. Kept as a deliberate choice
  /// rather than a silent fallback, so the customer is told it may not be
  /// covered before the feed filters on it.
  void _pickTyped(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(AreaPick(label: trimmed));
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppSizing.horizontalPadding(context);
    final results = searchServiceAreas(_query);
    final showRecents = _query.trim().isEmpty && widget.recentAreaIds.isNotEmpty;
    final recentAreas = showRecents
        ? widget.recentAreaIds
            .map(serviceAreaById)
            .whereType<ServiceArea>()
            .toList()
        : const <ServiceArea>[];
    final recentIds = recentAreas.map((area) => area.id).toSet();

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: C.surface(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadii.lg),
            topRight: Radius.circular(AppRadii.lg),
          ),
          boxShadow: AppNeumorphic.card,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: C.isDark(context)
                          ? AppDarkColors.surfaceLighter
                          : AppColors.grey300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpacing.md,
                  horizontalPadding,
                  0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set your browsing area',
                            style: AppTypography.title
                                .copyWith(color: C.textPrimary(context)),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Only areas with vendors nearby are listed.',
                            style: AppTypography.caption
                                .copyWith(color: C.textMuted(context)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        size: 22,
                        color: C.textMuted(context),
                      ),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpacing.md,
                  horizontalPadding,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _controller,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: C.textPrimary(context)),
                  decoration: InputDecoration(
                    hintText: 'Search area or estate',
                    hintStyle: TextStyle(color: C.textMuted(context)),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 22,
                      color: C.textMuted(context),
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                            icon: Icon(
                              Icons.clear,
                              size: 20,
                              color: C.textMuted(context),
                            ),
                            tooltip: 'Clear search',
                          ),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: C.divider(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: C.primary(context)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? _buildNoMatch(context, horizontalPadding)
                    : ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          AppSpacing.xs,
                          horizontalPadding,
                          AppSpacing.xxl,
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          if (recentAreas.isNotEmpty) ...[
                            _sectionLabel(context, 'Recent'),
                            for (final area in recentAreas)
                              _areaRow(context, area, isRecent: true),
                          ],
                          _sectionLabel(context, 'Available now'),
                          for (final area in results)
                            if (!(showRecents && recentIds.contains(area.id)))
                              _areaRow(context, area),
                          if (_query.trim().isNotEmpty &&
                              !_hasConfidentMatch(results, _query))
                            _typedOption(context, horizontalPadding),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// True when a result starts with what was typed, which is a confident
  /// enough match that offering to browse with the raw text would only add
  /// noise. Fuzzy (contains-only) hits still get the escape hatch.
  bool _hasConfidentMatch(List<ServiceArea> results, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    return results.any((area) {
      if (area.name.toLowerCase().startsWith(q)) return true;
      return area.aliases.any(
        (alias) => alias.toLowerCase().startsWith(q),
      );
    });
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.sm),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: C.textMuted(context),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _areaRow(BuildContext context, ServiceArea area, {bool isRecent = false}) {
    final selected = widget.currentAreaId == area.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _pick(area),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: selected ? C.primaryTint(context) : C.surface(context),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: selected ? C.primary(context) : C.divider(context),
                width: selected ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isRecent ? Icons.history : Icons.place_outlined,
                  size: 20,
                  color: selected ? C.primary(context) : C.textMuted(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        area.name,
                        style: AppTypography.labelMedium.copyWith(
                          color: C.textPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        area.region,
                        style: AppTypography.caption
                            .copyWith(color: C.textMuted(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.chevron_right,
                  size: 22,
                  color: selected ? C.primary(context) : C.textMuted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typedOption(BuildContext context, double horizontalPadding) {
    final typed = _controller.text.trim();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: C.surfaceLight(context),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: C.divider(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Not on the list?',
              style: AppTypography.labelMedium.copyWith(
                color: C.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Browse with “$typed” anyway. Vendors near you may not cover it '
              'yet, and deliveries still need a saved address.',
              style: AppTypography.caption.copyWith(color: C.textMuted(context)),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Use “$typed” anyway',
              onPressed: () => _pickTyped(typed),
              variant: AppButtonVariant.secondary,
              height: 44,
              radius: AppRadii.sm,
            ),
          ],
        ),
      ),
    );
  }

  /// Nothing matched: say so at selection time instead of at checkout.
  Widget _buildNoMatch(BuildContext context, double horizontalPadding) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.xxl,
        horizontalPadding,
        AppSpacing.xxl,
      ),
      children: [
        Icon(
          Icons.location_off_outlined,
          size: 40,
          color: C.textMuted(context),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'We don’t deliver to “${_query.trim()}” yet',
          style: AppTypography.title.copyWith(color: C.textPrimary(context)),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Our vendors cover the areas on this list. You can still browse with '
          'another area, or keep what you typed and add a delivery address '
          'later.',
          style: AppTypography.bodySmall.copyWith(color: C.textMuted(context)),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Browse with “${_query.trim()}” anyway',
          onPressed: () => _pickTyped(_query),
          variant: AppButtonVariant.secondary,
          expand: true,
          height: 48,
          radius: AppRadii.sm,
        ),
      ],
    );
  }
}
