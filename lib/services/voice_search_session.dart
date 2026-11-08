import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'speech_service.dart';
import 'voice_search_service.dart';

/// The state of the mic-button experience.
enum VoiceSearchState {
  /// Not listening, nothing to report.
  idle,

  /// The microphone is open and the field is showing partial words.
  listening,

  /// The session ended without a usable transcript; [VoiceSearchSession.message]
  /// carries what to show and the UI offers a retry.
  failed,

  /// Speech recognition is not available here (no engine, or permission
  /// refused), so the button is drawn disabled instead of doing nothing.
  unavailable,
}

/// Drives one voice query: start, live partials, stop-on-silence, submit.
///
/// The timing rules live here rather than in the screen so they can be tested
/// against a fake engine without pumping a keyboard or waiting on a plugin:
///
/// * every partial restarts a [silence] timer; when it fires with words, the
///   session stops and submits — this is what makes a short "rice" search fast,
///   because the engine's own `pauseFor` is never waited for;
/// * a final result submits immediately and only once;
/// * a session that hears nothing for [firstResultTimeout] stops and reports a
///   failure instead of leaving the mic open;
/// * a second tap while listening stops the session.
class VoiceSearchSession extends ChangeNotifier {
  VoiceSearchSession({
    required this.speech,
    VoiceSearchMatcher? matcher,
    this.silence = const Duration(milliseconds: 1200),
    this.firstResultTimeout = const Duration(seconds: 6),
    this.onPartial,
    this.onSubmit,
    this.haptics = true,
  }) : _matcher = matcher ?? VoiceSearchMatcher();

  /// How long a gap between words ends the query. Deliberately shorter than the
  /// engine's own end-of-speech pause: "rice" is a finished query, not a pause
  /// in a sentence.
  final Duration silence;

  /// How long to wait for any word at all before giving up.
  final Duration firstResultTimeout;

  final SpeechService speech;
  final VoiceSearchMatcher _matcher;

  /// Called with every partial transcript, so the field can show the words.
  final void Function(String text)? onPartial;

  /// Called with the finished query, already mapped onto the catalogue.
  final void Function(String query)? onSubmit;

  /// Off in tests, where platform haptics would need a channel handler.
  final bool haptics;

  StreamSubscription<SpeechEvent>? _subscription;
  Timer? _silenceTimer;
  Timer? _firstResultTimer;

  VoiceSearchState _state = VoiceSearchState.idle;
  String _transcript = '';
  String? _message;

  VoiceSearchState get state => _state;
  bool get isListening => _state == VoiceSearchState.listening;

  /// The best transcript so far, as the engine reported it.
  String get transcript => _transcript;

  /// What to show when [state] is [VoiceSearchState.failed] or
  /// [VoiceSearchState.unavailable].
  String? get message => _message;

  /// The plugin is initialised when the field first appears, so the button can
  /// tell "unsupported" from "not started yet" without waiting for a tap.
  Future<void> prepare() async {
    final available = await speech.initialize();
    if (!available && _state != VoiceSearchState.unavailable) {
      _state = VoiceSearchState.unavailable;
      _message = "Voice search isn't available on this device.";
      notifyListeners();
    }
  }

  /// The mic button: starts a session, or stops the running one.
  Future<void> toggle() async {
    if (isListening) return _finish();
    return start();
  }

  Future<void> start() async {
    _silenceTimer?.cancel();
    _firstResultTimer?.cancel();
    _subscription?.cancel();
    _transcript = '';
    _message = null;

    final available = await speech.initialize();
    if (!available) {
      _state = VoiceSearchState.unavailable;
      _message = "Voice search isn't available on this device.";
      notifyListeners();
      return;
    }

    _state = VoiceSearchState.listening;
    notifyListeners();
    if (haptics) HapticFeedback.selectionClick();

    _subscription = speech.events.listen(_onEvent);
    await speech.start();

    // Nothing heard at all: stop and let the customer retry, rather than
    // holding the microphone until the engine's 12-second ceiling.
    _firstResultTimer = Timer(firstResultTimeout, () {
      if (!isListening) return;
      _fail("Didn't catch that. Try again.");
    });
  }

  void _onEvent(SpeechEvent event) {
    switch (event) {
      case SpeechPartial(:final text):
        if (text.trim().isEmpty) return;
        _heard(text);
        // Each partial is a new "still speaking" signal.
        _silenceTimer?.cancel();
        _silenceTimer = Timer(silence, () {
          if (isListening) _finish();
        });
      case SpeechFinal(:final text):
        // A final ends the query on the spot: no silence timer, no second
        // submit if a partial had already scheduled one.
        _silenceTimer?.cancel();
        _firstResultTimer?.cancel();
        if (text.trim().isEmpty) {
          _fail("Didn't catch that. Try again.");
          return;
        }
        _heard(text);
        _finish();
      case SpeechFailure(:final kind):
        _silenceTimer?.cancel();
        _firstResultTimer?.cancel();
        if (kind == SpeechFailureKind.permissionDenied) {
          _state = VoiceSearchState.unavailable;
          _message = 'Microphone access is off. Turn it on to search by voice.';
        } else {
          _state = VoiceSearchState.failed;
          _message = "Didn't catch that. Try again.";
        }
        unawaited(speech.cancel());
        notifyListeners();
    }
  }

  /// Records words and pushes them into the search field as they arrive.
  void _heard(String text) {
    _transcript = text.trim();
    _firstResultTimer?.cancel();
    _firstResultTimer = null;
    onPartial?.call(_transcript);
  }

  /// Stops the current session because it ended or was tapped off.
  Future<void> _finish() async {
    final hadWords = _transcript.trim().isNotEmpty;
    _silenceTimer?.cancel();
    _firstResultTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _state = VoiceSearchState.idle;
    if (haptics) HapticFeedback.selectionClick();
    notifyListeners();

    await speech.stop();
    if (!hadWords) {
      _fail("Didn't catch that. Try again.");
      return;
    }
    // The catalogue's own wording when the transcript is close to it, so
    // "rise" searches Rice instead of finding nothing.
    onSubmit?.call(_matcher.resolve(_transcript));
  }

  void _fail(String message) {
    _silenceTimer?.cancel();
    _firstResultTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    unawaited(speech.cancel());
    _state = VoiceSearchState.failed;
    _message = message;
    notifyListeners();
  }

  /// Retry after a failure: the message is cleared and a fresh session starts.
  Future<void> retry() async {
    _state = VoiceSearchState.idle;
    _message = null;
    notifyListeners();
    await start();
  }

  /// Drops the session without submitting: switched tab, pushed route, app
  /// backgrounded, or screen disposed. The microphone is released.
  Future<void> cancel() async {
    _silenceTimer?.cancel();
    _firstResultTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    final wasListening = isListening;
    _state = VoiceSearchState.idle;
    _transcript = '';
    _message = null;
    if (wasListening) notifyListeners();
    await speech.cancel();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _firstResultTimer?.cancel();
    _subscription?.cancel();
    unawaited(speech.cancel());
    super.dispose();
  }
}
