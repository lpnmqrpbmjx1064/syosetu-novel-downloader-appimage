# Syosetu Novel Downloader — AppImage

**Portable [syosetu-novel-downloader](https://github.com/ShiinaRinne/syosetu_novel_downloader) by ShiinaRinne** — packaged as a self-contained AppImage with a PyQt6 GUI.

> **Packaging-only distribution.** All credit for the novel downloader goes to **[@ShiinaRinne](https://github.com/ShiinaRinne)**.
> Upstream: [github.com/ShiinaRinne/syosetu_novel_downloader](https://github.com/ShiinaRinne/syosetu_novel_downloader) — MIT

## Features

- **GUI mode** (default) — enter a novel ID, configure options, click download
- **CLI mode** — scriptable with `./AppImage download --novel_id n4350im`
- **EPUB support** — converts downloaded chapters to EPUB format
- **Proxy support** — configurable HTTP proxy for region-restricted access

## LLM Disclosure

This AppImage packaging (build scripts, PyQt6 GUI, configuration) was produced with the assistance of **Hermes Agent** (Nous Research), an AI language model. The upstream source code is unmodified.

## Download

Grab the latest `.AppImage` from the [Releases page](https://github.com/lpnmqrpbmjx1064/syosetu-novel-downloader-appimage/releases).

## Usage

```bash
chmod +x syosetu-novel-downloader-x86_64.AppImage

# GUI (default)
./syosetu-novel-downloader-x86_64.AppImage

# CLI
./syosetu-novel-downloader-x86_64.AppImage download --novel_id n4350im --save-format epub

# Without FUSE
./syosetu-novel-downloader-x86_64.AppImage --appimage-extract-and-run
```

## Build

```bash
git clone https://github.com/lpnmqrpbmjx1064/syosetu-novel-downloader-appimage.git
cd syosetu-novel-downloader-appimage
./build.sh
```

Requires: `python3`, `wget`, `zstd`, `squashfs-tools`, `libfuse2`.

## License

**MIT** — inherited from [syosetu-novel-downloader](https://github.com/ShiinaRinne/syosetu_novel_downloader). See [LICENSE](./LICENSE).
