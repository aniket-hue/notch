#!/bin/bash
# Build OpenNook.app from the Swift package, assemble the app bundle, ad-hoc
# sign it, and (optionally) launch it.
#
#   ./build.sh         build + assemble + sign
#   ./build.sh run     ...and then (re)launch the app
#   ./build.sh install ...and copy to /Applications, then launch (best for
#                         "Open at Login", which needs a stable app location)
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

# Bundle the Now Playing media bridge (perl script + framework) into Resources.
if [ -d "Vendor/mediaremote-adapter" ]; then
    cp -R "Vendor/mediaremote-adapter/MediaRemoteAdapter.framework" "${APP}/Contents/Resources/"
    cp "Vendor/mediaremote-adapter/mediaremote-adapter.pl" "${APP}/Contents/Resources/"
fi

echo "▶︎ Ad-hoc signing…"
codesign --force --deep \
    --sign - \
    --entitlements "${RES}/OpenNook.entitlements" \
    --options runtime \
    "${APP}" >/dev/null 2>&1 || \
codesign --force --deep --sign - "${APP}"   # fallback without hardened runtime

echo "✓ Built ${APP}"

if [ "${1:-}" == "install" ]; then
    echo "▶︎ Installing to /Applications…"
    pkill -x "${APP_NAME}" 2>/dev/null || true
    sleep 0.3
    rm -rf "/Applications/${APP}"
    cp -R "${APP}" "/Applications/${APP}"
    open "/Applications/${APP}"
    echo "✓ Installed and launched from /Applications. Toggle 'Open at Login' from the menu-bar icon."
elif [ "${1:-}" == "run" ]; then
    echo "▶︎ Relaunching…"
    pkill -x "${APP_NAME}" 2>/dev/null || true
    sleep 0.3
    open "${APP}"
    echo "✓ Launched. Look at your notch; the OpenNook icon is in the menu bar."
fi
