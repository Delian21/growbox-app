import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growbox/data/app_state.dart';
import 'package:growbox/data/mock_data.dart';

/// Lets the async restore/save chains settle.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
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

  test('cart items survive an app restart via shared_preferences', () async {
    SharedPreferences.setMockInitialValues({});

    // First "session": add items.
    final cart = CartNotifier();
    cart.add(rice);
    cart.add(rice); // quantity 2 via duplicates
    cart.add(beans);
    await _settle();

    // Second "session": a fresh notifier restores the stored cart.
    final restored = CartNotifier();
    await _settle();

    expect(restored.length, 3);
    expect(restored.countOf(restored.items.firstWhere((p) => p.name == 'Rice')),
        2);
    expect(restored.total, rice.price * 2 + beans.price);
    expect(restored.items.any((p) => p.name == 'Beans'), isTrue);
  });

  test('removing and clearing persists too', () async {
    SharedPreferences.setMockInitialValues({});

    final cart = CartNotifier();
    cart.add(rice);
    cart.add(beans);
    await _settle();

    cart.removeOne(rice);
    await _settle();

    final afterRemove = CartNotifier();
    await _settle();
    expect(afterRemove.length, 1);
    expect(afterRemove.items.single.name, 'Beans');

    afterRemove.clear();
    await _settle();

    final afterClear = CartNotifier();
    await _settle();
    expect(afterClear.isEmpty, isTrue);
  });

  test('corrupt stored JSON falls back to an empty cart', () async {
    SharedPreferences.setMockInitialValues({
      'cart_items_v1': 'this is {not valid json',
    });

    final cart = CartNotifier();
    await _settle();

    expect(cart.isEmpty, isTrue);
  });
}
