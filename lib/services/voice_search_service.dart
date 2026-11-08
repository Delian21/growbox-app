import '../data/app_state.dart';
import '../data/mock_data.dart';

/// Turns a spoken query into the catalogue's own wording.
///
/// Speech recognition on a phone gets short grocery words wrong in predictable
/// ways ("rise" for rice, "bearns" for beans). Searching the raw transcript
/// then finds nothing, which reads as the feature being broken rather than the
/// word being misheard. So the transcript is compared with every product and
/// vendor name we sell, and the closest one is used when it is close enough;
/// otherwise the customer's own words are searched unchanged, so a query we do
/// not stock behaves exactly like typing it.
class VoiceSearchMatcher {
  VoiceSearchMatcher({List<String>? productNames, List<String>? vendorNames})
      : _productNames = productNames ?? _catalogProductNames(),
        _vendorNames = vendorNames ?? _catalogVendorNames();

  final List<String> _productNames;
  final List<String> _vendorNames;

  /// Words the recogniser substitutes for grocery items, applied before any
  /// distance is measured. Kept short on purpose: each entry is a guess about
  /// one word, and a long table starts inventing matches.
  static const Map<String, String> _mishearings = {
    'rise': 'rice',
    'rices': 'rice',
    'bred': 'bread',
    'bead': 'bread',
    'bearns': 'beans',
    'been': 'beans',
    'flower': 'flour',
    'flour': 'flour',
    'mil': 'milk',
    'mile': 'milk',
    'egs': 'eggs',
    'egg': 'eggs',
    'tomatos': 'tomatoes',
    'potatos': 'potatoes',
    'onis': 'onions',
    'onin': 'onions',
    'peper': 'pepper',
    'peppers': 'pepper',
    'yan': 'yam',
    'yams': 'yam',
    'cabage': 'cabbage',
    'carrot': 'carrots',
    'bananna': 'banana',
    'orang': 'orange',
    'avacado': 'avocado',
    'spinich': 'spinach',
    'groundnut': 'groundnuts',
  };

  /// The catalogue name to search for [transcript].
  ///
  /// Always returns something usable: the matched name when one is close, the
  /// trimmed transcript otherwise.
  String resolve(String transcript) {
    final raw = transcript.trim();
    if (raw.isEmpty) return '';

    final normalized = _normalize(raw);
    if (normalized.isEmpty) return raw;

    final candidates = [..._productNames, ..._vendorNames];
    if (candidates.isEmpty) return raw;

    // 1. Exact, ignoring case and punctuation.
    for (final name in candidates) {
      if (_normalize(name) == normalized) return name;
    }

    // 2. One name contains the other: "fresh tomatoes" → Tomatoes,
    //    "green" → Green Farm. Longest name wins, so "palm oil" beats "oil".
    String? contained;
    for (final name in candidates) {
      final candidate = _normalize(name);
      if (candidate.isEmpty) continue;
      if (normalized == candidate ||
          normalized.contains(candidate) ||
          candidate.contains(normalized)) {
        if (contained == null || name.length > contained.length) {
          contained = name;
        }
      }
    }
    if (contained != null) return contained;

    // 3. Closest by edit distance. The allowance scales with the word: one
    //    letter for a four-letter item, two or three for longer names. This is
    //    what catches "rife" and "bears" without matching "peas" to "pears".
    String? best;
    int bestDistance = 1 << 30;
    for (final name in candidates) {
      final candidate = _normalize(name);
      if (candidate.isEmpty) continue;
      final distance = _levenshtein(normalized, candidate);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = name;
      }
    }

    // Both strings have to be close: "peas" is two edits from "beans" and only
    // four letters long, so a longer name's extra room must not rescue it.
    final allowance = _allowance(normalized, _normalize(best ?? ''));
    if (best != null && bestDistance <= allowance) return best;

    return raw;
  }

  /// Lowercase, punctuation-free, single-spaced, with mishearings repaired.
  String _normalize(String value) {
    final cleaned = value
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s']"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';

    final words = cleaned.split(' ');
    final repaired = <String>[];
    for (final word in words) {
      // Apostrophes are noise for matching ("bean's" → beans).
      final bare = word.replaceAll("'", '');
      repaired.add(_mishearings[bare] ?? bare);
    }
    return repaired.join(' ');
  }

  /// How many edits a pair of words may differ by and still be "the same
  /// thing". Scaled to the shorter word: one edit for four letters or fewer,
  /// two up to seven, three beyond that.
  int _allowance(String a, String b) {
    final shortest = a.length < b.length ? a.length : b.length;
    if (shortest <= 4) return 1;
    if (shortest <= 7) return 2;
    return 3;
  }

  /// Standard Levenshtein distance between two strings.
  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (int i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return previous[b.length];
  }

  static List<String> _catalogProductNames() {
    final names = <String>{};
    for (final vendor in MockVendors.vendors) {
      final products = vendor['products'] as List<VendorProduct>;
      for (final product in products) {
        names.add(product.name);
      }
    }
    for (final record in purchaseHistory) {
      names.add(record.product.name);
    }
    return names.toList();
  }

  static List<String> _catalogVendorNames() {
    final names = <String>{};
    for (final vendor in MockVendors.vendors) {
      final name = vendor['name'];
      if (name is String && name.trim().isNotEmpty) names.add(name);
    }
    return names.toList();
  }
}
