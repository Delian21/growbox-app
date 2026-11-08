import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_service.dart';

/// The real engine: `speech_to_text`, configured once for short search queries.
///
/// Everything that used to be decided at the call site lives here now:
///
/// * `partialResults: true` — the field shows words as they are recognised,
///   instead of waiting for the engine's own pause.
/// * `listenMode: ListenMode.search` — the mode for "a sequence of search
///   terms" rather than dictation. Only iOS honours it; it is harmless
///   elsewhere, and [start] falls back to dictation if a platform rejects it.
/// * `listenFor: 12 s` and `pauseFor: 2 s` — ceilings only. The UI submits on
///   its own 1.2 s silence timer, so a customer never waits out `pauseFor`.
/// * Locale: en-NG, then en-GB, then en-US, then whatever the device uses,
///   chosen from the engine's own list so an unavailable one is never asked
///   for.
class SpeechToTextService implements SpeechService {
  SpeechToTextService({SpeechToText? engine, List<String>? localePreferences})
      : _speech = engine ?? SpeechToText(),
        _localePreferences = localePreferences ?? defaultLocalePreferences;

  /// Nigeriian English first (the catalogue is priced in naira), then the two
  /// broadest English models, then the device default.
  static const List<String> defaultLocalePreferences = [
    'en_NG',
    'en_GB',
    'en_US',
  ];

  /// Hard ceiling on one session, so a stuck engine cannot hold the mic.
  static const Duration listenFor = Duration(seconds: 12);

  /// The engine's own end-of-speech pause. A fallback: the UI stops earlier.
  static const Duration pauseFor = Duration(seconds: 2);

  final SpeechToText _speech;
  final List<String> _localePreferences;

  final StreamController<SpeechEvent> _events =
      StreamController<SpeechEvent>.broadcast();

  Future<bool>? _initialization;
  bool _available = false;
  bool _listening = false;

  /// The locale the engine was asked to use, once resolved.
  String? _localeId;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _listening;

  /// Initialises once. The plugin caches its own initialisation too, but the
  /// locale lookup and permission answer are kept here so repeated mic taps
  /// cost nothing.
  @override
  Future<bool> initialize() {
    return _initialization ??= _initialize();
  }

  Future<bool> _initialize() async {
    try {
      final ok = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
      if (!ok) {
        _available = false;
        return false;
      }
      _localeId = await _pickLocale();
      _available = true;
      return true;
    } catch (error) {
      // No platform implementation (some browsers, a PWA without the plugin)
      // or the plugin refused to start: "not supported", not a crash.
      debugPrint('Speech recognition unavailable: $error');
      _available = false;
      return false;
    }
  }

  /// The first preferred locale the engine actually offers.
  ///
  /// Matching ignores case and separators because platforms disagree: iOS
  /// reports `en-NG`, Android `en_NG`, and some browsers drop the region. When
  /// none of the preferences exist, null is returned and the engine uses the
  /// device default — which is also what the requirement asks for last.
  Future<String?> _pickLocale() async {
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) return null;

      String normalize(String id) =>
          id.toLowerCase().replaceAll('-', '_').replaceAll('_', '');

      for (final preferred in _localePreferences) {
        final wanted = normalize(preferred);
        for (final locale in locales) {
          if (normalize(locale.localeId) == wanted) return locale.localeId;
        }
      }
    } catch (_) {
      // A platform without a locale list simply uses its default.
    }
    return null;
  }

  @override
  Future<void> start() async {
    if (_listening) return;

    final ready = await initialize();
    if (!ready) {
      _events.add(const SpeechFailure(SpeechFailureKind.unavailable));
      return;
    }

    _listening = true;
    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          // Search mode where it exists, but the important part is that the
          // engine reports words before the sentence is complete.
          listenMode: ListenMode.search,
          partialResults: true,
          cancelOnError: true,
          listenFor: listenFor,
          pauseFor: pauseFor,
          localeId: _localeId,
        ),
      );
    } catch (error) {
      // `ListenMode.search` is an iOS-only mode; a platform that rejects it
      // still gets a session, just with the default mode.
      try {
        await _speech.listen(
          onResult: _onResult,
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: true,
            listenFor: listenFor,
            pauseFor: pauseFor,
            localeId: _localeId,
          ),
        );
      } catch (_) {
        _listening = false;
        debugPrint('Speech session could not start: $error');
        _events.add(const SpeechFailure(SpeechFailureKind.unavailable));
      }
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.trim();

    if (result.finalResult) {
      // The end of the session, whatever it contains. An empty final is a real
      // outcome ("nothing was caught") and is forwarded so the UI can offer a
      // retry instead of sitting there.
      _listening = false;
      _events.add(SpeechFinal(text));
      return;
    }

    // A partial with no words yet (the engine's first few frames) is noise.
    if (text.isEmpty) return;
    _events.add(SpeechPartial(text));
  }

  void _onError(SpeechRecognitionError error) {
    _listening = false;
    _events.add(
      SpeechFailure(
        _classify(error.errorMsg),
        detail: error.errorMsg,
      ),
    );
  }

  /// Maps the plugin's error strings onto the cases the UI can act on.
  SpeechFailureKind _classify(String errorMsg) {
    final msg = errorMsg.toLowerCase();
    if (msg.contains('permission')) return SpeechFailureKind.permissionDenied;
    if (msg.contains('no_match') || msg.contains('speech_timeout')) {
      return SpeechFailureKind.noMatch;
    }
    if (msg.contains('network')) return SpeechFailureKind.network;
    if (msg.contains('not_available') || msg.contains('client')) {
      return SpeechFailureKind.unavailable;
    }
    return SpeechFailureKind.other;
  }

  void _onStatus(String status) {
    // The engine's own status strings. Only the terminal ones matter: the
    // final result carries the words, and the UI owns the stopping.
    final lower = status.toLowerCase();
    if (lower == 'done' || lower == 'notlistening') {
      _listening = false;
    }
  }

  @override
  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    try {
      await _speech.stop();
    } catch (_) {
      // Already stopped by the engine.
    }
  }

  @override
  Future<void> cancel() async {
    _listening = false;
    try {
      await _speech.cancel();
    } catch (_) {
      // Nothing was running.
    }
  }
}

/// The app's one speech engine.
///
/// Shared so Search and the catalog do not each pay an initialisation (and a
/// permission prompt round-trip) — the engine is a process-wide resource, and
/// only one session can hold the microphone anyway.
final SpeechService platformSpeechService = SpeechToTextService();
