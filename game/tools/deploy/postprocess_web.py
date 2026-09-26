# -*- coding: utf-8 -*-
"""Постобработка веб-сборки Godot: мобильная HTML-обвязка и PWA-мелочи.

Godot вставляет опцию html/head_include как *raw HTML*, а не как путь к файлу,
поэтому проще довести index.html до нужного вида здесь: подключить
web/head_include.html, поправить язык, viewport и заголовок загрузки.

Запуск: python tools/deploy/postprocess_web.py [build/web/index.html]
"""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HEAD_FILE = os.path.join(ROOT, "web", "head_include.html")
DEFAULT_INDEX = os.path.join(ROOT, "build", "web", "index.html")

MOBILE_META = ('<meta name="viewport" content="width=device-width, initial-scale=1.0, '
               'maximum-scale=1.0, minimum-scale=1.0, user-scalable=no, viewport-fit=cover" />')

# --------------------------------------------------------------------------- SW
# Godot кладёт файлы сборки в HTTP-кэш браузера. Если браузер закэшировал
# index.js/index.pck/index.wasm по старому правилу (max-age=604800, immutable),
# после обновления сайта он молча запускает ПРЕДЫДУЩУЮ сборку: страница новая,
# а игра старая (в старом меню, например, не доходили клики). Поэтому в service
# worker добавляем revalidate и сверку версии с сервером.
SW_FILE = "index.service.worker.js"
SW_MARK = "zone: сверка сборки с сервером"
ZONE_STATUS_CSS = "\t\t\t#status.zone-hidden { display: none !important; }\n"

SW_BLOCK = r"""// --- zone: сверка сборки с сервером -----------------------------------------
// Файлы сборки лежат в HTTP-кэше браузера. Если их закэшировали по старому
// правилу immutable, после обновления сайта игра запускается прошлой версией.
// Поэтому качаем файлы кэша с revalidate (no-cache) и перед загрузкой страницы
// сверяем ETag/Last-Modified index.wasm/index.pck с сервером, выбрасывая
// устаревшие записи — иначе страница новая, а игра старая.
function zoneTag(response) {
	// В Cache API ответ сервера может лежать как weak-ETag (W/"..."), поэтому
	// префикс убираем — иначе любая установка SW считалась бы обновлением сборки.
	return (response.headers.get('etag') || response.headers.get('last-modified') || '')
		.replace(/^W\//, '').trim();
}

// true, если в кэше клиента лежала другая (устаревшая) сборка.
let zoneBuildChanged = false;

// Идущая проверка сборки — чтобы не запускать её дважды одновременно.
let zoneBuildCheck = null;

// Одна проверка за раз: выбрасывает устаревшие index.wasm/index.pck.
function zoneCheckBuild() {
	if (zoneBuildCheck != null) {
		return zoneBuildCheck;
	}
	zoneBuildCheck = caches.open(CACHE_NAME)
		.then((cache) => zoneDropStaleBuild(cache))
		.then((dropped) => {
			if (dropped) {
				zoneBuildChanged = true;
			}
			zoneBuildCheck = null;
			return dropped;
		})
		.catch((e) => {
			zoneBuildCheck = null;
			console.warn('[zone] не проверил сборку: ' + e); // eslint-disable-line no-console
			return false;
		});
	return zoneBuildCheck;
}

// Проверка на каждой загрузке страницы: если сборка сменилась, выбрасываем её и
// один раз перезагружаем вкладки, иначе браузер так и будет играть прошлую версию.
async function zoneHealOnLoad() {
	if (await zoneCheckBuild()) {
		const all = await self.clients.matchAll({ type: 'window' });
		all.forEach((c) => c.navigate(c.url));
	}
}

self.addEventListener('fetch', (event) => {
	if (event.request.mode === 'navigate') {
		event.waitUntil(zoneHealOnLoad());
	}
});

async function zoneRefreshCache(cache) {
	for (const name of CACHED_FILES) {
		try {
			// cache: 'reload' — берём файл с сервера в обход HTTP-кэша: старая
			// запись могла быть сохранена как immutable и вернулась бы снова.
			const response = await fetch(name, { cache: 'reload' });
			if (response.ok || response.type === 'opaque') {
				await cache.put(name, response.clone());
			}
		} catch (e) {
			console.warn('[zone] не обновил ' + name + ': ' + e); // eslint-disable-line no-console
		}
	}
}

async function zoneDropStaleBuild(cache) {
	let dropped = false;
	for (const name of CACHEABLE_FILES) {
		const cached = await cache.match(name);
		if (cached == null) {
			continue;
		}
		let fresh = null;
		try {
			fresh = await fetch(name, { method: 'HEAD', cache: 'no-store' });
		} catch (e) {
			continue;
		}
		const has = zoneTag(cached);
		const now = zoneTag(fresh);
		if (has !== '' && now !== '' && has !== now) {
			console.info('[zone] сборка обновилась (' + name + '): ' + has + ' -> ' + now); // eslint-disable-line no-console
			await cache.delete(name);
			dropped = true;
			// Качаем заново в обход HTTP-кэша: старая запись могла быть сохранена
			// как immutable, и обычный запрос вернул бы её же.
			try {
				const full = await fetch(name, { cache: 'reload' });
				if (full.ok || full.type === 'opaque') {
					await cache.put(name, full.clone());
				}
			} catch (e) {
				console.warn('[zone] не перекачал ' + name + ': ' + e); // eslint-disable-line no-console
			}
		}
	}
	return dropped;
}
"""

SW_INSTALL_OLD = "\tevent.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));"
SW_INSTALL_NEW = ("\tevent.waitUntil(caches.open(CACHE_NAME).then(async (cache) => {\n"
                  "\t\tawait zoneRefreshCache(cache);\n"
                  "\t\tawait zoneCheckBuild();\n"
                  "\t\tawait self.skipWaiting();\n"
                  "\t}));")
SW_ACTIVATE_OLD = ("\t\treturn ('navigationPreload' in self.registration) "
                   "? self.registration.navigationPreload.enable() : Promise.resolve();\n\t}));")
SW_ACTIVATE_NEW = (
    "\t\treturn ('navigationPreload' in self.registration) "
    "? self.registration.navigationPreload.enable() : Promise.resolve();\n"
    "\t}).then(function () {\n"
    "\t\treturn self.clients.claim();\n"
    "\t}).then(function () {\n"
    "\t\t// zone: если в кэше лежала старая сборка, перезагружаем вкладки —\n"
    "\t\t// иначе они так и будут играть предыдущую версию.\n"
    "\t\tif (!zoneBuildChanged) {\n"
    "\t\t\treturn undefined;\n"
    "\t\t}\n"
    "\t\tzoneBuildChanged = false;\n"
    "\t\treturn self.clients.matchAll({ type: 'window' }).then((all) => {\n"
    "\t\t\tall.forEach((c) => c.navigate(c.url));\n"
    "\t\t});\n"
    "\t}));")
SW_FETCH_OLD = "\t\tresponse = await self.fetch(event.request);"
SW_FETCH_NEW = ("\t\t// zone: no-cache — иначе браузер отдаст уже закэшированные файлы сборки\n"
                "\t\tresponse = await self.fetch(event.request, { cache: 'no-cache' });")
SW_ANCHOR = "const FULL_CACHE = CACHED_FILES.concat(CACHEABLE_FILES);"


def patch_service_worker(path: str) -> bool:
    """Добавляет в service worker revalidate и сверку сборки с сервером."""
    if not os.path.isfile(path):
        print(f"    НЕТ service worker: {path}")
        return False
    with open(path, encoding="utf-8") as fh:
        js = fh.read()
    if SW_MARK in js:
        print(f"    ok  {SW_FILE}: правка кэша уже есть")
        return True
    for chunk in (SW_ANCHOR, SW_INSTALL_OLD, SW_FETCH_OLD, SW_ACTIVATE_OLD):
        if chunk not in js:
            print(f"    НЕТ куска в {SW_FILE}: {chunk.strip()[:60]}")
            return False
    js = js.replace(SW_ANCHOR, SW_ANCHOR + "\n\n" + SW_BLOCK, 1)
    js = js.replace(SW_INSTALL_OLD, SW_INSTALL_NEW, 1)
    js = js.replace(SW_FETCH_OLD, SW_FETCH_NEW, 1)
    js = js.replace(SW_ACTIVATE_OLD, SW_ACTIVATE_NEW, 1)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(js)
    print(f"    ok  {SW_FILE}: добавлены revalidate и сверка сборки с сервером")
    return True



def main(argv: list[str]) -> int:
    index_path = os.path.abspath(argv[0]) if argv else DEFAULT_INDEX
    if not os.path.isfile(index_path):
        print(f"[!] нет файла сборки: {index_path}")
        return 2
    with open(index_path, encoding="utf-8") as fh:
        html = fh.read()

    # 1. подключаем мобильную обвязку вместо текстовой ссылки на файл
    if os.path.isfile(HEAD_FILE):
        with open(HEAD_FILE, encoding="utf-8") as fh:
            head = fh.read()
        html = html.replace("res://web/head_include.html", head)
        # повторная сборка могла уже оставить тег — лишний убираем
        if head.strip() in html:
            html = html.replace(head.strip() + "\n" + head.strip(), head.strip())

    # 2. язык и viewport
    html = html.replace('<html lang="en">', '<html lang="ru">')
    html = re.sub(r'<meta name="viewport"[^>]*>', MOBILE_META, html, count=1)

    # 3. заголовок окна загрузки: прячем стандартный сплэш, показываем свой экран
    # 3. заголовок окна загрузки: прячем стандартный сплэш, показываем свой экран
    html = html.replace('<div id="status">', '<div id="status" class="zone-hidden">')
    if ZONE_STATUS_CSS not in html:
        html = html.replace("\t\t</style>", ZONE_STATUS_CSS + "\t\t</style>")

    # 4. прогресс-бар загрузки: русский текст вместо английского
    html = html.replace("Loading...", "Загрузка Зоны…")

    with open(index_path, "w", encoding="utf-8") as fh:
        fh.write(html)
    size = os.path.getsize(index_path)
    print(f"[+] {index_path} обработан ({size} байт)")
    sw_ok = patch_service_worker(os.path.join(os.path.dirname(index_path), SW_FILE))

    checks = {
        "zone-boot": "свой экран запуска",
        "viewport-fit=cover": "мобильный viewport",
        "safe-area-inset": "отступы под «челку»",
        'lang="ru"': "русский язык страницы",
        "fullscreen": "запрос полного экрана",
    }
    for needle, desc in checks.items():
        print(f"    {'ok ' if needle in html else 'НЕТ'} {desc} ({needle})")
    return 0 if sw_ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
