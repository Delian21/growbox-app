import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity signal for builds with a real network stack (Android, iOS,
/// desktop): the platform's own answer, via `connectivity_plus`.
///
/// The plugin reports which transports exist, not whether the internet is
/// reachable — a Wi-Fi network with no uplink still reads as connected. That is
/// the same guarantee the browser gives on web, so the banner and checkout
/// behave alike on every platform: they react to the device losing its link.
class PlatformConnectivity {
  final Connectivity _plugin = Connectivity();

  /// Last known state. Starts online so the first frames never flash an
  /// offline banner before the plugin has answered; the store keeps the real
  /// value after that, so this copy never changes.
  final bool _online = true;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isOnline => _online;

  void start(void Function(bool online) onChange) {
    // Stream listened to once: start() is called once from main, and a second
    // subscription would double every event.
    _subscription ??= _plugin.onConnectivityChanged.listen(
      (results) => onChange(_isOnline(results)),
      // A platform without the plugin (tests, an unsupported host) keeps the
      // optimistic default instead of throwing out of the stream.
      onError: (_) {},
    );

    // The current value, for the case where the app starts offline: the
    // stream only reports changes from now on. Ignored when unavailable, for
    // the same reason as the stream's onError.
    _plugin.checkConnectivity().then(
          (results) => onChange(_isOnline(results)),
          onError: (_) {},
        );
  }

  /// None of the reported transports means offline; anything else (wifi,
  /// mobile, ethernet, vpn) means there is a link to send over.
  static bool _isOnline(List<ConnectivityResult> results) =>
      results.isEmpty || results.any((result) => result != ConnectivityResult.none);
}
