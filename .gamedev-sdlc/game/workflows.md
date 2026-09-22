# Рецепты Godot game

Шаги, которые агент повторяет одинаково в Godot-проектах. Имена файлов
ниже — плейсхолдеры; реальные пути берёт из проектного `AGENTS.md`.
Класс задачи уже выбран process.

## Элаборация

Класс: `spec-only` или шаги 1–2 `feature-cycle`.

1. Прочитать проектный `AGENTS.md`: Godot-версия, платформы, budget,
   где docs / сцены.
2. Собрать блокеры (5–7). Остальное — `assumptions.md`.
3. Выбрать срезы из [design.md](design.md). Создать
   [templates/DESIGN.feature.md](templates/DESIGN.feature.md) или узкие файлы.
4. User paths в `spec.md`. Платформенная матрица — явно.
5. Scope: must / later. Vertical slice назван (какая сцена playable).
6. Критик — новый контекст. Human gate.
7. Issue: ссылки + `stage:elaboration`.

Не писать код. Не плодить полный GDD.

## Новый контур / механика

1. Элаборация закрыта (блокеров 0).
2. Минимальная раскладка по [layout.md](layout.md): сцена(ы), скрипты,
   ресурсы, при необходимости autoload.
3. Каркас + `ARCHITECTURE.md` по
   [templates/ARCHITECTURE.system.md](templates/ARCHITECTURE.system.md)
   (сцены ↔ сигналы ↔ данные).
4. Реализация must-scope на GDScript (или C#, если проект так выбрал).
   Контент — минимальный для playable path.
5. Точечные тесты + playable path в editor (F5 / Run) или CLI.
6. Вписать контур в проектный `AGENTS.md` (scope).
7. Draft PR → playtest → review loop (process).

Не копировать чужой контур целиком «чтобы было».

## Новый шаг существующей системы

1. Правило/метод в `.gd` + тест, если есть раннер.
2. Проводка: сигнал, сцена, ресурс, InputMap.
3. Дельта `ARCHITECTURE.md` и при необходимости дизайна.
4. Playtest только затронутых user paths.

## Отладка краша / красного export

1. Repro: устройство / Godot editor, build id, шаги, лог, stack.
2. Системный сбой (boot, save corrupt, missing resource/uid) vs
   единичный кейс контента — разделить.
3. Hotfix-граница: что обещано, что чиним.
4. Фикс минимальный. Не suppress ошибку пустым `pass` в `_ready`.
5. Регрессия repro + соседние пути модуля.
6. Типовые симптомы:
   - boot loop → autoload order / missing scene / wrong main scene;
   - crash on resume (mobile) → lifecycle / `NOTIFICATION_*`;
   - input dead zone → InputMap / touch vs mouse;
   - softlock → FSM / UI blocking / незакрытый popup;
   - save loss → путь `user://`, миграция, permissions;
   - FPS drop → Profiler / Monitors + budget; фича vs регрессия соседа;
   - broken export → preset, feature tags, missing plugin, signing.

Сначала модульный `SKILL.md` контура, если есть.

## Playtest

1. Взять user paths из спеки. Шаблон сессии:
   [templates/PLAYTEST.md](templates/PLAYTEST.md) (можно вложить в
   `test-report.md`).
2. Платформы из контракта. Touch не заменять мышью на mobile-контуре.
3. Зафиксировать build id (editor / export), устройство, результат.
4. Баги → Issue `type:bug` или пункты review; не чинить «втихую»
   без учёта, если это чужой PR (review-only).

## Локальная проверка

Команды — из проектного `AGENTS.md`. Типичный каркас:

```bash
# unit / GUT / проектный раннер
<project-test-command>

# editor / headless smoke (путь к godot — факт проекта)
godot --path . --quit-after 1
# или: Godot_v<ver>_console.exe --path . …

# export smoke (preset из проекта)
godot --headless --export-release "<PresetName>" <output>
```

Не ходить в production store и live economy с локальной машины,
если проект это явно не разрешил.

## PC release path

1. Class `release` подтверждён.
2. `release.md` + GitHub tag/release.
3. Export PC-пресета(ов) из `export_presets.cfg` (Windows / Linux /
   macOS — как объявил проект). Spot-check boot + critical path.
4. Upload по проектным командам (SteamPipe / itch / …).
5. Запись канала и build id в `release.md`.

## Mobile release path

1. Class `release` + гейт на public, если не internal.
2. Certificates / keystore / provisioning на месте (Secrets), не в git.
3. Export Android (и iOS, если в контракте). Версии versionName /
   versionCode / CFBundleVersion согласованы с проектом.
4. Internal track / sideload → smoke на устройстве.
5. Listing / screenshots / privacy — [templates/RELEASE.store.md](templates/RELEASE.store.md).
6. Public submit только по явной просьбе.
7. Запись в `release.md`: track, build number, статус review.
   iOS: отдельно отметить signing / App Store Connect, если путь иной.

## Ревью чужого diff-а

Чеклист: [review.md](review.md). Не переписывать стиль, если он уже
соответствует канону.

## Чего не делать в рецептах

- Не генерировать второй «временный» Godot-проект в корне без ignore.
- Не чинить флаки увеличением wait без понимания причины.
- Не смешивать store listing rewrite с gameplay feature в одном PR
  без явного класса/просьбы.
- Не коммитить debug export с зашитым keystore password.
