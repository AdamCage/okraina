# AGENTS.md — этот репозиторий

Канон агентского SDLC для **Godot** game development (PC и mobile),
не продукт. Нет имён конкретных игр, store-аккаунтов, сертификатов,
прод-команд чужих систем. Версия Godot и пути — у потребителя.
Факты здесь только про эволюцию канона.

Если этот файл расходится с [`process/AGENTS.md`](process/AGENTS.md)
в объявленных ниже пунктах — побеждает этот файл.

## Когда какой слой

| Слой | Когда |
|---|---|
| [`process/`](process/) | Всегда. Класс задачи — [`process/workflows/router.md`](process/workflows/router.md) |
| [`evolve/`](evolve/) | Меняем `process/`, `evolve/`, доменный канон, корневые README/AGENTS, шаблоны, skill/rule, `.github/` этого репо |
| [`game/`](game/) | Меняем канон game |

Потребитель канона `evolve/` не читает. Агент здесь — читает.

## Включённые классы

Включены: `spec-only`, `feature-cycle`, `increment`, `review-only`, `admin`.

Обычно выключены: `deploy`, `incident`.

`hotfix` — только если сломали опубликованный контракт потребителя
(входной путь, правило конфликта, шаблон обвязки).

`bootstrap-project` здесь — проверка, что рецепт живой, не поставка продукта.

`release` — только по явной просьбе человека версионировать канон.

## Hard invariants этого репозитория

Не дублируют [`process/AGENTS.md`](process/AGENTS.md) и
[`evolve/AGENTS.md`](evolve/AGENTS.md). Ссылки. Дополнительно:

1. Аналитика здесь — контракт для агентов (спека изменения канона),
   не GDD чужой игры.
2. E2E здесь: bootstrap на вымышленном репо даёт тонкий проектный
   `AGENTS.md` со ссылками и без копипасты принципов; новая задача
   попадает в верный workflow и домен.
3. GitHub — система учёта канона: Issues/PR для изменений,
   labels из [`.github/labels.yml`](.github/labels.yml), теги релизов
   через `gh`. Секреты store/CI не коммитить.

## Human gates

Спросить человека до:

- смены hard invariants процесса;
- переименования входных файлов (`README`, `process/AGENTS.md`,
  `process/workflows/router.md`, `*/specialize.md`, `*/SKILL.md`);
- удаления домена;
- смены правил конфликта;
- публикации GitHub Release / тега канона.

Остальные гейты — [`process/gates.md`](process/gates.md) и
[`evolve/AGENTS.md`](evolve/AGENTS.md).

## Проверка

- dry-run [`process/workflows/bootstrap-project.md`](process/workflows/bootstrap-project.md)
  на вымышленном репо: тонкий `AGENTS.md`, ссылки, нет скопированных принципов;
- живые относительные ссылки;
- новый класс задач — строка в router и в [`process/artifacts.md`](process/artifacts.md);
- у домена есть SKILL-таблица «задача → что читать»;
- `.github/` шаблоны ссылаются на существующие классы router.

## Указатели

- Процесс: [`process/AGENTS.md`](process/AGENTS.md), [`process/SKILL.md`](process/SKILL.md)
- GitHub: [`process/github.md`](process/github.md)
- Эволюция: [`evolve/AGENTS.md`](evolve/AGENTS.md), [`evolve/SKILL.md`](evolve/SKILL.md)
- Game: [`game/AGENTS.md`](game/AGENTS.md), [`game/SKILL.md`](game/SKILL.md)
- Специализация потребителя: [`process/specialize.md`](process/specialize.md)
