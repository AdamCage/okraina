# -*- coding: utf-8 -*-
"""Что реально происходило на сайте: записи из access.log по ассетам игры.

Запуск: python tools/deploy/logs.py [строк]
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import deploy  # noqa: E402


def main(argv: list[str]) -> int:
    tail = argv[0] if argv else "12"
    host, password, port = deploy.read_env()
    rem = deploy.Remote(host, password, port)
    try:
        print("== запросы ассетов игры (последние) ==")
        rem.run(f"grep -aE 'index\\.(wasm|js|pck|html)' /var/log/nginx/access.log | tail -{tail}")
        print("== всего запросов страницы ==")
        rem.run("grep -acE 'GET / HTTP' /var/log/nginx/access.log")
        print("== топ клиентов ==")
        rem.run("awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -6")
        print("== размер отданного wasm (должен быть ~39.5 МБ при полной загрузке) ==")
        rem.run("grep -a 'index.wasm' /var/log/nginx/access.log | tail -3")
    finally:
        rem.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
