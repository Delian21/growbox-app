import 'package:flutter/foundation.dart';

// Web reads `navigator.onLine` and the online/offline events; every other
// platform asks `connectivity_plus` (the native build's own signal).
import 'connectivity_signal_native.dart'
    if (dart.library.html) 'connectivity_signal_web.dart';

/// App-wide network status, the single source the banner and checkout read.
///
/// Two inputs meet here: the platform signal (the browser, on web) and the
/// demo tools' "Simulate offline" switch. Both end in [notifyListeners], so a
/// widget only has to listen to this store.
class ConnectivityStore extends ChangeNotifier {
  final PlatformConnectivity _signal = PlatformConnectivity();

  bool _platformOnline = true;
  bool _simulatedOffline = false;

  /// False while the platform reports offline or the demo switch is on.
  bool get isOnline => _platformOnline && !_simulatedOffline;

  /// Whether the demo switch is forcing offline.
  bool get simulatedOffline => _simulatedOffline;

  /// Subscribes to the platform signal. Called once from [main]; calling it
  /// again would duplicate the listeners.
  void start() {
    _platformOnline = _signal.isOnline;
    _signal.start(_setPlatformOnline);
  }

  void _setPlatformOnline(bool online) {
    if (_platformOnline == online) return;
    _platformOnline = online;
    notifyListeners();
  }

  /// Demo-only override, used by the Profile demo tools.
  void setSimulatedOffline(bool value) {
    if (_simulatedOffline == value) return;
    _simulatedOffline = value;
    notifyListeners();
  }
}

/// One connection state for the whole app.
final ConnectivityStore connectivityStore = ConnectivityStore();
