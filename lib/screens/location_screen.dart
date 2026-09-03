import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme.dart';
import '../widgets/scaffold_with_nav.dart';
import '../screens/home_screen.dart';

class LocationScreen extends StatefulWidget {
  final bool returnToCheckout;
  const LocationScreen({super.key, this.returnToCheckout = false});
  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with SingleTickerProviderStateMixin {
  String deliveryAddress = 'your location';

  /// Default center: Abuja, Nigeria
  static const LatLng _defaultCenter = LatLng(9.0579, 7.4951);

  GoogleMapController? _mapController;
  LatLng _selectedPosition = _defaultCenter;
  static const MarkerId _markerId = MarkerId('delivery');

  /// Marker shown on the map – follows the center pin.
  late Marker _deliveryMarker;

  // ── Sheet expand / collapse state ────────────────────────────────────
  AnimationController? _sheetAnimController;
  Animation<double>? _sheetAnimation;
  double _sheetFraction = 1.0; // 1.0 = expanded, 0.0 = collapsed

  static const double _collapsedFraction = 0.22; // show just the handle + hint
  static const double _collapseThreshold = 0.35; // drag past this → collapse

  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _deliveryMarker = Marker(
      markerId: _markerId,
      position: _selectedPosition,
      draggable: true,
      onDragEnd: _onMarkerDragged,
    );
  }

  @override
  void dispose() {
    _sheetAnimController?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Callbacks ────────────────────────────────────────────────────────────

  void _onMarkerDragged(LatLng newPosition) {
    setState(() => _selectedPosition = newPosition);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() {});
  }

  void _onCameraIdle() {
    // Marker already updates in real-time via onCameraMove.
  }

  // ── Sheet expand / collapse handlers ──────────────────────────────────

  void _onDragStart(DragStartDetails details) {
    _sheetAnimController?.stop();
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Convert pixel delta to fraction of total sheet height
    final deltaFraction = details.delta.dy / screenHeight;
    setState(() {
      _sheetFraction = (_sheetFraction + deltaFraction).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    setState(() => _isDragging = false);

    // Decide target based on position and velocity
    bool targetExpanded;
    if (velocity < -300) {
      // Fling up → expand
      targetExpanded = true;
    } else if (velocity > 300) {
      // Fling down → collapse
      targetExpanded = false;
    } else {
      // Snap to whichever is closer
      targetExpanded = _sheetFraction > _collapseThreshold;
    }

    _animateSheet(toExpanded: targetExpanded);
  }

  void _animateSheet({required bool toExpanded}) {
    final begin = _sheetFraction;
    final end = toExpanded ? 1.0 : _collapsedFraction;
    _sheetAnimController?.dispose();
    _sheetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sheetAnimation = Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: _sheetAnimController!, curve: Curves.easeOut),
    );
    _sheetAnimController!.addListener(() {
      setState(() => _sheetFraction = _sheetAnimation!.value);
    });
    _sheetAnimController!.forward();
  }

  void _finishLocation(String address) {
    if (widget.returnToCheckout) {
      Navigator.of(context).pop(address);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  void _editAddress() {
    final controller = TextEditingController(text: deliveryAddress);
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
                borderSide: BorderSide(color: AppColors.primaryDark),
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
                setState(() => deliveryAddress = newAddress);
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
                borderSide: BorderSide(color: AppColors.primaryDark),
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
                setState(() => deliveryAddress = newAddress);
                _finishLocation(newAddress);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;
    final screenHeight = size.height;
    // Cap sheet height so map + sheet never exceeds screen height.
    final double maxSheetHeight = screenHeight * 0.65;
    final double fullSheetHeight =
        (screenHeight * 0.50).clamp(300.0, 460.0).clamp(0.0, maxSheetHeight);
    final double collapsedSheetHeight =
        (fullSheetHeight * _collapsedFraction).clamp(80.0, 120.0);
    final double currentSheetHeight =
        (collapsedSheetHeight +
            (fullSheetHeight - collapsedSheetHeight) * _sheetFraction)
        .clamp(0.0, maxSheetHeight);
    final double mapHeight =
        (screenHeight - currentSheetHeight).clamp(100.0, double.infinity);
    final double horizontalPadding = AppSizing.horizontalPadding(context);
    final double titleFontSize = (screenWidth * 0.055).clamp(20.0, 24.0);

    return ScaffoldWithNav(
      activeIndex: 0,
      child: Stack(
          children: [
            // ── Interactive Google Map ────────────────────────────────
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
                          _deliveryMarker =
                              _deliveryMarker.copyWith(positionParam: position.target);
                        });
                      },
                    ),
                    // Center-pin overlay – a static pin icon in the middle of the map
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Padding(
                            // Nudge up slightly so the pin tip is at the true center
                            padding: EdgeInsets.only(bottom: 36),
                            child: Icon(
                              Icons.location_on,
                              size: 44,
                              color: AppColors.primary,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

            // ── Close button ─────────────────────────────────────────
            Positioned(
              left: 16,
              top: MediaQuery.paddingOf(context).top + 12,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: C.surface(context),
                    shape: BoxShape.circle,
                    boxShadow: AppNeumorphic.card,
                  ),
                  child:
                      Icon(Icons.close, size: 22, color: C.textPrimary(context)),
                ),
              ),
            ),            // ── Bottom sheet ─────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: currentSheetHeight,
              child: GestureDetector(
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isDragging ? 0.85 : 1.0,
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: C.surface(context),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadii.lg),
                        topRight: Radius.circular(AppRadii.lg),
                      ),
                    ),
                    child: Column(
                      children: [
                        // ── Drag handle ──────────────────────────────
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
                        // ── Collapsed peek: tap to expand ──────────
                        if (_sheetFraction <= _collapsedFraction + 0.05)
                          GestureDetector(
                            onTap: () => _animateSheet(toExpanded: true),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 20,
                                      color: C.textPrimary(context)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Where should we deliver?',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: C.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_up,
                                      size: 22,
                                      color: C.textMuted(context)),
                                ],
                              ),
                            ),
                          ),
                        // ── Expanded content ────────────────────────
                        if (_sheetFraction > _collapsedFraction + 0.05)
                          Expanded(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  screenHeight < 700 ? 12 : 16,
                                  horizontalPadding,
                                  0,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Where should we deliver?',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: titleFontSize,
                                        height: 1.2,
                                        fontWeight: FontWeight.w700,
                                        color: C.textPrimary(context),
                                      ),
                                    ),
                                    SizedBox(
                                        height: screenHeight < 700 ? 26 : 36),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.location_on_outlined,
                                            size: 24,
                                            color: C.textPrimary(context)),
                                        SizedBox(
                                            width:
                                                screenWidth < 360 ? 20 : 28),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Current location',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  height: 1.4,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      C.textPrimary(context),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              GestureDetector(
                                                onTap: _editAddress,
                                                child: Text(
                                                  deliveryAddress,
                                                  softWrap: true,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    height: 1.4,
                                                    fontWeight: FontWeight.w400,
                                                    color:
                                                        C.textMuted(context),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: C.isDark(context)
                                                      ? const Color(0x33E5A800)
                                                      : const Color(0x20E5A800),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          AppRadii.sm),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      size: 18,
                                                      color:
                                                          Color(0xFF8B7A00),
                                                    ),
                                                    const SizedBox(
                                                        width:
                                                            AppSpacing.sm),
                                                    Flexible(
                                                      child: Text(
                                                        'Missing address details',
                                                        softWrap: true,
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 13,
                                                          height: 1.3,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: const Color(
                                                              0xFF8B7A00),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.xxl),
                                    SizedBox(
                                      width: double.infinity,
                                      height:
                                          AppSizing.buttonHeight(context),
                                      child: ElevatedButton(
                                        onPressed: _addNewAddress,
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor: C.isDark(context)
                                              ? const Color(0x1AFFFFFF)
                                              : const Color(0x1A000000),
                                          foregroundColor:
                                              C.textPrimary(context),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal:
                                                      AppSpacing.lg),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    AppRadii.pill),
                                          ),
                                        ),
                                        child: Text(
                                          'Add a new address',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: C.textPrimary(context),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  MapType _currentMapType = MapType.normal;

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
