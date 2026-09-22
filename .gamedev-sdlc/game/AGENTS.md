# AGENTS.md — обвязка Godot game development

Правила для ИИ-агентов, которые проектируют, разрабатывают, отлаживают
и релизят компьютерные и мобильные игры на **Godot**. Файл общий для
Godot-проектов. Локальные имена, пути, версия Godot, export presets
и запреты — в `<game-root>/AGENTS.md` того репозитория.

Читать вместе с [SKILL.md](SKILL.md). Если этот файл расходится с
корневым `AGENTS.md` репозитория, побеждает корневой в своих
инвариантах.

Класс задачи — `<sdlc-root>/process/workflows/router.md`. Этот файл
не заменяет процесс.

## Когда применять

Любая работа с игровым дизайном, lore, systems, UX, сценами/нодами,
GDScript (или опциональным C#), ресурсами, autoload, UI, аудио/VFX,
сборками через export presets, device/playtest, store-чеклистами,
перфоманс-бюджетами платформ.
Не применять к чистому бэкенду live-ops, который живёт как отдельный
сервисный домен — у него своя обвязка (или тонкая проект-локальная).

## Порядок чтения

1. Корневой `AGENTS.md` потребителя и класс из
   `<sdlc-root>/process/workflows/router.md`.
2. Этот файл.
3. Проектный `<game-root>/AGENTS.md`.
4. По задаче — файлы из таблицы в [SKILL.md](SKILL.md).
5. `DESIGN.md` / `ARCHITECTURE.md` / модульный `SKILL.md` контура,
   если они есть.

Не читать все reference-файлы сразу.

## Hard invariants

1. **Playable path важнее абстракции.** Новая механика доказана
   запускаемым путём игрока (Godot editor / exported build), не только UML.
2. **Дизайн-пакет живой и урезанный.** Пишут только срезы, без которых
   нельзя реализовать и принять контур. Полный GDD «на будущее»
   запрещён. Меню срезов — [design.md](design.md).
3. **Scope режут явно.** Vertical slice / out-of-scope живут в спеке
   и дизайне. «Заодно» в код не протаскивают.
4. **Платформы — часть контракта.** PC и mobile расхождения
   (input, performance, store, lifecycle) фиксируют в спеке /
   [platforms.md](platforms.md), не «потом на портировании».
5. **Движок — Godot.** Канон рассчитан на Godot. Язык по умолчанию —
   **GDScript**; C# — только если проектный `AGENTS.md` явно выбрал.
   Версия Godot (мажор/минор) и путь к бинарнику — факты проекта.
6. **Данные контента отдельно от кода механики**, где проект это
   позволяет: `.tres` / `.res` / ресурсы и таблицы не хардкодят баланс
   в ветках без нужды.
7. **Сохранения и экономика идемпотентны к патчу.** Миграции save /
   inventory — явный контракт; тихий wipe запрещён без гейта.
8. **Перфоманс-бюджет платформы — гейт качества.** Превышение budget
   на целевом device/profile = blocker, не nit.
9. **Нет секретов в репо.** Keystore, provisioning, store API tokens,
   `.env` с ключами — Secrets/CI, не git.
10. **Архитектура контура документируется вместе с кодом.** Смена
    сцен / нод / autoload / зависимостей = правка `ARCHITECTURE.md`
    в том же изменении.

## Где живёт работа

| Слой | Что здесь | Чего здесь нет |
|---|---|---|
| `docs/<feature>/` (типично) | `spec.md`, дизайн-срезы, review/test/release | Секреты, бинарники билдов без политики LFS |
| Scenes / scripts | Механики, сигналы, UI-сцены | Store credentials |
| Resources / data | Баланс, уровни, локализация-ключи | Хардкод секретов |
| Export / platform | Export presets, CI jobs, signing wiring | Бизнес-правила механик |
| Store ops | Listings, tracks — по рецепту release | Новый gameplay «в том же PR» |

Точные пути — проектный `AGENTS.md` и [layout.md](layout.md).

## Стиль и процесс (кратко)

Полные тексты: [style.md](style.md), [principles.md](principles.md),
[design.md](design.md), [layout.md](layout.md), [platforms.md](platforms.md),
[workflows.md](workflows.md), [review.md](review.md).

- Имена сцен, нод и скриптов стабильные; стиль — [style.md](style.md)
  и принятый в проекте GDScript.
- Комментарии только про неочевидный intent / trade-off.
- Тесты — рядом с модулем; playtest — из user paths в editor / export.
- Перед store submit, wipe сохранений, force-push — спросить человека.

## Специализация

Как сузить этот канон под репозиторий: [specialize.md](specialize.md).
Шаблоны: [templates/](templates/).
