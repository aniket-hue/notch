#!/bin/bash
# Build OpenNook.app from the Swift package, assemble the app bundle, ad-hoc
# sign it, and (optionally) launch it.
#
#   ./build.sh         build + assemble + sign
#   ./build.sh run     ...and then (re)launch the app
#
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="OpenNook"
CONFIG="release"
RES="Sources/OpenNook/Resources"
BUILD_DIR=".build/${CONFIG}"
APP="${APP_NAME}.app"

echo "▶︎ Compiling (${CONFIG})…"
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)/${APP_NAME}"

echo "▶︎ Assembling ${APP}…"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS"
mkdir -p "${APP}/Contents/Resources"

cp "${BIN_PATH}" "${APP}/Contents/MacOS/${APP_NAME}"
cp "${RES}/Info.plist" "${APP}/Contents/Info.plist"

# Copy any bundled runtime resources (Now Playing adapter, etc.) if present.
if [ -d "${RES}/Adapter" ]; then
    cp -R "${RES}/Adapter/." "${APP}/Contents/Resources/"
fi

echo "▶︎ Ad-hoc signing…"
codesign --force --deep \
    --sign - \
    --entitlements "${RES}/OpenNook.entitlements" \
    --options runtime \
    "${APP}" >/dev/null 2>&1 || \
codesign --force --deep --sign - "${APP}"   # fallback without hardened runtime

echo "✓ Built ${APP}"

if [ "${1:-}" == "run" ]; then
    echo "▶︎ Relaunching…"
    pkill -x "${APP_NAME}" 2>/dev/null || true
    sleep 0.3
    open "${APP}"
    echo "✓ Launched. Look at your notch; the OpenNook icon is in the menu bar."
fi
