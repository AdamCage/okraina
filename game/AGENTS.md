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
- Бинарник `godot`: `tools/godot/Godot_v4.7.2-stable_win64.exe` (и `_console.exe`; каталог `tools/` в `.gitignore`)
- Язык: GDScript (default)
- Контуры: `game/docs/vertical_slice/`, `game/docs/combat_feel/` (E1), `game/docs/run_builds/` (E2), `game/docs/run_floors/` (E3), `game/docs/save_slot/` (E4) …
- Платформы: Windows now; Android next; iOS later
- Export presets: TBD
- Store каналы: нет (класс `release` выключен)

## Where work lives

- World / lore SoT (product): `docs/world/` (корень репо)
- Docs контура: `game/docs/<feature_id>/`
- Scenes: `game/scenes/`
- Scripts (`.gd`): `game/scripts/` + `game/autoload/`
- Resources / data: `game/resources/`
- Autoloads: `GameState`
- Export presets: `game/export_presets.cfg` (+ Secrets для signing)

## Local invariants

1. Нет IAP / prod-store submit из агентских задач.
2. Performance budgets: TBD (placeholder slice).
3. Save path: один слот `user://slot.json`. Контракт: `game/docs/save_slot/`.

## Commands

- Test: `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game -s res://scripts/full_smoke.gd`
- Combat smoke (E1): `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game -s res://scripts/combat_feel_smoke.gd`
- Builds smoke (E2): `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game -s res://scripts/builds_smoke.gd`
- Floors smoke (E3): `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game -s res://scripts/floors_smoke.gd`
- Save smoke (E4): `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game -s res://scripts/slot_smoke.gd`
- Loop smoke: `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game -s res://scripts/loop_smoke.gd`
- Editor play / smoke: `tools\godot\Godot_v4.7.2-stable_win64.exe --path game`
- Headless / CLI: `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game --quit-after 3`
- Export PC: нет
- Export mobile: нет
- Internal deploy: класса нет

## Pointers

- Process router: [`../.gamedev-sdlc/process/workflows/router.md`](../.gamedev-sdlc/process/workflows/router.md)
- Game skill: [`../.gamedev-sdlc/game/SKILL.md`](../.gamedev-sdlc/game/SKILL.md)
- Design canon: [`../.gamedev-sdlc/game/design.md`](../.gamedev-sdlc/game/design.md)
- World SoT: [`../docs/world/`](../docs/world/)
- Программа этапов: [`../docs/program/spec.md`](../docs/program/spec.md) (следующий этап после E4 — E5)
