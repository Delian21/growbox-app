#!/usr/bin/env bash
# Fetches the real TTFs that the opt-in widget tooling renders with, into
# build/gbfonts/ (gitignored — they are 1.8 MB of binaries that the app itself
# does not ship).
#
#     tool/fetch_test_fonts.sh
#
# Why the files are needed at all: the app asks google_fonts for Poppins/Inter,
# and google_fonts downloads each face from fonts.gstatic.com on first use. A
# widget test has no network, falls back to the test font, and every screenshot
# or measurement taken with it would be wrong. tool/real_fonts.dart loads these
# files into the test binding instead.
#
# Weights: the app uses only w400/w500/w600/w700 — `grep -rho "FontWeight\.w[0-9]00" lib/`.
#
# The CSS API answers a modern browser with .woff2 and an ancient one with
# .eot, but an unidentifiable one with the .ttf the app itself ends up using,
# which keeps these files byte-identical to what google_fonts downloads.
set -euo pipefail
cd "$(dirname "$0")/.."

UA='Mozilla/5.0'

fetch() { # family weight output
  local css url
  css=$(curl -fsS "https://fonts.googleapis.com/css2?family=$1:wght@$2" -H "User-Agent: $UA")
  # The last block is the latin subset, which is the one the app renders.
  url=$(printf '%s' "$css" | grep -o 'https://[^)]*' | tail -1)
  if [ -z "$url" ]; then
    echo "fetch_test_fonts: no font url in the CSS for $1 $2" >&2
    return 1
  fi
  curl -fsSL -o "build/gbfonts/$3" "$url"
  # A TTF starts with the sfnt version 0x00010000; anything else is an error page.
  if [ "$(head -c 4 "build/gbfonts/$3" | od -An -tx1 | tr -d ' \n')" != '00010000' ]; then
    echo "fetch_test_fonts: $3 is not a TTF" >&2
    return 1
  fi
  echo "build/gbfonts/$3"
}

mkdir -p build/gbfonts

for weight in 400 500 600 700; do
  fetch Inter "$weight" "inter-$weight.ttf"
done
for weight in 400 500 600 700; do
  fetch Poppins "$weight" "poppins-$weight.ttf"
done

# Family-less TextStyles (the Google/Apple button labels) use the platform
# default, which is Roboto.
fetch Roboto 400 roboto-400.ttf
