#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

VERSION=$(grep -m1 '^version:' "${ROOT_DIR}/pubspec.yaml" | sed -E 's/version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
DMG_OUTPUT="${1:-${ROOT_DIR}/fima-${VERSION}.dmg}"
RELEASE_APP="${ROOT_DIR}/build/macos/Build/Products/Release/fima.app"
BACKGROUND_PNG="${SCRIPT_DIR}/dmg_background.png"
VOLICON="${RELEASE_APP}/Contents/Resources/AppIcon.icns"

if [[ ! -d "${RELEASE_APP}" ]]; then
  echo "Error: ${RELEASE_APP} does not exist. Run 'flutter build macos --release --no-tree-shake-icons' first." >&2
  exit 1
fi

if [[ ! -f "${BACKGROUND_PNG}" ]]; then
  echo "Generating DMG background image..."
  swift "${SCRIPT_DIR}/generate_dmg_background.swift"
fi

echo "Staging clean bundle for DMG..."
STAGING_DIR="$(mktemp -d -t fima_dmg_staging.XXXXXX)"
cleanup() {
  rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT INT TERM

# Copy ONLY the fima.app into staging (no intermediate .o, .dSYM, or build artifacts)
cp -R "${RELEASE_APP}" "${STAGING_DIR}/"

echo "Building clean DMG at ${DMG_OUTPUT}..."
rm -f "${DMG_OUTPUT}"

create-dmg \
  --volname "Fima" \
  --volicon "${VOLICON}" \
  --background "${BACKGROUND_PNG}" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 110 \
  --text-size 12 \
  --icon "fima.app" 175 195 \
  --hide-extension "fima.app" \
  --app-drop-link 485 195 \
  --no-internet-enable \
  --overwrite \
  "${DMG_OUTPUT}" \
  "${STAGING_DIR}/"

if [[ "$(basename "${DMG_OUTPUT}")" != "fima.dmg" ]]; then
  ln -sf "$(basename "${DMG_OUTPUT}")" "${ROOT_DIR}/fima.dmg"
fi

echo "Successfully created clean DMG: ${DMG_OUTPUT}"
