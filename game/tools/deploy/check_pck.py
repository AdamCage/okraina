# -*- coding: utf-8 -*-
"""Проверка содержимого Godot .pck (что именно уезжает в веб-сборке).

Формат Godot 4: сигнатура "GDPC", версия формата, версия движка, флаги,
смещение базы, 16 резервных int, число файлов, затем записи:
длина пути, путь (выровнен по 4), смещение, размер, md5[16], флаги.

Запуск: python tools/deploy/check_pck.py [build/web/index.pck]
"""
from __future__ import annotations

import os
import struct
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT = os.path.join(ROOT, "build", "web", "index.pck")

MUST_HAVE = [
    "scenes/game.tscn",
    "autoload/assets.gd",
    "autoload/game_state.gd",
    "autoload/quests.gd",
    "autoload/sfx.gd",
    "scripts/game.gd",
    "scripts/world.gd",
    "scripts/player.gd",
    "scripts/enemy.gd",
    "scripts/anomaly.gd",
    "scripts/hud.gd",
    "scripts/touch_ui.gd",
    "assets/ui/Oswald.ttf",
    "assets/ui/PT_Sans-Narrow-Web-Regular.ttf",
    "assets/textures/ground_atlas.png",
    "assets/textures/wall_atlas.png",
]


def read_pck(path: str) -> tuple[int, list[str]]:
    with open(path, "rb") as fh:
        magic = fh.read(4)
        if magic != b"GDPC":
            raise SystemExit(f"не Godot-пак (сигнатура {magic!r})")
        fmt = struct.unpack("<I", fh.read(4))[0]
        ver = tuple(struct.unpack("<3I", fh.read(12)))
        _flags = struct.unpack("<I", fh.read(4))[0]
        _file_base = struct.unpack("<Q", fh.read(8))[0]
        reserved = struct.unpack("<16I", fh.read(64))
        count_at_head = struct.unpack("<I", fh.read(4))[0]
        # в Godot 4.4+ каталог файлов может лежать в конце пака,
        # его смещение — первый резервный int
        dir_offset = reserved[0] if count_at_head == 0 and reserved[0] > 0 else 0
        fh.seek(dir_offset)
        count = struct.unpack("<I", fh.read(4))[0]
        names: list[str] = []
        for _ in range(count):
            plen = struct.unpack("<i", fh.read(4))[0]
            raw = fh.read(plen)
            name = raw.split(b"\x00", 1)[0].decode("utf-8", "replace")
            pad = (4 - (plen % 4)) % 4
            if pad:
                fh.read(pad)
            fh.read(8 + 8 + 16 + 4)          # offset, size, md5, flags
            names.append(name)
    print(f"[i] формат pck: v{fmt} (движок {ver[0]}.{ver[1]}.{ver[2]}), файлов: {count}"
          + (f", каталог @ {dir_offset}" if dir_offset else ""))
    return count, names


## Что обязательно должно уехать в браузер (ищем по подстроке: экспорт
## переименовывает .tscn в .scn, а картинки — в .ctex в .godot/imported).
MUST_HAVE = [
    "game.scn", "project.binary",
    "assets.gd", "game_state.gd", "quests.gd", "sfx.gd",
    "game.gd", "world.gd", "player.gd", "enemy.gd", "anomaly.gd",
    "hud.gd", "inventory_ui.gd", "journal_ui.gd", "menu_ui.gd", "touch_ui.gd",
    "dialog_ui.gd", "item_db.gd", "loot.gd", "container.gd", "npc.gd",
    "Oswald.ttf", "PT_Sans-Narrow-Web-Regular.ttf",
    "ground_atlas.png", "wall_atlas.png", "decal_atlas.png",
    "stalker_idle.png", "dog_walk.png", "mutant_walk.png",
]


def main(argv: list[str]) -> int:
    path = os.path.abspath(argv[0]) if argv else DEFAULT
    if not os.path.isfile(path):
        print(f"[!] нет файла {path}")
        return 2
    size = os.path.getsize(path) / 1048576.0
    count, names = read_pck(path)
    joined = [n.lstrip("/") for n in names]
    missing = [m for m in MUST_HAVE if not any(m in n for n in joined)]
    print(f"[i] {path}: {size:.1f} МБ")
    exts: dict[str, int] = {}
    for n in joined:
        ext = os.path.splitext(n)[1].lower() or "(без расширения)"
        exts[ext] = exts.get(ext, 0) + 1
    for m in MUST_HAVE:
        print(f"    {'ok ' if m not in missing else 'НЕТ'} {m}")
    print("[i] по расширениям:", ", ".join(f"{k}:{v}" for k, v in
          sorted(exts.items(), key=lambda kv: -kv[1])[:10]))
    for sample in joined[:4]:
        print("    пример:", sample)
    if missing:
        print(f"[!] В ПАКЕ НЕТ: {missing}")
        return 1
    print("[i] все ключевые ресурсы на месте")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
