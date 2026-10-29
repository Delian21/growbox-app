import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/addresses.dart';
import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/screens/account_screen.dart';
import 'package:growbox/screens/address_management_screen.dart';
import 'package:growbox/screens/deactivation_screen.dart';
import 'package:growbox/screens/faq_screen.dart';
import 'package:growbox/screens/forgot_password_screen.dart';
import 'package:growbox/theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CustomerData.clear();
    await addressesStore.load(force: true);
  });

  Widget themed(Widget child, {Brightness brightness = Brightness.dark}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartNotifier()),
        ChangeNotifierProvider<AddressesStore>.value(value: addressesStore),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: child,
      ),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('forgot password colors follow $brightness theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(const ForgotPasswordScreen(), brightness: brightness),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final context = tester.element(find.text('Reset Password').first);
      expect(scaffold.backgroundColor, C.background(context));
      expect(find.text('Forgot your password?'), findsOneWidget);
      expect(
        C.primary(context),
        brightness == Brightness.dark
            ? AppDarkColors.primary
            : AppColors.primary,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('address and FAQ colors follow $brightness theme', (
      tester,
    ) async {
      await addressesStore.save(
        const Address(
          id: 'dark-check-address',
          label: 'Home',
          street: '12 Test Street',
          area: 'Gwarinpa',
        ),
      );
      await addressesStore.select('dark-check-address');
      await tester.pumpWidget(
        themed(
          AddressManagementScreen(store: addressesStore),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Home').first);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        C.background(context),
      );
      final addressCard = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.textContaining('12 Test Street'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final addressDecoration = addressCard.decoration! as BoxDecoration;
      expect((addressDecoration.border as Border).top.width, 2);
      expect(addressDecoration.color, isNot(C.surface(context)));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        themed(const FAQScreen(), brightness: brightness),
      );
      await tester.pumpAndSettle();
      final faqContext = tester.element(find.text('FAQ'));
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        C.background(faqContext),
      );
      final faqTitle = tester.widget<Text>(find.text('FAQ'));
      expect(faqTitle.style!.color, C.textPrimary(faqContext));
      final backIcon = tester.widget<Icon>(find.byIcon(Icons.arrow_back));
      expect(backIcon.color, C.textPrimary(faqContext));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'account dialog and deactivation colors follow $brightness theme',
      (tester) async {
        await tester.pumpWidget(
          themed(const AccountScreen(), brightness: brightness),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete Account'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor,
          C.surface(tester.element(find.text('Delete account'))),
        );
        await tester.pumpWidget(
          themed(const DeactivationScreen(), brightness: brightness),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
