# -*- coding: utf-8 -*-
"""Точечная выкладка одного файла сборки на ВМ (без полного put_tree).

Запуск: python tools/deploy/_put_sw.py [локальный файл] [путь на ВМ]
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stdout.reconfigure(encoding="utf-8")

import deploy  # noqa: E402

LOCAL = r"C:\projects\test\build\web\index.service.worker.js"
REMOTE = "/var/www/zone/index.service.worker.js"


def main(argv: list[str]) -> int:
    local = argv[0] if argv else LOCAL
    remote = argv[1] if len(argv) > 1 else REMOTE
    host, password, port = deploy.read_env()
    rem = deploy.Remote(host, password, port)
    try:
        print(f"[+] кладу {local} -> {remote}")
        rem.sftp.put(local, remote)
        rem.run(f"ls -l {remote}")
        rem.run("nginx -t")
        rem.run(f"curl -sI https://31-130-128-81.sslip.io/{os.path.basename(remote)} | head -12")
        code, out = rem.run(f"curl -s https://31-130-128-81.sslip.io/{os.path.basename(remote)}"
                            " | grep -c 'zone: сверка сборки'")
        print(f"[+] маркеров правки на сервере: {out.strip()}")
    finally:
        rem.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
