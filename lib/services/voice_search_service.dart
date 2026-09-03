import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../data/mock_data.dart';
import '../data/app_state.dart';

// ---------------------------------------------------------------------------
// Parsed Intent — the structured output of voice analysis
// ---------------------------------------------------------------------------

/// The action the user wants to perform.
enum VoiceAction { search, addToCart, removeFromCart, navigate, unknown }

/// A parsed quantity with optional unit.
class ParsedQuantity {
  final int value;
  final String unit; // 'kg', 'bag', 'piece', 'bunch', '', etc.

  const ParsedQuantity({required this.value, this.unit = ''});

  @override
  String toString() => unit.isNotEmpty ? '$value $unit' : '$value';
}

/// The fully parsed intent from a voice command.
class VoiceIntent {
  final VoiceAction action;
  final String productQuery; // raw product name from speech
  final String? matchedProductName; // resolved against product database
  final String? matchedVendorName;
  final ParsedQuantity? quantity;
  final String rawText;

  const VoiceIntent({
    required this.action,
    required this.productQuery,
    this.matchedProductName,
    this.matchedVendorName,
    this.quantity,
    required this.rawText,
  });

  bool get hasMatch => matchedProductName != null;
  bool get hasQuantity => quantity != null;

  String get displayAction {
    switch (action) {
      case VoiceAction.addToCart:
        return 'Add to Box';
      case VoiceAction.removeFromCart:
        return 'Remove from Box';
      case VoiceAction.search:
        return 'Search';
      case VoiceAction.navigate:
        return 'Navigate';
      case VoiceAction.unknown:
        return 'Search';
    }
  }

  String get summary {
    final buf = StringBuffer(displayAction);
    if (quantity != null) buf.write(' $quantity');
    if (hasMatch) {
      buf.write(' $matchedProductName');
      if (matchedVendorName != null) buf.write(' from $matchedVendorName');
    } else {
      buf.write(' "$productQuery"');
    }
    return buf.toString();
  }
}

// ---------------------------------------------------------------------------
// Voice Search Service — speech-to-text + intent parsing
// ---------------------------------------------------------------------------

class VoiceSearchService {
  VoiceSearchService._();
  static final VoiceSearchService instance = VoiceSearchService._();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  /// All known product names (lowercased) for fuzzy matching.
  late final List<_ProductEntry> _productIndex;

  /// Initialize speech engine and build product index.
  Future<bool> init() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    _buildProductIndex();
    return _isInitialized;
  }

  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized;

  /// Start listening. Returns a stream of partial results.
  Stream<String> startListening() async* {
    if (!_isInitialized) await init();
    if (!_isInitialized) return;

    _isListening = true;
    final controller = StreamController<String>();

    _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.recognizedWords.isNotEmpty) {
          controller.add(result.recognizedWords);
        }
        if (result.finalResult) {
          _isListening = false;
          controller.close();
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
        // Auto-stop after 3 seconds of silence (no need to tap to stop).
        pauseFor: const Duration(seconds: 3),
        // Hard stop after 10 seconds as a safety net.
        listenFor: const Duration(seconds: 10),
      ),
    );

    yield* controller.stream;
  }

  /// Stop listening.
  void stopListening() {
    _speech.stop();
    _isListening = false;
  }

  /// Parse raw speech text into a structured intent.
  VoiceIntent parseIntent(String rawText) {
    final text = rawText.toLowerCase().trim();

    // 1. Detect action
    final action = _detectAction(text);

    // 2. Extract quantity
    final quantity = _extractQuantity(text);

    // 3. Extract product query (strip action words and quantities)
    final productQuery = _extractProductQuery(text, action);

    // 4. Fuzzy match against product database
    final match = _fuzzyMatch(productQuery);

    return VoiceIntent(
      action: action,
      productQuery: productQuery,
      matchedProductName: match?.name,
      matchedVendorName: match?.vendorName,
      quantity: quantity,
      rawText: rawText,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTION DETECTION
  // ═══════════════════════════════════════════════════════════════════════

  VoiceAction _detectAction(String text) {
    // Order matters: check more specific patterns first.
    if (_matchesAny(text, [
      'remove', 'delete', 'take out', 'take off',
    ])) {
      return VoiceAction.removeFromCart;
    }
    if (_matchesAny(text, [
      'add', 'put in', 'put in my box', 'order', 'buy',
      'get me', 'get some', 'i need', 'i want',
      'include', 'throw in', 'grab',
    ])) {
      return VoiceAction.addToCart;
    }
    if (_matchesAny(text, [
      'go to', 'open', 'show me', 'navigate to', 'take me to',
    ])) {
      return VoiceAction.navigate;
    }
    // Default: if a product is found, treat as add-to-cart; otherwise search.
    return VoiceAction.search;
  }

  bool _matchesAny(String text, List<String> patterns) {
    return patterns.any((p) => text.contains(p));
  }

  // ═══════════════════════════════════════════════════════════════════════
  // QUANTITY EXTRACTION
  // ═══════════════════════════════════════════════════════════════════════

  ParsedQuantity? _extractQuantity(String text) {
    // Patterns like "5kg", "5 kg", "2 bags", "3 pieces", "a dozen"
    final patterns = [
      RegExp(r'(\d+)\s*(kg|kilogram|kilograms?)'),
      RegExp(r'(\d+)\s*(g|gram|grams?)'),
      RegExp(r'(\d+)\s*(lb|pound|pounds?)'),
      RegExp(r'(\d+)\s*(bag|bags|sack|sacks?)'),
      RegExp(r'(\d+)\s*(bunch|bunches?)'),
      RegExp(r'(\d+)\s*(piece|pieces|pc|pcs)'),
      RegExp(r'(\d+)\s*(tray|trays?)'),
      RegExp(r'(\d+)\s*(basket|baskets?)'),
      RegExp(r'(\d+)\s*(pack|packs|package|packages?)'),
      RegExp(r'(\d+)\s*(crate|crates?)'),
      RegExp(r'(\d+)\s*(load|loads?)'),
      RegExp(r'(\d+)\s*(item|items?)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = int.tryParse(match.group(1) ?? '');
        if (value != null && value > 0) {
          return ParsedQuantity(
            value: value,
            unit: _normalizeUnit(match.group(2) ?? ''),
          );
        }
      }
    }

    // Handle word numbers: "two bags", "five kg"
    final wordNumbers = {
      'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
      'eleven': 11, 'twelve': 12, 'dozen': 12,
    };

    for (final entry in wordNumbers.entries) {
      if (text.contains(entry.key)) {
        // Check if followed by a unit
        final unitPattern = RegExp(
          '${entry.key}\\s+(kg|kilogram|bags?|bunch|pieces?|tray|basket|pack|crate|load|items?)',
        );
        final unitMatch = unitPattern.firstMatch(text);
        if (unitMatch != null) {
          return ParsedQuantity(
            value: entry.value,
            unit: _normalizeUnit(unitMatch.group(1) ?? ''),
          );
        }
        // Just a number, no unit
        return ParsedQuantity(value: entry.value);
      }
    }

    // "a" or "an" means 1
    if (text.contains(RegExp(r'\ba\b|\ban\b'))) {
      return const ParsedQuantity(value: 1);
    }

    return null;
  }

  String _normalizeUnit(String raw) {
    final lower = raw.toLowerCase();
    if (lower.startsWith('kilogram')) return 'kg';
    if (lower.startsWith('gram')) return 'g';
    if (lower.startsWith('pound') || lower == 'lb') return 'lb';
    if (lower.startsWith('bag')) return 'bag';
    if (lower.startsWith('bunch')) return 'bunch';
    if (lower.startsWith('piece') || lower.startsWith('pc')) return 'piece';
    if (lower.startsWith('tray')) return 'tray';
    if (lower.startsWith('basket')) return 'basket';
    if (lower.startsWith('pack')) return 'pack';
    if (lower.startsWith('crate')) return 'crate';
    if (lower.startsWith('load')) return 'load';
    if (lower.startsWith('item')) return 'item';
    return lower;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PRODUCT QUERY EXTRACTION
  // ═══════════════════════════════════════════════════════════════════════

  String _extractProductQuery(String text, VoiceAction action) {
    // Remove action words
    var cleaned = text;
    final actionWords = [
      'add', 'remove', 'delete', 'buy', 'order', 'get', 'put',
      'in', 'my', 'box', 'to', 'some', 'me', 'from', 'into',
      'i need', 'i want', 'include', 'throw', 'grab', 'take',
      'out', 'off', 'go to', 'open', 'show', 'navigate',
    ];
    for (final word in actionWords) {
      cleaned = cleaned.replaceAll(RegExp(r'\b' + word + r'\b'), ' ');
    }

    // Remove quantity phrases
    cleaned = cleaned.replaceAll(
      RegExp(r'\d+\s*(kg|g|lb|bags?|bunch|pieces?|tray|basket|pack|crate|load|items?|kilograms?|grams?|pounds?)'),
      ' ',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|dozen|a|an)\s*(kg|g|lb|bags?|bunch|pieces?|tray|basket|pack|crate|load|items?)?'),
      ' ',
    );

    // Remove filler words
    cleaned = cleaned.replaceAll(RegExp(r'\b(fresh|of|the|please|now|right|away)\b'), ' ');

    // Clean up whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FUZZY PRODUCT MATCHING
  // ═══════════════════════════════════════════════════════════════════════

  void _buildProductIndex() {
    final Set<String> seen = {};
    _productIndex = [];

    for (final vendor in MockVendors.vendors) {
      final products = vendor['products'] as List<VendorProduct>;
      for (final product in products) {
        final key = '${product.name.toLowerCase()}:${vendor['name']}';
        if (!seen.contains(key)) {
          seen.add(key);
          _productIndex.add(_ProductEntry(
            name: product.name,
            nameLower: product.name.toLowerCase(),
            vendorName: vendor['name'] as String,
            category: product.category.toLowerCase(),
            product: product,
          ));
        }
      }
    }

    // Also index from the purchase history products.
    for (final record in purchaseHistory) {
      final key = '${record.product.name.toLowerCase()}:${record.product.vendorName}';
      if (!seen.contains(key)) {
        seen.add(key);
        _productIndex.add(_ProductEntry(
          name: record.product.name,
          nameLower: record.product.name.toLowerCase(),
          vendorName: record.product.vendorName,
          category: record.product.category.toLowerCase(),
          product: record.product,
        ));
      }
    }
  }

  /// Find the best fuzzy match for a product query.
  _ProductEntry? _fuzzyMatch(String query) {
    if (query.isEmpty) return null;

    final q = query.toLowerCase().trim();

    // 1. Exact match
    for (final entry in _productIndex) {
      if (entry.nameLower == q) return entry;
    }

    // 2. Starts-with match
    for (final entry in _productIndex) {
      if (entry.nameLower.startsWith(q)) return entry;
    }

    // 3. Contains match
    for (final entry in _productIndex) {
      if (entry.nameLower.contains(q) || q.contains(entry.nameLower)) {
        return entry;
      }
    }

    // 4. Word overlap — check if any word in the query matches a product name word
    final queryWords = q.split(RegExp(r'\s+'));
    _ProductEntry? bestWordMatch;
    int bestScore = 0;

    for (final entry in _productIndex) {
      final productWords = entry.nameLower.split(RegExp(r'\s+'));
      int score = 0;
      for (final qw in queryWords) {
        for (final pw in productWords) {
          if (pw == qw) {
            score += 3;
          } else if (pw.startsWith(qw) || qw.startsWith(pw)) {
            score += 2;
          } else if (_levenshtein(pw, qw) <= 2) {
            score += 1;
          }
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestWordMatch = entry;
      }
    }

    if (bestScore >= 2) return bestWordMatch;

    // 5. Levenshtein distance — find closest product name
    _ProductEntry? closest;
    int minDist = 999;

    for (final entry in _productIndex) {
      final dist = _levenshtein(q, entry.nameLower);
      if (dist < minDist) {
        minDist = dist;
        closest = entry;
      }
    }

    // Only accept if the distance is reasonable (less than half the query length)
    if (closest != null && minDist <= (q.length * 0.5).ceil()) {
      return closest;
    }

    return null;
  }

  /// Simple Levenshtein distance between two strings.
  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NAVIGATION TARGETS
  // ═══════════════════════════════════════════════════════════════════════

  /// Known navigation targets for "go to" commands.
  static const Map<String, String> navigationTargets = {
    'cart': 'cart',
    'box': 'cart',
    'my box': 'cart',
    'profile': 'profile',
    'account': 'profile',
    'orders': 'orders',
    'order history': 'orders',
    'box history': 'orders',
    'favorites': 'favorites',
    'favourites': 'favorites',
    'search': 'search',
    'home': 'home',
    'menu': 'menu',
    'produce': 'menu',
    'notifications': 'notifications',
    'faq': 'faq',
    'help': 'faq',
  };

  /// Check if the query is a navigation command and return the target route.
  String? parseNavigationTarget(String text) {
    final lower = text.toLowerCase();
    for (final entry in navigationTargets.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Internal product index entry
// ---------------------------------------------------------------------------

class _ProductEntry {
  final String name;
  final String nameLower;
  final String vendorName;
  final String category;
  final VendorProduct product;

  const _ProductEntry({
    required this.name,
    required this.nameLower,
    required this.vendorName,
    required this.category,
    required this.product,
  });
}
