# -*- coding: utf-8 -*-
"""Правка импорта звуков: включаем зацикливание у лупов и сжатие OggVorbis.

Зачем:
  * Sfx.ambient/music играют лупы, а AudioStreamWAV без loop_mode проигрывается
    один раз — эмбиент замолкал бы навсегда;
  * WAV 44100/16 в несжатом виде весит много, для веб-сборки лучше OggVorbis.

Запуск после генерации звуков:  python tools/gen/fix_audio_imports.py
Затем прогнать импорт:          godot --headless --path . --import
"""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
AUD = os.path.join(ROOT, "assets", "audio")

LOOP_HINTS = ("_loop", "amb_", "mus_")
LOOP_MIN_DURATION_GUESS = 1.0   # доли секунды: всё, что содержит намёк на луп
WAV_COMPRESS_MODE = "0"         # 0 = без сжатия (PCM), 2 = OggVorbis
LOOP_COMPRESS_MODE = "2"        # длинные лупы жмём в OggVorbis
LOOP_QUALITY = "0.6"


def patch_import(path: str) -> tuple[bool, str]:
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    name = os.path.basename(path).lower()
    is_loop = any(h in name for h in LOOP_HINTS)
    original = text

    def set_param(t: str, key: str, value: str) -> str:
        if re.search(rf"(?m)^{re.escape(key)}=.*$", t):
            return re.sub(rf"(?m)^{re.escape(key)}=.*$", f"{key}={value}", t)
        return t.replace("[params]", f"[params]\n\n{key}={value}", 1)

    if is_loop:
        text = set_param(text, "edit/loop_mode", "1")          # 1 = Forward
        text = set_param(text, "edit/loop_begin", "0")
        text = set_param(text, "edit/loop_end", "-1")
        text = set_param(text, "compress/mode", LOOP_COMPRESS_MODE)
        text = set_param(text, "quality", LOOP_QUALITY)
    else:
        text = set_param(text, "compress/mode", WAV_COMPRESS_MODE)
    if text == original:
        return False, "без изменений"
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    return True, "луп: OggVorbis + loop" if is_loop else "PCM"


def main(argv: list[str]) -> int:
    if not os.path.isdir(AUD):
        print(f"[!] нет каталога {AUD} — сначала сгенерируйте звуки")
        return 1
    changed = 0
    total_bytes = 0
    loops = 0
    for name in sorted(os.listdir(AUD)):
        if not name.endswith(".wav"):
            continue
        wav_path = os.path.join(AUD, name)
        total_bytes += os.path.getsize(wav_path)
        imp_path = wav_path + ".import"
        if not os.path.isfile(imp_path):
            print(f"    [!] нет {name}.import — прогоните импорт в Godot")
            continue
        patched, what = patch_import(imp_path)
        low = name.lower()
        if any(h in low for h in LOOP_HINTS):
            loops += 1
        if patched:
            changed += 1
            print(f"    {name}: {what}")
    print(f"[i] звуков: {loops} лупов, обновлено .import: {changed}, "
          f"суммарный WAV: {total_bytes / 1048576:.1f} МБ")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
