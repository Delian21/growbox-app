import 'dart:async';

import 'package:flutter/material.dart';

import '../services/connectivity.dart';
import '../theme.dart';

/// The connectivity banner, wrapped around the whole app.
///
/// While offline it shows a slim amber bar above everything else; when the
/// connection returns it says "Back online" for two seconds and disappears.
///
/// The bar is laid out *above* the app's navigator instead of floating over
/// it, so it pushes the current screen down: no header or floating bottom nav
/// is ever covered. Connected, this widget returns [child] untouched.
class OfflineBannerHost extends StatefulWidget {
  const OfflineBannerHost({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineBannerHost> createState() => _OfflineBannerHostState();
}

class _OfflineBannerHostState extends State<OfflineBannerHost> {
  /// How long "Back online" stays up before it gets out of the way.
  static const Duration _backOnlineDuration = Duration(seconds: 2);

  /// True between going offline and coming back, so a later "online" event is
  /// only celebrated once.
  bool _wasOffline = !connectivityStore.isOnline;

  bool _showingBackOnline = false;

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    connectivityStore.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    connectivityStore.removeListener(_onConnectivityChanged);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (!mounted) return;
    _hideTimer?.cancel();

    if (!connectivityStore.isOnline) {
      setState(() {
        _wasOffline = true;
        _showingBackOnline = false;
      });
      return;
    }

    // Already online (for example the demo switch was on twice): nothing to
    // announce.
    if (!_wasOffline) return;

    setState(() {
      _wasOffline = false;
      _showingBackOnline = true;
    });
    _hideTimer = Timer(_backOnlineDuration, () {
      if (!mounted) return;
      setState(() => _showingBackOnline = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final offline = !connectivityStore.isOnline;
    if (!offline && !_showingBackOnline) return widget.child;

    return Column(
      children: [
        _buildBanner(context, backOnline: !offline),
        Expanded(
          // The bar has already cleared the status bar for the screen below,
          // so the screen's own SafeArea must not add that inset a second
          // time while the bar is up.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }

  Widget _buildBanner(BuildContext context, {required bool backOnline}) {
    final background =
        backOnline ? C.successSoft(context) : C.warningSoft(context);
    final foreground =
        backOnline ? C.onSuccessSoft(context) : C.warningText(context);

    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          // Announced when it appears, without stealing focus.
          liveRegion: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  backOnline
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  size: 16,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    backOnline
                        ? 'Back online'
                        : "You're offline. Some things may not work.",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
