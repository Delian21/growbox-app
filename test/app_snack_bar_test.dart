import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:growbox/widgets/app_snack_bar.dart';
import 'package:growbox/widgets/bottom_nav.dart';

/// WCAG 2.1 relative-luminance contrast ratio.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

Widget harness({
  required Brightness brightness,
  EdgeInsets padding = EdgeInsets.zero,
  void Function(BuildContext) onPressed = _noop,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(padding: padding),
      child: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => onPressed(context),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    ),
  );
}

void _noop(BuildContext context) {}

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
        'snackbar text clears 4.5:1 on its surface (${brightness.name})',
        (tester) async {
      await tester.pumpWidget(harness(
        brightness: brightness,
        onPressed: (context) => showAppSnackBar(
          context,
          'Added to box',
          actionLabel: 'View box',
          onAction: () {},
        ),
      ));

      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      final background = bar.backgroundColor!;
      final message = tester.widget<Text>(find.text('Added to box'));
      final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));

      expect(
        contrastRatio(message.style!.color!, background),
        greaterThanOrEqualTo(4.5),
        reason: 'message text must be readable on the snackbar surface',
      );
      expect(
        contrastRatio(action.textColor!, background),
        greaterThanOrEqualTo(4.5),
        reason: 'the action label must be readable too',
      );
    });
  }

  testWidgets('snackbar floats above the nav, even with a gesture inset',
      (tester) async {
    const inset = 34.0;
    await tester.pumpWidget(harness(
      brightness: Brightness.light,
      padding: const EdgeInsets.only(bottom: inset),
      onPressed: (context) => showAppSnackBar(context, 'Added to box'),
    ));

    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final context = tester.element(find.text('show'));
    final expectedBottom =
        BottomNavMetrics.reserved(context) + 8; // pill + margin + inset + gap
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));

    expect((bar.margin! as EdgeInsets).bottom, expectedBottom);
    expect(BottomNavMetrics.reserved(context), 72 + 12 + inset);

    // And the painted surface actually ends that far above the bottom edge.
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final surface = find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first;
    expect(
      tester.getRect(surface).bottom,
      closeTo(screenHeight - expectedBottom, 1.0),
    );
  });
}
