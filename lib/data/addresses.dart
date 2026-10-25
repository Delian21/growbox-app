import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_data.dart';

// ---------------------------------------------------------------------------
// Delivery address model
// ---------------------------------------------------------------------------

/// A saved delivery address.
///
/// The street line is deliberately separate from the area: the rider needs a
/// street to find a door, while the feed and the header only need the area, and
/// checkout has to be able to tell the two cases apart. [street] can be empty —
/// an address imported from the map picker has an area but no house number —
/// and [isComplete] says whether it can actually be delivered to.
class Address {
  final String id;

  /// 'Home', 'Office', …
  final String label;

  /// House number and street. May be empty.
  final String street;

  /// Area / neighbourhood, e.g. 'Gwarinpa, Abuja'.
  final String area;

  /// Nearest gate, bus stop or other hint for the rider.
  final String? landmark;

  /// Contact number for this address.
  final String? phone;

  const Address({
    required this.id,
    required this.label,
    this.street = '',
    this.area = '',
    this.landmark,
    this.phone,
  });

  /// The full address in one line: street first, then area.
  String get fullAddress => [street, area]
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(', ');

  /// The one-line summary a header shows: the area, or the street if that is
  /// all this address has.
  String get summary {
    if (area.trim().isNotEmpty) return area.trim();
    return street.trim();
  }

  /// True when the address has the street line a rider needs. An area alone is
  /// not deliverable, which is what checkout warns about.
  bool get isComplete => street.trim().isNotEmpty;

  Address copyWith({
    String? label,
    String? street,
    String? area,
    String? landmark,
    String? phone,
    bool clearLandmark = false,
    bool clearPhone = false,
  }) =>
      Address(
        id: id,
        label: label ?? this.label,
        street: street ?? this.street,
        area: area ?? this.area,
        landmark: clearLandmark ? null : (landmark ?? this.landmark),
        phone: clearPhone ? null : (phone ?? this.phone),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'street': street,
        'area': area,
        'landmark': landmark,
        'phone': phone,
      };

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Home',
        street: json['street'] as String? ?? '',
        area: json['area'] as String? ?? '',
        landmark: json['landmark'] as String?,
        phone: json['phone'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Address && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ---------------------------------------------------------------------------
// Repository contract
// ---------------------------------------------------------------------------

/// Source of delivery addresses.
///
/// Screens and the [AddressesStore] depend only on this interface, so moving
/// from device storage to a real API is a one-line change at the composition
/// point ([addressesStore]) and no widget changes.
abstract class AddressRepository {
  /// Which account these addresses belong to.
  ///
  /// The local implementation uses it to pick a storage bucket, so two accounts
  /// on one device never see each other's addresses. A server-backed
  /// implementation can ignore it.
  String get accountKey;

  Future<List<Address>> getAddresses();

  /// The selected address, or null when nothing is selected.
  Future<Address?> getSelectedAddress();

  /// Selects a saved address by id. Unknown ids are ignored rather than stored.
  Future<void> selectAddress(String id);

  /// Adds [address], or replaces the saved one with the same id.
  Future<void> saveAddress(Address address);

  /// Removes [addressId]; the selection moves to another saved address or
  /// clears.
  Future<void> deleteAddress(String addressId);
}

/// Who is logged in, as far as storage is concerned.
///
/// The mock auth keeps a profile but no user id, so the login email is the one
/// stable identity available. Logging out clears it, which parks the addresses
/// in the guest bucket until the same email signs in again — and signing in
/// with that email brings them straight back.
String? currentAddressAccountKey() {
  final email = CustomerData.email?.trim().toLowerCase();
  return (email == null || email.isEmpty) ? null : email;
}

// ---------------------------------------------------------------------------
// Local implementation (shared_preferences)
// ---------------------------------------------------------------------------

/// Stores addresses and the selected id on the device.
///
/// Only the selected *id* is persisted; the address text is always read from
/// the saved list, so editing an address cannot leave a stale selection behind.
class LocalAddressRepository implements AddressRepository {
  LocalAddressRepository({String? Function()? account})
      : _account = account ?? currentAddressAccountKey;

  /// Resolved on every call, so a login or logout mid-session is picked up.
  final String? Function() _account;

  @override
  String get accountKey => _account() ?? '';

  static const String _addressesRoot = 'delivery_addresses_v2';
  static const String _selectedRoot = 'selected_address_v2';

  /// Guest storage keeps the plain key so a signed-out device still has a
  /// stable bucket.
  String get _addressesKey =>
      accountKey.isEmpty ? _addressesRoot : '$_addressesRoot:$accountKey';
  String get _selectedKey =>
      accountKey.isEmpty ? _selectedRoot : '$_selectedRoot:$accountKey';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<List<Address>> getAddresses() async {
    try {
      final raw = (await _prefs).getString(_addressesKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return List<Address>.unmodifiable(
        decoded.map((e) => Address.fromJson(e as Map<String, dynamic>)),
      );
    } catch (_) {
      // Corrupt storage reads as "no addresses" instead of wiping the app.
      return const [];
    }
  }

  @override
  Future<Address?> getSelectedAddress() async {
    final id = (await _prefs).getString(_selectedKey);
    if (id == null || id.isEmpty) return null;
    for (final address in await getAddresses()) {
      if (address.id == id) return address;
    }
    // The selection points at something that no longer exists.
    return null;
  }

  @override
  Future<void> selectAddress(String id) async {
    final saved = await getAddresses();
    if (!saved.any((address) => address.id == id)) return;
    await (await _prefs).setString(_selectedKey, id);
  }

  @override
  Future<void> saveAddress(Address address) async {
    final saved = [...await getAddresses()];
    final index = saved.indexWhere((a) => a.id == address.id);
    if (index >= 0) {
      saved[index] = address;
    } else {
      saved.add(address);
    }
    await _write(saved);

    // The first address becomes the selection, so a new customer who adds one
    // address can check out without a second step.
    final selected = (await _prefs).getString(_selectedKey);
    if (selected == null || selected.isEmpty) {
      await selectAddress(address.id);
    }
  }

  @override
  Future<void> deleteAddress(String addressId) async {
    final remaining =
        (await getAddresses()).where((a) => a.id != addressId).toList();
    await _write(remaining);

    final selected = (await _prefs).getString(_selectedKey);
    if (selected != addressId) return;

    // Never leave the selection dangling and never invent a replacement
    // address: move to a real saved one, or to nothing at all.
    if (remaining.isEmpty) {
      await (await _prefs).remove(_selectedKey);
    } else {
      await selectAddress(remaining.first.id);
    }
  }

  Future<void> _write(List<Address> addresses) async {
    final prefs = await _prefs;
    if (addresses.isEmpty) {
      await prefs.remove(_addressesKey);
      return;
    }
    await prefs.setString(
      _addressesKey,
      jsonEncode(addresses.map((a) => a.toJson()).toList()),
    );
  }
}

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

/// Holds the saved addresses and the selection for the UI.
///
/// This is the single place the app talks to an [AddressRepository]; screens
/// listen to it instead of keeping their own copy of an address string.
class AddressesStore extends ChangeNotifier {
  AddressesStore(this._repository);

  final AddressRepository _repository;

  List<Address> _addresses = const [];
  Address? _selected;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String _loadedFor = '';

  List<Address> get addresses => _addresses;

  /// The address checkout will deliver to, or null when none is selected.
  Address? get selectedAddress => _selected;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isEmpty => _addresses.isEmpty;

  /// True when there is a selected address but it is missing the street line
  /// the rider needs.
  bool get selectionNeedsStreet =>
      _selected != null && !_selected!.isComplete;

  /// Reads the saved addresses and selection.
  ///
  /// Reloads by itself when the account changed (login / logout), so a screen
  /// never shows the previous customer's addresses.
  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force && _loadedFor == _repository.accountKey) return;

    _isLoading = true;
    notifyListeners();
    try {
      await _refresh();
      _loadedFor = _repository.accountKey;
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> select(String addressId) async {
    await _repository.selectAddress(addressId);
    await _reload();
  }

  Future<void> save(Address address) async {
    await _repository.saveAddress(address);
    await _reload();
  }

  Future<void> delete(String addressId) async {
    await _repository.deleteAddress(addressId);
    await _reload();
  }

  Future<void> _reload() async {
    await _refresh();
    notifyListeners();
  }

  Future<void> _refresh() async {
    _addresses = await _repository.getAddresses();
    _selected = await _repository.getSelectedAddress();
  }
}

/// App-wide instance. `main()` warms it up before the first frame.
final AddressesStore addressesStore = AddressesStore(LocalAddressRepository());

// ---------------------------------------------------------------------------
// Browsing area
// ---------------------------------------------------------------------------

/// Where the customer is browsing from.
///
/// This is deliberately *not* a delivery address: "Current location" can set
/// the area the feed is browsed in, but checkout only ever uses a saved
/// [Address] with a street line.
class BrowsingAreaStore extends ChangeNotifier {
  static const String _storageKey = 'browsing_area_v1';

  String? _area;
  bool _hasLoaded = false;

  String? get area => _area;
  bool get hasArea => (_area ?? '').trim().isNotEmpty;

  Future<void> load() async {
    if (_hasLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _area = prefs.getString(_storageKey);
    } catch (_) {
      // Unreadable storage simply means no browsing area yet.
    }
    _hasLoaded = true;
    notifyListeners();
  }

  Future<void> setArea(String value) async {
    final trimmed = value.trim();
    _area = trimmed.isEmpty ? null : trimmed;
    _hasLoaded = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_area == null) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, _area!);
      }
    } catch (_) {
      // Best effort: the in-memory area still applies for this session.
    }
  }
}

/// App-wide instance, loaded alongside [addressesStore] at startup.
final BrowsingAreaStore browsingAreaStore = BrowsingAreaStore();
