// Shared by the opt-in tooling under tool/ (screenshot sweep, welcome fold
// check). Makes a widget test render the app in its real typefaces and icons.
//
//     flutter test tool/<script>.dart
//
// Three things a widget test gets wrong on its own, all fixed here:
//
//  1. google_fonts downloads Poppins/Inter at runtime. A test has no network,
//     so the faces are missing and the fallback font has different metrics.
//     Fetch them once into build/ (gitignored) with
//
//         tool/fetch_test_fonts.sh
//
//  2. The Material icon font is not loaded either, so every Icon photographs as
//     an empty box. It is read out of the test run's own asset bundle.
//
//  3. When google_fonts cannot find a face it rethrows into a future nobody
//     awaits, and flutter_test reports that as a test failure. `_serveFonts`
//     answers its asset lookup with the local files, so it never reaches for
//     the network at all.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// One face of one family, in the three names the stack knows it by:
/// the google_fonts family (`Inter`), the API variant google_fonts asks for
/// (`Regular`, `SemiBold`, …) and the name it registers a loaded face under.
class _Face {
  const _Face(this.family, this.variant, this.registeredAs, this.file);

  final String family;
  final String variant;

  /// google_fonts names the text style's family `<Family>_<variant string>`,
  /// which is not the same string as the API variant: `w400` is `Regular` in a
  /// filename and `regular` in a family name.
  final String registeredAs;
  final String file;

  /// The asset key google_fonts matches by filename suffix.
  String get assetKey => 'build/gbfonts/$family-$variant.ttf';
}

/// Every face the app asks for. `grep -rho "FontWeight.w[0-9]00" lib/` returns
/// only w400/w500/w600/w700, and the Material text themes contribute w400/w500.
const List<_Face> _faces = [
  _Face('Inter', 'Regular', 'Inter_regular', 'build/gbfonts/inter-400.ttf'),
  _Face('Inter', 'Medium', 'Inter_500', 'build/gbfonts/inter-500.ttf'),
  _Face('Inter', 'SemiBold', 'Inter_600', 'build/gbfonts/inter-600.ttf'),
  _Face('Inter', 'Bold', 'Inter_700', 'build/gbfonts/inter-700.ttf'),
  _Face('Poppins', 'Regular', 'Poppins_regular', 'build/gbfonts/poppins-400.ttf'),
  _Face('Poppins', 'Medium', 'Poppins_500', 'build/gbfonts/poppins-500.ttf'),
  _Face(
      'Poppins', 'SemiBold', 'Poppins_600', 'build/gbfonts/poppins-600.ttf'),
  _Face('Poppins', 'Bold', 'Poppins_700', 'build/gbfonts/poppins-700.ttf'),
];

/// Registers the real faces and icons, and keeps google_fonts offline.
Future<void> loadRealFonts() async {
  await _loadIcons();
  await _loadTextFaces();
  _serveFonts();
}

/// Without this every `Icon` in the app photographs as an empty box: the
/// engine does not load the fonts the test bundle declares.
Future<void> _loadIcons() async {
  const material = 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf';
  _require(material);
  await _register('MaterialIcons', material);
}

/// Registers each TTF under the family name the app's styles end up carrying,
/// so the first frame already renders in the real face. google_fonts loads the
/// same bytes again once it is awake; the duplicate is harmless.
Future<void> _loadTextFaces() async {
  for (final face in _faces) {
    _require(face.file);
    await _register(face.registeredAs, face.file);
  }

  // Family-less TextStyles (the Google/Apple button labels) use the platform
  // default, which is Roboto.
  const roboto = 'build/gbfonts/roboto-400.ttf';
  _require(roboto);
  await _register('Roboto', roboto);
}

void _require(String file) {
  if (!File(file).existsSync()) {
    fail('Missing $file. Run tool/fetch_test_fonts.sh first.');
  }
}

Future<void> _register(String family, String file) async {
  final loader = FontLoader(family);
  loader
      .addFont(Future.value(ByteData.sublistView(File(file).readAsBytesSync())));
  await loader.load();
}

/// Answers google_fonts' "is this face an asset?" question with the local
/// files, over the asset channel.
///
/// google_fonts asks the framework's [AssetManifest] for the bundle's assets,
/// which a test bundle lists without any of these faces — hence the network
/// attempt above. The manifest is a StandardMessageCodec-encoded map of asset
/// key to variants, so the test run's own manifest is decoded, given an entry
/// per face and re-encoded. Everything else asked for is served from the bundle
/// the test run built.
void _serveFonts() {
  final served = <String, ByteData>{
    for (final face in _faces) face.assetKey: _bytes(face.file),
  };
  served[_manifestKey] = _manifestWithFaces(served.keys.toList());

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
    final key = utf8.decode(message!.buffer.asUint8List());
    final asset = served[key];
    if (asset != null) return asset;
    final file = File('$_bundleDir$key');
    return file.existsSync() ? _bytes(file.path) : null;
  });

  // A face that slips past the manifest above fails loudly instead of silently
  // reaching for the network, which a test blocks anyway.
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Where `flutter test` puts the bundle the test binding serves.
const String _bundleDir = 'build/unit_test_assets/';
const String _manifestKey = 'AssetManifest.bin';

ByteData _bytes(String file) =>
    ByteData.sublistView(File(file).readAsBytesSync());

ByteData _manifestWithFaces(List<String> assetKeys) {
  _require('$_bundleDir$_manifestKey');
  const codec = StandardMessageCodec();
  final manifest = codec.decodeMessage(_bytes('$_bundleDir$_manifestKey'))
      as Map<Object?, Object?>;
  for (final key in assetKeys) {
    manifest[key] = <Object?>[
      <Object?, Object?>{'asset': key},
    ];
  }
  return codec.encodeMessage(manifest)!;
}
