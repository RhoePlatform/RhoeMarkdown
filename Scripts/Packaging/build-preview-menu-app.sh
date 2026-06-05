#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

CONFIGURATION="${RHOE_PREVIEW_MENU_CONFIGURATION:-release}"
APP_NAME="RhoeMarkdown Preview"
APP_DIR="${RHOE_PREVIEW_MENU_APP_DIR:-${ROOT_DIR}/.build/${APP_NAME}.app}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
EXECUTABLE_DIR="${ROOT_DIR}/.build/${CONFIGURATION}"

echo "==> Building rhoemd and rhoemd-preview-menu (${CONFIGURATION})"
swift build -c "${CONFIGURATION}" --product rhoemd
swift build -c "${CONFIGURATION}" --product rhoemd-preview-menu

echo "==> Assembling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${EXECUTABLE_DIR}/rhoemd-preview-menu" "${MACOS_DIR}/rhoemd-preview-menu"
cp "${EXECUTABLE_DIR}/rhoemd" "${MACOS_DIR}/rhoemd"
chmod +x "${MACOS_DIR}/rhoemd-preview-menu" "${MACOS_DIR}/rhoemd"

cat > "${CONTENTS_DIR}/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>RhoeMarkdown Preview</string>
  <key>CFBundleExecutable</key>
  <string>rhoemd-preview-menu</string>
  <key>CFBundleIdentifier</key>
  <string>dev.rhoe.rhoemarkdown.preview</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>RhoeMarkdown Preview</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.1</string>
  <key>CFBundleVersion</key>
  <string>0.1.1</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

cat > "${RESOURCES_DIR}/README.txt" <<'TEXT'
RhoeMarkdown Preview is an unsigned macOS 26 menu bar extra bundle assembled
from SwiftPM release binaries. Signed and notarized distribution is deferred to
the release packaging lane.
TEXT

echo "Preview menu app bundle ready: ${APP_DIR}"
