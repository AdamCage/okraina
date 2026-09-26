# -*- coding: utf-8 -*-
"""Загрузка export-шаблонов Godot 4.7.2 (только нужные платформы).

Официальный .tpz весит ~1.28 ГБ, но это обычный ZIP. Читаем его центральный
каталог через HTTP Range-запросы и скачиваем только нужные элементы
(по умолчанию — web-шаблоны, ~120 МБ).

Запуск:
    python tools/deploy/fetch_templates.py            # только web
    python tools/deploy/fetch_templates.py --list     # показать содержимое
    python tools/deploy/fetch_templates.py --all      # всё (1.28 ГБ)
"""
from __future__ import annotations

import os
import sys
import time
import urllib.request
import zipfile

VERSION = "4.7.2-stable"
TAG = VERSION
DIR_VERSION = "4.7.2.stable"     # каталог шаблонов Godot называет через точку
TPZ_URL = (
    "https://github.com/godotengine/godot/releases/download/"
    f"{TAG}/Godot_v{TAG}_export_templates.tpz"
)
DEST = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), "Godot",
                    "export_templates", DIR_VERSION)
WANT_DEFAULT = ("web",)
BLOCK = 1 << 22  # 4 МБ буфер докачки


class HttpFile:
    """Минимальный seekable-объект поверх HTTP Range (нужен zipfile)."""

    def __init__(self, url: str) -> None:
        self.url = url
        self.pos = 0
        self.size = self._content_length()
        self._cache_start = 0
        self._cache = b""

    def _content_length(self) -> int:
        req = urllib.request.Request(self.url, method="HEAD")
        with urllib.request.urlopen(req, timeout=60) as resp:
            return int(resp.headers["Content-Length"])

    def _fetch(self, start: int, length: int) -> bytes:
        end = min(self.size, start + length) - 1
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={start}-{end}"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            return resp.read()

    def seek(self, off: int, whence: int = 0) -> int:
        if whence == 0:
            self.pos = off
        elif whence == 1:
            self.pos += off
        else:
            self.pos = self.size + off
        return self.pos

    def tell(self) -> int:
        return self.pos

    def seekable(self) -> bool:
        return True

    def readable(self) -> bool:
        return True

    def writable(self) -> bool:
        return False

    def read(self, n: int = -1) -> bytes:
        if n is None or n < 0:
            n = self.size - self.pos
        if n == 0 or self.pos >= self.size:
            return b""
        n = min(n, self.size - self.pos)
        end = self.pos + n
        # попадает в кэш?
        if self._cache_start <= self.pos and end <= self._cache_start + len(self._cache):
            off = self.pos - self._cache_start
            self.pos = end
            return self._cache[off:off + n]
        # качаем блок с выравниванием
        start = (self.pos // BLOCK) * BLOCK
        want = max(BLOCK, end - start)
        self._cache = self._fetch(start, want)
        self._cache_start = start
        if not self._cache:
            return b""
        off = self.pos - start
        chunk = self._cache[off:off + n]
        self.pos += len(chunk)
        return chunk


def human(n: float) -> str:
    for unit in ("Б", "КБ", "МБ", "ГБ"):
        if n < 1024 or unit == "ГБ":
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} ГБ"


def main(argv: list[str]) -> int:
    want_all = "--all" in argv
    list_only = "--list" in argv
    print(f"[i] архив: {TPZ_URL}")
    t0 = time.time()
    remote = HttpFile(TPZ_URL)
    print(f"[i] размер архива: {human(remote.size)} (за {time.time() - t0:.1f} с)")
    zf = zipfile.ZipFile(remote)
    entries = zf.infolist()
    os.makedirs(DEST, exist_ok=True)
    print(f"[i] элементов в архиве: {len(entries)} | каталог назначения: {DEST}")
    if list_only:
        for e in entries:
            print(f"    {e.filename:60s} {human(e.file_size)}")
        return 0

    picked = []
    for e in entries:
        if e.is_dir():
            continue
        base = os.path.basename(e.filename)
        if want_all or base == "version.txt" or any(w in base for w in WANT_DEFAULT):
            picked.append(e)

    if not picked:
        print("[!] ничего не найдено для скачивания")
        return 2

    total = sum(e.file_size for e in picked)
    print(f"[i] выбрано {len(picked)} элементов, распакованный объём {human(total)}")
    done = 0
    for e in picked:
        base = os.path.basename(e.filename)
        path = os.path.join(DEST, base)
        if os.path.exists(path) and os.path.getsize(path) == e.file_size:
            print(f"[=] {base} (уже есть)")
            continue
        t = time.time()
        data = zf.read(e)
        with open(path, "wb") as fh:
            fh.write(data)
        done += 1
        speed = len(data) / max(1e-6, time.time() - t)
        print(f"[+] {base:42s} {human(len(data))} за {time.time() - t:.1f} с ({human(speed)}/с)")
    print(f"[i] готово: {done} файлов записано в {DEST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
