import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme.dart';
import '../data/addresses.dart';
import '../widgets/saved_address_picker.dart';
import '../widgets/area_picker_sheet.dart';
import '../widgets/app_button.dart';
import 'address_management_screen.dart';
import '../widgets/root_shell.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key, this.isFirstRun = false});

  /// True when this screen IS the first-run setup step, reached from
  /// [AppEntryGate] before the customer has ever seen Home.
  ///
  /// That changes what finishing means: setup ends in Home, while the same
  /// screen opened from the Home header only pops back with the choice made.
  final bool isFirstRun;
  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  /// Guards against an older detection completing after a newer one.
  int _resolveToken = 0;

  /// True while the pin is being resolved (drives the "Detecting..." copy).
  bool _detectingLocation = true;

  /// True while the address sheet route is on screen.
  bool _sheetOpen = false;

  /// Setter for the sheet's own StatefulBuilder, so detection results can
  /// repaint the sheet without rebuilding the whole screen.
  StateSetter? _sheetSetState;

  /// How much of the screen the address sheet covers.
  static const double _sheetHeightFraction = 0.52;

  /// The web build only gets a working map once a real Maps JavaScript key
  /// replaces the `YOUR_API_KEY` placeholder in web/index.html. Until then
  /// Google paints its own grey "Oops! Something went wrong" box inside the
  /// map view, so we show a branded placeholder instead of mounting the map.
  /// Enable it with: flutter run/build --dart-define=GROWBOX_MAPS_ENABLED=true
  static const bool _mapsEnabled = bool.fromEnvironment('GROWBOX_MAPS_ENABLED');

  bool get _mapSupported => !kIsWeb || _mapsEnabled;

  /// Default center: Abuja, Nigeria
  static const LatLng _defaultCenter = LatLng(9.0579, 7.4951);

  GoogleMapController? _mapController;
  LatLng _selectedPosition = _defaultCenter;
  static const MarkerId _markerId = MarkerId('delivery');

  /// Marker shown on the map – follows the center pin.
  late Marker _deliveryMarker;

  MapType _currentMapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _deliveryMarker = Marker(
      markerId: _markerId,
      position: _selectedPosition,
      draggable: true,
      onDragEnd: _onMarkerDragged,
    );
    _resolveAddress();
    // Slide the sheet up over the whole app (including the bottom nav) once
    // the first frame is laid out, so it animates instead of popping in.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openAddressSheet());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── Callbacks ────────────────────────────────────────────────────────────

  void _onMarkerDragged(LatLng newPosition) {
    setState(() => _selectedPosition = newPosition);
    _resolveAddress();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _resolveAddress();
  }

  void _onCameraIdle() {
    // The pin moved: the address behind it is stale until we resolve again.
    _resolveAddress();
  }

  // ── Address resolution ───────────────────────────────────────────────────

  /// Resolves the pin to a human-readable address.
  ///
  /// The app ships no geocoding service (it is offline-first and the map's
  /// API key is still a placeholder), so the pin shows the chosen browsing
  /// area rather than inventing a street name. Browsing area is kept separate
  /// from delivery addresses: it is never offered to checkout as an address.
  void _resolveAddress() {
    if (!mounted) return;
    final token = ++_resolveToken;
    setState(() => _detectingLocation = true);
    _refreshSheet();

    Future<void>(() async {
      await browsingAreaStore.load();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted || token != _resolveToken) return;
      setState(() => _detectingLocation = false);
      _refreshSheet();
    });
  }

  /// Rebuilds the open sheet (if any) after screen-state changes.
  void _refreshSheet() => _sheetSetState?.call(() {});

  /// What the subtitle shows: the browsing area, or an explicit state.
  String get _addressLine {
    if (_detectingLocation) return 'Detecting your location...';
    return browsingAreaStore.area ?? 'No saved area yet — tap to set one';
  }

  // ── Closing / finishing ──────────────────────────────────────────────────

  /// Leaves the location screen, telling the caller where we are.
  ///
  /// First run: setup is over, so Home replaces everything (the gate's stack is
  /// gone anyway — popping would reveal the splash). Any other entry point
  /// (Home header) just pops, handing the chosen address back to the caller.
  void _finish({Address? address}) {
    final navigator = Navigator.of(context);
    if (_sheetOpen) navigator.pop();
    if (widget.isFirstRun) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RootShell()),
        (route) => false,
      );
      return;
    }
    navigator.pop<Address?>(address);
  }

  /// True when there is a browsing area checkout can never use but the feed
  /// can — the "browsing only" case first-run setup allows.
  bool get _canBrowseOnly => browsingAreaStore.hasArea;

  // ── Browsing area / delivery address ───────────────────────────────

  /// Edits the browsing area only, by picking it from the served areas.
  ///
  /// The pin says where the customer is shopping from, not where an order can
  /// be delivered: an area without a street is never handed to checkout. A
  /// picked area is stored with its curated id so the feed can tell a served
  /// area from text someone typed by hand.
  Future<void> _editArea() async {
    await browsingAreaStore.load();
    if (!mounted) return;
    final pick = await showAreaPickerSheet(
      context,
      currentAreaId: browsingAreaStore.areaId,
      recentAreaIds: browsingAreaStore.recentAreaIds,
    );
    if (pick == null || !mounted) return;
    await browsingAreaStore.setArea(pick.label, areaId: pick.id);
    if (!mounted) return;
    setState(() {});
    _refreshSheet();
  }

  /// Opens the app's one address editor (with a new-address sheet ready).
  Future<void> _openAddressEditor(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    setState(() {});
    // First run: saving an address (the repository auto-selects the first one)
    // completes setup, so go straight to Home instead of making the customer
    // pick the address they just created. Other entry points stay here.
    final saved = addressesStore.selectedAddress;
    if (widget.isFirstRun && saved != null) {
      _finish(address: saved);
      return;
    }
    _refreshSheet();
  }

  void _addNewAddress() =>
      _openAddressEditor(const AddressManagementScreen(startAdding: true));

  /// Makes [address] the delivery address and leaves the location screen, so
  /// the caller (Home, registration) shows the new area immediately.
  Future<void> _selectAddress(Address address) async {
    await addressesStore.select(address.id);
    if (!mounted) return;
    setState(() {});
    // Setup done (Home) or a choice handed back to whoever opened the sheet.
    _finish(address: address);
  }

  /// "Missing address details": fixes the selected address, or adds one.
  void _fixSelectedAddress() {
    final selected = addressesStore.selectedAddress;
    if (selected == null) {
      _addNewAddress();
    } else {
      _openAddressEditor(AddressManagementScreen(editAddressId: selected.id));
    }
  }

  // ── Address sheet ────────────────────────────────────────────────────────

  /// Presents the address panel as a root-navigator modal so it sits above
  /// the bottom nav instead of stopping at the body's edge.
  Future<void> _openAddressSheet() async {
    if (_sheetOpen || !mounted) return;
    setState(() => _sheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: AppColors.transparent,
      barrierColor: AppColors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          _sheetSetState = setSheetState;
          return _buildAddressSheet(context);
        },
      ),
    );
    _sheetSetState = null;
    if (mounted) setState(() => _sheetOpen = false);
  }

  Widget _buildAddressSheet(BuildContext context) {
    final horizontalPadding = AppSizing.horizontalPadding(context);
    return FractionallySizedBox(
      heightFactor: _sheetHeightFraction,
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
        child: Column(
          children: [
            // ── Drag handle ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
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
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  AppSpacing.md,
                  horizontalPadding,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Where should we deliver?',
                        textAlign: TextAlign.center,
                        style: AppTypography.title.copyWith(
                          color: C.textPrimary(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 24,
                          color: C.textPrimary(context),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current location',
                                style: AppTypography.labelLarge.copyWith(
                                  color: C.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              GestureDetector(
                                onTap: _editArea,
                                child: Text(
                                  _addressLine,
                                  softWrap: true,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: C.textMuted(context),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              // Only shown for text that is not on the served
                              // list: the picker already said so, this keeps it
                              // visible after the sheet is closed.
                              if (browsingAreaStore.isUnlistedArea) ...[
                                Text(
                                  'Not a covered area yet — vendors may be '
                                  'limited.',
                                  style: AppTypography.caption.copyWith(
                                    color: C.accentOrange(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                              ],
                              Text(
                                'Browsing only — deliveries go to a saved address.',
                                style: AppTypography.caption.copyWith(
                                  color: C.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Deliver to',
                      style: AppTypography.labelLarge.copyWith(
                        color: C.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ListenableBuilder(
                      listenable: addressesStore,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SavedAddressPicker(
                            addresses: addressesStore.addresses,
                            selectedId: addressesStore.selectedAddress?.id,
                            onSelect: _selectAddress,
                          ),
                          if (addressesStore.selectionNeedsStreet) ...[
                            const SizedBox(height: AppSpacing.md),
                            _buildAddressWarningChip(context),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: 'Add a new address',
                        onPressed: _addNewAddress,
                        variant: AppButtonVariant.secondary,
                        expand: true,
                        height: AppSizing.buttonHeight(context),
                        radius: AppRadii.pill,
                      ),
                    ),
                    // First-run escape hatch: browse the feed without a
                    // delivery address. Checkout still refuses without one,
                    // so this can never produce an undeliverable order.
                    if (widget.isFirstRun) ...[
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: 'Continue with browsing only',
                          onPressed: _canBrowseOnly ? () => _finish() : null,
                          variant: AppButtonVariant.text,
                          expand: true,
                          height: AppSizing.buttonHeight(context),
                          radius: AppRadii.pill,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _canBrowseOnly
                            ? 'Browse vendors around you. Add an address when '
                                'you are ready to order.'
                            : 'Set your area above to browse without an address.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption
                            .copyWith(color: C.textMuted(context)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Amber "missing details" chip: readable in both themes and tappable, so
  /// it opens the add-address flow instead of just stating the problem.
  Widget _buildAddressWarningChip(BuildContext context) {
    final background = C.warningSoft(context);
    final foreground = C.onWarningSoft(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: _fixSelectedAddress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: foreground.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Missing address details',
                  softWrap: true,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, size: 18, color: foreground),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = AppSizing.horizontalPadding(context);

    // Opened from Home's location chip, not a tab: no bottom nav here.
    return Scaffold(
      backgroundColor: C.background(context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double mapHeight = constraints.maxHeight;
          // Centre the pin in the part of the map the sheet does not cover,
          // so it never collides with the sheet's first row.
          final double visibleMapHeight = _sheetOpen
              ? mapHeight * (1 - _sheetHeightFraction)
              : mapHeight;
          final double pinTop = (visibleMapHeight / 2) - 22;

          return Stack(
            children: [
              // ── Map area ────────────────────────────────────────────
              // Without a usable key the platform view renders Google's own
              // error box, so fall back to an on-brand panel instead.
              if (!_mapSupported)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: mapHeight,
                  child: const _MapUnavailableView(),
                ),

              // ── Interactive Google Map ──────────────────────────────
              if (_mapSupported)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: mapHeight,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppRadii.md),
                      bottomRight: Radius.circular(AppRadii.md),
                    ),
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: const CameraPosition(
                            target: _defaultCenter,
                            zoom: 15,
                          ),
                          onMapCreated: _onMapCreated,
                          onCameraIdle: _onCameraIdle,
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          rotateGesturesEnabled: true,
                          scrollGesturesEnabled: true,
                          tiltGesturesEnabled: false,
                          markers: {_deliveryMarker},
                          mapType: _currentMapType,
                          onCameraMove: (position) {
                            // Update marker in real-time while panning
                            setState(() {
                              _selectedPosition = position.target;
                              _deliveryMarker = _deliveryMarker.copyWith(
                                positionParam: position.target,
                              );
                            });
                          },
                        ),
                        // User-location button
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: _MapIconButton(
                            icon: Icons.my_location,
                            onTap: _centerOnDefault,
                          ),
                        ),
                        // Map style toggle
                        Positioned(
                          right: 12,
                          bottom: 60,
                          child: _MapIconButton(
                            icon: Icons.layers_outlined,
                            onTap: _cycleMapType,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Center pin ───────────────────────────────────────────
              // Positioned by map geometry (not Center) so it stays clear of
              // the sheet's header row.
              if (_mapSupported)
                Positioned(
                  top: pinTop,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Icon(
                        Icons.location_on,
                        size: 44,
                        color: C.primary(context),
                        shadows: [
                          Shadow(
                            color: AppColors.black26,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Close button ─────────────────────────────────────────
              Positioned(
                left: 16,
                top: MediaQuery.paddingOf(context).top + 12,
                child: GestureDetector(
                  // First run cannot pop back to sign-up, so the close button
                  // ends setup in Home as well.
                  onTap: _finish,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: C.surface(context),
                      shape: BoxShape.circle,
                      boxShadow: AppNeumorphic.card,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 22,
                      color: C.textPrimary(context),
                    ),
                  ),
                ),
              ),

              // ── Re-open affordance (sheet dismissed) ─────────────────
              if (!_sheetOpen)
                Positioned(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  // Sits clear of the home indicator.
                  bottom: AppSpacing.xxl,
                  child: GestureDetector(
                    onTap: _openAddressSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: C.surface(context),
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: AppNeumorphic.card,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 20,
                            color: C.textPrimary(context),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _addressLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelMedium.copyWith(
                                color: C.textPrimary(context),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_up,
                            size: 22,
                            color: C.textMuted(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _cycleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
    // Force rebuild of the GoogleMap widget
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _selectedPosition, zoom: 15),
      ),
    );
  }

  void _centerOnDefault() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _defaultCenter, zoom: 15),
      ),
    );
  }
}

// ── Branded fallback shown when the map cannot be rendered ──────────────────

class _MapUnavailableView extends StatelessWidget {
  const _MapUnavailableView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.surfaceLight(context),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 40, color: C.textMuted(context)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Map preview unavailable',
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge.copyWith(
              color: C.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Add your delivery address below and we will pin it for you.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: C.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small floating action button used on the map ────────────────────────────

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: C.surface(context),
          shape: BoxShape.circle,
          boxShadow: AppNeumorphic.card,
        ),
        child: Icon(icon, size: 20, color: C.textPrimary(context)),
      ),
    );
  }
}
