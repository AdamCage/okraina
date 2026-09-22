# GitHub — система учёта и координации

GitHub — SoR для работы агентов и людей. Чат не заменяет Issue/PR.
Команды ниже — через [`gh`](https://cli.github.com/) и UI; точные
имена репо/org — факты проектного `AGENTS.md`.

## Что обязательно

| Объект | Зачем |
|---|---|
| Issue | Контур / баг / инцидент. Ссылка на `spec.md`, дизайн-пакет, класс router |
| Pull Request | Diff цикла. Ссылка на Issue, `test-report.md`, `review.md` |
| Labels | Класс задачи, платформа, приоритет, стадия |
| Milestone / Project | Версия / спринт / vertical slice |
| Branch protection | Required checks + reviews на default branch |
| Actions | Сборка, тесты, lint, (опционально) upload артефакта |
| Release + tag | Поставка по классу `release` |

Шаблоны канона: [../.github/](../.github/). При bootstrap — скопировать
в продукт и заполнить факты (не принципы).

## Labels (канон)

Определения: [../.github/labels.yml](../.github/labels.yml).

| Группа | Примеры |
|---|---|
| Класс | `class:feature-cycle`, `class:increment`, `class:hotfix`, … |
| Стадия | `stage:analysis`, `stage:elaboration`, `stage:dev`, `stage:playtest`, `stage:review`, `stage:release` |
| Платформа | `platform:pc`, `platform:mobile`, `platform:both` |
| Приоритет | `prio:p0`, `prio:p1`, `prio:p2` |
| Тип | `type:bug`, `type:design`, `type:tech`, `type:docs`, `type:admin` |

Агент при создании Issue/PR ставит минимум: класс + платформа + тип.

## Issue

1. Заголовок = цель игрока/системы, не «fix stuff».
2. Тело — из шаблона: класс router, ссылки на артефакты, acceptance.
3. Не дублировать спеку в Issue: Issue ссылается на файлы.
4. Закрывать Issue через `Fixes #N` в PR, когда контракт выполнен
   и блокеров ревью 0 (или человек принял остаток).

## Pull Request

1. Одна задача / один класс. Не смешивать hotfix и feature.
2. Описание: класс, Issue, что проверено, платформы.
3. Draft PR допустим на время реализации; ready for review —
   когда есть `test-report.md` (если класс требует) и нет
   аналитических блокеров.
4. Review comments ↔ пункты `review.md` (ID `R1`… в тексте комментария).
5. Merge только при green checks и `blocker = 0`, если защита ветки
   и класс это требуют.

## Actions

Канон даёт заготовки workflow, не продакшен-пайплайн чужого движка:

- [../.github/workflows/sdlc-checks.yml](../.github/workflows/sdlc-checks.yml) —
  проверка ссылок / структуры docs (адаптировать);
- [../.github/workflows/build-stub.yml](../.github/workflows/build-stub.yml) —
  плейсхолдер сборки: команды подставляет проект.

Секреты — GitHub Secrets / Environments. Не в yaml и не в логах.

## Branch protection (рекомендация канона)

На default branch:

- require PR;
- require status checks (минимум workflow checks проекта);
- require review от человека или CODEOWNERS, если проект завёл;
- ban force-push;
- ban deletion.

Смена правил — класс `admin` + гейт человека ([gates.md](gates.md)).

## `gh` — типичные команды

Факты репо — из `git remote` / проектного `AGENTS.md`. Примеры:

```bash
gh issue create --title "..." --body-file ... --label "class:feature-cycle,platform:both"
gh pr create --title "..." --body-file ... --draft
gh pr review <n> --comment --body "см. docs/.../review.md R1–R3"
gh pr checks <n>
gh release create vX.Y.Z --notes-file docs/.../release.md
gh label clone <source-repo>   # или применить labels.yml скриптом проекта
```

Не печатать токены. Не `gh` с `--admin` без гейта.

## Стык с классами

| Класс | GitHub |
|---|---|
| `bootstrap-project` | Создать labels, скопировать issue/PR templates, описать protection |
| `spec-only` | Issue + вложения/ссылки на спеку |
| `feature-cycle` / `increment` | Issue → branch → PR → review loop → merge |
| `hotfix` | Issue `type:bug` + PR; ускоренный review, не обход protection без гейта |
| `review-only` | Только PR review + `review.md` |
| `incident` | Issue `prio:p0`; таймлайн в Issue/комментариях |
| `deploy` | Comment в Issue/PR: что/куда/результат; Environment если есть |
| `admin` | PR на `.github/`, branch rules; гейт на protection |
| `release` | Tag + `gh release create` + `release.md` |

## Чего не делать

- Не закрывать Issue «потому что в чате договорились» без артефактов.
- Не вести второй SoR (Notion-роман без ссылки из Issue) как единственный контракт.
- Не класть бинарники билдов в git без LFS-политики проекта.
- Не публиковать store credentials в Actions logs.
