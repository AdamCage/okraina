---
name: sdlc-process
description: >-
  Classify an SDLC task, bootstrap a project wrapper around this canon,
  run feature-cycle / increment / hotfix / review / release, or specialize
  the canon into a game product repo. Use when a repo attached <sdlc-root>,
  when starting any non-trivial change, or when the user asks for spec,
  game design elaboration, implementation, playtest, review, hotfix,
  incident, deploy, or release.
---

# Процесс — skill

Канон подхода. Проектные пути, команды и выключенные стадии —
в корневом `AGENTS.md` потребителя. Не дублировать их здесь.

## Что прочитать по задаче

Сначала [AGENTS.md](AGENTS.md) и корневой `AGENTS.md` потребителя.
Дальше только нужная строка:

| Задача | Читать |
|---|---|
| Неясно, какой это класс | [workflows/router.md](workflows/router.md) |
| Подключить канон в продукт | [workflows/bootstrap-project.md](workflows/bootstrap-project.md), [specialize.md](specialize.md), [github.md](github.md) |
| Только аналитика / контракт | [workflows/spec-only.md](workflows/spec-only.md), [artifacts.md](artifacts.md) |
| Новый контур / новая фича / новая механика | [workflows/feature-cycle.md](workflows/feature-cycle.md) |
| Дельта к существующему контуру | [workflows/increment.md](workflows/increment.md) |
| Срочный баг на известном поведении | [workflows/hotfix.md](workflows/hotfix.md) |
| Ревью чужого diff-а / playtest-критика | [workflows/review-only.md](workflows/review-only.md), [review.md](review.md) |
| Прод / live-ops сломан | [workflows/incident.md](workflows/incident.md) |
| Выкатить уже собранное (build / store track) | [workflows/deploy.md](workflows/deploy.md) |
| CI, права, labels, branch protection, editor | [workflows/admin.md](workflows/admin.md), [github.md](github.md) |
| Версия / тег / GitHub Release / store ship | [workflows/release.md](workflows/release.md) |
| Завести предметный домен | [new-domain.md](new-domain.md) |
| Какие артефакты обязательны | [artifacts.md](artifacts.md) |
| Где стоп до человека | [gates.md](gates.md) |
| GitHub Issues / PR / labels / Actions | [github.md](github.md) |
| Роль (что делать / не делать) | [roles/](roles/analyst.md) |

После класса — `SKILL.md` затронутого домена. Не читать все домены.

## Короткие запреты

- Не начинать код, пока router не назвал класс.
- Не подменять `feature-cycle` чатом без `spec.md`.
- Не чинить ревьюемым тот же diff.
- Не копировать этот каталог в проектный `AGENTS.md`.
- Не открывать `evolve/`, если задача — продукт, а не этот канон.
- Не вести учёт работы только в чате в обход GitHub Issue/PR.
