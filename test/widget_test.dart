import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growbox/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('GROWBOX splash screen loads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const GrowboxApp());

    // The bundled GROWBOX brand logo renders on the splash.
    expect(
      find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/images/growbox_logo.png'),
      findsOneWidget,
    );

    // Let the splash navigation timer fire so nothing is left pending.
    await tester.pump(const Duration(seconds: 5));
  });
}