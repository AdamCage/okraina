# Как специализировать обвязку Godot game под проект

`<sdlc-root>/game` задаёт подход для Godot. Репозиторий добавляет
факты: какие контуры есть, какая версия Godot, какие платформы,
какие budget и запреты.

Сначала процесс: `<sdlc-root>/process/workflows/bootstrap-project.md`
и `<sdlc-root>/process/specialize.md`. Этот файл — только домен.

## Что писать в проектном `AGENTS.md`

Держать коротким. Структура — шаблон
[templates/AGENTS.project.md](templates/AGENTS.project.md).

Обязательно:

- ссылка на `<sdlc-root>/game/AGENTS.md` в первых абзацах;
- Godot версия (мажор/минор) / путь к бинарнику / где `project.godot`;
- язык: GDScript (по умолчанию) или C# (явный opt-in);
- список платформ, export presets и store-каналов;
- performance budgets;
- список контуров / docs paths / ключевых сцен;
- локальные инварианты (save path `user://…`, запрет трогать IAP X, …);
- команды test / editor play / headless / export PC / export mobile /
  internal deploy;
- куда смотреть за живым дизайном и краш-репортерами.

Не копировать сюда принципы, стиль и рецепты канона. Ссылка.

## Что писать в модульном `SKILL.md`

Cookbook модуля: раскладка сцен/скриптов, рецепт «добавить состояние
*здесь*», типичные поломки *этой* системы. Шаблон:
[templates/SKILL.module.md](templates/SKILL.module.md).

## Что писать в `ARCHITECTURE.md`

Граф сцен/нод/сигналов, контракты ресурсов, модель ошибок **этого**
контура. Шаблон: [templates/ARCHITECTURE.system.md](templates/ARCHITECTURE.system.md).
Меняется вместе с кодом.

## Cursor / другие агентские инструменты

- skill проекта с `description` про Godot game и указателем на
  `<sdlc-root>/game/SKILL.md` (и на `<sdlc-root>/process`, если
  обвязка процесса ещё не повешена);
- rule с glob на игровые пути (`**/*.gd`, `**/*.tscn`, `**/*.tres`,
  `scenes/**`, `docs/**`) и двумя ссылками: канон + проектный `AGENTS.md`.

## Новый репозиторий с нуля

1. Подключить канон как `<sdlc-root>` (subtree / submodule / копия).
   Не редактировать канон под одну игру.
2. Пройти `<sdlc-root>/process/workflows/bootstrap-project.md`
   (включая GitHub templates/labels).
3. Создать `<game-root>/AGENTS.md` из шаблона (версия Godot, presets).
4. Создать первый контур по [workflows.md](workflows.md) (элаборация → код).
5. Заполнить `DESIGN` / `ARCHITECTURE` по необходимости.
6. Корневой `AGENTS.md` продукта ссылается на process и на этот домен.

## Когда расширять канон, а не проект

В `<sdlc-root>/game` — только то, что должно быть верно для *любого*
следующего Godot-проекта: новый инвариант, паттерн элаборации,
уточнение platform/export checklist. Подъём — `<sdlc-root>/evolve/`,
не правка vendor-копии.

В проект — имена, конкретная версия Godot, сервисы, исключения,
числа budget, имена presets.

Если одно и то же исключение появилось в третьем репозитории — поднять
его в канон или явно описать как допустимый вариант, а не размножать
копипасту.
