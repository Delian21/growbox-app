import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/screens/home_screen.dart';
import 'package:growbox/theme.dart';

/// The Home promo banner carries white text on a green gradient, so its
/// gradient may only ever be a green white can be read on — in either
/// appearance. Dark mode's primary is the lifted green (#7ED36B), where white
/// sits at ~1.9:1, which is why the banner has its own pair.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// WCAG relative luminance, from the sRGB channels.
  double luminance(Color color) {
    double channel(double value) => value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  double contrast(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  Widget home(ThemeMode mode) => ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
          darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
          themeMode: mode,
          home: const HomeScreen(),
        ),
      );

  /// The gradient actually painted by the banner around its headline.
  List<Color> paintedGradient(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Free Delivery!'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    return (decoration.gradient! as LinearGradient).colors;
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('the promo banner stays readable in $mode', (tester) async {
      tester.view.devicePixelRatio = 1;
      // Wide enough that Home's own search bar lays out without overflow in
      // the test font; the banner is full-width either way.
      tester.view.physicalSize = const Size(600, 1000);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(home(mode));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Free Delivery!'), findsOneWidget);

      // Both ends of the gradient, where the white text can land.
      for (final color in paintedGradient(tester)) {
        expect(
          contrast(AppColors.white, color),
          greaterThanOrEqualTo(4.5),
          reason: 'white on ${color.toARGB32().toRadixString(16)} is too weak',
        );
      }

      // The "Shop Now" label is brand green on a white pill.
      final label = tester.widget<Text>(find.text('Shop Now'));
      expect(label.style?.color, AppColors.brand);
      expect(
        contrast(AppColors.brand, AppColors.white),
        greaterThanOrEqualTo(4.5),
      );

      await tester.pumpAndSettle();
    });
  }
}
