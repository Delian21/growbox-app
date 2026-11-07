import 'dart:js_interop';

// The smallest view of the browser globals this file needs. `dart:js_interop`
// is the supported way to reach them from a web build; there is no package to
// add and nothing here ships in a native build.
extension type _Navigator._(JSObject _) implements JSObject {
  external bool get onLine;
}

extension type _Window._(JSObject _) implements JSObject {
  external _Navigator get navigator;
  external set ononline(JSFunction? handler);
  external set onoffline(JSFunction? handler);
}

@JS('window')
external _Window get _window;

/// Connectivity signal for the web build: the browser's own answer.
///
/// `navigator.onLine` gives the current state, and the window's `online` /
/// `offline` events say when it changes. The native build asks
/// `connectivity_plus` instead, so a web build still ships nothing extra.
class PlatformConnectivity {
  bool get isOnline => _window.navigator.onLine;

  void start(void Function(bool online) onChange) {
    _window.ononline = (() => onChange(true)).toJS;
    _window.onoffline = (() => onChange(false)).toJS;
  }
}
