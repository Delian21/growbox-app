import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/screens/registration_screen.dart';
import 'package:growbox/screens/splash_screen.dart';
import 'package:growbox/theme.dart';

/// The splash and the sign-up hero are brand surfaces: the white logo and
/// orange wordmark were drawn for #1C4815, so those screens must not follow
/// the theme. These tests pin that in every appearance the app can be in.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget themed(Widget home, ThemeMode mode) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      themeMode: mode,
      home: home,
    );
  }

  // The three appearances a phone can actually produce: light, dark, and
  // "follow the system" while the system is dark.
  final cases = <({String name, ThemeMode mode, Brightness platform})>[
    (name: 'ThemeMode.light', mode: ThemeMode.light, platform: Brightness.light),
    (name: 'ThemeMode.dark', mode: ThemeMode.dark, platform: Brightness.light),
    (
      name: 'ThemeMode.system with a dark platform',
      mode: ThemeMode.system,
      platform: Brightness.dark,
    ),
  ];

  for (final testCase in cases) {
    testWidgets('splash stays brand green under ${testCase.name}', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = testCase.platform;

      await tester.pumpWidget(
        themed(const SplashScreen(), testCase.mode),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // The painted background is the fixed brand green, not the theme's
      // primary (which is #7ED36B in dark mode).
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.brand);

      // And the radial highlight ramps from the lifted green in the middle
      // to exactly brand at the edges — never toward white.
      final glow = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).gradient is RadialGradient,
        ),
      );
      final gradient =
          (glow.decoration as BoxDecoration).gradient! as RadialGradient;
      expect(gradient.colors.first, AppColors.brandHighlight);
      expect(gradient.colors.last, AppColors.brand);

      // Let the 4 s hand-off timer fire so the test ends without a pending
      // timer; the splash is disposed and its pulse loop with it.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('sign-up hero stays brand green under ${testCase.name}', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = testCase.platform;

      await tester.pumpWidget(
        themed(const RegistrationScreen(), testCase.mode),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.brand);

      // The foreground on that band is white in every theme. It used to be
      // C.onPrimary(context), which turns near-black in dark mode because it
      // expects the lifted green.
      final tagline = tester.widget<Text>(
        find.text('Fresh from the farm to your door'),
      );
      expect(
        tagline.style?.color,
        AppColors.onBrand.withValues(alpha: 0.82),
      );
    });
  }

  test('web theme-color and manifest background use the same brand green', () {
    // These are read at install time by the browser/OS, before any Dart runs,
    // so they cannot import AppColors.brand — the hex is duplicated and
    // pinned here instead.
    final manifest = File('web/manifest.json').readAsStringSync();
    expect(manifest, contains('"background_color": "#1C4815"'));
    expect(manifest, contains('"theme_color": "#1C4815"'));

    final indexHtml = File('web/index.html').readAsStringSync();
    expect(indexHtml, contains('<meta name="theme-color" content="#1C4815">'));
  });
}
