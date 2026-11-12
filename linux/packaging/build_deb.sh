#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

VERSION=$(grep -m1 '^version:' "${ROOT_DIR}/pubspec.yaml" | sed -E 's/version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
DEB_OUTPUT="${1:-${ROOT_DIR}/fima-${VERSION}.deb}"
BUNDLE_DIR="${ROOT_DIR}/build/linux/x64/release/bundle"

if [[ ! -d "${BUNDLE_DIR}" ]]; then
  echo "Error: ${BUNDLE_DIR} does not exist. Run 'flutter build linux --release --no-tree-shake-icons' first." >&2
  exit 1
fi

STAGE_DIR="$(mktemp -d -t fima_deb_staging.XXXXXX)"
cleanup() {
  rm -rf "${STAGE_DIR}"
}
trap cleanup EXIT INT TERM

PKG_DIR="${STAGE_DIR}/fima_${VERSION}_amd64"
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}/usr/lib/fima"
mkdir -p "${PKG_DIR}/usr/bin"
mkdir -p "${PKG_DIR}/usr/share/applications"
mkdir -p "${PKG_DIR}/usr/share/icons/hicolor/512x512/apps"

cp -r "${BUNDLE_DIR}/." "${PKG_DIR}/usr/lib/fima/"
ln -s /usr/lib/fima/fima "${PKG_DIR}/usr/bin/fima"
cp "${SCRIPT_DIR}/sk.spajdo.fima.desktop" "${PKG_DIR}/usr/share/applications/"
cp "${ROOT_DIR}/assets/icons/fima_icon_light.png" "${PKG_DIR}/usr/share/icons/hicolor/512x512/apps/fima.png"

# Copy control template and dynamically set Version from pubspec.yaml
cp "${SCRIPT_DIR}/control" "${PKG_DIR}/DEBIAN/control"
sed -i "s/^Version:.*/Version: ${VERSION}/" "${PKG_DIR}/DEBIAN/control"

chmod 755 "${PKG_DIR}/usr/lib/fima/fima"

dpkg-deb --build "${PKG_DIR}"
mv "${STAGE_DIR}/fima_${VERSION}_amd64.deb" "${DEB_OUTPUT}"

echo "Successfully created Debian package: ${DEB_OUTPUT}"

