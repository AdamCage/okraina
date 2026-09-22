# AGENTS.md — Game / Godot (проектная специализация)

Локальные правила игры этого репозитория. Канон Godot:
[`../.gamedev-sdlc/game/AGENTS.md`](../.gamedev-sdlc/game/AGENTS.md).
Сначала канон, потом этот файл.

Когда файлы расходятся: здесь побеждают пути, имена и локальные
инварианты; канон побеждает в стиле и раскладке, пока пункт
ниже явно не переопределён.

Корневой процесс: [`../AGENTS.md`](../AGENTS.md).

## Scope

- Godot версия: `4.7` (патч — по политике проекта; бинарник TBD)
- Путь к `project.godot`: `game/project.godot` (ещё не создан)
- Бинарник `godot`: TBD (не в PATH на bootstrap-машине)
- Язык: GDScript (default)
- Контуры: `game/docs/<feature_id>/` …
- Платформы: Windows now; Android next; iOS later
- Export presets: TBD (`Windows Desktop`, `Android`, …)
- Store каналы: нет (класс `release` выключен)

## Where work lives

- World / lore SoT (product): `docs/world/` (корень репо)
- Docs контура: `game/docs/<feature_id>/`
- Scenes: `game/scenes/`
- Scripts (`.gd`): `game/scripts/`
- Resources / data: `game/resources/`
- Autoloads: TBD после появления `project.godot`
- Export presets: `game/export_presets.cfg` (+ Secrets для signing)

## Local invariants

1. Нет IAP / prod-store submit из агентских задач.
2. Performance budgets: TBD на первом playable slice (fps / memory / cold start / build size).
3. Save path: `user://` (конкретный файл — при первом save-контуре).

## Configuration / content

- Баланс / контент-данные — через `.tres` / таблицы под `game/resources/` (когда появятся).
- Save format / migration owner — TBD с первым save-контуром.

## Common tasks

- Добавить механику → элаборация + сцена/скрипт + `ARCHITECTURE.md` в `game/docs/<feature_id>/`
- Lore / world bible → `docs/world/` (`spec-only`, без кода)

## Commands

- Test: раннера нет
- Editor play / smoke: раннера нет
- Headless / CLI: раннера нет
- Export PC: нет
- Export mobile: нет
- Internal deploy: класса нет

## Pointers

- Process router: [`../.gamedev-sdlc/process/workflows/router.md`](../.gamedev-sdlc/process/workflows/router.md)
- Game skill: [`../.gamedev-sdlc/game/SKILL.md`](../.gamedev-sdlc/game/SKILL.md)
- Design canon: [`../.gamedev-sdlc/game/design.md`](../.gamedev-sdlc/game/design.md)
- World SoT: [`../docs/world/`](../docs/world/)
