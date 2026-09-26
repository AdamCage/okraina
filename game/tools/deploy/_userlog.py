# -*- coding: utf-8 -*-
"""Что именно запрашивал конкретный клиент (для разбора «меню не активно»).

Запуск: python tools/deploy/_userlog.py [ip|ua-подстрока] [строк]
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import deploy  # noqa: E402


def main(argv: list[str]) -> int:
    needle = argv[0] if argv else "Chrome/154"
    tail = argv[1] if len(argv) > 1 else "80"
    host, password, port = deploy.read_env()
    rem = deploy.Remote(host, password, port)
    try:
        print(f"== все запросы клиента «{needle}» (последние {tail}) ==")
        rem.run(f"grep -a '{needle}' /var/log/nginx/access.log | tail -{tail}")
        print(f"== только ассеты сборки ==")
        rem.run(f"grep -a '{needle}' /var/log/nginx/access.log | grep -aE 'index\\.(wasm|pck|js|html|service)' | tail -40")
        print("== текущий заголовок кэша для ассетов (проверка nginx) ==")
        rem.run("curl -sSI https://31-130-128-81.sslip.io/index.wasm | head -20")
        rem.run("curl -sSI https://31-130-128-81.sslip.io/ -H 'Host: 31-130-128-81.sslip.io' | head -14")
    finally:
        rem.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
