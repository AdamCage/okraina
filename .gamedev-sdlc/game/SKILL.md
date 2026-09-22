---
name: game-dev
description: >-
  Design, implement, playtest, review, and release PC and mobile Godot
  games with an agentic SDLC: living design slices, scenes/signals,
  GDScript, export presets, playable builds, and store-aware releases.
  Use for GDD slices, systems, UX, Godot scenes, device testing,
  performance budgets, or PC/mobile shipping.
---

# Game development — Godot skill

Канон подхода для Godot. Проектные пути, версия Godot и запреты —
в `<game-root>/AGENTS.md`. Не дублировать их здесь.

Стык с процессом (`<sdlc-root>/process`):

- новый контур / новая механика → класс `feature-cycle` или `increment`,
  затем рецепты ниже;
- краш / красный export / сломанный playable path → `hotfix` или `incident`,
  затем «Отладка» в [workflows.md](workflows.md);
- ревью gameplay/diff / playtest-критика → `review-only` + [review.md](review.md);
- ship / store → класс `release` + [platforms.md](platforms.md).

## Что прочитать по задаче

Сначала [AGENTS.md](AGENTS.md) и проектный `AGENTS.md`. Дальше только
нужная строка:

| Задача | Читать |
|---|---|
| Элаборация: дизайн, lore, systems, UX, tech, scope | [design.md](design.md), [workflows.md](workflows.md) («Элаборация») |
| Новый контур / механика / сцена | [workflows.md](workflows.md), [layout.md](layout.md) |
| Стиль / именование GDScript | [style.md](style.md) |
| Спорим, *как* проектировать | [principles.md](principles.md) |
| PC vs mobile, export, stores, certificates, budgets | [platforms.md](platforms.md) |
| Ревью diff-а / критика дизайна / playtest | [review.md](review.md) |
| Подключаем обвязку в другой репозиторий | [specialize.md](specialize.md) |
| Правка конкретного контура | его `DESIGN.md` + `ARCHITECTURE.md` + модульный `SKILL.md` |

## Рабочий цикл

1. Найти контур по проектному `AGENTS.md` / Issue. Не угадывать пути.
2. Понять слой: дизайн, сцена/скрипт, ресурс, export/platform.
3. Следовать рецепту в [workflows.md](workflows.md). Не изобретать второй
   способ, если в модуле уже есть паттерн.
4. Сохранить инварианты AGENTS.md (scope, платформы, budget, секреты).
5. Обновить живые доки контура, если изменились обещание или раскладка.
6. Прогнать точечный тест / playable path из проектного `AGENTS.md`
   (editor Run или CLI `godot`).

## Короткие запреты

- Не писать полный GDD вместо узкого среза.
- Не игнорировать mobile/PC расхождения «потому что сначала PC».
- Не класть keystore / provisioning / store tokens в git.
- Не маскировать краш увеличением timeout / suppress.
- Не шипить store без класса `release` и гейта человека.
- Не менять live economy / wipe save без гейта.
- Не подменять GDScript на C# без явной записи в проектном `AGENTS.md`.

## Шаблоны

- [templates/AGENTS.project.md](templates/AGENTS.project.md)
- [templates/DESIGN.feature.md](templates/DESIGN.feature.md)
- [templates/ARCHITECTURE.system.md](templates/ARCHITECTURE.system.md)
- [templates/SKILL.module.md](templates/SKILL.module.md)
- [templates/PLAYTEST.md](templates/PLAYTEST.md)
- [templates/RELEASE.store.md](templates/RELEASE.store.md)
