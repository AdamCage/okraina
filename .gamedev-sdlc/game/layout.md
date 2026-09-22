# Раскладка Godot-проекта

Типичное дерево. Проект имеет право иначе — тогда пути пишет
`<game-root>/AGENTS.md`. Канон рассчитан на Godot.

```
<game-root>/
  AGENTS.md                 # проектная специализация домена
  project.godot             # корень проекта Godot
  docs/
    <feature_id>/
      spec.md
      assumptions.md
      DESIGN.md             # или срезы: systems.md, ux.md, …
      ARCHITECTURE.md
      review.md
      test-report.md
      release.md            # если этот контур шипят отдельно
  scenes/                   # .tscn (и вложенные инстансы)
  scripts/ | …              # .gd (GDScript по умолчанию)
  resources/ | data/        # .tres / .res / таблицы баланса
  autoload/                 # синглтоны из Project Settings → Autoload
  addons/                   # плагины; версия и license — факт проекта
  export_presets.cfg        # профили экспорта (секреты — не сюда)
  tests/ | …                # unit/integration — факт проекта
  builds/ | export/         # артефакты; обычно gitignore
  .github/                  # Actions, templates (часто в корне репо)
```

Точные имена каталогов (`scenes/` vs `src/`) — проект. Обязательны
`project.godot` и явное место сцен / скриптов / ресурсов в
`<game-root>/AGENTS.md`.

## Контур

Контур = одна механика / режим / система с живой спекой.
Имена стабильные: `<feature_id>` в docs и labels Issue.

| Артефакт | Когда |
|---|---|
| `spec.md` | всегда для feature-cycle / increment с дельтой |
| `DESIGN.md` (срезы) | элаборация нового игрового обещания |
| `ARCHITECTURE.md` | появился/изменился граф сцен/нод/сигналов/autoload |
| модульный `SKILL.md` | пакет нетривиален; шаблон [templates/SKILL.module.md](templates/SKILL.module.md) |

## Слои (логические, в терминах Godot)

| Слой | Ответственность | Типичные артефакты |
|---|---|---|
| Presentation / UI | Ввод, HUD, экраны | Control-сцены, InputMap |
| Gameplay / systems | Правила, FSM, симуляция | Node / Node2D / Node3D + `.gd` |
| Content / data | Баланс, уровни, локализация | `.tres`, `.res`, CSV/JSON по проекту |
| Services | Save, net, analytics, IAP adapters | Autoload + адаптеры |
| Platform | Export presets, permissions, store hooks | `export_presets.cfg`, CI |

Не смешивать store hooks с правилами механики в одном «god node».

## Сцены, ноды, сигналы, ресурсы

- Сцена (`.tscn`) — единица композиции; инстансы вместо копипасты деревьев.
- Сигналы — явный контракт между нодами; не заменять скрытыми
  глобальными мутациями без нужды.
- Ресурсы (`.tres` / `.res`) — данные и конфиги; баланс не прятать
  в ветках скрипта без причины.
- Autoload — общие сервисы; не свалка всего игрового состояния.

## Ассеты

- Источник истины импорта — Godot import + политика проекта
  (LFS / внешнее хранилище).
- Канон запрещает секреты в ассетах и гигантские бинарники в git
  без политики проекта.
- Имена ассетов стабильные; переименование ломает `uid` / пути —
  дельта в доке.

## Сборки и export

Каталог export/builds не коммитить по умолчанию. CI artifact /
GitHub Release assets — факт проекта. Build id должен быть читаем
в runtime логах. Export presets называют платформы из контракта;
пароли keystore / entitlements — Secrets, не `export_presets.cfg` в git.
