// Welcome-step fold check — run on demand, not part of `flutter test`'s
// default run (it lives in tool/, not test/, because it needs real font files).
//
//     flutter test tool/welcome_fit_check.dart
//
// The sign-up wizard uses google_fonts, which downloads Poppins/Inter at
// runtime; in a widget test the fallback test font has different metrics, so a
// fold measurement taken with it would be meaningless. This harness loads the
// real TTFs through tool/real_fonts.dart, which documents how to fetch them
// into the (gitignored) build/ directory and fails fast when they are missing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:growbox/screens/registration_screen.dart';

import 'real_fonts.dart';

/// Measures the welcome step and returns whether its last two elements — the
/// consent notice and the Skip shortcut — end above the fold.
Future<({Rect notice, Rect skip, double fold, double maxScroll})> _measure(
  WidgetTester tester,
  Size size,
  FakeViewPadding insets,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = insets;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
    home: const RegistrationScreen(),
  ));
  await tester.pumpAndSettle();

  final scroll = tester.state<ScrollableState>(find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  ));
  final position = scroll.position;

  final notice = tester.getRect(find.byWidgetPredicate((w) =>
      w is RichText && w.text.toPlainText().contains('By continuing,')));
  final skip = tester.getRect(find.text('Skip'));

  // The fold is the bottom of the usable area, not the raw window: the whole
  // layout sits inside a SafeArea.
  return (
    notice: notice,
    skip: skip,
    fold: size.height - insets.bottom,
    maxScroll: position.maxScrollExtent,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The sizes the design is checked against, plus two diagnostics: a 320-wide
  // phone below the target, and a taller phone the compact layout skips.
  final cases = <(String, Size, FakeViewPadding, bool)>[
    ('360x640 (target)', const Size(360, 640), FakeViewPadding.zero, true),
    ('360x640 + gesture inset', const Size(360, 640),
        const FakeViewPadding(top: 24, bottom: 34), true),
    ('360x640 + notch', const Size(360, 640),
        const FakeViewPadding(top: 47, bottom: 34), true),
    ('320x568', const Size(320, 568), FakeViewPadding.zero, false),
    ('360x780', const Size(360, 780), FakeViewPadding.zero, false),
    ('390x844', const Size(390, 844), FakeViewPadding.zero, false),
  ];

  for (final (label, size, insets, required) in cases) {
    testWidgets('welcome step at $label', (tester) async {
      // In the test body, not setUpAll: the binding hands out a fresh binary
      // messenger for every test, which would drop the asset handler that keeps
      // google_fonts offline.
      await loadRealFonts();

      final r = await _measure(tester, size, insets);

      debugPrint('MEASURE $label '
          'notice=[${r.notice.top.toStringAsFixed(0)}..'
          '${r.notice.bottom.toStringAsFixed(0)}] '
          'skip=[${r.skip.top.toStringAsFixed(0)}..'
          '${r.skip.bottom.toStringAsFixed(0)}] '
          'fold=${r.fold.toStringAsFixed(0)} '
          'maxScroll=${r.maxScroll.toStringAsFixed(1)}');

      if (!required) return; // recorded for context only

      expect(r.notice.bottom, lessThanOrEqualTo(r.fold),
          reason: 'consent notice must be above the fold at $label');
      expect(r.skip.bottom, lessThanOrEqualTo(r.fold),
          reason: 'Skip must be above the fold at $label');
    });
  }
}
