# AGENTS.md — проект

Локальные факты репозитория. Канон процесса:
[`.gamedev-sdlc/process/AGENTS.md`](.gamedev-sdlc/process/AGENTS.md).
Не копировать принципы и рецепты канона сюда.

Конфликт слоёв: [`.gamedev-sdlc/process/specialize.md`](.gamedev-sdlc/process/specialize.md).
GitHub: [`.gamedev-sdlc/process/github.md`](.gamedev-sdlc/process/github.md).

`<sdlc-root>` в этом репо = [`.gamedev-sdlc/`](.gamedev-sdlc/).

## Канон

- Процесс: [`.gamedev-sdlc/process/`](.gamedev-sdlc/process/)
- Домены: [`.gamedev-sdlc/game/`](.gamedev-sdlc/game/)
- `evolve/` не подключать (канон не правим из этого продукта)

## Домены в этом репозитории

- game: [`game/AGENTS.md`](game/AGENTS.md) (`<game-root>` = `game/`)

Kit product domain today: only `game`. No other companion product domains are defined in the canon; `evolve/` is canon-maintenance only and is not wired here.

## Классы задач

Включены: `spec-only`, `feature-cycle`, `increment`, `hotfix`, `review-only`, `admin`

Выключены (пока явно не попросят): `deploy`, `incident`, `release`

Также доступен router-класс `bootstrap-project` только для повторной обвязки.

## Платформы

- PC: Windows (сейчас)
- Mobile: Android (следующая цель); iOS — later
- Godot: `4.7`, бинарник (gitignore): `tools/godot/Godot_v4.7.2-stable_win64.exe` / `_console.exe`; `project.godot` — `game/project.godot`
- Язык: GDScript (default)

## Команды

- Тесты / smoke: `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game -s res://scripts/smoke_test.gd`
- Loop smoke: `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game -s res://scripts/loop_smoke.gd`
- Editor play / playtest: `tools\godot\Godot_v4.7.2-stable_win64.exe --path game`
- Headless boot: `tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game --quit-after 3`
- Export PC: `нет` (класс `release` выключен)
- Export mobile: `нет`
- Lint / точечная проверка: проверить относительные ссылки из этого файла и `game/AGENTS.md`
- Deploy internal: класса нет

## GitHub

- Repo: `AdamCage/okraina`
- Default branch: `main`
- Required checks: `sdlc-checks` (адаптированный stub); `build-stub` — placeholder
- Branch protection: рекомендована каноном (PR + checks + ban force-push); **не менять без human gate / класса `admin`**
- `gh` доступен: да

## Extra human gates

1. prod-store submit / production track
2. IAP / live economy
3. force-push / снятие branch protection / wipe сохранений
4. смена signing / store credentials в CI
5. включение выключенных классов (`deploy`, `incident`, `release`)

## Local hard invariants

1. Не коммитить store/signing secrets, keystores, API tokens.
2. Не править `.gamedev-sdlc/` под этот продукт (канон только по ссылке).
3. Design source of truth: [`docs/world/`](docs/world/).
4. Агент не делает: prod-store submit, IAP, force-push.

## Spot-check

- Есть корневой `AGENTS.md`, `game/AGENTS.md`, `.gamedev-sdlc/process/workflows/router.md`.
- `docs/world/` существует как SoT дизайна мира.
- Issue можно открыть из `.github/ISSUE_TEMPLATE/` с классом и платформой.
- Следующая задача: этот файл → [router](.gamedev-sdlc/process/workflows/router.md) → `game`.
