# syosetu-novel-downloader AppImage

**Portable [syosetu_novel_downloader](https://github.com/ShiinaRinne/syosetu_novel_downloader)** — packaged as a self-contained AppImage for Linux.

> **Packaging-only.** All credit goes to **ShiinaRinne**.
> Upstream: [github.com/ShiinaRinne/syosetu_novel_downloader](https://github.com/ShiinaRinne/syosetu_novel_downloader) — MIT

## LLM Disclosure

This packaging (build scripts, README, config) was produced with the assistance of an AI language model. The upstream source code is unmodified.

## Usage

```bash
# GUI (default — just run it)
./syosetu-novel-downloader-x86_64.AppImage

# CLI download
./syosetu-novel-downloader-x86_64.AppImage download --novel_id n1234ab --save-format epub

# On FUSE3-only systems (Fedora, Bazzite, Silverblue):
./syosetu-novel-downloader-x86_64.AppImage --appimage-extract-and-run
```

## Build

```bash
chmod +x build.sh
./build.sh
```

Requires: `wget`, `zstd`, `python3`, `git`, `Pillow` (`pip install Pillow`), `squashfs-tools`.

Output: `syosetu-novel-downloader-x86_64.AppImage`

## Changes from Upstream

- **GUI wrapper**: PyQt6 frontend wrapping the CLI tool's options
- **Filename sanitization**: Novel titles with `/` (e.g. `4/18`) are handled correctly
- **Wayland fix**: Sets `QT_QPA_PLATFORM=wayland` for Wayland-only environments (Bazzite, Fedora KDE)
- **CLI & GUI**: Both modes preserved — `download` subcommand for CLI, bare invocation for GUI

## Download

Get the latest build from the [Releases](https://github.com/lpnmqrpbmjx1064/syosetu-novel-downloader-appimage/releases) page.
