import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Reads the current time. Tests replace [SessionStore.clock] with a value they
/// control, so the 30-minute window can be crossed without waiting.
typedef Clock = DateTime Function();

/// The mock signed-in session.
///
/// Only an identifier, the email it belongs to and the last activity stamp are
/// stored — never a password, token or anything else secret. [lastActiveAt] is
/// what [kSessionAwayLimit] is measured from.
///
/// CLIENT-SIDE ONLY: with a real backend this becomes a short-lived access
/// token plus a refresh token, and the server — not this class — decides
/// whether a session is still valid.
class MockSession {
  const MockSession({
    required this.userId,
    required this.email,
    required this.lastActiveAt,
  });

  final String userId;

  /// Empty for a guest who tapped "Skip" instead of signing up.
  final String email;

  final DateTime lastActiveAt;

  bool get isGuest => email.isEmpty;

  MockSession copyWith({DateTime? lastActiveAt}) => MockSession(
        userId: userId,
        email: email,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'lastActiveAt': lastActiveAt.toIso8601String(),
      };

  /// Returns null for anything that is not a complete, usable session, so a
  /// corrupt or half-written record is treated as "signed out" rather than
  /// crashing startup.
  static MockSession? fromJson(Map<String, dynamic> json) {
    final userId = json['userId'];
    final email = json['email'];
    final rawStamp = json['lastActiveAt'];
    if (userId is! String || userId.isEmpty) return null;
    if (email is! String) return null;
    if (rawStamp is! String) return null;
    final stamp = DateTime.tryParse(rawStamp);
    if (stamp == null) return null;
    return MockSession(userId: userId, email: email, lastActiveAt: stamp);
  }
}

/// Persists [MockSession] in shared_preferences and enforces the away limit.
///
/// Reads are synchronous from memory (restored in `main()` before the first
/// frame); writes go through the same storage plugin the rest of the app uses.
class SessionStore {
  SessionStore._();

  static const String _storageKey = 'mock_session_v1';

  /// Persisted stamps are refreshed at most this often while the customer is
  /// interacting, so a scrolling session does not write on every touch.
  static const Duration _touchThrottle = Duration(minutes: 1);

  /// Injectable clock. Replaced by tests.
  static Clock clock = DateTime.now;

  static MockSession? _session;

  /// When we last wrote `lastActiveAt`, used to throttle [markActive].
  static DateTime? _lastWrite;

  static MockSession? get session => _session;
  static bool get isSignedIn => _session != null;
  static bool get isGuest => _session?.isGuest ?? false;

  /// The copy LoginScreen shows after an automatic sign-out.
  static String get signedOutNotice =>
      'You were signed out after ${kSessionAwayLimit.inMinutes} minutes away. '
      'Please log in again.';

  /// True when the stored session is older than [kSessionAwayLimit].
  static bool get isExpired {
    final current = _session;
    if (current == null) return false;
    return _isPastLimit(current);
  }

  static bool _isPastLimit(MockSession value) =>
      clock().difference(value.lastActiveAt) > kSessionAwayLimit;

  /// Loads the session written by a previous run, dropping it if the customer
  /// has been away too long. Called from `main()` before the first frame.
  static Future<void> restore() async {
    _session = null;
    _lastWrite = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final restored = MockSession.fromJson(map);
      if (restored == null) {
        // Unreadable: drop the record so the next start is clean.
        await prefs.remove(_storageKey);
        return;
      }
      // An expired record is kept in memory on purpose: [AppEntryGate] calls
      // [clearIfExpired] and, when that has just happened, opens LoginScreen
      // with the "signed out after 30 minutes" notice. Dropping it here would
      // make a cold start look like a plain signed-out start and show the
      // welcome screen instead.
      _session = restored;
      _lastWrite = restored.lastActiveAt;
    } catch (_) {
      // Unreadable storage simply means "signed out"; never crash startup.
    }
  }

  /// Signs a customer in after login or sign-up. Only identity is kept.
  static Future<void> start({required String email}) async {
    final trimmed = email.trim();
    _session = MockSession(
      userId: 'usr_${trimmed.toLowerCase()}',
      email: trimmed,
      lastActiveAt: clock(),
    );
    _lastWrite = _session!.lastActiveAt;
    await _write();
  }

  /// Starts the session a guest gets by skipping sign-up, so they are not sent
  /// back to the welcome screen on the next cold start.
  static Future<void> startGuest() async {
    _session = MockSession(
      userId: 'guest',
      email: '',
      lastActiveAt: clock(),
    );
    _lastWrite = _session!.lastActiveAt;
    await _write();
  }

  /// Clears the session and nothing else: cart, addresses, the selected
  /// address, the theme choice and onboardingSeen all survive.
  static Future<void> clear() async {
    _session = null;
    _lastWrite = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Best effort: the in-memory session is gone either way.
    }
  }

  /// Records that the customer is still here.
  ///
  /// Writes at most once per [_touchThrottle] unless [force] is set (going to
  /// the background, or coming back, has to be exact).
  static Future<void> markActive({bool force = false}) async {
    final current = _session;
    if (current == null) return;
    final now = clock();
    final lastWrite = _lastWrite;
    if (!force &&
        lastWrite != null &&
        now.difference(lastWrite) < _touchThrottle) {
      return;
    }
    _session = current.copyWith(lastActiveAt: now);
    _lastWrite = now;
    await _write();
  }

  /// Clears the session if it is past the limit; returns whether it did.
  ///
  /// Used on resume and by the entry gate, so both paths share one rule.
  static Future<bool> clearIfExpired() async {
    if (!isExpired) return false;
    await clear();
    return true;
  }

  static Future<void> _write() async {
    final current = _session;
    if (current == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(current.toJson()));
    } catch (_) {
      // Persistence is best effort; the in-memory session still applies.
    }
  }
}
