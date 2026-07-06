#!/usr/bin/env python3
"""Patch syosetu.py for AppImage packaging — v1.1.0."""
import sys, re

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

# 3. Add _sanitize method + insert before __get_novel_title
sanitize = '''    @staticmethod
    def _sanitize(name: str) -> str:
        """Replace path-unsafe characters so they work as file names."""
        return name.replace("/", "\\uff0f")

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

# 5. PAGINATION FIX — fetch all pages of chapter list (syosetu shows 100 per page)
pagination_method = '''
    async def __fetch_remaining_pages(self):
        """Fetch remaining pages of chapter list (syosetu paginates at 100/page)."""
        pager = self.__novel_info_soup.find('div', class_='c-pager')
        if not pager:
            return
        last_link = pager.find('a', class_='c-pager__item--last')
        if not last_link:
            return
        import re as re2
        m = re2.search(r'\\?p=(\\d+)', last_link.get('href', ''))
        if not m:
            return
        total = int(m.group(1))
        if total <= 1:
            return
        # Insert chapter elements from each subsequent page before the pager
        for p in range(2, total + 1):
            async with self.__session.get(
                f"{MAIN_URL}/{self.novel_id}/?p={p}",
                headers=headers, proxy=self.proxy
            ) as resp:
                soup = BeautifulSoup(await resp.text(), "html.parser")
                for tag in soup.find_all(['div'], class_=['p-eplist__chapter-title', 'p-eplist__sublist']):
                    pager.insert_before(tag)
        # Remove the pager now that all chapters are merged
        pager.decompose()
'''
# Insert after async_init's __fetch_novel_info call
old_async_init = '''        self.__novel_info_soup = await self.__fetch_novel_info()
        self.novel_title = self.__get_novel_title()'''
new_async_init = '''        self.__novel_info_soup = await self.__fetch_novel_info()
        await self.__fetch_remaining_pages()
        self.novel_title = self.__get_novel_title()'''
content = content.replace(old_async_init, new_async_init)

# Insert the pagination method before __get_novel_parts
old_parts = '''    async def __get_novel_parts(self) -> dict[NovelTitle, ChapterRange]:'''
content = content.replace(old_parts, pagination_method + old_parts)

with open(path, 'w') as f:
    f.write(content)

print(f"Patched {path} — pagination fix applied")
