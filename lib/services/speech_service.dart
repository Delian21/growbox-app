import 'dart:async';

/// One event from a running speech session.
///
/// Partial and final are separate types instead of a `bool` on one class so a
/// caller cannot forget to check the flag — the submit path only accepts a
/// final, and a typo cannot make a partial submit twice.
sealed class SpeechEvent {
  const SpeechEvent();
}

/// Words recognised so far. The engine revises these as the sentence grows, so
/// the newest event replaces the previous one rather than adding to it.
class SpeechPartial extends SpeechEvent {
  final String text;
  const SpeechPartial(this.text);
}

/// The engine's settled transcript. What was said does not change after this.
class SpeechFinal extends SpeechEvent {
  final String text;
  const SpeechFinal(this.text);
}

/// The session ended without usable words.
class SpeechFailure extends SpeechEvent {
  final SpeechFailureKind kind;

  /// The platform's own wording, for logs. Never shown to the customer.
  final String? detail;

  const SpeechFailure(this.kind, {this.detail});
}

/// Why a session failed, reduced to the cases the UI can act on.
enum SpeechFailureKind {
  /// The microphone permission was refused (or was revoked mid-session).
  permissionDenied,

  /// The recogniser exists but did not hear a word.
  noMatch,

  /// The device or browser has no speech recognition at all.
  unavailable,

  /// Recognition needs a connection and had none.
  network,

  /// Anything the platform reported that the app cannot classify.
  other,
}

/// The speech engine the search field talks to.
///
/// An interface rather than using `speech_to_text` directly, for two reasons:
/// widget tests get a fake with no platform channel (the plugin's methods all
/// hang in a test binding), and the screens only know about partials, finals
/// and failures instead of the plugin's listener callbacks.
abstract class SpeechService {
  /// Prepares the engine and picks a locale. Safe to call repeatedly: the
  /// result is cached, so a second mic tap does not re-initialise the engine.
  Future<bool> initialize();

  /// True once [initialize] has succeeded.
  bool get isAvailable;

  /// True between [start] and the end of the session.
  bool get isListening;

  /// Every event of the current and any later session.
  ///
  /// One broadcast stream for the life of the service: subscribers attach when
  /// a session starts and detach when it ends, so a stream cannot be closed out
  /// from under the next session.
  Stream<SpeechEvent> get events;

  /// Starts a session. Throws nothing: failures arrive on [events].
  Future<void> start();

  /// Ends the session and keeps what was heard (the engine sends a final).
  Future<void> stop();

  /// Ends the session and discards what was heard.
  Future<void> cancel();
}
