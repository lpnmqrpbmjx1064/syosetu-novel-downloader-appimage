#!/usr/bin/env python3
"""PyQt6 GUI wrapper for syosetu_novel_downloader."""

import sys
import os
import asyncio
from pathlib import Path

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QLineEdit, QPushButton, QComboBox, QCheckBox,
    QTextEdit, QFileDialog, QGroupBox, QFormLayout, QMessageBox,
    QProgressBar, QStatusBar
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal


class DownloadWorker(QThread):
    """Runs the download in a background thread."""
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
            self.log.emit(f"Starting download of novel: {self.novel_id}")
            self.log.emit(f"Output: {self.output_dir}")
            self.log.emit(f"Format: {self.save_format}")
            if self.proxy:
                self.log.emit(f"Proxy: {self.proxy}")

            async def do_download():
                from syosetu_app.syosetu import Syosetu
                syosetu = Syosetu(self.novel_id, self.proxy)
                await syosetu.async_init()
                syosetu.record_chapter_index = self.record_chapter
                self.log.emit(f"Title: {syosetu.novel_title}")
                self.log.emit("Downloading chapters...")
                await syosetu.async_download(self.output_dir)
                await syosetu.async_close()

                if self.save_format == "epub":
                    self.log.emit("Converting to EPUB...")
                    from syosetu_app.converters import convert_directory_txt_to_epub
                    novel_dir = os.path.join(self.output_dir, syosetu.novel_title)
                    if os.path.isdir(novel_dir):
                        convert_directory_txt_to_epub(novel_dir)
                    else:
                        convert_directory_txt_to_epub(self.output_dir, syosetu.novel_title)
                    self.log.emit("EPUB conversion done.")

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

        # Input group
        input_group = QGroupBox("Novel Settings")
        form = QFormLayout(input_group)

        self.novel_id_input = QLineEdit()
        self.novel_id_input.setPlaceholderText("e.g. n4350im")
        form.addRow("Novel ID:", self.novel_id_input)

        self.proxy_input = QLineEdit()
        self.proxy_input.setPlaceholderText("e.g. http://localhost:10809 (optional)")
        form.addRow("Proxy:", self.proxy_input)

        # Output directory
        out_layout = QHBoxLayout()
        default_out = str(Path.home() / "Downloads" / "syosetu")
        self.output_dir_input = QLineEdit(default_out)
        out_layout.addWidget(self.output_dir_input)
        browse_btn = QPushButton("Browse...")
        browse_btn.clicked.connect(self._browse_output)
        out_layout.addWidget(browse_btn)
        form.addRow("Output:", out_layout)

        # Save format
        self.format_combo = QComboBox()
        self.format_combo.addItems(["txt", "epub"])
        form.addRow("Save Format:", self.format_combo)

        # Record chapter number
        self.record_chk = QCheckBox("Record chapter numbers")
        form.addRow("", self.record_chk)

        layout.addWidget(input_group)

        # Download button
        self.dl_btn = QPushButton("Download")
        self.dl_btn.clicked.connect(self._start_download)
        self.dl_btn.setStyleSheet("""
            QPushButton {
                background-color: #4a90d9;
                color: white;
                font-size: 14px;
                padding: 8px;
                border-radius: 4px;
            }
            QPushButton:disabled {
                background-color: #888;
            }
        """)
        layout.addWidget(self.dl_btn)

        # Progress bar
        self.progress = QProgressBar()
        self.progress.setVisible(False)
        layout.addWidget(self.progress)

        # Log output
        log_group = QGroupBox("Log")
        log_layout = QVBoxLayout(log_group)
        self.log_output = QTextEdit()
        self.log_output.setReadOnly(True)
        self.log_output.setStyleSheet("font-family: monospace; font-size: 9pt;")
        log_layout.addWidget(self.log_output)
        layout.addWidget(log_group, stretch=1)

        # Status bar
        self.status = QStatusBar()
        self.setStatusBar(self.status)
        self.status.showMessage("Ready")

    def _browse_output(self):
        path = QFileDialog.getExistingDirectory(
            self, "Select Output Directory", self.output_dir_input.text()
        )
        if path:
            self.output_dir_input.setText(path)

    def _start_download(self):
        novel_id = self.novel_id_input.text().strip()
        if not novel_id:
            QMessageBox.warning(self, "Missing Input", "Please enter a Novel ID.")
            return

        proxy = self.proxy_input.text().strip()
        output_dir = self.output_dir_input.text().strip()
        save_format = self.format_combo.currentText()
        record_chapter = self.record_chk.isChecked()

        if not output_dir:
            output_dir = str(Path.home() / "Downloads" / "syosetu")

        self.dl_btn.setEnabled(False)
        self.dl_btn.setText("Downloading...")
        self.log_output.clear()
        self.progress.setVisible(True)
        self.progress.setRange(0, 0)

        self.worker = DownloadWorker(
            novel_id, proxy, output_dir, save_format, record_chapter
        )
        self.worker.log.connect(self._append_log)
        self.worker.finished.connect(self._on_finished)
        self.worker.start()

    def _append_log(self, text):
        self.log_output.append(text)

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
