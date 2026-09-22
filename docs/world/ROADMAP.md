# ROADMAP.md — следующие стадии «Окраина» (агентский SDLC)

Исполняемый план для следующего агента. **Не wishlist.**  
Каждая стадия = **ровно один** класс из router
(`.gamedev-sdlc/process/workflows/router.md`).

## Текущая база (уже на `main`)

| Что | Где / факт |
|---|---|
| Lore bible v0.1 | `docs/world/` · commit `03930ee` · Issue #1 |
| Playable core | `game/` · Godot 4.7.2 · Issues #2 / #3 · commits `02b983e`, `5376b4d` |
| Цикл сейчас | квартира → 3 этажа гигахруща → melee → death/extract → 1 meta-boon → ЖЭК/`/pod/` текст → дверь за кухней |
| Smoke | `full_smoke.gd` → `FULL_SMOKE_OK` |
| Классы ON | `spec-only`, `feature-cycle`, `increment`, `hotfix`, `review-only`, `admin` |
| Классы OFF | `deploy`, `incident`, `release` — **не планировать** |
| B1 / B2 / B3 | OPEN в `docs/world` (AUTHOR UNSET, топоним, Поезд). Не лочить в плане. Working assumptions — в стадиях |

## Правила исполнения

1. Перед работой: корневой `AGENTS.md` → router → **один** рецепт → `game/AGENTS.md`.
2. Новый контур / новый путь игрока → `feature-cycle`. Дельта к живому контуру → `increment`. Только контракт → `spec-only`.
3. Issue labels минимум: `class:<…>`, `platform:pc` (или `platform:both` позже), `type:design|tech`, стадии `stage:*` по рецепту.
4. Артефакты класть в `game/docs/<feature_id>/` (геймплей) или `docs/world/` (мир). Не спойлерить AUTHOR TRUTH в player text.
5. После кода: headless smoke + запись в `test-report.md`; commit/push только когда человек/задача просят ship инкремента (этот ROADMAP сам **не** требует коммита).
6. `hotfix` / `review-only` / `admin` — по событию, не как «следующая фича».

## Порядок стадий (обязательная последовательность зависимостей)

```
S0 → R1 → R2 → R3 → R4 → R5 → R6 → P1 → A1
         ↘ (опц.) H* / V* / ADM* вклиниваются по событию
```

---

### S0 — Стабилизация контракта роадмапа

| Поле | Содержание |
|---|---|
| **Класс** | `admin` (узко: docs/указатели) **или** пропуск, если агент только читает этот файл |
| **Почему router** | Не новая механика; правка обвязки/указателей SoT |
| **Цель** | Следующий агент видит `ROADMAP.md` из `docs/world/README.md` |
| **In** | Добавить строку в README; при необходимости ссылку в `game/AGENTS.md` Pointers |
| **Out** | Геймплей, новые Issues фич |
| **Входы** | Этот файл |
| **Артефакты** | `docs/world/ROADMAP.md`, правка `README.md` |
| **Exit** | README ссылается на ROADMAP; пути живые |
| **Зависимости** | — |
| **Гейты** | нет |

*Если ROADMAP уже с указателем — S0 считать выполненным и начинать с R1.*

---

### R1 — Сборка билдов внутри забега (roguelite depth)

| Поле | Содержание |
|---|---|
| **Класс** | `feature-cycle` |
| **Почему router** | Новый путь игрока: **выбор способности/предмета во время забега** (не только boon после). Новый контур поверх vertical_slice |
| **Цель (игроку)** | Каждые N убийств / этаж — экран выбора из 3 офферов; билд ощутимо меняет текущий забег |
| **In** | 1 тип оффера (ability **или** weapon mod); 8–12 офферов; UI выбора; статы ТЕЛО/НЕРВ задеты минимально (2 оси) |
| **Out** | Полный Diablo-лут, сеты, крафт, 4 полных архетипа |
| **Входы** | `game/docs/vertical_slice/spec.md`, `docs/world/LORE.md` §RPG-крючок, Issue #2/#3 |
| **Артефакты** | Issue `class:feature-cycle,platform:pc,type:design` → `stage:analysis`…; `game/docs/run_builds/spec.md`, `assumptions.md`, `DESIGN.md`, `ARCHITECTURE.md`, `review.md`, `test-report.md` |
| **Exit** | User paths: получить оффер → выбрать → урон/скорость/эффект меняется **в том же забеге**; headless: симуляция pick + стат-дельта; `FULL_SMOKE`/новый `builds_smoke` зелёный; регрессия death/extract |
| **Зависимости** | Текущий core на `main` |
| **Гейты** | нет (B1 не нужен). Working: офферы не объясняют «что случилось с миром» |

---

### R2 — Имиджборда как система (не тикер)

| Поле | Содержание |
|---|---|
| **Класс** | `feature-cycle` |
| **Почему router** | Новый режим/путь: **интерактивный `/pod/` (и заготовка `/hr/`)** до забега; лиды могут врать |
| **Цель** | В квартире открыть борду, прочитать 3–5 тредов, выбрать «проверить подъезд» → влияет на стартовый этаж / модификатор забега |
| **In** | UI списка тредов + тело; генерация/таблица постов от `last_result`/kills/floors; 1 правдивый / 1 ложный / 1 тролль-лид |
| **Out** | Полный клиент всех бордов, мультиплеер, настоящий http |
| **Входы** | `docs/world/LORE.md` §6, A16; hub `board_feed` сейчас |
| **Артефакты** | `game/docs/imageboard/spec.md` + assumptions/DESIGN/…; Issue labels как у feature-cycle |
| **Exit** | Путь: открыть борду → выбрать тред → старт забега с иным `run_modifier`; headless: выбор лида меняет fingerprint/флаг; тон без AUTHOR-спойлера |
| **Зависимости** | R1 желателен (общие UI-паттерны), но **можно параллелить после спеки**, если не трогать одни сцены без интеграции |
| **Гейты** | нет |

---

### R3 — ЖЭК / объявления как система давления

| Поле | Содержание |
|---|---|
| **Класс** | `increment` на контуре hub **или** `feature-cycle`, если появляется отдельный «журнал объявлений» с правилами |
| **Почему router** | Если только расширяем существующий hub-ticker + 1–2 механики штрафа/баффа — `increment`. Если новый экран + экономика объявлений — `feature-cycle` |
| **Цель** | Объявления ЖЭКа дают **игровой эффект** (штраф к весу, запрет зоны, временный бафф «не оставлять велосипеды» = +dodge) |
| **In** | 5–8 шаблонов объявлений; 2 эффекта; лог в квартире |
| **Out** | Симуляция всего ЖКХ города |
| **Входы** | LORE эстетика; `GameState.zh_ek_notice` |
| **Артефакты** | Дельта в `game/docs/vertical_slice/spec.md` **или** `game/docs/zh_ek/spec.md`; test-report |
| **Exit** | После забега объявление меняет стат/правило на **следующий** забег; headless assert на флаге эффекта |
| **Зависимости** | Core; лучше после R2 (оба читают hub), иначе конфликт merge в `apartment_hub` |
| **Гейты** | нет |

**Рекомендация агенту:** начать R3 как `increment` к hub; эскалировать в `feature-cycle` только если спека потребует отдельный журнал.

---

### R4 — Прогрессия «дверь за кухней» (сюжетный крючок без финала)

| Поле | Содержание |
|---|---|
| **Класс** | `feature-cycle` |
| **Почему router** | Новый сюжетный путь: состояния двери / комната-копия / улики 2002 — новый контур нарратива |
| **Цель** | 3 состояния крючка (закрыто → контур → можно войти в «старую» кухню-копию); 2–3 документа; **без** ответа «что истинно» |
| **In** | Сцена `kitchen_beyond`; журнал «дело»; тексты в тоне LORE |
| **Out** | Полная кампания, лок AUTHOR TRUTH, все версии квартир |
| **Входы** | LORE §крючок, A14; `AUTHOR_TRUTH.md` (только правила письма!) |
| **Артефакты** | `game/docs/kitchen_door/spec.md` + DESIGN (lore slice) + assumptions с **working** «STATE machine only; B1 unset» |
| **Exit** | Пути: 1-й extract → дверь; N extract/death → вход в копию; осмотр ПК/форума 2002 без спойлера; headless флаги state 0→1→2 |
| **Зависимости** | R1 или R2 желательны (мета-прогресс «после N забегов») |
| **Гейты** | **B1 не обязателен** для этой стадии. Если агент хочет «правильный» ответ комнаты — **стоп**, working assumption: комната усиливает ≥2 теории, не выбирает одну |

---

### R5 — Разнообразие гигахруща (контент + лёгкая процедурность)

| Поле | Содержание |
|---|---|
| **Класс** | `increment` (если расширяем `run_floor` / floor table) **или** `feature-cycle` (если новый пайплайн seed+биомы) |
| **Почему router** | Дельта к существующему multi-floor → чаще `increment`. Новый generator-контур → `feature-cycle` |
| **Цель** | ≥6 уникальных layout-пресетов; 2 типа врагов; этажность забега 4–6 с весом «обычные / смещение / техзона» |
| **In** | Данные layout в `resources/`; 2-й enemy; seed в GameState |
| **Out** | Бесконечный гигахрущ AAA, боссы-камеры |
| **Входы** | LORE §5 dungeon-структура; vertical_slice delta |
| **Артефакты** | Дельта spec + `ARCHITECTURE`; расширенный smoke fingerprints ≥6 |
| **Exit** | Два забега с разным seed ≠ одинаковые fingerprints; kill обоих типов врагов в smoke |
| **Зависимости** | R1 (билды на длинном забеге), иначе контент «пустой» |
| **Гейты** | нет |

**Рекомендация:** `increment` с таблицей пресетов; не писать полный procgen engine в одной стадии.

---

### R6 — Восприятие (Perception) как опасная прокачка

| Поле | Содержание |
|---|---|
| **Класс** | `feature-cycle` |
| **Почему router** | Новая ось RPG и новый путь «увидел то, чего не было» |
| **Цель** | Стат Восприятие 1…N; на порогах появляются/исчезают двери, ложные NPC, шум HUD (в духе LORE, без `[невозможно отобразить]` как краша) |
| **In** | 3 порога; 2 визуальных эффекта; связь с meta или оффером R1 |
| **Out** | Полная формула 4 статов + все угрозы Perception 40 |
| **Входы** | LORE §11, A12 |
| **Артефакты** | `game/docs/perception/spec.md`… |
| **Exit** | Headless: perception=low → объект скрыт; =high → видим; death/extract не ломаются |
| **Зависимости** | R1 (источник прокачки), R4 опционально (дверь как perception-объект) |
| **Гейты** | не путать баги и аномалии (A13) — список «намеренных глитчей» в assumptions, иначе только визуал |

---

### P1 — Windows feel / polish (без store)

| Поле | Содержание |
|---|---|
| **Класс** | `increment` (пачка UX/багфиксов одного контура) + точечные `hotfix` по багам |
| **Почему router** | Нет нового фантазийного контура; дельта к обещанному playable |
| **Цель** | Стабильный 60s «ещё один забег» на Windows: пауза, settings (клавиши), понятный HUD, нет softlock |
| **In** | Pause; remap или документированный input; фикс известных дыр smoke |
| **Out** | Steam page, ачивки, `release`, красивый арт |
| **Входы** | `test-report` предыдущих; playtest notes |
| **Артефакты** | Дельты в существующих spec; `test-report`; Issue `class:increment` или `hotfix` |
| **Exit** | Ручной windowed чеклист 10 мин + полный headless suite зелёный |
| **Зависимости** | Хотя бы R1+R2+R4 **или** R1+R5 — иначе полируем слишком тонкий срез |
| **Гейты** | нет. **Не** `release` / store |

---

### A1 — Android readiness (не ship)

| Поле | Содержание |
|---|---|
| **Класс** | `feature-cycle` (новый platform path: touch + export **preset в репо**) **или** `admin` (только CI/docs), если код игры не меняется |
| **Почему router** | Touch controls + mobile layout = новый подход к вводу → обычно `feature-cycle`. Чистая обвязка tooling → `admin` |
| **Цель** | Игра **запускается** на Android-эмуляторе/устройстве с touch move+attack; export preset в проекте; **без** store submit |
| **In** | Virtual stick / buttons; UI safe area; `export_presets.cfg` без секретов |
| **Out** | Google Play, signing в CI, `deploy`/`release` |
| **Входы** | `AGENTS.md` platforms; P1 |
| **Артефакты** | `game/docs/android_touch/spec.md`; labels `platform:mobile` или `platform:both` |
| **Exit** | Документированная команда export; smoke desktop не красный; touch path в editor/device checklist в test-report |
| **Зависимости** | P1 |
| **Гейты** | Signing secrets / store → **человек**. В плане только preset-заготовка. Класс `deploy`/`release` — **не в этом плане** |

---

## Событийные классы (не стадии контента)

| ID | Класс | Когда брать |
|---|---|---|
| H* | `hotfix` | Сломан уже обещанный путь (death/extract/boon/smoke) |
| V* | `review-only` | Просят только critique diff/playtest без правок автора |
| ADM* | `admin` | labels, branch protection (с гейтом), skills, ignore, CI stubs |
| — | `deploy` / `incident` / `release` | **Не в этом плане** (выключены / store) |

## Не в этом плане

- Store submit, IAP, production track  
- Лок B1 AUTHOR TRUTH / канон топонима B2 / Поезд-as-metaphysics B3 (можно **спросить** человека между R4 и «большой нитью», но стадии выше идут на working assumptions)  
- Поезд-hub как замена квартиры (ждёт B3)  
- iOS export (later после A1)  
- Полноценный online / MMO  

## Suggested Issue titles (копипаст)

1. `[feature] Run builds — офферы внутри забега` → R1  
2. `[feature] Imageboard /pod/ как система лидов` → R2  
3. `[increment] ЖЭК-объявления с эффектами на следующий забег` → R3  
4. `[feature] Прогрессия двери за кухней (без финала тайны)` → R4  
5. `[increment] Пресеты этажей гигахруща ×6 + 2-й враг` → R5  
6. `[feature] Восприятие — опасные пороги видимости` → R6  
7. `[increment] Windows polish: pause, HUD, softlock pass` → P1  
8. `[feature] Android touch + export preset (no store)` → A1  

## Старт для следующего агента

1. Открыть Issue по R1.  
2. Router подтверждает `feature-cycle`.  
3. Спека в `game/docs/run_builds/`.  
4. Не начинать A1 и не включать `release`.  
5. B1–B3 не закрывать «заодно».
