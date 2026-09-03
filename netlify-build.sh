#!/usr/bin/env bash
# GROWBOX — Flutter web build for Netlify.
#
# Netlify's build images don't ship the Flutter SDK, so we install the pinned
# stable SDK into $HOME (every build starts from a fresh VM, hence the clone)
# and then run the standard release web build.
set -euo pipefail

FLUTTER_DIR="${HOME}/flutter"
SDK_VERSION="${FLUTTER_VERSION:-stable}"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "▶ Installing Flutter ${SDK_VERSION}…"
  git clone --quiet --depth 1 --branch "${SDK_VERSION}" \
    https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
flutter config --no-analytics >/dev/null 2>&1 || true
flutter pub get
flutter build web --release
echo "✓ Web bundle ready in build/web"
