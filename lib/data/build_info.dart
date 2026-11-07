/// What build a device is running.
///
/// The version string is duplicated here rather than read from pubspec at
/// runtime: Flutter cannot read pubspec from a compiled app, and adding a
/// package (`package_info_plus`) for one line would be a dependency for a
/// label. Keep it in step with the `version:` line in pubspec.yaml, ignoring
/// the `+build` suffix — that suffix is the store's build number, not the
/// version customers see.
const String kAppVersion = '1.0.0';

/// The deployment's identity, supplied at build time:
/// `--dart-define=BUILD_ID=<sha or tag>`.
///
/// The default is `dev`, not the commit or a timestamp, because it has to be
/// obvious that a build was made without one: a label that always looks
/// unique is a label nobody checks.
const String kBuildId = String.fromEnvironment('BUILD_ID', defaultValue: 'dev');

/// "Growbox v1.0.0 · dev" — the one way the app writes its own build.
///
/// Const, so the whole string (and the two constants above) fold into a single
/// literal at compile time and a release build with no define is unchanged
/// apart from printing `dev`.
const String kBuildLabel = 'Growbox v$kAppVersion · $kBuildId';
