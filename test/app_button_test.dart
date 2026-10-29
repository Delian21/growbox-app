import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growbox/theme.dart';
import 'package:growbox/widgets/app_button.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('primary and disabled buttons use theme tokens in $brightness',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: Column(
              children: [
                AppButton(label: 'Continue', onPressed: () {}),
                const AppButton(label: 'Disabled', onPressed: null),
              ],
            ),
          ),
        ),
      );

      final primary = tester.widget<ElevatedButton>(
        find.ancestor(of: find.text('Continue'), matching: find.byType(ElevatedButton)),
      );
      final primaryStyle = primary.style!;
      expect(primaryStyle.backgroundColor!.resolve({}), C.primary(tester.element(find.text('Continue'))));
      expect(primaryStyle.foregroundColor!.resolve({}), C.onPrimary(tester.element(find.text('Continue'))));

      final disabled = tester.widget<ElevatedButton>(
        find.ancestor(of: find.text('Disabled'), matching: find.byType(ElevatedButton)),
      );
      final disabledStyle = disabled.style!;
      expect(disabledStyle.backgroundColor!.resolve({WidgetState.disabled}),
          C.surfaceVariant(tester.element(find.text('Disabled'))));
      expect(disabledStyle.foregroundColor!.resolve({WidgetState.disabled}),
          C.textMuted(tester.element(find.text('Disabled'))));
    });
  }
}
