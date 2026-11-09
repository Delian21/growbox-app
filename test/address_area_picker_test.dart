import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/addresses.dart';
import 'package:growbox/screens/address_management_screen.dart';
import 'package:growbox/widgets/area_picker_sheet.dart';

/// The address form used to take its area as free text, so the same street
/// could be saved as "Gwarinpa", "Gwarimpa" or "Gwarinpa, Abuja". The field is
/// now a chooser backed by the same picker the browsing area uses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await addressesStore.load(force: true);
  });

  /// A phone-sized surface: the sheet is tall, and the default 800x600 test
  /// window pushes the area field under the fold.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1900);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openForm(WidgetTester tester, {String? editId}) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: editId == null
            ? const AddressManagementScreen(startAdding: true)
            : AddressManagementScreen(editAddressId: editId),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder pickerSearch() => find.descendant(
        of: find.byType(AreaPickerSheet),
        matching: find.byType(TextField),
      );

  testWidgets('the area field opens the picker and shows the picked area', (
    tester,
  ) async {
    await openForm(tester);

    expect(find.text('Choose your area'), findsOneWidget);

    await tester.tap(find.text('Choose your area'));
    await tester.pumpAndSettle();

    expect(find.text('Set your browsing area'), findsOneWidget);
    await tester.tap(find.text('Apo'));
    await tester.pumpAndSettle();

    expect(find.text('Apo, Abuja'), findsOneWidget);
  });

  testWidgets('saving stores the picked label, not what was typed', (
    tester,
  ) async {
    await openForm(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'House number and street'),
      'No. 12 Aminu Kano Crescent',
    );
    await tester.tap(find.text('Choose your area'));
    await tester.pumpAndSettle();

    // The picker's own search still finds a misspelled area; picking it is
    // what decides the saved value.
    await tester.enterText(pickerSearch(), 'gwarimpa');
    await tester.pumpAndSettle();
    expect(find.text('Use “gwarimpa” anyway'), findsNothing);
    await tester.tap(find.text('Gwarinpa'));
    await tester.pumpAndSettle();

    expect(find.text('Gwarinpa, Abuja'), findsOneWidget);

    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    final saved = addressesStore.addresses.single;
    expect(saved.area, 'Gwarinpa, Abuja');
    expect(saved.street, 'No. 12 Aminu Kano Crescent');
  });

  testWidgets('editing shows the saved area selected and can change it', (
    tester,
  ) async {
    await addressesStore.save(
      const Address(
        id: 'addr_1',
        label: 'Home',
        street: 'No. 4 Jabi Lake Road',
        area: 'Jabi, Abuja',
      ),
    );

    await openForm(tester, editId: 'addr_1');

    expect(find.text('Jabi, Abuja'), findsWidgets);

    await tester.tap(find.text('Jabi, Abuja').last);
    await tester.pumpAndSettle();
    // The current area comes back marked selected.
    expect(find.byIcon(Icons.check_circle), findsWidgets);

    await tester.enterText(pickerSearch(), 'wuse');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wuse 2'));
    await tester.pumpAndSettle();
    expect(find.text('Wuse 2, Abuja'), findsOneWidget);
  });
}
