---
name: <domain>
description: >-
  (одно предложение: когда звать этот skill; без имён продукта)
---

# `<domain>` — skill

Канон подхода. Пути и запреты проекта — в `<domain-root>/AGENTS.md`.

Стык с процессом:

- новый контур → класс `feature-cycle` или `increment`, затем рецепты здесь;
- красный прогон / сломанное обещание → `hotfix` или `incident`, затем debug;
- ревью diff-а домена → `review-only` + [review.md](review.md).

## Что прочитать по задаче

Сначала [AGENTS.md](AGENTS.md) и проектный `AGENTS.md`. Дальше одна строка:

| Задача | Читать |
|---|---|
| (типовая работа) | [workflows.md](workflows.md) |
| Стиль / имена | [style.md](style.md) |
| Раскладка / граф | [layout.md](layout.md) |
| Зачем инварианты | [principles.md](principles.md) |
| Ревью | [review.md](review.md) |
| Подключить в продукт | [specialize.md](specialize.md) |

## Короткие запреты

- Не повторять роли и router process.
- Не писать `@`-рецепты, которых нет в workflows.
- Не класть секреты в примеры.
