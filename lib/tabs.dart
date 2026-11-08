import 'package:flutter/material.dart';

/// The four tabs behind the bottom nav.
///
/// The order is the order of the nav items, and [index] is what the bar and the
/// shell are drawn from — there is no second place that numbers them.
enum AppTab { home, search, cart, profile }

/// Which tab is showing, and the one-shot request to focus Search's field.
///
/// This used to be a route: every tab was pushed with `pushAndRemoveUntil`, so
/// switching tabs threw the previous tab's scroll position and form state away,
/// and Back on any tab left the app because there was nothing underneath.
/// The tabs are now one [IndexedStack] in [RootShell]; this object is the only
/// mutable bit of that, so the bar, the shell, pushed screens and the tests all
/// read and change the same value.
class TabNavigator extends ChangeNotifier {
  int _index = AppTab.home.index;

  /// Index of the tab that is showing.
  int get index => _index;

  /// The tab that is showing.
  AppTab get tab => AppTab.values[_index];

  int _searchFocusRequest = 0;

  /// Bumped each time something asks for the Search field to be focused.
  ///
  /// A counter rather than a bool: tapping the Home search bar twice in a row
  /// must focus twice, and the Search screen only has to compare it with the
  /// value it last acted on.
  int get searchFocusRequest => _searchFocusRequest;

  /// Shows [tab], optionally asking Search to focus its field.
  ///
  /// [focusSearchField] is separate from the index because the bottom nav tap
  /// and the Home search bar both land on the Search tab but mean different
  /// things: the bar is "I want to type", the nav is "show me Search".
  void select(AppTab tab, {bool focusSearchField = false}) {
    final next = tab.index;
    if (focusSearchField) _searchFocusRequest++;
    if (next == _index && !focusSearchField) return;
    _index = next;
    notifyListeners();
  }

  /// Back from a tab root: returns to Home.
  ///
  /// Returns false when Home is already showing, so the shell knows the back
  /// gesture has reached the bottom of the stack.
  bool backToHome() {
    if (_index == AppTab.home.index) return false;
    select(AppTab.home);
    return true;
  }

  /// Test hook: forget the selected tab and any pending focus request.
  @visibleForTesting
  void reset() {
    _index = AppTab.home.index;
    _searchFocusRequest = 0;
    // No notifyListeners: nothing is listening between tests, and a rebuild
    // during teardown would pump a disposed tree.
  }
}

/// The app's single tab state.
///
/// A singleton like [connectivityStore] and [ordersStore]: pushed screens (a
/// product page's "View box") need to switch tabs after popping themselves, and
/// they are not descendants of the shell, so a Provider would not reach them.
final TabNavigator tabNavigator = TabNavigator();

/// Opens [tab] from anywhere, dropping any pushed screens on the way.
///
/// This is the replacement for the old `AppRoutes.pushReplaceAll(context,
/// AppRoutes.cart)`: same "leave what I was doing and show the tab" intent,
/// except the tab underneath is the same shell with its state intact, and the
/// pop is the normal one — no route is destroyed, so Back still has somewhere
/// to go.
void openTab(
  BuildContext context,
  AppTab tab, {
  bool focusSearchField = false,
}) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  tabNavigator.select(tab, focusSearchField: focusSearchField);
}
