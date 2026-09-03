import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Every getter target inside [PlaceholderImages] must resolve to a real
/// bundled file. If an asset is renamed (or a getter typo'd), this test fails
/// with the offending getter named — turning the silent broken-image class of
/// bugs (grey basket/storefront icons) into a build-time error.
void main() {
  test('every PlaceholderImages getter points at an existing asset file',
      () {
    final source =
        File('lib/data/placeholder_images.dart').readAsStringSync();

    final targets = <String, String>{}; // asset file -> getter name

    // _asset('name') style getters -> assets/images/<name>.jpg
    for (final m in RegExp(
            r"static String get (\w+) => _asset\('([a-z_]+)'\)")
        .allMatches(source)) {
      targets['${m[2]}.jpg'] = m[1]!;
    }
    // Direct-path style getters -> 'assets/images/<file>.png'
    for (final m in RegExp(
            r"static String get (\w+) => 'assets/images/([a-z_.]+)'")
        .allMatches(source)) {
      targets[m[2]!] = m[1]!;
    }

    expect(targets.length, greaterThan(10),
        reason: 'expected to find the full getter table');

    final missing = <String>[];
    for (final entry in targets.entries) {
      final file = File('assets/images/${entry.key}');
      if (!file.existsSync()) {
        missing.add('${entry.value} -> assets/images/${entry.key}');
      }
    }

    expect(missing, isEmpty,
        reason: 'missing asset files referenced by PlaceholderImages:\n'
            '${missing.join('\n')}\n'
            'Rename the asset file or update the getter so they stay in sync.');
  });
}
