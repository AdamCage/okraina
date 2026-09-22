# AGENTS.md — проект

Локальные факты репозитория. Канон процесса:
`<sdlc-root>/process/AGENTS.md`
(поправь относительный путь после подключения).
Не копировать принципы и рецепты канона сюда.

Конфликт слоёв: `<sdlc-root>/process/specialize.md`.
GitHub: `<sdlc-root>/process/github.md`.

## Канон

- Процесс: `<sdlc-root>/process/`
- Домены: `<sdlc-root>/game/` (оставь только те, что есть в репо)
- `evolve/` не подключать (канон не правим из этого продукта)

## Домены в этом репозитории

- (game: путь к `<game-root>/AGENTS.md`)
- (другие — проект-локальные обвязки, не второй SDLC)

## Классы задач

Включены: (например `spec-only`, `feature-cycle`, `increment`, `hotfix`, `review-only`, `deploy`, `release`)

Выключены: (например `incident`)

## Платформы

- PC: (Steam / itch / … или «нет»)
- Mobile: (iOS / Android / обе / «нет»)
- Godot: версия `<major.minor>`, путь к `godot` / `project.godot`
- Язык: GDScript (default) / C# (opt-in)

## Команды

- Тесты: `(команда)`
- Editor play / playtest: `(команда или «раннера нет»)`
- Headless / CLI Godot: `(команда)`
- Export PC: `(команда + preset)`
- Export mobile: `(команда + preset)`
- Lint / точечная проверка: `(команда)`
- Deploy internal: `(команда или «класса нет»)`

## GitHub

- Repo: `(org/name)`
- Default branch: `(main)`
- Required checks: `(имена workflows)`
- Branch protection: `(кратко; менять только с гейтом)`
- `gh` доступен: да / нет

## Extra human gates

1. (prod-store, IAP, live economy, …)
2.

## Local hard invariants

1. (запреты и обещания этого репо)
2.

## Spot-check

- (как быстро понять, что обвязка жива: Godot editor Run, headless smoke, …)
