# AGENTS.md — Game / Godot (проектная специализация)

Локальные правила игры этого репозитория. Канон Godot:
[`../.gamedev-sdlc/game/AGENTS.md`](../.gamedev-sdlc/game/AGENTS.md).
Сначала канон, потом этот файл.

Когда файлы расходятся: здесь побеждают пути, имена и локальные
инварианты; канон побеждает в стиле и раскладке, пока пункт
ниже явно не переопределён.

Корневой процесс: [`../AGENTS.md`](../AGENTS.md).

## Scope

- Godot версия: `4.7.2`
- Путь к `project.godot`: `game/project.godot`
- Версия игры: `0.1.3` (`application/config/version`); история — [`CHANGELOG.md`](CHANGELOG.md)
- Бинарник `godot`: `tools/godot/Godot_v4.7.2-stable_win64.exe` (и `_console.exe`; каталог `tools/godot/` в `.gitignore`)
- Язык: GDScript (default)
- Контуры: [`docs/`](docs/) — `INTERFACES.md` (контракты классов и API автолоадов);
  [`docs/vertical_slice/`](docs/vertical_slice/) — артефакты первого вертикального среза,
  его сцены и скрипты заменены игрой 0.1.x (доки оставлены как история контура)
- Платформы: Windows now; Web (публичное демо) — есть; Android next; iOS later
- Export presets: [`export_presets.cfg`](export_presets.cfg) — пресет `Web`
  (сборка — [`tools/deploy/build_web.ps1`](tools/deploy/build_web.ps1))
- Store каналы: нет (класс `release` выключен)

## Where work lives

- World / lore SoT (product): `docs/world/` (корень репо)
- Docs контура: `game/docs/<feature_id>/`
- Scenes: `game/scenes/` (корневая — `game.tscn`)
- Scripts (`.gd`): `game/scripts/` + `game/autoload/`
- Resources / data: каталога `game/resources/` пока нет — данные предметов в `game/scripts/item_db.gd`
- Assets: `game/assets/{textures,sprites,ui,audio}/` — всё сгенерировано `game/tools/gen/*.py`
- Tests (headless, `extends SceneTree`): `game/tests/`
- Web-обвязка: `game/web/head_include.html`
- Сборка / деплой: `game/tools/deploy/`
- Autoloads: `GameState`, `Assets`, `Quests`, `Sfx`
- Export presets: `game/export_presets.cfg` (+ Secrets для signing)

## Local invariants

1. Нет IAP / prod-store submit из агентских задач.
2. Бюджет веса: `index.pck` ≤ 8 МБ (0.1.3 — 5.90 МБ); ничего из `game/tools/`
   не должно попадать в пак (`exclude_filter` в `export_presets.cfg`).
3. Save path: `user://zone_save.json` (в web — хранилище браузера).
4. Публичное демо: <https://31-130-128-81.sslip.io/>; выкладка вручную —
   `game\tools\deploy\build_web.ps1 -Deploy`; креды ВМ только в `.env` (в `.gitignore`).

## Commands

- Самотест игры (мир, бой, лут, квесты, сохранение): `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game -- --selftest`
- Плейтест игровых путей (16 проверок): `... --headless --path game -- --playtest`
- Тесты систем: `... --headless --path game -s res://tests/t_combat.gd` (`t_world.gd`, `t_ui.gd`)
- Editor play / smoke: `tools\godot\Godot_v4.7.2-stable_win64.exe --path game`
- Headless / CLI: `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game --quit-after 3`
- Генерация ассетов: `cd game\tools\gen`, затем `python gen_ground.py` / `gen_sprites.py` / `gen_ui.py` / `gen_audio.py`
- Export Web: `powershell -File game\tools\deploy\build_web.ps1` (с `-Deploy` — и выкладка)
- После сборки Godot перезаписывает `*.import` (новый mtime), и `git status` может показать
  ~239 `.import` как изменённые, хотя содержимое совпадает с индексом байт-в-байт
  (`git diff` пуст, хеши совпадают). Снимается `git add -A` — коммитить там нечего.
- Export PC: нет
- Export mobile: нет
- Internal deploy: `game\tools\deploy\deploy.py` (`probe|upload|nginx|cert|verify`), класс `deploy` выключен

## Pointers

- Process router: [`../.gamedev-sdlc/process/workflows/router.md`](../.gamedev-sdlc/process/workflows/router.md)
- Game skill: [`../.gamedev-sdlc/game/SKILL.md`](../.gamedev-sdlc/game/SKILL.md)
- Design canon: [`../.gamedev-sdlc/game/design.md`](../.gamedev-sdlc/game/design.md)
- World SoT: [`../docs/world/`](../docs/world/)
- Программа этапов: [`../docs/program/spec.md`](../docs/program/spec.md) (следующий этап — E1)
