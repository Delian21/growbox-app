import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme.dart';
import '../data/app_state.dart';
import '../widgets/scaffold_with_nav.dart';
import '../screens/home_screen.dart';

class LocationScreen extends StatefulWidget {
  final bool returnToCheckout;
  const LocationScreen({super.key, this.returnToCheckout = false});
  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  /// Address the user typed or picked. Takes precedence over the detected one.
  String? _deliveryAddress;

  /// Address resolved for the map pin, null until detection finishes.
  String? _resolvedAddress;

  /// True while the pin is being resolved (drives the "Detecting..." copy).
  bool _detectingLocation = true;

  /// Guards against an older detection completing after a newer one.
  int _resolveToken = 0;

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
  static const bool _mapsEnabled =
      bool.fromEnvironment('GROWBOX_MAPS_ENABLED');

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
  /// API key is still a placeholder), so the pin is matched against the saved
  /// delivery address rather than inventing a street name. With no saved
  /// address the UI says so instead of printing raw coordinates.
  void _resolveAddress() {
    if (!mounted) return;
    final token = ++_resolveToken;
    setState(() => _detectingLocation = true);
    _refreshSheet();

    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || token != _resolveToken) return;
      setState(() {
        _detectingLocation = false;
        _resolvedAddress = defaultAddress?.address;
      });
      _refreshSheet();
    });
  }

  /// Rebuilds the open sheet (if any) after screen-state changes.
  void _refreshSheet() => _sheetSetState?.call(() {});

  /// What the subtitle shows: detected address, or an explicit state.
  String get _addressLine {
    if (_detectingLocation) return 'Detecting your location...';
    final address = _deliveryAddress ?? _resolvedAddress;
    return address ?? 'No saved address yet — tap to add one';
  }

  // ── Closing / finishing ──────────────────────────────────────────────────

  void _exit() {
    final navigator = Navigator.of(context);
    if (_sheetOpen) navigator.pop();
    navigator.pop();
  }

  void _finishLocation(String address) {
    final navigator = Navigator.of(context);
    // The sheet is its own route on the root navigator: close it before
    // popping or replacing the screen route underneath.
    if (_sheetOpen) navigator.pop();
    if (widget.returnToCheckout) {
      navigator.pop(address);
    } else {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  // ── Address dialogs ──────────────────────────────────────────────────────

  void _editAddress() {
    final controller =
        TextEditingController(text: _deliveryAddress ?? _resolvedAddress ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: C.surface(dialogContext),
          title: Text('Edit delivery address',
            style: TextStyle(color: C.textPrimary(dialogContext))),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 2,
            style: TextStyle(color: C.textPrimary(dialogContext)),
            decoration: InputDecoration(
              hintText: 'Enter your delivery address',
              hintStyle: TextStyle(color: C.textMuted(dialogContext)),
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: C.divider(dialogContext)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: C.textMuted(dialogContext))),
            ),
            ElevatedButton(
              onPressed: () {
                final newAddress = controller.text.trim();
                if (newAddress.isEmpty) return;
                Navigator.of(dialogContext).pop();
                setState(() => _deliveryAddress = newAddress);
                _finishLocation(newAddress);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _addNewAddress() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: C.surface(dialogContext),
          title: Text('Add a new address',
            style: TextStyle(color: C.textPrimary(dialogContext))),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 2,
            style: TextStyle(color: C.textPrimary(dialogContext)),
            decoration: InputDecoration(
              hintText: 'Enter your delivery address',
              hintStyle: TextStyle(color: C.textMuted(dialogContext)),
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: C.divider(dialogContext)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: C.textMuted(dialogContext))),
            ),
            ElevatedButton(
              onPressed: () {
                final newAddress = controller.text.trim();
                if (newAddress.isEmpty) return;
                Navigator.of(dialogContext).pop();
                setState(() => _deliveryAddress = newAddress);
                _finishLocation(newAddress);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
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
                        style: AppTypography.title
                            .copyWith(color: C.textPrimary(context)),
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
                                style: AppTypography.labelLarge
                                    .copyWith(color: C.textPrimary(context)),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              GestureDetector(
                                onTap: _editAddress,
                                child: Text(
                                  _addressLine,
                                  softWrap: true,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: C.textMuted(context),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _buildAddressWarningChip(context),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SizedBox(
                      width: double.infinity,
                      height: AppSizing.buttonHeight(context),
                      child: ElevatedButton(
                        onPressed: _addNewAddress,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: C.isDark(context)
                              ? AppColors.white.withValues(alpha: 0.1)
                              : AppColors.black.withValues(alpha: 0.1),
                          foregroundColor: C.textPrimary(context),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                        child: Text(
                          'Add a new address',
                          textAlign: TextAlign.center,
                          style: AppTypography.labelMedium.copyWith(
                            color: C.textPrimary(context),
                          ),
                        ),
                      ),
                    ),
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
    final isDark = C.isDark(context);
    final background = isDark
        ? AppColors.warning.withValues(alpha: 0.16)
        : AppColors.warningSoft;
    final foreground =
        isDark ? AppColors.warning : AppColors.accentOrangeDeep;

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: _addNewAddress,
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

    return ScaffoldWithNav(
      activeIndex: 0,
      child: LayoutBuilder(
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
                            _deliveryMarker = _deliveryMarker
                                .copyWith(positionParam: position.target);
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
                      color: AppColors.primary,
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
                  onTap: _exit,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: C.surface(context),
                      shape: BoxShape.circle,
                      boxShadow: AppNeumorphic.card,
                    ),
                    child: Icon(Icons.close,
                        size: 22, color: C.textPrimary(context)),
                  ),
                ),
              ),

              // ── Re-open affordance (sheet dismissed) ─────────────────
              if (!_sheetOpen)
                Positioned(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom: AppSpacing.md,
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
                          Icon(Icons.location_on_outlined,
                              size: 20, color: C.textPrimary(context)),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _addressLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelMedium
                                  .copyWith(color: C.textPrimary(context)),
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_up,
                              size: 22, color: C.textMuted(context)),
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
            style: AppTypography.labelLarge
                .copyWith(color: C.textPrimary(context)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Add your delivery address below and we will pin it for you.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: C.textMuted(context)),
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
