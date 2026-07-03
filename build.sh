#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# syosetu-novel-downloader AppImage builder
# Repo: https://github.com/lpnmqrpbmjx1064/syosetu-novel-downloader-appimage
# Upstream: https://github.com/ShiinaRinne/syosetu_novel_downloader (MIT)
# =============================================================================

BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(mktemp -d)"
RELEASE_TAG="20260623"
PYTHON_VER="3.12.13"
APP_NAME="syosetu-novel-downloader"
APPIMAGE_NAME="${APP_NAME}-x86_64.AppImage"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

echo "=== Step 1: Download python-build-standalone (full stdlib) ==="
cd "$WORK_DIR"
wget -q --show-progress \
  "https://github.com/astral-sh/python-build-standalone/releases/download/${RELEASE_TAG}/cpython-${PYTHON_VER}+${RELEASE_TAG}-x86_64-unknown-linux-gnu-install_only_stripped.tar.zst"
tar -I zstd -xf "cpython-${PYTHON_VER}+${RELEASE_TAG}-x86_64-unknown-linux-gnu-install_only_stripped.tar.zst"
mv install/* . && rmdir install

echo "=== Step 2: Install dependencies ==="
./bin/python3 -m pip install pip --upgrade -q
./bin/python3 -m pip install --target=./lib/python3.12/site-packages \
  aiohttp \
  beautifulsoup4 \
  lxml \
  PyQt6 \
  -q

echo "=== Step 3: Verify imports ==="
./bin/python3 -c "
import aiohttp, bs4, lxml, PyQt6
from PyQt6.QtWidgets import QApplication
print('All imports OK')
"

echo "=== Step 4: Clone upstream & install app ==="
git clone --depth 1 https://github.com/ShiinaRinne/syosetu_novel_downloader.git upstream
./bin/python3 -m pip install --target=./lib/python3.12/site-packages ./upstream -q

echo "=== Step 5: Fix pip shebangs ==="
for script in ./bin/syosetu* ./bin/syosetu_novel_downloader 2>/dev/null; do
  [ -f "$script" ] || continue
  cat > "$script" << 'SCRIPT'
#!/bin/sh
APPDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
export PYTHONHOME="${APPDIR}"
export PYTHONNOUSERSITE=1
exec "${APPDIR}/bin/python3" -m syosetu_app "$@"
SCRIPT
done

echo "=== Step 6: Build AppDir structure ==="
mkdir -p AppDir/usr
cp -r ./* AppDir/usr/ 2>/dev/null || true
# Don't copy AppDir into itself
rm -rf AppDir/usr/AppDir 2>/dev/null || true

# AppRun — with Wayland env for Bazzite/KDE
cat > AppDir/AppRun << 'APPRUN'
#!/bin/bash
APPDIR="$(dirname "$(readlink -f "$0")")"
export PYTHONHOME="${APPDIR}/usr"
export PYTHONNOUSERSITE=1
export PATH="${APPDIR}/usr/bin:${PATH}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
export XDG_CURRENT_DESKTOP=KDE

exec "${APPDIR}/usr/bin/python3" -m syosetu_app "$@"
APPRUN
chmod +x AppDir/AppRun

# Desktop file
cat > AppDir/syosetu.desktop << 'DESKTOP'
[Desktop Entry]
Name=Syosetu Novel Downloader
Comment=Download Japanese novels from syosetu.com
Exec=syosetu-novel-downloader
Icon=syosetu
Terminal=false
Type=Application
Categories=Office;TextTools;
StartupNotify=true
DESKTOP

# Icon (blue square with "S")
python3 -c "
from PIL import Image, ImageDraw
img = Image.new('RGBA', (256, 256), (52, 102, 153, 255))
draw = ImageDraw.Draw(img)
draw.rectangle([10, 10, 246, 246], outline='white', width=4)
img.save('AppDir/syosetu.png', 'PNG')
"

# .DirIcon symlink
ln -sf syosetu.png AppDir/.DirIcon

echo "=== Step 7: Build AppImage ==="
if [ ! -f appimagetool ]; then
  wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x appimagetool-x86_64.AppImage
  ./appimagetool-x86_64.AppImage --appimage-extract >/dev/null 2>&1
  mv squashfs-root/AppRun appimagetool
  rm -rf squashfs-root appimagetool-x86_64.AppImage
fi

./appimagetool AppDir/ "${APPIMAGE_NAME}" -g 2>&1

echo "=== Step 8: Verify ==="
./"${APPIMAGE_NAME}" --appimage-extract-and-run --help 2>&1 | head -10
echo "---"
ls -lh "${APPIMAGE_NAME}"

# Copy to builds dir
cp "${APPIMAGE_NAME}" "${BUILD_DIR}/${APPIMAGE_NAME}"
echo "=== DONE: ${BUILD_DIR}/${APPIMAGE_NAME} ==="
