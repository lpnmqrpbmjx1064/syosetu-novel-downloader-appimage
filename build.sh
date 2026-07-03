#!/usr/bin/env bash
set -euo pipefail

# Build syosetu-novel-downloader AppImage
# Requires: python3, wget, zstd, squashfs-tools, libfuse2

PACKAGE="syosetu-novel-downloader"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT="$SCRIPT_DIR/${PACKAGE}-x86_64.AppImage"

echo "==> Setting up"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "==> Downloading python-build-standalone"
PYTHON_TAG="20260623"
wget -q "https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_TAG}/cpython-3.12.13+${PYTHON_TAG}-x86_64-unknown-linux-gnu-pgo+lto-full.tar.zst"
tar -I zstd -xf "cpython-3.12.13+${PYTHON_TAG}-x86_64-unknown-linux-gnu-pgo+lto-full.tar.zst"
mv install/* . && rmdir install
rm -f "cpython-3.12.13+${PYTHON_TAG}-x86_64-unknown-linux-gnu-pgo+lto-full.tar.zst"

echo "==> Installing dependencies"
./bin/python3 -m pip install pip --upgrade -q
./bin/python3 -m pip install \
    --target=./lib/python3.12/site-packages \
    aiofiles aiohttp beautifulsoup4 EbookLib pydantic deprecated PyQt6 -q

echo "==> Verifying all deps bundled"
./bin/python3 -c "
import aiohttp, bs4, ebooklib, pydantic, deprecated, aiofiles, PyQt6
print('All deps verified OK')
"

echo "==> Installing application package"
cp -r "$SCRIPT_DIR/syosetu_app" ./lib/python3.12/site-packages/syosetu_app
./bin/python3 -c "from syosetu_app import Syosetu; from syosetu_app.gui import launch_gui; print('Package OK')"

echo "==> Fixing pip scripts"
for script in ./bin/*; do
    head -1 "$script" | grep -q "build/" || continue
    cat > "$script" << 'SCRIPT'
#!/bin/sh
APPDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
export PYTHONHOME="${APPDIR}"
export PYTHONNOUSERSITE=1
exec "${APPDIR}/bin/python3" -m syosetu_app "$@"
SCRIPT
done

echo "==> Building AppImage"
cd "$SCRIPT_DIR"
rm -rf AppDir
mkdir -p AppDir/usr
cp -r build/* AppDir/usr/

cat > AppDir/AppRun << 'RUNEOF'
#!/bin/bash
APPDIR="$(dirname "$(readlink -f "$0")")"
export PYTHONHOME="${APPDIR}/usr"
export PYTHONNOUSERSITE=1
export PATH="${APPDIR}/usr/bin:${PATH}"
exec "${APPDIR}/usr/bin/python3" -m syosetu_app "$@"
RUNEOF
chmod +x AppDir/AppRun

cat > AppDir/syosetu.desktop << 'DESKEOF'
[Desktop Entry]
Name=Syosetu Novel Downloader
Comment=Download Japanese novels from syosetu.com
Exec=syosetu
Icon=syosetu
Terminal=false
Type=Application
Categories=Office;TextTools;
StartupNotify=true
DESKEOF

echo "==> Downloading appimagetool"
[ -f appimagetool ] || wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O appimagetool
chmod +x appimagetool
[ -d squashfs-root ] || ./appimagetool --appimage-extract > /dev/null 2>&1
./squashfs-root/AppRun AppDir/ "$OUTPUT"

echo "==> Done!"
ls -lh "$OUTPUT"
