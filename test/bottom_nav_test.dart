import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/app_state.dart';
import 'package:growbox/routes.dart';
import 'package:growbox/screens/home_screen.dart';
import 'package:growbox/screens/search_screen.dart';
import 'package:growbox/theme.dart';
import 'package:growbox/widgets/bottom_nav.dart';
import 'package:growbox/widgets/scaffold_with_nav.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// The nav on its own, with a chosen active tab and cart badge.
  Widget navHarness({
    int activeIndex = 0,
    int badge = 0,
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: brightness),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: BottomNav.growbox(
            activeIndex: activeIndex,
            cartBadgeCount: badge,
            onHome: () {},
            onSearch: () {},
            onCart: () {},
            onProfile: () {},
          ),
        ),
      ),
    );
  }

  Finder barOutline() => find.descendant(
        of: find.byType(BottomNav),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border != null),
      );

  testWidgets('active tab is a solid primary pill with on-primary content',
      (tester) async {
    await tester.pumpWidget(navHarness());
    await tester.pump();

    // The indicator slides rather than jumping: 200 ms easeOut.
    final indicator = tester.widget<AnimatedAlign>(find.descendant(
      of: find.byType(BottomNav),
      matching: find.byType(AnimatedAlign),
    ));
    expect(indicator.duration, const Duration(milliseconds: 200));
    expect(indicator.curve, Curves.easeOut);
    // Home is tab 0 of 4 → far left.
    expect(indicator.alignment, const Alignment(-1, 0));

    // Solid primary fill, and no glow/shadow around it.
    final pill = tester.widget<DecoratedBox>(find.descendant(
      of: find.byType(AnimatedAlign),
      matching: find.byType(DecoratedBox),
    ));
    final pillDecoration = pill.decoration as BoxDecoration;
    expect(pillDecoration.color, AppColors.primary);
    expect(pillDecoration.boxShadow, isNull);
    expect(pillDecoration.borderRadius, BorderRadius.circular(AppRadii.pill));

    // Content on the fill uses the token that is legible on primary.
    final activeIcon = tester.widget<Icon>(find.byIcon(Icons.home_outlined));
    expect(activeIcon.color, AppColors.white);

    // Inactive tabs use the muted token at 12 px.
    final inactiveLabel =
        tester.renderObject<RenderParagraph>(find.text('Search'));
    expect(inactiveLabel.text.style?.color, AppColors.textMuted);
    expect(inactiveLabel.text.style?.fontSize, 12);
    final inactiveIcon = tester.widget<Icon>(find.byIcon(Icons.search));
    expect(inactiveIcon.color, AppColors.textMuted);

    // 1px surface hairline around the pill.
    final container = tester.widget<Container>(barOutline());
    final border = (container.decoration as BoxDecoration).border! as Border;
    expect(border.top.width, 1);
    expect(border.top.color, AppColors.grey200);

    // The fill actually sits behind both the icon and the label.
    final fill = tester.getRect(find.descendant(
      of: find.byType(AnimatedAlign),
      matching: find.byType(DecoratedBox),
    ));
    expect(fill.contains(tester.getRect(find.byIcon(Icons.home_outlined)).center),
        isTrue);
    expect(fill.contains(tester.getRect(find.text('Home')).center), isTrue);
  });

  testWidgets('active tab stays legible on a dark surface', (tester) async {
    await tester.pumpWidget(navHarness(brightness: Brightness.dark));
    await tester.pump();

    // Lifted green fill with near-black content: 10.3:1.
    final fill = tester.widget<DecoratedBox>(find.descendant(
      of: find.byType(AnimatedAlign),
      matching: find.byType(DecoratedBox),
    ));
    expect((fill.decoration as BoxDecoration).color, AppDarkColors.primary);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.home_outlined)).color,
      AppDarkColors.background,
    );
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('Search'))
          .text
          .style
          ?.color,
      AppDarkColors.textMuted,
    );

    final container = tester.widget<Container>(barOutline());
    final border = (container.decoration as BoxDecoration).border! as Border;
    expect(border.top.color, AppDarkColors.surfaceLighter);
  });

  testWidgets('tapping a tab fires selection haptics and slides the indicator',
      (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );

    var active = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: StatefulBuilder(
              builder: (context, setState) => BottomNav.growbox(
                activeIndex: active,
                onHome: () => setState(() => active = 0),
                onSearch: () => setState(() => active = 1),
                onCart: () => setState(() => active = 2),
                onProfile: () => setState(() => active = 3),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Cart'));
    await tester.pump();

    expect(
      calls.any((c) =>
          c.method == 'HapticFeedback.vibrate' &&
          c.arguments == 'HapticFeedbackType.selectionClick'),
      isTrue,
    );

    // Indicator travels to tab 2 of 4 → one third of the way across.
    final indicator = tester.widget<AnimatedAlign>(find.descendant(
      of: find.byType(BottomNav),
      matching: find.byType(AnimatedAlign),
    ));
    expect(
      (indicator.alignment as Alignment).x,
      closeTo(2 * 2 / 3 - 1, 0.001),
    );

    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('cart icon bounces when the item count grows', (tester) async {
    await tester.pumpWidget(navHarness(badge: 1));
    await tester.pump();

    Finder cartBounce() => find.descendant(
          of: find.ancestor(
            of: find.byIcon(Icons.shopping_cart_outlined),
            matching: find.byType(Expanded),
          ),
          matching: find.byKey(const ValueKey('navBadgeBounce')),
        );

    expect(tester.widget<ScaleTransition>(cartBounce()).scale.value, 1.0);

    await tester.pumpWidget(navHarness(badge: 3));
    await tester.pump(const Duration(milliseconds: 90));
    expect(
      tester.widget<ScaleTransition>(cartBounce()).scale.value,
      greaterThan(1.0),
    );

    // It settles back at rest.
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<ScaleTransition>(cartBounce()).scale.value, 1.0);
  });

  testWidgets('nav sits above the system gesture inset', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(navHarness());
    await tester.pump();

    final pill = tester.getRect(barOutline());
    // 800 − 34 (gesture bar) − 12 (margin) = pill's bottom edge.
    expect(pill.bottom, closeTo(800 - 34 - BottomNavMetrics.barMargin, 0.01));

    final context = tester.element(find.byType(BottomNav));
    expect(
      BottomNavMetrics.contentInset(context),
      BottomNavMetrics.barHeight +
          BottomNavMetrics.barMargin +
          34 +
          AppSpacing.md,
    );
  });

  testWidgets('pill fits a narrow phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(navHarness(activeIndex: 2, badge: 12));
    await tester.pump();

    // An overflow would have thrown during the pump.
    for (final label in ['Home', 'Search', 'Cart', 'Profile']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('scrollable content reserves room for the floating pill',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final context = tester.element(find.byType(ScaffoldWithNav));
    final inset = BottomNavMetrics.contentInset(context);

    // The vendor feed ends with that much padding, so the last card and the
    // end-of-list note clear the bar.
    final vendorList = tester.widget<ListView>(find.byWidgetPredicate((w) =>
        w is ListView &&
        w.padding == EdgeInsets.only(bottom: inset)));
    expect(vendorList.padding, EdgeInsets.only(bottom: inset));

    // The nav is stacked over the page, not below it.
    final scaffold = tester.widget<Scaffold>(find.descendant(
      of: find.byType(ScaffoldWithNav),
      matching: find.byType(Scaffold),
    ));
    expect(scaffold.body, isA<Stack>());
  });

  testWidgets('home search bar opens the Search tab with its field focused',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartNotifier(),
        child: MaterialApp(
          initialRoute: AppRoutes.home,
          routes: AppRoutes.routes,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Search for produce...'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode?.hasFocus, isTrue);
  });
}
