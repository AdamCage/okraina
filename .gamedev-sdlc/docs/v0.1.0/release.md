# release.md — gamedev-sdlc v0.1.0

Только поставка. Новых фич в этом файле нет.
Первый опубликованный релиз канона: специализация под Godot +
двуязычный README.

## Что вошло

- SHA: `31be365d0542d65775f5d1e57dfac716b5b6b7d3`
- Контуры / домены: `process/`, `evolve/`, `game/` (Godot), `.github/`,
  корневые `README.md` / `AGENTS.md`, `docs/v0.1.0/`
- Ссылка на проверки: [test-report.md](test-report.md), [review.md](review.md)

### Изменения этого релиза

- Домен `game/` специализирован под Godot (раскладка, GDScript,
  сигналы/сцены/ресурсы, export presets, editor/CLI, PC+mobile).
- `README.md` — полный английский и полный русский в одном файле.
- Шаблоны bootstrap / project AGENTS и skill pointers обновлены под Godot.
- Пример `.sdlc.exmaple/` не входит в релиз и не коммитится.

## Совместимость

- Ломает потребителей? да — канон больше не «движок на выбор»;
  ожидается Godot. Потребителю: указать версию Godot и presets в
  тонком `AGENTS.md`; перечитать `game/specialize.md`.
- Что сделать потребителю: подключить репозиторий как `<sdlc-root>`;
  корневой `AGENTS.md` — по `process/templates/AGENTS.project.md`;
  скопировать `.github/` templates/labels; не читать `evolve/`, пока
  не контрибьютят.

## Платформы

| Платформа | Статус | Канал | Заметка |
|---|---|---|---|
| PC | n/a | — | Канон SDLC (Godot), не игра |
| Mobile iOS | n/a | — | Путь описан в `game/platforms.md` |
| Mobile Android | n/a | — | Путь описан в `game/platforms.md` |

## Откат

- Как вернуть предыдущую версию: предыдущего тега нет; не подключать
  эту ревизию / снять submodule на коммит до `v0.1.0`.

## Публикация

- Тег: `v0.1.0`
- GitHub Release: да (по просьбе человека)
- Deploy этой версией просили? нет (канон, не store)
