import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:growbox/data/addresses.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/data/service_areas.dart';
import 'package:growbox/widgets/area_picker_sheet.dart';

/// The browsing area used to be one free-text field, so "Gwarinpa", "Gwarimpa"
/// and "Abuja" were three different places as far as the feed was concerned.
/// These tests pin the curated list, its search behaviour and the escape hatch
/// that keeps typed text working.
void main() {
  group('service areas', () {
    test('ids are unique and every area is in Abuja', () {
      final ids = kAreaCatalog.map((area) => area.id).toSet();
      expect(ids, hasLength(kAreaCatalog.length));
      for (final area in kAreaCatalog) {
        expect(area.city, 'Abuja');
        expect(area.label, endsWith(', Abuja'));
      }
    });

    test('the served list is exactly what the vendors cover', () {
      final fromVendors = <String>{};
      for (final vendor in MockVendors.vendors) {
        fromVendors.addAll((vendor['serviceAreas'] as List).cast<String>());
      }
      expect(kServiceAreas.map((area) => area.id).toSet(), fromVendors);
    });

    test('every vendor area id exists in the catalog', () {
      final known = kAreaCatalog.map((area) => area.id).toSet();
      for (final vendor in MockVendors.vendors) {
        final areas = (vendor['serviceAreas'] as List).cast<String>();
        expect(areas, isNotEmpty, reason: '${vendor['name']} serves nowhere');
        expect(known.containsAll(areas), isTrue,
            reason: '${vendor['name']} lists an unknown area');
      }
    });

    test('a catalogued area no vendor covers is not offered', () {
      final unserved =
          kAreaCatalog.where((area) => !isServiceAreaServed(area.id)).toList();
      expect(unserved, isNotEmpty);
      for (final area in unserved) {
        expect(searchServiceAreas(area.name), isEmpty);
        expect(serviceAreaById(area.id), isNotNull);
      }
    });

    test('search ranks the area name before the LGA', () {
      final results = searchServiceAreas('wuse');
      expect(results.first.id, 'wuse-2');
    });

    test('search finds common misspellings through aliases', () {
      expect(searchServiceAreas('gwarimpa').first.id, 'gwarinpa');
      expect(searchServiceAreas('wuse ii').first.id, 'wuse-2');
      expect(searchServiceAreas('lifecamp').first.id, 'life-camp');
    });

    test('search matches the LGA so a customer can find areas by council', () {
      final names = searchServiceAreas('bwari').map((area) => area.id);
      expect(names, containsAll(<String>['bwari', 'kubwa', 'dutse-alhaji', 'ushafa']));
    });

    test('empty search returns the served list in list order', () {
      expect(searchServiceAreas('   '), same(kServiceAreas));
    });

    test('an area outside the list has no match', () {
      expect(searchServiceAreas('kigali'), isEmpty);
    });

    test('labels resolve back to the curated area, legacy text included', () {
      expect(serviceAreaForLabel('Gwarinpa, Abuja')?.id, 'gwarinpa');
      expect(serviceAreaForLabel('gwarinpa')?.id, 'gwarinpa');
      expect(serviceAreaForLabel('Kano')?.id, isNull);
      expect(serviceAreaForLabel(null)?.id, isNull);
    });
  });

  group('browsing area store', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('picking a listed area keeps its id and remembers it', () async {
      final store = BrowsingAreaStore();
      await store.setArea('Gwarinpa, Abuja', areaId: 'gwarinpa');
      expect(store.area, 'Gwarinpa, Abuja');
      expect(store.areaId, 'gwarinpa');
      expect(store.isUnlistedArea, isFalse);
      expect(store.recentAreaIds, <String>['gwarinpa']);
    });

    test('pre-picker text adopts its curated id on load', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.browsing_area_v1': '"Gwarinpa, Abuja"',
      });
      final store = BrowsingAreaStore();
      await store.load();
      expect(store.areaId, 'gwarinpa');
      expect(store.isUnlistedArea, isFalse);
    });

    test('typed text is kept but marked as not covered', () async {
      final store = BrowsingAreaStore();
      await store.setArea('Kigali');
      expect(store.area, 'Kigali');
      expect(store.areaId, isNull);
      expect(store.isUnlistedArea, isTrue);
    });

    test('recent picks are de-duplicated, newest first, capped at four', () async {
      final store = BrowsingAreaStore();
      for (final id in <String>['jabi', 'garki', 'jabi', 'wuye', 'utako', 'apo']) {
        final area = serviceAreaById(id)!;
        await store.setArea(area.label, areaId: id);
      }
      expect(store.recentAreaIds, <String>['apo', 'utako', 'wuye', 'jabi']);
    });

    test('the pick survives a reload', () async {
      final first = BrowsingAreaStore();
      await first.setArea('Jabi, Abuja', areaId: 'jabi');
      await first.setArea('Utako, Abuja', areaId: 'utako');

      final reloaded = BrowsingAreaStore();
      await reloaded.load();
      expect(reloaded.area, 'Utako, Abuja');
      expect(reloaded.areaId, 'utako');
      expect(reloaded.recentAreaIds.first, 'utako');
    });

    test('clearing the area clears the id and leaves recents alone', () async {
      final store = BrowsingAreaStore();
      await store.setArea('Jabi, Abuja', areaId: 'jabi');
      await store.setArea('');
      expect(store.hasArea, isFalse);
      expect(store.areaId, isNull);
      expect(store.recentAreaIds, <String>['jabi']);
    });
  });

  group('area picker sheet', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<AreaPick?> openSheet(
      WidgetTester tester, {
      String? currentAreaId,
      List<String> recent = const <String>[],
    }) async {
      AreaPick? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await showAreaPickerSheet(
                      context,
                      currentAreaId: currentAreaId,
                      recentAreaIds: recent,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('lists served areas and returns the picked one', (tester) async {
      await openSheet(tester);
      expect(find.text('Available now'), findsOneWidget);
      expect(find.text('Apo'), findsOneWidget);
      expect(find.text('AMAC · Abuja'), findsWidgets);

      await tester.tap(find.text('Apo'));
      await tester.pumpAndSettle();
      expect(find.text('Set your browsing area'), findsNothing);
    });

    testWidgets('picking a row hands back the curated id', (tester) async {
      AreaPick? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await showAreaPickerSheet(context);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apo'));
      await tester.pumpAndSettle();

      expect(result?.id, 'apo');
      expect(result?.label, 'Apo, Abuja');
    });

    testWidgets('search narrows the list and offers typed text', (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byType(TextField), 'gwarimpa');
      await tester.pumpAndSettle();

      expect(find.text('Gwarinpa'), findsOneWidget);
      expect(find.text('Jabi'), findsNothing);
      // A typo that lands on an alias is still a confident match, so the raw
      // text escape hatch stays out of the way.
      expect(find.textContaining('anyway'), findsNothing);
    });

    testWidgets('a fuzzy match still offers the typed text', (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byType(TextField), 'estate');
      await tester.pumpAndSettle();

      expect(find.text('Life Camp'), findsOneWidget);
      expect(find.text('Use “estate” anyway'), findsOneWidget);
    });

    testWidgets('unknown text says so before the customer commits', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.enterText(find.byType(TextField), 'Kigali');
      await tester.pumpAndSettle();

      expect(find.text('We don’t deliver to “Kigali” yet'), findsOneWidget);
      expect(find.textContaining('Browse with'), findsOneWidget);
    });

    testWidgets('the current area is marked as selected', (tester) async {
      await openSheet(tester, currentAreaId: 'apo');
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('recent picks are grouped above the full list', (tester) async {
      await openSheet(tester, recent: <String>['apo']);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
      // Apo appears once: the recents row, not again under the full list.
      expect(find.text('Apo'), findsOneWidget);
    });
  });
}
