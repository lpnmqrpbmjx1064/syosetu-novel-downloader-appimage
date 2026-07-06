# syosetu-novel-downloader AppImage

[![Fork](https://img.shields.io/badge/fork-ShiinaRinne/syosetu__novel__downloader-blue)](https://github.com/ShiinaRinne/syosetu_novel_downloader)

**Fork of [syosetu_novel_downloader](https://github.com/ShiinaRinne/syosetu_novel_downloader)** — packaged as a self-contained AppImage for Linux.

> Upstream: [github.com/ShiinaRinne/syosetu_novel_downloader](https://github.com/ShiinaRinne/syosetu_novel_downloader) — MIT

## LLM Disclosure

This packaging (build scripts, README, config) was produced with the assistance of an AI language model. The upstream source code patches are documented below.

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

This repo maintains a set of patches on top of the upstream source via `patch_syosetu.py`, applied during the AppImage build. Current patches:

| # | Patch | Purpose |
|---|-------|---------|
| 1 | **Relative imports** | `from custom_typing import` → `from .custom_typing import` for module packaging |
| 2 | **HTML selector update** | Chapter list selector changed from `<dd>` to `div.p-eplist__sublist` (upstream's selector no longer matches shosetsu-ts' current HTML) |
| 3 | **Filename sanitization** | Novel titles with `/` (e.g. `4/18`) are replaced with fullwidth solidus `／` so they work as directory/file names |
| 4 | **Wayland fix** | Sets `QT_QPA_PLATFORM=wayland;xcb` fallback chain for Wayland-only environments (Bazzite, Fedora KDE) |
| 5 | **Pagination fix** | Syosetu paginates chapter lists at 100 per page. The fix fetches all remaining pages (`?p=2`, `?p=3`, …) and merges them into a flat chapter list so novels with >100 chapters download completely |

### Patch Application

Patches are applied automatically by `build.sh`:
```bash
python3 patch_syosetu.py usr/lib/python3.12/site-packages/syosetu_app/syosetu.py
```

To see the exact diff from upstream:
```bash
diff -u <(git show upstream:syosetu/syosetu.py) <(python3 patch_syosetu.py syosetu.py && cat syosetu.py)
```

## Download

Get the latest build from the [Releases](https://github.com/lpnmqrpbmjx1064/syosetu-novel-downloader-appimage/releases) page.
