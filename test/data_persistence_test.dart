import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';
import 'package:growbox/screens/order_history_screen.dart';

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  group('CustomerData', () {
    test('setters persist and restore survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      CustomerData.clear();

      CustomerData.name = 'Ada';
      CustomerData.email = 'ada@growbox.com';
      CustomerData.phone = '08012345678';
      await _settle();

      // Simulate restart: read back what the store wrote.
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString('customer_profile_v1')!);
      expect(saved['name'], 'Ada');
      expect(saved['email'], 'ada@growbox.com');
      expect(saved['phone'], '08012345678');
    });

    test('restore hydrates fields from a stored profile', () async {
      SharedPreferences.setMockInitialValues({
        'customer_profile_v1': jsonEncode(
            {'name': 'Bee', 'email': 'bee@growbox.com', 'phone': null}),
      });
      await CustomerData.restore();
      expect(CustomerData.name, 'Bee');
      expect(CustomerData.email, 'bee@growbox.com');
      expect(CustomerData.phone, isNull);
    });
  });

  group('Addresses', () {
    test('addAddress persists and restoreAddresses reloads them', () async {
      SharedPreferences.setMockInitialValues({});
      savedAddresses.clear();

      addAddress(DeliveryAddress(
        id: 'addr_x',
        label: 'Office',
        address: 'Garki, Abuja',
        phone: '08011111111',
        isDefault: true,
      ));
      await _settle();

      // Simulate restart: wipe memory, then hydrate from storage.
      savedAddresses.clear();
      await restoreAddresses();

      expect(savedAddresses.length, 1);
      expect(savedAddresses.single.label, 'Office');
      expect(savedAddresses.single.address, 'Garki, Abuja');
      expect(savedAddresses.single.isDefault, isTrue);
    });

    test('removeAddress persists too', () async {
      SharedPreferences.setMockInitialValues({});
      savedAddresses
        ..clear()
        ..add(DeliveryAddress(
            id: 'a1', label: 'Home', address: 'Asokoro, Abuja'));
      persistAddresses();
      await _settle();

      removeAddress('a1');
      await _settle();

      savedAddresses.clear();
      await restoreAddresses();
      expect(savedAddresses, isEmpty);
    });
  });

  group('Favorites', () {
    test('vendor favorites persist across a restart', () async {
      SharedPreferences.setMockInitialValues({});
      favoriteVendors.clear();

      favoriteVendors.add({
        'name': 'Green Farm',
        'image': 'assets/images/farmland.jpg',
      });
      persistFavorites();
      await _settle();

      favoriteVendors.clear();
      await restoreFavorites();

      expect(favoriteVendors.length, 1);
      expect(favoriteVendors.single['name'], 'Green Farm');
    });
  });

  group('Orders', () {
    const rice = VendorProduct(
      image: 'assets/images/rice.jpg',
      name: 'Rice',
      description: 'Quality rice',
      price: 2550,
      category: 'GRAINS',
      vendorName: 'Green Farm',
    );
    const beans = VendorProduct(
      image: 'assets/images/beans.jpg',
      name: 'Beans',
      description: 'Quality beans',
      price: 3200,
      category: 'LEGUMES',
      vendorName: 'Green Farm',
    );

    test('recordOrder snapshots price/image and groups duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      storedOrders.clear();

      recordOrder(
        orderNumber: 'GBX-77',
        cartItems: [rice, rice, beans],
        deliveryFee: 1500,
      );

      expect(storedOrders.first.orderNumber, 'GBX-77');
      expect(storedOrders.first.items.length, 2);
      final riceLine =
          storedOrders.first.items.firstWhere((i) => i.name == 'Rice');
      expect(riceLine.quantity, 2);
      expect(riceLine.price, 2550); // snapshot of catalog price
      expect(riceLine.image, 'assets/images/rice.jpg');
      expect(storedOrders.first.total, 2550 * 2 + 3200 + 1500);
    });

    test('order history survives a restart via shared_preferences', () async {
      SharedPreferences.setMockInitialValues({});
      storedOrders.clear();
      recordOrder(
        orderNumber: 'GBX-88',
        cartItems: [beans],
        deliveryFee: 1500,
      );
      await _settle();

      // Simulate restart: wipe memory, hydrate from storage.
      storedOrders.clear();
      await restoreOrders();

      expect(storedOrders.length, 1);
      expect(storedOrders.single.orderNumber, 'GBX-88');
      expect(storedOrders.single.items.single.name, 'Beans');
    });

    test('restoreOrders seeds mock history when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      storedOrders.clear();

      await restoreOrders();

      expect(storedOrders.length, greaterThanOrEqualTo(4));
      expect(
        storedOrders.map((o) => o.status),
        containsAll(['Order placed', 'Delivered', 'Cancelled', 'Pending']),
      );
    });

    testWidgets('order history screen shows a persisted order',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      storedOrders.clear();
      recordOrder(
        orderNumber: 'GBX-900',
        cartItems: [rice],
        deliveryFee: 1500,
        deliveryAddress: 'Gwarinpa, Abuja',
      );

      await tester.pumpWidget(
        const MaterialApp(home: OrderHistoryScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('#GBX-900'), findsOneWidget);
      expect(find.text('Order placed'), findsOneWidget);
    });
  });
}
