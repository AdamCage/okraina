# Agentic SDLC — Godot Game Development

This repository is the **canon** for how AI agents design, build, playtest,
and ship PC and mobile games in **Godot**. It is not a product game.
Project names, store accounts, certificates, Godot patch version, and
prod commands live in the consumer project's thin `AGENTS.md`, not here.

## Two axes

| Axis | Directory | Question |
|---|---|---|
| Process | [`process/`](process/) | How agents work: task class, roles, artifacts, gates, GitHub |
| Domain | `<sdlc-root>/<domain>/` | How agents produce work in the subject area |

Current product domain: [`game/`](game/) — Godot, PC and mobile.
New domains sit at the repo root next to `game/`, not under `process/`,
not under `domains/`. Shape matches `game/`. See
[`process/new-domain.md`](process/new-domain.md).

[`evolve/`](evolve/) is the domain for changing **this** repository.
Consumers **do not** read it unless they contribute to the canon.

## Godot scope

Canon assumes:

- **Godot** project layout (`project.godot`, scenes, nodes, resources,
  autoloads);
- **GDScript** as the default language (C# only if the project opts in);
- signals, scenes, resources, and **export presets** for PC and mobile;
- run/debug via the Godot editor and, where useful, headless/CLI
  (`godot` / Godot console);
- export and release for PC (Windows / Linux / macOS as the project
  declares) and mobile (Android; iOS called out where signing/store differ).

Godot **major/minor version** is a project decision, pinned in the thin
project `AGENTS.md` — not hard-coded in every canon sentence.

## How to attach as `<sdlc-root>`

Attach the canon whole: submodule, subtree, or copy. In the product the
folder may be named `sdlc/`, `vendor/sdlc`, etc. In canon texts the path
is always `<sdlc-root>`.

1. Do not edit the canon for one product.
2. Do not copy principles and recipes into project files. Link.
3. Create the product root `AGENTS.md` from
   [`process/workflows/bootstrap-project.md`](process/workflows/bootstrap-project.md)
   and [`process/templates/AGENTS.project.md`](process/templates/AGENTS.project.md).
4. For each known domain — its `specialize.md`
   (today: [`game/specialize.md`](game/specialize.md)).
5. Wire GitHub as system of record:
   [`process/github.md`](process/github.md) and [`.github/`](.github/).

Next product task reads: root `AGENTS.md` →
[`process/workflows/router.md`](process/workflows/router.md) → domain.
Not the whole canon at once.

## Layer conflict

1. Consumer root `AGENTS.md` wins on declared hard invariants.
2. Project `<domain>/AGENTS.md` wins on paths, names, local invariants.
3. `<sdlc-root>/process` wins on process unless a stage is explicitly off.
4. `<sdlc-root>/<domain>` wins on style and layout unless a principle is
   explicitly overridden.

Full text: [`process/specialize.md`](process/specialize.md).

## Contents

| Path | Role |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Wrapper for **this** repo (canon evolution) |
| [`process/`](process/) | Shared SDLC + GitHub SoR |
| [`evolve/`](evolve/) | Domain for changing the canon |
| [`game/`](game/) | Godot domain: PC and mobile games |
| [`.github/`](.github/) | Issue/PR templates, labels, Action stubs |

## Lifecycle map

| Stage | Where in canon |
|---|---|
| 1. Analysis | `spec-only` / step 1 of `feature-cycle` |
| 2. Elaboration (design, lore, systems, UX, tech, scope) | steps 1–2 + [`game/design.md`](game/design.md), [`game/workflows.md`](game/workflows.md) |
| 3. Development | step 3 `feature-cycle` / `increment` + `game/` recipes |
| 4. Run and debug (playable builds) | step 4 + `deploy` / `hotfix` + [`game/workflows.md`](game/workflows.md) (debug) |
| 5. Review and critique | critic + `review-only` / review loop + [`game/review.md`](game/review.md) |
| 6. Fixes, tests, re-review | steps 5–6 of `feature-cycle` |
| 7. Release (PC and mobile) | `release` + [`game/platforms.md`](game/platforms.md) |

## What an agent reads

- Work in a product with canon attached → product root `AGENTS.md`, then
  [`process/SKILL.md`](process/SKILL.md).
- Attach canon from scratch →
  [`process/workflows/bootstrap-project.md`](process/workflows/bootstrap-project.md).
- Change this repository → [`evolve/AGENTS.md`](evolve/AGENTS.md) and
  [`evolve/SKILL.md`](evolve/SKILL.md).
- Game / Godot work → process class, then [`game/AGENTS.md`](game/AGENTS.md)
  and [`game/SKILL.md`](game/SKILL.md).

---

# Агентный SDLC — разработка игр на Godot

Этот репозиторий — **канон** работы ИИ-агентов для проектирования,
сборки, playtest и поставки компьютерных и мобильных игр на **Godot**.
Не продукт. Имена проектов, store-аккаунты, сертификаты, патч-версия
Godot и прод-команды живут в тонком проектном `AGENTS.md`, не здесь.

## Две оси

| Ось | Каталог | Вопрос |
|---|---|---|
| Процесс | [`process/`](process/) | Как агенты работают: класс задачи, роли, артефакты, гейты, GitHub |
| Домен | `<sdlc-root>/<domain>/` | Как агенты производят работу в предметной области |

Сейчас предметный домен один: [`game/`](game/) — Godot, PC и mobile.
Новый домен кладётся в корень репозитория рядом с `game/`, не под
`process/`, не в `domains/`. Форма — как у `game/`. См.
[`process/new-domain.md`](process/new-domain.md).

[`evolve/`](evolve/) — домен «как менять **этот** репозиторий».
Потребитель его **не читает**, пока не контрибьютит в канон.

## Область Godot

Канон предполагает:

- раскладку проекта **Godot** (`project.godot`, сцены, ноды, ресурсы,
  autoload);
- **GDScript** как язык по умолчанию (C# — только если проект явно
  выбрал);
- сигналы, сцены, ресурсы и **export presets** для PC и mobile;
- запуск/отладку в редакторе Godot и, где уместно, headless/CLI
  (`godot` / Godot console);
- экспорт и релиз для PC (Windows / Linux / macOS — как объявит проект)
  и mobile (Android; iOS отдельно, где отличаются подпись и store).

**Мажор/минор версия Godot** — решение проекта, фиксируется в тонком
проектном `AGENTS.md`, а не хардкодится в каждом предложении канона.

## Как подключить как `<sdlc-root>`

Канон подключается в продукт целиком: submodule, subtree или копия.
В проекте каталог может называться `sdlc/`, `vendor/sdlc` и т.п.
В текстах канона путь всегда `<sdlc-root>`.

1. Не редактировать канон под один продукт.
2. Не копировать принципы и рецепты в проектные файлы. Ссылаться.
3. Создать корневой `AGENTS.md` продукта по
   [`process/workflows/bootstrap-project.md`](process/workflows/bootstrap-project.md)
   и шаблону [`process/templates/AGENTS.project.md`](process/templates/AGENTS.project.md).
4. Для каждого известного домена — его `specialize.md`
   (сегодня: [`game/specialize.md`](game/specialize.md)).
5. Настроить GitHub как систему учёта:
   [`process/github.md`](process/github.md) и шаблоны в [`.github/`](.github/).

Следующая задача в продукте читает: корневой `AGENTS.md` →
[`process/workflows/router.md`](process/workflows/router.md) →
нужный домен. Не весь канон сразу.

## Конфликт слоёв

1. Корневой `AGENTS.md` потребителя побеждает в объявленных hard invariants.
2. Проектный `<domain>/AGENTS.md` побеждает в путях, именах и локальных инвариантах.
3. `<sdlc-root>/process` побеждает в процессе, пока стадия явно не выключена.
4. `<sdlc-root>/<domain>` побеждает в стиле и раскладке домена, пока принцип
   явно не переопределён.

Полный текст: [`process/specialize.md`](process/specialize.md).

## Состав

| Путь | Назначение |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Обвязка **этого** репозитория (эволюция канона) |
| [`process/`](process/) | Общий SDLC + GitHub SoR |
| [`evolve/`](evolve/) | Домен изменения канона |
| [`game/`](game/) | Предметный домен Godot: PC и mobile games |
| [`.github/`](.github/) | Issue/PR templates, labels, Actions-заготовки |

## Стадии жизненного цикла (карта)

| Стадия | Где в каноне |
|---|---|
| 1. Анализ | `spec-only` / шаг 1 `feature-cycle` |
| 2. Элаборация (дизайн, lore, systems, UX, tech, scope) | шаг 1–2 + [`game/design.md`](game/design.md), [`game/workflows.md`](game/workflows.md) |
| 3. Разработка | шаг 3 `feature-cycle` / `increment` + рецепты `game/` |
| 4. Запуск и отладка (playable builds) | шаг 4 + `deploy` / `hotfix` + [`game/workflows.md`](game/workflows.md) (debug) |
| 5. Ревью и критика | критик + `review-only` / цикл ревью + [`game/review.md`](game/review.md) |
| 6. Фиксы, тесты, повторные ревью | шаги 5–6 `feature-cycle` |
| 7. Релиз (PC и mobile) | `release` + [`game/platforms.md`](game/platforms.md) |

## Что читает агент

- Работа в чужом продукте, канон уже подключён → корневой `AGENTS.md`
  продукта, затем [`process/SKILL.md`](process/SKILL.md).
- Подключаем канон с нуля →
  [`process/workflows/bootstrap-project.md`](process/workflows/bootstrap-project.md).
- Меняем этот репозиторий → [`evolve/AGENTS.md`](evolve/AGENTS.md)
  и [`evolve/SKILL.md`](evolve/SKILL.md).
- Задача про игру / Godot → класс из process, затем
  [`game/AGENTS.md`](game/AGENTS.md) и [`game/SKILL.md`](game/SKILL.md).
