import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/build_info.dart';
import 'package:growbox/services/connectivity.dart';
import 'package:growbox/screens/profile_screen.dart';
import 'package:growbox/screens/state_gallery_screen.dart';
import 'package:growbox/theme.dart';

Widget harness(ThemeNotifier notifier) => ThemeProvider(
      notifier: notifier,
      child: ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: const MaterialApp(home: StateGalleryScreen()),
      ),
    );

Future<void> pumpGallery(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(harness(ThemeNotifier()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the gallery lists the states and opens the real widgets',
      (tester) async {
    await pumpGallery(tester);

    expect(find.text('Empty cart'), findsOneWidget);
    expect(find.text('No active orders'), findsOneWidget);
    expect(find.text('Search with no results'), findsOneWidget);

    await tester.tap(find.text('Empty cart'));
    await tester.pumpAndSettle();
    // The real CartScreen, empty.
    expect(find.text('Your box is empty'), findsOneWidget);
    expect(find.text('Browse produce'), findsOneWidget);

    // Back to the gallery for a terminal order state.
    Navigator.of(tester.element(find.text('Browse produce'))).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Cancelled order'), 250);
    await tester.tap(find.text('Cancelled order'));
    await tester.pumpAndSettle();

    expect(find.text('Order cancelled'), findsOneWidget);
    expect(find.text('Ordered by mistake'), findsOneWidget);
    expect(find.text('Reorder'), findsOneWidget);
  });

  testWidgets('the delivered entry opens the real rating sheet',
      (tester) async {
    await pumpGallery(tester);

    await tester.scrollUntilVisible(find.text('Delivered + rating sheet'), 250);
    await tester.tap(find.text('Delivered + rating sheet'));
    await tester.pumpAndSettle();

    expect(
      find.text('Did you enjoy your order from Green Farm?'),
      findsOneWidget,
    );
    expect(find.text('Liked it'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('the light/dark toggle previews without persisting',
      (tester) async {
    final notifier = ThemeNotifier();
    await tester.pumpWidget(harness(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(notifier.value, ThemeMode.dark);

    // Leaving the gallery restores the appearance it found.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(notifier.value, ThemeMode.system);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), isNull);
  });

  testWidgets('the build badge shows the build and copies it', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpGallery(tester);

    expect(find.text(kBuildLabel), findsOneWidget);
    await tester.tap(find.byTooltip('Copy build id'));
    await tester.pumpAndSettle();

    // What a tester pastes into the bug report is exactly the app's label,
    // version and build id included.
    expect(copied, kBuildLabel);
    expect(find.text('Build id copied'), findsOneWidget);
  });

  testWidgets('the gallery opens the orders load-error state', (tester) async {
    await pumpGallery(tester);

    await tester.scrollUntilVisible(find.text('Orders load error'), 250);
    await tester.tap(find.text('Orders load error'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load orders"), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
  });

  testWidgets('the gallery opens the search load-error state', (tester) async {
    await pumpGallery(tester);

    await tester.scrollUntilVisible(
      find.text('Search results load error'),
      250,
    );
    await tester.tap(find.text('Search results load error'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load results"), findsOneWidget);
  });

  testWidgets('the gallery opens checkout offline and restores the store', (
    tester,
  ) async {
    addTearDown(() => connectivityStore.setSimulatedOffline(false));
    await pumpGallery(tester);

    await tester.scrollUntilVisible(find.text('Checkout offline'), 250);
    await tester.tap(find.text('Checkout offline'));
    await tester.pumpAndSettle();

    // The real checkout, with the real CTA, reading the real store.
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.textContaining('Place order'), findsNothing);
    expect(connectivityStore.simulatedOffline, isTrue);

    Navigator.of(tester.element(find.text("You're offline"))).pop();
    await tester.pumpAndSettle();

    // Looking at the state must not leave the whole app offline.
    expect(connectivityStore.simulatedOffline, isFalse);
  });

  testWidgets('Demo tools links to the gallery from Profile', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1200);
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

    await tester.scrollUntilVisible(find.text('State gallery'), 250);
    await tester.tap(find.text('State gallery'));
    await tester.pumpAndSettle();

    expect(find.byType(StateGalleryScreen), findsOneWidget);
    expect(find.text('Empty cart'), findsOneWidget);
  });
}
