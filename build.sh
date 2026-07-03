#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# syosetu-novel-downloader AppImage builder
# Repo: https://github.com/lpnmqrpbmjx1064/syosetu-novel-downloader-appimage
# Upstream: https://github.com/ShiinaRinne/syosetu_novel_downloader (MIT)
#
# DETERMINISTIC BUILD — all versions pinned. Same input → same output.
# =============================================================================

BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(mktemp -d)"

# ---- PINS ----
PYTHON_RELEASE_TAG="20260623"
PYTHON_VER="3.12.13"
UPSTREAM_COMMIT="916cb27c7faed6badbe567f6690b00842926e64e"
APPIMAGETOOL_SHA256="a6d71e2b6cd66f8e8d16c37ad164658985e0cf5fcaa950c90a482890cb9d13e0"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
APP_NAME="syosetu-novel-downloader"
APPIMAGE_NAME="${APP_NAME}-x86_64.AppImage"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

echo "=== Step 1: Download python-build-standalone ==="
cd "$WORK_DIR"
wget -q --show-progress \
  "https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_RELEASE_TAG}/cpython-${PYTHON_VER}+${PYTHON_RELEASE_TAG}-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"
tar -xzf "cpython-${PYTHON_VER}+${PYTHON_RELEASE_TAG}-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"
mv python/* . && rmdir python

echo "=== Step 2: Install pinned dependencies ==="
./bin/python3 -m pip install pip --upgrade -q
./bin/python3 -m pip install --target=./lib/python3.12/site-packages \
  --requirement="${BUILD_DIR}/requirements.txt" -q

echo "=== Step 3: Verify imports ==="
./bin/python3 -c "
import aiohttp, bs4, lxml, PyQt6
from PyQt6.QtWidgets import QApplication
print('All imports OK')
"

echo "=== Step 4: Clone upstream at pinned commit ==="
git clone https://github.com/ShiinaRinne/syosetu_novel_downloader.git upstream
cd upstream
git checkout "${UPSTREAM_COMMIT}"
cd ..

echo "=== Step 4b: Build syosetu_app module ==="
SITE_PKG="lib/python3.12/site-packages"
MODULE="${SITE_PKG}/syosetu_app"
mkdir -p "${MODULE}/converters"

# Copy upstream files into the module
cp upstream/syosetu.py "${MODULE}/"
cp upstream/mian.py "${MODULE}/"
cp upstream/custom_typing.py "${MODULE}/"
cp upstream/LICENSE "${MODULE}/"

# Patch syosetu.py: relative imports, HTML selector fix, _sanitize
python3 "${BUILD_DIR}/patch_syosetu.py" "${MODULE}/syosetu.py"

# Fix mian.py import: from syosetu → from .syosetu
sed -i 's/^from syosetu import/from .syosetu import/' "${MODULE}/mian.py"

# Copy converters
cp upstream/converters/__init__.py "${MODULE}/converters/"
cp upstream/converters/txt2epub.py "${MODULE}/converters/"

# Create __init__.py
cat > "${MODULE}/__init__.py" << 'INIT'
"""syosetu-novel-downloader — download Japanese novels from syosetu.com."""
from .syosetu import Syosetu, SaveFormat
from .mian import main as cli_main
INIT

# Create __main__.py — entry point with GUI default + CLI download subcommand
cat > "${MODULE}/__main__.py" << 'MAIN'
#!/usr/bin/env python3
"""Entry point — GUI by default, CLI via download subcommand."""
import sys, argparse, asyncio, os

def main():
    parser = argparse.ArgumentParser(
        prog="syosetu-novel-downloader",
        description="Download Japanese novels from syosetu.com",
    )
    subparsers = parser.add_subparsers(dest="command", help="Subcommands")
    dl = subparsers.add_parser("download", help="Download a novel from CLI")
    dl.add_argument("--novel_id", required=True, help="Novel ID (e.g. n4350im)")
    dl.add_argument("--save-format", default="txt", choices=["txt", "epub"])
    dl.add_argument("--proxy", default="", help="HTTP proxy (e.g. http://localhost:10809)")
    dl.add_argument("--output-dir", default="./downloads", help="Output directory")
    dl.add_argument("--record-chapter-number", action="store_true",
                    help="Record chapter numbers in output")
    subparsers.add_parser("gui", help="Launch the GUI")
    args = parser.parse_args()

    if args.command == "download":
        return run_cli(args)
    elif args.command == "gui" or args.command is None:
        return launch_gui()
    else:
        parser.print_help()
        return 1

def run_cli(args):
    from syosetu_app.syosetu import Syosetu
    from syosetu_app.converters import convert_directory_txt_to_epub
    async def do_download():
        syosetu = Syosetu(args.novel_id, args.proxy)
        await syosetu.async_init()
        syosetu.record_chapter_index = args.record_chapter_number
        await syosetu.async_download(args.output_dir)
        await syosetu.async_close()
        if args.save_format == "epub":
            novel_dir = os.path.join(args.output_dir, syosetu.novel_title)
            if os.path.isdir(novel_dir):
                convert_directory_txt_to_epub(novel_dir)
            else:
                convert_directory_txt_to_epub(args.output_dir, syosetu.novel_title)
        print(f"Done. Saved to {os.path.join(args.output_dir, syosetu.novel_title)}")
    asyncio.run(do_download())
    return 0

def launch_gui():
    from syosetu_app.gui import launch_gui as _gui
    return _gui()

if __name__ == "__main__":
    sys.exit(main())
MAIN

# Create gui.py — PyQt6 GUI wrapper
cat > "${MODULE}/gui.py" << 'GUI'
#!/usr/bin/env python3
"""PyQt6 GUI wrapper for syosetu_novel_downloader."""
import sys, os, asyncio
from pathlib import Path
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QLineEdit, QPushButton, QComboBox, QCheckBox,
    QTextEdit, QFileDialog, QGroupBox, QFormLayout, QMessageBox,
    QProgressBar, QStatusBar
)
from PyQt6.QtCore import QThread, pyqtSignal

class DownloadWorker(QThread):
    log = pyqtSignal(str)
    finished = pyqtSignal(bool, str)
    def __init__(self, novel_id, proxy, output_dir, save_format, record_chapter):
        super().__init__()
        self.novel_id = novel_id
        self.proxy = proxy
        self.output_dir = output_dir
        self.save_format = save_format
        self.record_chapter = record_chapter
    def run(self):
        try:
            from syosetu_app.syosetu import Syosetu
            from syosetu_app.converters import convert_directory_txt_to_epub
            self.log.emit(f"Starting download of novel: {self.novel_id}")
            async def do_download():
                syosetu = Syosetu(self.novel_id, self.proxy)
                await syosetu.async_init()
                syosetu.record_chapter_index = self.record_chapter
                self.log.emit(f"Title: {syosetu.novel_title}")
                await syosetu.async_download(self.output_dir)
                await syosetu.async_close()
                if self.save_format == "epub":
                    self.log.emit("Converting to EPUB...")
                    novel_dir = os.path.join(self.output_dir, syosetu.novel_title)
                    if os.path.isdir(novel_dir):
                        convert_directory_txt_to_epub(novel_dir)
                    else:
                        convert_directory_txt_to_epub(self.output_dir, syosetu.novel_title)
                self.log.emit("Download complete!")
                return True, "Download finished successfully."
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            success, msg = loop.run_until_complete(do_download())
            loop.close()
            self.finished.emit(success, msg)
        except Exception as e:
            import traceback
            self.log.emit(f"ERROR: {e}")
            self.log.emit(traceback.format_exc())
            self.finished.emit(False, str(e))

class SyosetuGUI(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Syosetu Novel Downloader")
        self.setMinimumSize(620, 520)
        self.worker = None
        self._setup_ui()
    def _setup_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        input_group = QGroupBox("Novel Settings")
        form = QFormLayout(input_group)
        self.novel_id_input = QLineEdit()
        self.novel_id_input.setPlaceholderText("e.g. n4350im")
        form.addRow("Novel ID:", self.novel_id_input)
        self.proxy_input = QLineEdit()
        self.proxy_input.setPlaceholderText("e.g. http://localhost:10809 (optional)")
        form.addRow("Proxy:", self.proxy_input)
        out_layout = QHBoxLayout()
        default_out = str(Path.home() / "Downloads" / "syosetu")
        self.output_dir_input = QLineEdit(default_out)
        out_layout.addWidget(self.output_dir_input)
        browse_btn = QPushButton("Browse...")
        browse_btn.clicked.connect(self._browse_output)
        out_layout.addWidget(browse_btn)
        form.addRow("Output:", out_layout)
        self.format_combo = QComboBox()
        self.format_combo.addItems(["txt", "epub"])
        form.addRow("Save Format:", self.format_combo)
        self.record_chk = QCheckBox("Record chapter numbers")
        form.addRow("", self.record_chk)
        layout.addWidget(input_group)
        self.dl_btn = QPushButton("Download")
        self.dl_btn.clicked.connect(self._start_download)
        self.dl_btn.setStyleSheet(
            "QPushButton{background-color:#4a90d9;color:white;font-size:14px;padding:8px;border-radius:4px}"
            "QPushButton:disabled{background-color:#888}"
        )
        layout.addWidget(self.dl_btn)
        self.progress = QProgressBar()
        self.progress.setVisible(False)
        layout.addWidget(self.progress)
        log_group = QGroupBox("Log")
        log_layout = QVBoxLayout(log_group)
        self.log_output = QTextEdit()
        self.log_output.setReadOnly(True)
        self.log_output.setStyleSheet("font-family:monospace;font-size:9pt")
        log_layout.addWidget(self.log_output)
        layout.addWidget(log_group, stretch=1)
        self.status = QStatusBar()
        self.setStatusBar(self.status)
        self.status.showMessage("Ready")
    def _browse_output(self):
        path = QFileDialog.getExistingDirectory(self, "Select Output Directory", self.output_dir_input.text())
        if path:
            self.output_dir_input.setText(path)
    def _start_download(self):
        novel_id = self.novel_id_input.text().strip()
        if not novel_id:
            QMessageBox.warning(self, "Missing Input", "Please enter a Novel ID.")
            return
        self.dl_btn.setEnabled(False)
        self.dl_btn.setText("Downloading...")
        self.log_output.clear()
        self.progress.setVisible(True)
        self.progress.setRange(0, 0)
        self.worker = DownloadWorker(
            novel_id, self.proxy_input.text().strip(),
            self.output_dir_input.text().strip() or str(Path.home() / "Downloads" / "syosetu"),
            self.format_combo.currentText(), self.record_chk.isChecked()
        )
        self.worker.log.connect(self.log_output.append)
        self.worker.finished.connect(self._on_finished)
        self.worker.start()
    def _on_finished(self, success, msg):
        self.progress.setVisible(False)
        self.dl_btn.setEnabled(True)
        self.dl_btn.setText("Download")
        self.status.showMessage(msg)
        if success:
            QMessageBox.information(self, "Success", msg)
        else:
            QMessageBox.critical(self, "Error", f"Download failed:\n{msg}")
    def closeEvent(self, event):
        if self.worker and self.worker.isRunning():
            self.worker.quit()
            self.worker.wait()
        event.accept()

def launch_gui():
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    window = SyosetuGUI()
    window.show()
    return app.exec()

if __name__ == "__main__":
    sys.exit(launch_gui())
GUI

echo "=== Step 5: Fix pip shebangs ==="
for script in ./bin/syosetu* ./bin/syosetu_novel_downloader; do
  [ -f "$script" ] || continue
  cat > "$script" << 'SCRIPT'
#!/bin/sh
APPDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
export PYTHONHOME="${APPDIR}"
export PYTHONNOUSERSITE=1
exec "${APPDIR}/bin/python3" -m syosetu_app "$@"
SCRIPT
done 2>/dev/null

echo "=== Step 6: Build AppDir ==="
mkdir -p AppDir/usr
cp -r ./* AppDir/usr/ 2>/dev/null || true
rm -rf AppDir/usr/AppDir 2>/dev/null || true

# AppRun
cat > AppDir/AppRun << 'APPRUN'
#!/bin/bash
APPDIR="$(dirname "$(readlink -f "$0")")"
export PYTHONHOME="${APPDIR}/usr"
export PYTHONNOUSERSITE=1
export PATH="${APPDIR}/usr/bin:${PATH}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
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

# Icon
python3 -c "
from PIL import Image, ImageDraw
img = Image.new('RGBA', (256, 256), (52, 102, 153, 255))
draw = ImageDraw.Draw(img)
draw.rectangle([10, 10, 246, 246], outline='white', width=4)
img.save('AppDir/syosetu.png', 'PNG')
"
ln -sf syosetu.png AppDir/.DirIcon

echo "=== Step 7: Download appimagetool (sha256 verified) ==="
if [ ! -f appimagetool ]; then
  wget -q -O aitool.AppImage "${APPIMAGETOOL_URL}"
  echo "${APPIMAGETOOL_SHA256}  aitool.AppImage" | sha256sum --check
  chmod +x aitool.AppImage
  ./aitool.AppImage --appimage-extract >/dev/null 2>&1
  mv squashfs-root/usr/bin/appimagetool appimagetool
  rm -rf squashfs-root aitool.AppImage
fi

echo "=== Step 8: Build AppImage ==="
./appimagetool AppDir/ "${APPIMAGE_NAME}" -g 2>&1

echo "=== Step 9: Verify ==="
if ./"${APPIMAGE_NAME}" --appimage-extract-and-run --help 2>&1 | head -10; then
    echo "--- appimagetool verification passed ---"
else
    echo "--- No FUSE2 available, using --appimage-extract instead ---"
    ./"${APPIMAGE_NAME}" --appimage-extract >/dev/null 2>&1
    if [ -f squashfs-root/AppRun ]; then
        echo "--- Extraction OK — AppImage is valid ---"
        rm -rf squashfs-root
    fi
fi
echo "---"
ls -lh "${APPIMAGE_NAME}"
sha256sum "${APPIMAGE_NAME}"

cp "${APPIMAGE_NAME}" "${BUILD_DIR}/${APPIMAGE_NAME}"
echo "=== DONE: ${BUILD_DIR}/${APPIMAGE_NAME} ==="
