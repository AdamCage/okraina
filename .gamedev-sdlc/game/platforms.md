# Платформы: PC и mobile (Godot)

Расхождения lifecycle, которые нельзя оставлять «на потом».
Конкретные store-аккаунты, путь к `godot`, имена export presets —
проектный `AGENTS.md`.

## Матрица

| Тема | PC | Mobile |
|---|---|---|
| Input | Клавиатура / мышь / геймпад | Touch / жесты; геймпад опционально |
| UI | Курсор, окна, safe area реже | Safe area, notch, DPI, one-hand |
| Lifecycle | Focus / alt-tab | Background / resume / OS kill |
| Performance | Desktop GPU tiers | Device tiers + thermal; строже budget |
| Distribution | Steam / itch / MS Store / installer | App Store / Google Play tracks |
| Signing | Иногда code signing | Обязательны certificates / keystore |
| Permissions | Редко | Camera, notifications, tracking — явно |
| Updates | Патч / depot | Store review + staged rollout |
| Monetization | Часто one-time / DLC | Часто IAP / ads — отдельный контракт |
| QA | Keyboard paths + pad | Device farm / физические устройства |
| Godot export | Windows / Linux / macOS presets | Android preset; iOS — отдельный signing path |

## В контракте

Спека и дизайн обязаны сказать:

1. Какие платформы в *этом* контуре (PC / mobile / both).
2. Что одинаково, что расходится.
3. Целевой performance profile (из проектного списка).
4. Какие export presets участвуют.
5. Нужен ли store listing change в этом ship.

Нет строки — критик ставит блокер на feature-cycle с «both».

## Performance budgets

Проект задаёт числа. Канон задаёт правило:

- budget назван в `<game-root>/AGENTS.md` (fps, memory, cold start, size);
- превышение на целевом profile = `blocker` в ревью/playtest;
- hotfix не обязан улучшать budget соседей, но не должен его ломать;
- измерять в editor Profiler / на device export, не «на глаз».

## Device / local runs

| Цель | Типичный путь |
|---|---|
| Dev loop | Godot editor Run (F5) / remote debug |
| Headless / CI smoke | `godot --headless` / console binary — команды проекта |
| Playable build | Export preset → локальный или CI artifact |
| Device | Android sideload / internal track; iOS TestFlight / device |
| Store | Class `release` + гейт |

Команды — только из проектного `AGENTS.md`. Не выдумывать
`adb` / `xcrun` / SteamPipe / точный путь к Godot, если их нет в обвязке.

## Certificates и секреты

- Signing identity / keystore — CI Secrets / Environments.
- Не логировать пароли keystore; не класть их в `export_presets.cfg`.
- Ротация сертификата — `admin` + гейт, не hotfix «заодно».
- iOS: provisioning / capabilities отличаются от Android — явная
  строка в проектном `AGENTS.md`, если iOS в scope.

## Store listings

Чеклист поставки: [templates/RELEASE.store.md](templates/RELEASE.store.md).
Тексты стора и скриншоты — артефакты релиза, не код механики.
Изменение IAP product id — контракт + возможно отдельный Issue.

## Чего не делать

- Не обещать «mobile later» внутри PR, который уже label `platform:both`.
- Не тестировать touch-only UX только мышью и считать mobile закрытым.
- Не шипить public track без прогона internal.
- Не считать editor Run достаточным доказательством export-пути на
  целевой платформе, если контракт требует device/export.
