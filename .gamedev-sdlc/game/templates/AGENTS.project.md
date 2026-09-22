# AGENTS.md — Game / Godot (проектная специализация)

Локальные правила игры этого репозитория. Канон Godot:
`<sdlc-root>/game/AGENTS.md`
(поправь относительный путь после подключения). Сначала канон,
потом этот файл.

Когда файлы расходятся: здесь побеждают пути, имена и локальные
инварианты; канон побеждает в стиле и раскладке, пока пункт
ниже явно не переопределён.

## Scope

- Godot версия: `<major.minor>` (патч — по политике проекта)
- Путь к `project.godot` / бинарнику `godot`: `<…>`
- Язык: GDScript (default) / C# (opt-in)
- Контуры: `docs/<feature_id>/` …
- Платформы: PC / mobile / both
- Export presets: `<Windows Desktop>`, `<Android>`, …
- Store каналы: `<…>`

## Where work lives

- Docs контура: `docs/<feature_id>/`
- Scenes: `<path>`
- Scripts (`.gd`): `<path>`
- Resources / data: `<path>`
- Autoloads: `<names>`
- Export presets: `export_presets.cfg` (+ Secrets для signing)

## Local invariants

1. (проектные запреты, которых нет в каноне)
2. Performance budgets: (fps / memory / cold start / build size)
3.

## Configuration / content

- Как добавлять параметр баланса (`.tres` / таблица — какие файлы).
- Save format / migration owner (`user://…`).

## Common tasks

- Добавить механику → элаборация + сцена/скрипт + `ARCHITECTURE.md`
- (другие частые операции этого репозитория)

## Commands

- Test:
- Editor play / smoke:
- Headless / CLI:
- Export PC:
- Export mobile:
- Internal deploy:

## Pointers

- `<game-root>/` README если есть
- Crash reporter / analytics dashboards (ссылки, не секреты)
- Соседние сервисы (backend), если игра их зовёт
