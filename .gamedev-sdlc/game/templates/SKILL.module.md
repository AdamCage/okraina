---
name: <module-name>
description: >-
  Develop and debug the `<feature_id>` Godot system / module. Use when
  editing its scenes, GDScript, resources, signals, or local playable paths.
---

# `<feature_id>` / `<module>`

Канон контура: [ARCHITECTURE.md](ARCHITECTURE.md), [DESIGN.md](DESIGN.md).
Универсальные правила: проектный `AGENTS.md` + `<sdlc-root>/game`.

## Layout

- (сцены / скрипты / ресурсы — по одному предложению каждый)

## Conventions

- Где живёт баланс / `.tres`.
- Как устроен input на PC и mobile (InputMap).
- Какие сигналы публичный контракт.
- Наблюдаемость: какой лог / crash breadcrumb обязателен.
- Ошибки: что `push_error` / assert, что recover.

## Recipe: add a state / step

1. Правило в gameplay-скрипте + тест.
2. Проводка сигнала / UI-сцены / ресурса.
3. `ARCHITECTURE.md`.
4. Если меняется обещание — дельта `DESIGN.md` / `spec.md`.

## Debugging

1. (симптом этого модуля → куда смотреть в editor / Debugger)
2.
3.

## Don't

- (локальные ловушки)
- Секреты / store tokens в этом модуле.
- Ломать uid/пути сцен без дельты в доке.
