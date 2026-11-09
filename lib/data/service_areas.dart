import 'mock_data.dart';

/// The places the app can be browsed from.
///
/// A [ServiceArea] is a curated, human-known neighbourhood rather than an
/// administrative unit: the LGAs of Abuja are far too coarse to describe where
/// a rider goes (Gwarinpa, Wuse and Lugbe are all inside AMAC), so the list is
/// flat and each entry carries its LGA only as context.
///
/// [kAreaCatalog] is the set of neighbourhoods the app knows how to name, and
/// [kServiceAreas] is the subset some vendor actually delivers to. Only the
/// latter is offered in the picker: listing an area the app cannot serve would
/// promise a delivery window that does not exist. Customers can still type
/// anything they like — [BrowsingAreaStore] keeps that text as-is — but only
/// catalogued entries get a canonical [ServiceArea.id].
class ServiceArea {
  const ServiceArea({
    required this.id,
    required this.name,
    required this.lga,
    this.aliases = const <String>[],
  });

  /// Stable key, safe to persist. Never build one from [name].
  final String id;

  /// What people call the place, e.g. 'Gwarinpa'.
  final String name;

  /// Area council / LGA, shown as context only, e.g. 'AMAC'.
  final String lga;

  /// Other strings that should find this entry: misspellings, roman numerals,
  /// estate and bus-stop names.
  final List<String> aliases;

  /// Always Abuja while the catalog is.
  String get city => 'Abuja';

  /// What the header and the store show, e.g. 'Gwarinpa, Abuja'.
  String get label => '$name, $city';

  /// The one line under the name in the picker, e.g. 'AMAC · Abuja'.
  String get region => '$lga · $city';
}

/// Every neighbourhood the app can name, alphabetical so the list can be
/// scanned. This is the name/alias/LGA dictionary only — what is *served* is
/// derived from the vendors in [kServiceAreas].
///
/// Adding an entry here does not offer it to customers; a vendor has to list
/// its id in its own `serviceAreas` first.
const List<ServiceArea> kAreaCatalog = <ServiceArea>[
  ServiceArea(id: 'apo', name: 'Apo', lga: 'AMAC', aliases: ['Apo Legislative Quarters', 'Apo Mechanic']),
  ServiceArea(id: 'asokoro', name: 'Asokoro', lga: 'AMAC'),
  ServiceArea(id: 'bwari', name: 'Bwari', lga: 'Bwari'),
  ServiceArea(id: 'central-area', name: 'Central Area', lga: 'AMAC', aliases: ['CBD', 'Area 1', 'Area 10']),
  ServiceArea(id: 'dawaki', name: 'Dawaki', lga: 'AMAC'),
  ServiceArea(id: 'durumi', name: 'Durumi', lga: 'AMAC'),
  ServiceArea(id: 'dutse-alhaji', name: 'Dutse Alhaji', lga: 'Bwari', aliases: ['Dutse']),
  ServiceArea(id: 'gaduwa', name: 'Gaduwa', lga: 'AMAC'),
  ServiceArea(id: 'galadimawa', name: 'Galadimawa', lga: 'AMAC'),
  ServiceArea(id: 'garki', name: 'Garki', lga: 'AMAC', aliases: ['Garki 1', 'Garki 2', 'Garki I', 'Garki II']),
  ServiceArea(id: 'gudu', name: 'Gudu', lga: 'AMAC'),
  ServiceArea(id: 'gwagwalada', name: 'Gwagwalada', lga: 'Gwagwalada'),
  ServiceArea(id: 'gwarinpa', name: 'Gwarinpa', lga: 'AMAC', aliases: ['Gwarimpa', 'Gwarinpa Estate', '3rd Avenue']),
  ServiceArea(id: 'jabi', name: 'Jabi', lga: 'AMAC', aliases: ['Jabi Lake']),
  ServiceArea(id: 'karu', name: 'Karu', lga: 'AMAC', aliases: ['Karu Site', 'Karu Abuja']),
  ServiceArea(id: 'karsana', name: 'Karsana', lga: 'AMAC'),
  ServiceArea(id: 'kubwa', name: 'Kubwa', lga: 'Bwari', aliases: ['Kubwa Phase 4', 'Gwarinpa-Kubwa Road']),
  ServiceArea(id: 'life-camp', name: 'Life Camp', lga: 'AMAC', aliases: ['Lifecamp', 'Life Camp Estate']),
  ServiceArea(id: 'lokogoma', name: 'Lokogoma', lga: 'AMAC', aliases: ['Lokogoma District']),
  ServiceArea(id: 'lugbe', name: 'Lugbe', lga: 'AMAC', aliases: ['Lugbe Airport Road', 'Airport Road']),
  ServiceArea(id: 'maitama', name: 'Maitama', lga: 'AMAC', aliases: ['Maitama District']),
  ServiceArea(id: 'nyanya', name: 'Nyanya', lga: 'AMAC', aliases: ['Nyanya Gwandara']),
  ServiceArea(id: 'ushafa', name: 'Ushafa', lga: 'Bwari'),
  ServiceArea(id: 'utako', name: 'Utako', lga: 'AMAC'),
  ServiceArea(id: 'wuse-2', name: 'Wuse 2', lga: 'AMAC', aliases: ['Wuse II', 'Wuse Two']),
  ServiceArea(id: 'wuye', name: 'Wuye', lga: 'AMAC'),
];

/// The areas at least one vendor delivers to, alphabetical.
///
/// Derived rather than hand-written: a vendor's own coverage is the honest
/// source of truth, so adding or dropping an area is one edit in the vendor
/// data and cannot drift from what the picker offers. A catalogued area no
/// vendor serves (say Karu today) simply does not appear.
final List<ServiceArea> kServiceAreas = _servedAreas();

List<ServiceArea> _servedAreas() {
  final served = <String>{};
  for (final vendor in MockVendors.vendors) {
    final areas = vendor['serviceAreas'];
    if (areas is List) served.addAll(areas.whereType<String>());
  }
  return [
    for (final area in kAreaCatalog)
      if (served.contains(area.id)) area,
  ];
}

/// True when some vendor covers [id]. Unknown ids are not served.
bool isServiceAreaServed(String? id) {
  if (id == null || id.isEmpty) return false;
  for (final area in kServiceAreas) {
    if (area.id == id) return true;
  }
  return false;
}

/// Finds a catalogued area by its persisted [ServiceArea.id].
///
/// Looks at the whole catalog, not just what is served today, so a saved area
/// keeps its identity if a vendor later stops covering it.
ServiceArea? serviceAreaById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final area in kAreaCatalog) {
    if (area.id == id) return area;
  }
  return null;
}

/// Finds a curated area from the label a customer last saved.
///
/// Handles legacy free-text values, so 'gwarinpa' typed before this list
/// existed still resolves to the curated entry.
ServiceArea? serviceAreaForLabel(String? label) {
  final query = _normalise(label ?? '');
  if (query.isEmpty) return null;
  for (final area in kAreaCatalog) {
    if (_normalise(area.label) == query || _normalise(area.name) == query) {
      return area;
    }
  }
  return null;
}

/// Areas matching [query], best match first.
///
/// Empty query returns every area in list order. Ranking puts a name prefix
/// first, then a name substring, then an alias, then the LGA, so typing 'wuse'
/// lands on Wuse 2 before the areas whose LGA merely mentions it.
List<ServiceArea> searchServiceAreas(String query) {
  final q = _normalise(query);
  if (q.isEmpty) return kServiceAreas;

  final scored = <({ServiceArea area, int score})>[];
  for (final area in kServiceAreas) {
    final score = _score(area, q);
    if (score != null) scored.add((area: area, score: score));
  }
  scored.sort((a, b) {
    final byScore = a.score.compareTo(b.score);
    if (byScore != 0) return byScore;
    return a.area.name.compareTo(b.area.name);
  });
  return [for (final entry in scored) entry.area];
}

int? _score(ServiceArea area, String q) {
  final name = _normalise(area.name);
  if (name.startsWith(q)) return 0;
  if (name.contains(q)) return 1;
  for (final alias in area.aliases) {
    if (_normalise(alias).startsWith(q)) return 2;
  }
  for (final alias in area.aliases) {
    if (_normalise(alias).contains(q)) return 3;
  }
  if (_normalise(area.lga).startsWith(q)) return 4;
  return null;
}

/// Lowercase, commas and punctuation folded to spaces, runs collapsed.
///
/// Keeps 'Wuse II' and 'wuse 2' apart only through [ServiceArea.aliases], so
/// the normaliser stays predictable rather than clever.
String _normalise(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();
