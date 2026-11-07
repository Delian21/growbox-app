import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/build_info.dart';
import 'package:growbox/screens/profile_screen.dart';
import 'package:growbox/theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('build id defaults to dev when no define is passed', () {
    // `flutter test` passes no --dart-define=BUILD_ID, exactly like a plain
    // `flutter run` on a developer's machine.
    expect(kBuildId, 'dev');
    expect(kBuildLabel, 'Growbox v$kAppVersion · dev');
  });

  testWidgets('Profile prints the build label under the version line',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ThemeProvider(
        notifier: ThemeNotifier(),
        child: ChangeNotifierProvider(
          create: (_) => CartNotifier(),
          child: const MaterialApp(home: ProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text(kBuildLabel), 300);
    expect(find.text(kBuildLabel), findsOneWidget);
    // The old hardcoded placeholder is gone.
    expect(find.text('Version 2026.20.vfhvf'), findsNothing);
  });
}
