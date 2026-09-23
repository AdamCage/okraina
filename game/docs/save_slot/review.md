# review.md — save_slot (E4)

Итерация: `1` ревью реализации. Ревьюер не патчит этот diff.
Аналитика закрыта своим проходом (итерация 2). Секция analytics и строки C1–C3 ниже сохранены.

## Вердикт

- Блокеров: `0`
- Выход разрешён: да
- Дедлок: нет

Цикл можно закрывать. Открытых пунктов нет.

## Пункты

Ревью реализации новых строк не открыло. C1–C3 — история аналитики, все закрыты.

| ID | Суть (проблема / риск / пробел) | Приоритет | Статус | Итерация |
|---|---|---|---|---|
| C1 | Прежние смоуки в начале прогона обязаны удалить `user://slot.json` и сбросить мета-поля хаба к новой игре, чтобы слот, уже прочитанный в `GameState._ready`, не ронял `floors_smoke` (`last_result`) и `builds_smoke` (`pending_boon`) | high | closed | 1 |
| C2 | JSON-число для `version`, `last_kills` и `last_floors` годится как int и как float без дробной части; ненулевая дробная часть — порча | high | closed | 1 |
| C3 | Поздняя запись квартиры заменяет битый слот годным файлом версии 1, бытовая строка в нём — обычный `zh_ek_notice`. SV2 квартиру не открывает. Копия по другому пути не затрагивается | mid | closed | 1 |

## Секция analytics

| ID | Суть | Блокер? | Статус |
|---|---|---|---|
| C1 | Контракт снаружи и A4 требуют от `full`, `loop`, `combat_feel`, `builds`, `floors` в начале прогона сбросить мета-поля хаба к новой игре и удалить `user://slot.json`. Чтение в `_ready` этим не отменяется. У пустого `GameState` `last_result` пустой, `pending_boon` — `none`, поэтому чужой `extract` не доходит до раннего выхода `floors_smoke`, а чужой `pending_boon` не копируется в `active_boon` на `go_run` в `builds_smoke`. | нет | closed |
| C2 | П.3: те же три ключа принимаются и как int, и как float без дробной части: Godot читает JSON-число как float. Ненулевая дробная часть — порча, чтение не удалось. Запись кладёт целые, поэтому SV1 «записал флаг → новый GameState → load вернул флаг» сходится. | нет | closed |
| C3 | П.3: само неудачное чтение файл не пишет и не удаляет. П.4: квартира после показа пишет только `user://slot.json`; если чтение было порчей, эта запись заменяет битые байты годным файлом версии 1, и бытовая строка лежит как обычный `zh_ek_notice`. SV2 квартиру не открывает, в самом SV2 битые байты ещё на месте. Копия по другому пути не затрагивается ни чтением, ни этой записью. Выход программы E4 про заранее скопированный целый слот держится. | нет | closed |

## Регрессия аналитики (сохранено, итерация аналитики 2)

- Что перепроверили: открытые C1–C3 против `spec.md` (п.3, п.4, контракты снаружи), `assumptions.md` (A4), `DESIGN.md`, `ARCHITECTURE.md` и выход E4 в `docs/program/spec.md`. Бытовая строка в дизайне та же. Квартира показывает поля и затем пишет. Целая копия не стирается.
- П.3 «при неудачном чтении файл не пишется» и п.4 «поздняя запись квартиры заменяет битые байты» — два момента одного пути. Таблица «int» и допуск float без дробной части — одно правило: запись кладёт целые, чтение принимает целое значение в обоих видах JSON-числа.
- Новых вкусовых пунктов нет: да

## Проверка реализации

Класс diff-а — `feature-cycle`: один файл `user://slot.json`, версия 1, чтение при входе `GameState`, запись из квартиры и по закрытию окна, явная миграция, смоук SV1–SV3, сброс прежних смоуков, правка инварианта save в `game/AGENTS.md`. Облака, нескольких слотов, шифрования и середины забега в diff нет. Индекс `docs/world/ROADMAP.md` сдвигает следующий шаг на E5. S4 vertical slice указывает на спеку E4.

- Пишет store только `user://slot.json` (`SlotStore.PATH`). `wipe_slot` удаляет только `slot.json`. После записи в `user://` лежит один этот файл. Секретов, keystore и токенов в diff нет.
- Запись кладёт целые JSON-числа: `"version":1`, `"last_kills":4`, `"last_floors":5`. Godot `4.7.2` читает их как float. Float `1.0` / `4.0` / `5.0` при полном наборе ключей поднимает дверь, `pending_boon = damage`, счётчики 4 и 5. Файл `version` `1.5` с тем же полным набором даёт бытовую строку, дверь закрыта, байты файла те же.
- Чтение порчи `{not json` файл не пишет и не удаляет. Копия `user://slot_copy.json` по байтам совпадает с целым слотом, снятым до порчи. Второй объект `GameState` получает новую игру и строку «Папка с документами не читается. Завели новую карточку жильца.» Движок при этом печатает `Parse JSON failed`; чтение всё равно даёт новую игру.
- SV1: `kitchen_door_unlocked` и `pending_boon = damage` записаны, второй объект читает их с диска, плюс `last_kills` 4 и `last_floors` 5. SV3: после удаления файла новая игра, прежняя строка ЖЭКа, не бытовая строка порчи.
- В файле нет середины забега. Ключи записи — десять полей версии 1. `current_floor`, `player_hp`, `kills`, `floors_reached`, `run_seed`, `next_run_seed`, `pending_offer_ids`, `picked_offer_ids` в текст не попадают. Чужие ключи в файле версии 1 в память этих полей не копируются: после чтения `current_floor` остаётся 1, `player_hp` 100, `run_seed` 0. `NOTIFICATION_WM_CLOSE_REQUEST` вызывает ту же запись: дверь и `pending_boon` на диске, номера этажа, HP, seed и офферов в файле нет.
- Квартира в `_ready` сначала ставит строку ЖЭКа, `/pod/` и дверь, потом зовёт `save_slot`. `finish_extract` / `finish_death` по-прежнему пишут итог только в память.
- `full`, `loop`, `combat_feel`, `builds`, `floors` в начале зовут `reset_hub_meta`. Повтор на уже лежащем слоте с `last_result = extract`: `FLOORS_SMOKE_OK`. Повтор на слоте с `pending_boon = damage`: `BUILDS_SMOKE_OK`. Рядом зелёные `COMBAT_FEEL_OK`, `FULL_SMOKE_OK`, `LOOP_SMOKE_OK`.
- Повторный прогон тем же headless Godot `4.7.2`, exit 0: `SLOT_SMOKE_OK`, `FLOORS_SMOKE_OK`, `COMBAT_FEEL_OK`, `BUILDS_SMOKE_OK`, `FULL_SMOKE_OK`, `LOOP_SMOKE_OK`. Checks PR `product-wrapper-structure` и `build-stub` — success. Канон `.gamedev-sdlc/` не скопирован в проект. `ARCHITECTURE.md` называет `slot_store.gd`, чтение в `_ready`, запись по закрытию окна и запись квартиры после показа.

## Вход

- spec / assumptions / дизайн: `game/docs/save_slot/spec.md`, `assumptions.md`, `DESIGN.md`, `ARCHITECTURE.md`
- program E4: `docs/program/spec.md` этап E4
- diff: `git diff cursor/run-floors-e3-2b73...HEAD`
- код: `game/scripts/slot_store.gd`, `game/scripts/slot_smoke.gd`, `game/autoload/game_state.gd` (load/save/reset), `game/scripts/apartment_hub.gd`
- test-report: `game/docs/save_slot/test-report.md` (повторно гонялся тем же headless Godot `4.7.2`)
- доменный чеклист: `.gamedev-sdlc/game/review.md`
- процесс: `.gamedev-sdlc/process/review.md`
- GitHub PR: https://github.com/AdamCage/okraina/pull/9
- Issue не связан: A6 открыт, реализацию не держит. Labels PR пустые; класс `feature-cycle` и платформа `pc` названы в теле PR. Это не сломанный контракт и отдельным пунктом не открыто.
