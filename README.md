# Окраина — играбельная Зона, собранная агентами по ИИ-SDLC

Игра **«ЗОНА: Пикник на обочине»** — rogue-like ARPG на Godot 4.7.2 (GDScript) про
аномалии, хабар и Сталкеров. Продуктовый код, ассеты, тесты и релизный конвейер
написаны ИИ-агентами по процессу из [`.gamedev-sdlc/`](.gamedev-sdlc/); человек
вмешивался только на гейтах.

**Играть в браузере (телефон и ПК):** <https://31-130-128-81.sslip.io/>

[![sdlc-checks](https://github.com/AdamCage/okraina/actions/workflows/sdlc-checks.yml/badge.svg?branch=main)](https://github.com/AdamCage/okraina/actions/workflows/sdlc-checks.yml)

- версия игры **0.1.3** (`game/project.godot`, `application/config/version`);
- `game/` — 582 файла: 15 342 строки GDScript в 36 файлах, 480 ассетов на 12,8 МиБ
  (вся графика и звук генерируются скриптами, бинарных исходников нет);
- веб-пак: 557 файлов, 5,82 МиБ — первая загрузка по gzip ~2 с;
- проверки: `--selftest` и `--playtest` (16/16) зелёные, `t_combat` — 91/91.

## Скриншоты

Кадры сняты с живого веб-билда 0.1.3 (1280×720 и Pixel 8 в ландшафте), лежат в
[`docs/screenshots/`](docs/screenshots/).

| Стартовый экран | Главное меню |
|---|---|
| [![Стартовый экран](docs/screenshots/01-start.png)](docs/screenshots/01-start.png) | [![Главное меню](docs/screenshots/02-menu.png)](docs/screenshots/02-menu.png) |
| «ВОЙТИ В ЗОНУ» — обвязка браузерной сборки: разблокировка звука, полный экран, PWA | Логотип, пять кнопок и версия из `project.godot` |
| **Рейд в Зоне** | **Сумка** |
| [![Рейд в Зоне](docs/screenshots/03-zone.png)](docs/screenshots/03-zone.png) | [![Сумка](docs/screenshots/04-inventory.png)](docs/screenshots/04-inventory.png) |
| Мир, HUD, миникарта, трекер квестов, лог событий | 40 слотов, фильтры, снаряжение, артефакты |
| **Журнал** | **Мобильная раскладка** |
| [![Журнал](docs/screenshots/05-journal.png)](docs/screenshots/05-journal.png) | [![Мобильная раскладка](docs/screenshots/06-mobile.png)](docs/screenshots/06-mobile.png) |
| Задания, трекер, детали квеста | Два стика и восемь крупных кнопок на телефоне |


## Что в репозитории: три слоя

| Слой | Путь | Назначение |
|---|---|---|
| Канон процесса | [`.gamedev-sdlc/`](.gamedev-sdlc/) | как агенты работают: классы задач, роли, артефакты, гейты, GitHub как система учёта; предметный домен — `game/` (Godot, PC и mobile) |
| Дизайн-правда | [`docs/world/`](docs/world/) | `spec.md`, `assumptions.md` (OPEN), `LORE.md`, `AUTHOR_TRUTH.md`, `review.md`, `ROADMAP.md` |
| Продукт | [`game/`](game/) | Godot-проект 0.1.3: код, ассеты, тесты, инструменты сборки и деплоя |

Обвязка продукта — тонкая: корневой [`AGENTS.md`](AGENTS.md) (факты, команды,
hard invariants, дополнительные гейты), [`game/AGENTS.md`](game/AGENTS.md)
(пути, тесты, сборка), правила и навыки агента в [`.cursor/`](.cursor/)
(`rules/okraina-game.mdc`, `skills/game-dev`, `skills/sdlc-process`, headless-окружение
Godot 4.7.2 в [`environment.json`](.cursor/environment.json)). Принципы и рецепты
процесса здесь не копируются — канон подключается по ссылке.

## Как это делалось: ИИ-SDLC

Маршрут любой задачи: корневой `AGENTS.md` →
[`router`](.gamedev-sdlc/process/workflows/router.md) → класс задачи → домен
[`game/`](.gamedev-sdlc/game/AGENTS.md). Класс определяет набор ролей, обязательных
артефактов и гейтов, а не «что агент успел сделать».

| Роль | Что делает | Где закреплено |
|---|---|---|
| Аналитик, элаборация | спека, допущения, дизайн-пакет | [`roles/analyst.md`](.gamedev-sdlc/process/roles/analyst.md) |
| Реализатор | код, ассеты, тесты в рамках класса | [`roles/implementer.md`](.gamedev-sdlc/process/roles/implementer.md) |
| Тестировщик | `selftest`, `playtest`, системные тесты, отчёт | [`roles/tester.md`](.gamedev-sdlc/process/roles/tester.md) |
| Критик | разбор решения до ревью | [`roles/critic.md`](.gamedev-sdlc/process/roles/critic.md) |
| Ревьюер | гейт выхода: `blocker = 0` | [`roles/reviewer.md`](.gamedev-sdlc/process/roles/reviewer.md) |
| Релизер | сборка, выкладка, артефакты релиза | [`roles/releaser.md`](.gamedev-sdlc/process/roles/releaser.md) |

**Артефакт важнее кода:** `spec.md`, `assumptions.md` (что принято как допущение,
с явными OPEN), `review.md`, `test-report.md`, `release.md` — шаблоны в
[`.gamedev-sdlc/process/templates/`](.gamedev-sdlc/process/templates/), рабочий
пример прогона — [`.gamedev-sdlc/docs/v0.1.0/`](.gamedev-sdlc/docs/v0.1.0/)
(отчёт тестов, ревью и релиз первого среза).

**Классы задач включены:** `spec-only`, `feature-cycle`, `increment`, `hotfix`,
`review-only`, `admin`. Выключены до явной просьбы: `deploy`, `incident`, `release` —
агент не «сам догадывается» выкладывать в прод.

**Human gates (агент останавливается и спрашивает):** прод-store submit / production
track; IAP и live economy; force-push, перепись истории, снятие branch protection,
wipe сохранений; смена signing и store-credentials в CI; включение выключенных
классов задач. Полный список — [`process/gates.md`](.gamedev-sdlc/process/gates.md)
и раздел «Extra human gates» в [`AGENTS.md`](AGENTS.md).

**GitHub как система учёта:** issue-шаблоны с классом и платформой
([`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE/)), метки
([`labels.yml`](.github/labels.yml)), PR-шаблон с перечнем артефактов, обязательная
проверка `sdlc-checks` и заглушка `build-stub`. Дизайн мира живёт в issues и
`docs/world/` (контур лора — issue #1).

**Что это дало на практике:** 15 342 строки GDScript, процедурная графика и звук,
15 файлов тестов, веб-сборка с деплоем и CI — всё прошло один и тот же цикл:
спека → реализация → плейтест → критик → ревью → выкладка. История версий игры
0.1.0 → 0.1.3 — в [`game/CHANGELOG.md`](game/CHANGELOG.md).

## Что уже играется

- Одна бесшовная Зона ~260×200 тайлов из пяти районов (Кордон, Деревня, Завод,
  Болото, Бункер) плюс аномальное поле; дороги, дома с проходимыми интерьерами,
  пропы с коллизиями, контейнеры, NPC-заказчики.
- Сталкер: бег, рывок, стрельба и ближний бой, фонарь, перезарядка, обыск
  контейнеров, здоровье/силы/радиация, вес и деньги.
- 4 типа врагов со своим ИИ и лутом плюс два босса (Завод и Бункер);
  4 типа аномалий с артефактами внутри.
- Инвентарь на 40 слотов, экипировка (оружие, броня, шлем, три артефакта),
  торговля хламом, отдых у костра.
- Квестовая цепочка: 8 основных и 3 побочных задания, журнал, трекер, диалоги.
- HUD: здоровье/силы/опыт/радиация, патроны, миникарта, трекер, лог событий,
  детектор артефактов, цифры урона.
- Мобильный интерфейс: два виртуальных стика, восемь крупных кнопок, мультитач,
  всё главное меню, пауза, настройки и экран смерти — на русском.
- Сохранение прогресса (на web — в IndexedDB), сид мира восстанавливается из сейва.
- Вся графика и звук генерируются скриптами (`game/tools/gen/`) — в репозитории нет
  ни одного «нарисованного руками» исходника.

Подробности, таблица управления и мобильные детали — в [`game/README.md`](game/README.md).

## Как запустить

Бинарники Godot 4.7.2 кладутся в `tools/godot/` (каталог в `.gitignore`, рядом с
проектом тоже работает). Все команды — из корня репозитория:

```powershell
$g = "tools\godot\Godot_v4.7.2-stable_win64_console.exe"

& $g --headless --path game --import                 # импорт ассетов после клона
tools\godot\Godot_v4.7.2-stable_win64.exe --path game   # поиграть
& $g --headless --path game -- --selftest            # самотест игры, exit 0 = зелено
& $g --headless --path game -- --playtest            # 16 проверок в живой игре
& $g --headless --path game -s res://tests/t_combat.gd   # системные тесты
```

Сборка и выкладка веб-версии:

```powershell
powershell -File game\tools\deploy\build_web.ps1            # импорт → самотест → экспорт → проверка пака
powershell -File game\tools\deploy\build_web.ps1 -Selftest   # то же плюс скриншоты в game\tools\gen\_out\
powershell -File game\tools\deploy\build_web.ps1 -Deploy     # сборка и заливка на ВМ (нужен .env с доступом)
```

## Проверки

| Проверка | Команда | Состояние |
|---|---|---|
| Самотест игры (мир, бой, лут, квесты, сохранение) | `--headless --path game -- --selftest` | exit 0, 10,4 с |
| Плейтест игровых путей в живой игре | `--headless --path game -- --playtest` | 16 проверок, 0 провалов, 6,6 с |
| Бой | `-s res://tests/t_combat.gd` | 91 проверка, 0 провалов |
| Мир и генерация | `-s res://tests/t_world.gd` | 55 проверок, 0 провалов |
| Интерфейс | `-s res://tests/t_ui.gd` | 109 проверок, 2 известных провала (см. «Статус») |
| Содержимое веб-пака | `python game\tools\deploy\check_pck.py` | 557 файлов, 5,82 МиБ, ключевые ресурсы на месте |
| Что отдаёт сервер | `python game\tools\deploy\logs.py` | запросы `index.*`, размеры wasm, топ клиентов |

## Структура

```
AGENTS.md               факты, команды, hard invariants и дополнительные гейты продукта
.gamedev-sdlc/          канон процесса и домен game (под этот продукт не правится)
.cursor/                правила, навыки и headless-окружение головного агента
.github/                issue/PR-шаблоны, метки, CI: sdlc-checks и build-stub
docs/world/             дизайн-правда: спека лора, допущения, ROADMAP
docs/screenshots/       кадры игры для этого README
game/                   Godot-проект 0.1.3 (детали — game/README.md)
  autoload/             assets, game_state, quests, sfx
  scripts/              17 файлов: мир, игрок, враги, аномалии, HUD, меню, сумка, журнал, тач
  scenes/game.tscn      единственная сцена — остальное строится кодом
  tests/                15 файлов: t_combat, t_world, t_ui, самотест, плейтест и пробы
  tools/deploy/         build_web.ps1, deploy.py, check_pck.py, logs.py
  tools/gen/            генераторы графики и звука (выход — в _out/, в gitignore)
  web/head_include.html обвязка браузера: safe-area, экран входа, PWA-манифест
  assets/               480 файлов: атласы, спрайты, шрифты, звуки
  project.godot         1280×720, canvas_items + expand, версия 0.1.3
```

## CI

- `sdlc-checks` — обязательная проверка продуктовой обвязки: наличие
  `AGENTS.md`, `game/AGENTS.md`, `docs/world/README.md`, файлов канона, шаблонов
  GitHub, а также запрет случайного каталога `.common`. История: 4 успешных
  прогона на `main` ([workflow](.github/workflows/sdlc-checks.yml)).
- `build-stub` — заглушка сборки для будущих прогонов Godot на раннере
  ([workflow](.github/workflows/build-stub.yml)); сейчас сборка веб-версии идёт
  локально через `build_web.ps1`.
- Branch protection для `main` пока не включён; в `AGENTS.md` он записан как
  рекомендованный, а его снятие — human gate.

## Статус и открытые пункты

- **Экспорт только веб.** Пресеты PC и Android не настроены (`Export PC: нет`,
  `Export mobile: нет` в `AGENTS.md`); Android объявлен следующей целью, iOS — позже.
- **Живой сайт отдаёт пак до правки `exclude_filter`:** 568 записей и 6 184 120 Б
  против 557 и 6 104 896 Б в репозитории. Лишние 13 записей — само-загрузка
  (`build/web/index.*.png.import`, `index.manifest.json` и их `.ctex`). Актуализация:
  `powershell -File game\tools\deploy\build_web.ps1 -Deploy` (нужен `.env` с доступом к ВМ).
- **2 известных провала `t_ui`:** проверка ожидает `process_mode = WHEN_PAUSED` и
  `Panel`-фолбэк для окон, тогда как код осознанно перешёл на `PROCESS_MODE_ALWAYS`
  и NinePatch из ассетов. Это устаревшие ожидания теста, а не дефект игры —
  пункт на разбор.
- **Один тест мира требует каталога артефактов:** `t_world` падает на сохранении
  отладочной карты, если `game/tools/gen/_out/` отсутствует (каталог в `.gitignore`).
  После его создания 55 проверок проходят.
- **Расходятся имена:** дизайн-правда в `docs/world/` называет игру «Окраина»,
  шиппинговая сборка — «ЗОНА: Пикник на обочине». Единое решение не принято.
- **Лицензия не задана**, `homepage` репозитория пуст — сайт игры живёт только
  ссылкой из README.
- **После сборки Godot перезаписывает `*.import`** (меняется mtime при том же
  содержимом): `git status` показывает десятки «изменённых» файлов без диффа,
  лечится `git add -A`. Разбор — в [`game/AGENTS.md`](game/AGENTS.md).

## Документы

- [`game/README.md`](game/README.md) — игра: состав, управление, сборка, мобильные детали
- [`game/CHANGELOG.md`](game/CHANGELOG.md) — история версий 0.1.0 → 0.1.3
- [`AGENTS.md`](AGENTS.md) и [`game/AGENTS.md`](game/AGENTS.md) — факты продукта и домена
- [`.gamedev-sdlc/README.md`](.gamedev-sdlc/README.md) — что такое канон и как его подключать
- [`.gamedev-sdlc/process/gates.md`](.gamedev-sdlc/process/gates.md) — гейты,
  [`.gamedev-sdlc/process/workflows/router.md`](.gamedev-sdlc/process/workflows/router.md) — маршрутизация задач
- [`docs/world/README.md`](docs/world/README.md) — дизайн-правда о мире Зоны
