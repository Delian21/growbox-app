import 'mock_backend.dart';
import 'mock_data.dart';

/// Reads the mock catalogue the way a server-backed repository would.
///
/// The vendors and menus themselves still come from [MockVendors]; this class
/// only puts them behind [MockBackend], so every screen that shows catalogue
/// data can render a real loading state, a real failure state and a retry.
class CatalogRepository {
  const CatalogRepository();

  /// Every vendor, in feed order.
  Future<List<Map<String, dynamic>>> getVendors() =>
      MockBackend.run(() => MockVendors.vendors);

  /// One vendor's menu. [products] is the list the caller already knows the
  /// vendor has; the delay stands in for fetching it again.
  Future<List<VendorProduct>> getMenu(List<VendorProduct> products) =>
      MockBackend.run(() => products);
}

/// The app has one catalogue, so one instance.
const CatalogRepository catalogRepository = CatalogRepository();
