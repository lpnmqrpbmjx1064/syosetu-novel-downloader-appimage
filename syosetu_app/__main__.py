#!/usr/bin/env python3
"""Entry point — GUI by default, CLI via download subcommand."""

import sys
import argparse


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

    # GUI subcommand (explicit)
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
    import asyncio
    import os
    from syosetu_app.syosetu import Syosetu

    async def do_download():
        syosetu = Syosetu(args.novel_id, args.proxy)
        await syosetu.async_init()
        syosetu.record_chapter_index = args.record_chapter_number
        await syosetu.async_download(args.output_dir)
        await syosetu.async_close()

        if args.save_format == "epub":
            from syosetu_app.converters import convert_directory_txt_to_epub
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
