#!/usr/bin/env python3
"""Patch syosetu.py for AppImage packaging."""
import sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

# 1. Fix import: from custom_typing → from .custom_typing
content = content.replace("from custom_typing import", "from .custom_typing import")

# 2. Fix __get_chapters_range: <dd> → p-eplist__sublist
content = content.replace(
    'chapters = self.__novel_info_soup.find_all("dd")',
    'chapters = self.__novel_info_soup.find_all("div", class_="p-eplist__sublist")'
)

# 3. Add _sanitize method before __get_novel_title and use it in paths
sanitize = '''    @staticmethod
    def _sanitize(name: str) -> str:
        """Replace path-unsafe characters so they work as file names."""
        return name.replace("/", "\uff0f")

    def __get_novel_title(self) -> NovelTitle:
        return self.__novel_info_soup.find("h1", class_="p-novel__title").text
'''
old_title = '''    def __get_novel_title(self) -> NovelTitle:
        return self.__novel_info_soup.find("h1", class_="p-novel__title").text'''
content = content.replace(old_title, sanitize)

# 4. Use _sanitize in all file path constructions
content = content.replace(
    'os.path.join(output_dir, self.novel_title)',
    'os.path.join(output_dir, self._sanitize(self.novel_title))'
)

with open(path, 'w') as f:
    f.write(content)

print(f"Patched {path}")
