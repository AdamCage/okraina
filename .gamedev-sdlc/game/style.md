# Стиль кода и артефактов Godot

Единый вид артефактов и кода. Проект может добавить локальные правила,
но не ослаблять этот файл без явной записи в своём `AGENTS.md`.
Канон по умолчанию — **GDScript**. C# — только если проект явно выбрал;
тогда стиль C# пишет проектный `AGENTS.md`, не этот файл.

## Именование

| Сущность | Форма | Пример-плейсхолдер |
|---|---|---|
| Feature / контур | `snake_case` id | `dash_combo` |
| Docs folder | `docs/<feature_id>/` | `docs/dash_combo/` |
| Scene file | `PascalCase.tscn` или принятый в проекте | `DashArena.tscn` |
| Node in scene | `PascalCase` | `Player`, `HudRoot` |
| GDScript class / file | `snake_case.gd` / `class_name` по проекту | `dash_system.gd` |
| Signal | `snake_case` | `dash_finished` |
| Resource | стабильное имя + `.tres`/`.res` | `dash_tuning.tres` |
| Autoload name | стабильное ASCII | `SaveService` |
| User path id | короткий id | `UP-dash-cancel` |
| Build id | читаемый в логах | из CI / export |
| Issue label platform | `platform:pc` / `mobile` / `both` | |
| Export preset | имя из `export_presets.cfg` | `Windows Desktop` |

Идентификаторы — ASCII. Текст дизайна — язык команды (часто русский).

## Документы

- Спека и дизайн — настоящее время, проверяемые утверждения.
- Не дублировать одно обещание в трёх файлах: ссылка.
- Таблицы вместо простыней, где есть список сущностей.

## Код (GDScript)

- Публичные границы модулей явные; циклы зависимостей сцен/autoload
  не плодить.
- `@export` / ресурсы для баланса, если проект так устроен; не
  магические числа в ветках без нужды.
- Сигналы — контракт; `Callable` / прямые вызовы — осознанный выбор.
- Логи: английский для технических сообщений; с build id / player action id.
- Не логировать PII и токены.
- Ошибки: не глотать пустым `pass`; краш-репортер проекта — если завёден.
- `class_name` и preload — стабильные; переименование = дельта в доке.

## Комментарии

Писать, только если intent или trade-off неочевидны. Запрещены:

- комментарии, дублирующие имя функции;
- декоративные emoji;
- `# increment counter`.

## Тесты

- Unit на чистую логику без полного boot сцены, где возможно.
- Playtest / E2E — из user paths в editor или export, не второй сюжет.
- Фикстуры без секретов и без гигантских production-ассетов.

## Зависимости / addons

- Не добавлять addon «потому что привык», если в проекте есть эквивалент.
- Mobile permissions и privacy манифесты обновлять вместе с плагином/SDK.
- Версия Godot addons совместима с версией из проектного `AGENTS.md`.
