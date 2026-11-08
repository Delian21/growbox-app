import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/screens/search_screen.dart';
import 'package:growbox/services/speech_service.dart';
import 'package:growbox/services/voice_search_service.dart';

/// A speech engine with no platform channel behind it.
///
/// Widget tests cannot use `speech_to_text`: its methods wait on a channel that
/// no test binding answers, so a session would simply hang. The fake also makes
/// the interesting cases reachable — a partial that stops being revised, a
/// final, an empty final, no engine at all — which a real microphone cannot.
class FakeSpeechService implements SpeechService {
  FakeSpeechService({this.available = true});

  bool available;
  int initCalls = 0;
  int starts = 0;
  int stops = 0;
  int cancels = 0;

  final StreamController<SpeechEvent> _events =
      StreamController<SpeechEvent>.broadcast();
  bool _listening = false;

  @override
  Future<bool> initialize() async {
    initCalls++;
    return available;
  }

  @override
  bool get isAvailable => available;

  @override
  bool get isListening => _listening;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Future<void> start() async {
    starts++;
    _listening = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    _listening = false;
  }

  void partial(String text) => _events.add(SpeechPartial(text));
  void finalResult(String text) => _events.add(SpeechFinal(text));
  void fail(SpeechFailureKind kind) => _events.add(SpeechFailure(kind));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget harness(FakeSpeechService speech) => ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: MaterialApp(home: SearchScreen(speechService: speech)),
      );

  Finder mic() => find.byKey(const ValueKey('voiceSearchMic'));
  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('a partial, then silence, submits the search', (tester) async {
    final speech = FakeSpeechService();
    await tester.pumpWidget(harness(speech));
    await tester.pumpAndSettle();

    await tester.tap(mic());
    await tester.pump();
    expect(speech.starts, 1);
    expect(find.text('Listening…'), findsOneWidget);

    // The word appears in the field as it is recognised, without submitting.
    speech.partial('rise');
    await tester.pump();
    expect(fieldText(tester), 'rise');
    expect(speech.stops, 0);

    // 1.2 s of no new partial ends the query on its own, well before the
    // engine's own 2 s pause.
    await tester.pump(const Duration(milliseconds: 1300));

    expect(speech.stops, 1);
    // "rise" is matched to the catalogue's "Rice" so the search finds it.
    expect(fieldText(tester), 'Rice');
    expect(find.text('Listening…'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a final result submits exactly once', (tester) async {
    final speech = FakeSpeechService();
    await tester.pumpWidget(harness(speech));
    await tester.pumpAndSettle();

    await tester.tap(mic());
    await tester.pump();

    speech.partial('bea');
    await tester.pump();
    speech.partial('beans');
    await tester.pump();
    speech.finalResult('beans');
    await tester.pump();

    expect(speech.stops, 1);
    expect(fieldText(tester), 'Beans');

    // The silence timer that the partials started must not submit again.
    await tester.pump(const Duration(seconds: 3));
    expect(speech.stops, 1);
  });

  testWidgets('an empty result offers a retry', (tester) async {
    final speech = FakeSpeechService();
    await tester.pumpWidget(harness(speech));
    await tester.pumpAndSettle();

    await tester.tap(mic());
    await tester.pump();
    speech.finalResult('');
    await tester.pump();

    expect(find.text("Didn't catch that. Try again."), findsOneWidget);
    expect(find.byKey(const ValueKey('voiceSearchRetry')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('voiceSearchRetry')));
    await tester.pump();
    expect(speech.starts, 2);
    expect(find.text("Didn't catch that. Try again."), findsNothing);
  });

  testWidgets('hearing nothing for six seconds asks for a retry',
      (tester) async {
    final speech = FakeSpeechService();
    await tester.pumpWidget(harness(speech));
    await tester.pumpAndSettle();

    await tester.tap(mic());
    await tester.pump();
    expect(find.text('Listening…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));

    expect(find.text("Didn't catch that. Try again."), findsOneWidget);
    expect(speech.cancels, greaterThanOrEqualTo(1));
  });

  testWidgets('no speech recognition means no mic', (tester) async {
    final speech = FakeSpeechService(available: false);
    await tester.pumpWidget(harness(speech));
    await tester.pumpAndSettle();

    // The engine is asked once on open, and the button is not drawn at all.
    expect(speech.initCalls, 1);
    expect(mic(), findsNothing);
    expect(
      find.text("Voice search isn't available on this device."),
      findsOneWidget,
    );
  });

  testWidgets('a missed second tap stops instead of listening twice',
      (tester) async {
    final speech = FakeSpeechService();
    await tester.pumpWidget(harness(speech));
    await tester.pumpAndSettle();

    await tester.tap(mic());
    await tester.pump();
    speech.partial('rice');
    await tester.pump();

    // Tapping the pulsing mic ends the session and submits what was heard.
    await tester.tap(mic());
    await tester.pump();

    expect(speech.starts, 1);
    expect(speech.stops, 1);
    expect(fieldText(tester), 'Rice');
    await tester.pumpAndSettle();
  });

  testWidgets('disposing the screen cancels the microphone', (tester) async {
    final speech = FakeSpeechService();
    await tester.pumpWidget(harness(speech));
    await tester.pumpAndSettle();

    await tester.tap(mic());
    await tester.pump();
    expect(speech.isListening, isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(speech.cancels, greaterThanOrEqualTo(1));
    expect(speech.isListening, isFalse);
  });

  group('catalog matching', () {
    VoiceSearchMatcher matcher() => VoiceSearchMatcher(
          productNames: const ['Rice', 'Beans', 'Tomatoes', 'Palm Oil'],
          vendorNames: const ['Green Farm', 'Yummy Bunch'],
        );

    test('repairs a common mishearing', () {
      expect(matcher().resolve('rise'), 'Rice');
    });

    test('ignores case and punctuation', () {
      expect(matcher().resolve('  RICE! '), 'Rice');
      expect(matcher().resolve('green farm'), 'Green Farm');
    });

    test('uses a near miss, not a distant one', () {
      expect(matcher().resolve('beenz'), 'Beans');
      // "peas" is not near "Rice" or "Beans": search it as spoken.
      expect(matcher().resolve('peas'), 'peas');
    });

    test('keeps an unmatched query as the customer said it', () {
      expect(matcher().resolve('dragon fruit'), 'dragon fruit');
    });
  });
}
