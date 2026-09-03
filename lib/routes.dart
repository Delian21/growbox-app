import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/menu_screen.dart';
import '../screens/location_screen.dart';
import '../screens/account_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/order_history_screen.dart';
import '../screens/change_email_screen.dart';
import '../screens/change_phone_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/deactivation_screen.dart';
import '../screens/address_management_screen.dart';
import '../screens/faq_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/home';
  static const String search = '/search';
  static const String cart = '/cart';
  static const String profile = '/profile';
  static const String menu = '/menu';
  static const String location = '/location';
  static const String account = '/account';
  static const String favorites = '/favorites';
  static const String notifications = '/notifications';
  static const String orderHistory = '/order-history';
  static const String changeEmail = '/change-email';
  static const String changePhone = '/change-phone';
  static const String privacy = '/privacy';
  static const String deactivate = '/deactivate';
  static const String addresses = '/addresses';
  static const String faq = '/faq';

  static Map<String, WidgetBuilder> get routes => {
        home: (_) => const HomeScreen(),
        search: (_) => const SearchScreen(),
        cart: (_) => const CartScreen(),
        profile: (_) => const ProfileScreen(),
        menu: (_) => const MenuScreen(),
        location: (_) => const LocationScreen(),
        account: (_) => AccountScreen(),
        favorites: (_) => FavoritesScreen(),
        notifications: (_) => NotificationsScreen(),
        orderHistory: (_) => OrderHistoryScreen(),
        changeEmail: (_) => ChangeEmailScreen(),
        changePhone: (_) => ChangePhoneNumberScreen(),
        privacy: (_) => ManagePrivacyScreen(),
        deactivate: (_) => DeactivationScreen(),
        addresses: (_) => AddressManagementScreen(),
        faq: (_) => FAQScreen(),
      };

  /// Push a named route. Drop-in replacement for Navigator.pushNamed
  /// that uses the standard slide transition.
  static void push(BuildContext context, String route, {Object? arguments}) {
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  /// Push and remove everything below (for tab switches).
  static void pushReplaceAll(BuildContext context, String route) {
    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
  }
}
