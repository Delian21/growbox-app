import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;

/// Thrown by [MockBackend] when a request has been armed to fail.
///
/// The UI only cares that the call threw, so it has no fields: every failure
/// is shown as the same "check your connection" state.
class MockNetworkException implements Exception {
  const MockNetworkException();

  @override
  String toString() => 'MockNetworkException: the request failed.';
}

/// The network the mock repositories pretend to use.
///
/// There is no server anywhere in this app, so every repository call goes
/// through here instead: it waits [latency] so skeletons and spinners are
/// visible, fails once after [failNextRequest] (the demo tools' button), and
/// gives up after [timeout] so a request that never resolves still ends in the
/// UI's error state rather than a permanent skeleton.
class MockBackend {
  MockBackend._();

  /// How long a mock request takes. Long enough to see the loading state,
  /// short enough that it never feels broken.
  static Duration latency = const Duration(milliseconds: 600);

  /// Hard deadline for a single request, mirroring what the UI treats as a
  /// hung connection.
  static const Duration timeout = Duration(seconds: 10);

  static bool _failNext = false;

  /// Arms exactly one failure. The next [run] throws [MockNetworkException]
  /// and the flag clears itself, so a retry succeeds again.
  static void failNextRequest() => _failNext = true;

  /// Armed by the demo tools' "Fail next order" button.
  static bool _failNextOrder = false;

  /// Arms exactly one failed order placement.
  ///
  /// Placement is not a [run] call (checkout writes straight to local
  /// storage, not through a repository), so it asks [takeOrderFailure]
  /// instead. One-shot for the same reason as [failNextRequest]: the retry
  /// must succeed, or the failure screen's "Try again" would loop.
  static void failNextOrder() => _failNextOrder = true;

  /// Consumes the armed placement failure: true exactly once.
  static bool takeOrderFailure() {
    final fail = _failNextOrder;
    _failNextOrder = false;
    return fail;
  }

  /// Runs [load] behind the simulated latency and deadline.
  static Future<T> run<T>(FutureOr<T> Function() load) {
    final fail = _failNext;
    _failNext = false;
    return Future<T>.delayed(latency, () {
      if (fail) throw const MockNetworkException();
      return load();
    }).timeout(timeout);
  }
}

/// Whether the demo-only controls exist in this build.
///
/// True in `flutter run` (debug) and in a release built with
/// `--dart-define=DEMO_TOOLS=true`; a normal release build has neither, so
/// [profile] omits the section entirely and the optimizer drops the code.
const bool kDemoTools = kDebugMode || bool.fromEnvironment('DEMO_TOOLS');
