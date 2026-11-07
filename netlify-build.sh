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

# BUILD_ID: Netlify puts the deployed commit in $COMMIT_REF, so the label at
# the bottom of Profile names the exact commit the tester is looking at.
# Falls back to "dev" on a build without that variable.
BUILD_ID="${COMMIT_REF:-dev}"

# --pwa-strategy=none: while we are testing, no service worker is registered,
# so a reload always fetches the deployed build instead of the cached one.
# Flutter still writes flutter_service_worker.js, and with this strategy its
# body unregisters the old worker and reloads open tabs once — that is how
# devices still holding the previous cached app move onto the new build.
flutter build web --release \
  --pwa-strategy=none \
  --dart-define=BUILD_ID="${BUILD_ID}"

echo "✓ Web bundle ready in build/web (BUILD_ID=${BUILD_ID})"
