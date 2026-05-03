#!/usr/bin/env python3
# wallpaper_search.py — парсер wallpaperflare.com
# Использование: python3 wallpaper_search.py "Nord dark"
# Вывод: JSON-массив в stdout → [{"thumb": "...", "url": "...", "title": "..."}, ...]
# При ошибке: {"error": "..."}

import sys
import json
import re
import urllib.request
import urllib.parse

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.wallpaperflare.com/",
}

def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.read().decode("utf-8", errors="replace")

def parse(html: str) -> list[dict]:
    results = []

    # Стратегия 1: <figure> с data-src или src на превью
    # wallpaperflare использует <figure class="..."><a href="/wallpaper/..."><img ...></a></figure>
    figure_blocks = re.findall(
        r'<figure[^>]*>.*?</figure>',
        html, re.DOTALL | re.IGNORECASE
    )

    for block in figure_blocks:
        # Ссылка на страницу обоев
        page_m = re.search(r'href="(https://www\.wallpaperflare\.com/[^"]+)"', block)
        if not page_m:
            continue
        page_url = page_m.group(1)

        # Превью: data-src приоритетнее src (lazy load)
        thumb_m = re.search(r'data-src="([^"]+\.(?:jpg|jpeg|png|webp))"', block, re.IGNORECASE)
        if not thumb_m:
            thumb_m = re.search(r'src="([^"]+\.(?:jpg|jpeg|png|webp))"', block, re.IGNORECASE)
        if not thumb_m:
            continue
        thumb = thumb_m.group(1)

        # Пропускаем иконки/аватары/рекламу
        if any(x in thumb for x in ["avatar", "logo", "icon", "ad", "banner"]):
            continue

        # Полный URL обоев: на wallpaperflare превью выглядит как
        # https://c4.wallpaperflare.com/wallpaper/NNN/NNN/NNN/...-small.jpg
        # Полный = заменить -small. → пустое, или взять из страницы
        full_url = re.sub(r'-small(?=\.\w+$)', '', thumb)
        # Альтернатива: попробовать -medium → без суффикса
        full_url = re.sub(r'-medium(?=\.\w+$)', '', full_url)

        # Заголовок из alt
        title_m = re.search(r'alt="([^"]*)"', block)
        title = title_m.group(1) if title_m else ""

        results.append({
            "thumb": thumb,
            "url":   full_url,
            "title": title,
            "page":  page_url,
        })

    # Стратегия 2: если figure не нашли — ищем img напрямую рядом с ссылками
    if not results:
        # Паттерн: <a href="/wallpaper/slug">...<img ... data-src="...">...</a>
        link_img_blocks = re.findall(
            r'<a\s+href="(https://www\.wallpaperflare\.com/[^"]+)"[^>]*>.*?<img[^>]+>.*?</a>',
            html, re.DOTALL | re.IGNORECASE
        )
        for block in link_img_blocks:
            # block здесь — это href, нам нужна группа + img
            pass

        # Простой fallback: все img с data-src внутри ссылок на обои
        pattern = re.compile(
            r'href="(https://www\.wallpaperflare\.com/\S+?)"'
            r'.*?'
            r'(?:data-src|src)="([^"]+\.(?:jpg|jpeg|png|webp)[^"]*)"',
            re.DOTALL | re.IGNORECASE
        )
        for m in pattern.finditer(html):
            page_url = m.group(1)
            thumb    = m.group(2)
            if any(x in thumb for x in ["avatar", "logo", "icon"]):
                continue
            full_url = re.sub(r'-small(?=\.\w+)', '', thumb)
            results.append({
                "thumb": thumb,
                "url":   full_url,
                "title": "",
                "page":  page_url,
            })

    # Дедупликация по thumb
    seen = set()
    unique = []
    for r in results:
        key = r["thumb"]
        if key not in seen:
            seen.add(key)
            unique.append(r)

    return unique[:30]


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: wallpaper_search.py <query>"}))
        sys.exit(1)

    query = " ".join(sys.argv[1:]).strip()
    url   = "https://www.wallpaperflare.com/search?wallpaper=" + urllib.parse.quote_plus(query)

    try:
        html    = fetch(url)
        results = parse(html)
        print(json.dumps(results, ensure_ascii=False))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
