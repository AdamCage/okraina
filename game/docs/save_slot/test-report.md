# test-report.md — save_slot (E4)

Godot: `4.7.2.stable`, linux headless.

## Прогон

| Команда | Результат |
|---|---|
| `godot --headless --path game -s res://scripts/slot_smoke.gd` | `SLOT_SMOKE_OK`, exit 0. На битом JSON движок печатает `Parse JSON failed`; чтение всё равно даёт новую игру, копия цела |
| `godot --headless --path game -s res://scripts/floors_smoke.gd` | `FLOORS_SMOKE_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/combat_feel_smoke.gd` | `COMBAT_FEEL_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/builds_smoke.gd` | `BUILDS_SMOKE_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/full_smoke.gd` | `FULL_SMOKE_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/loop_smoke.gd` | `LOOP_SMOKE_OK`, exit 0 |

## Пути

| Путь | Как проверяли |
|---|---|
| SV1 | `kitchen_door_unlocked` и `pending_boon = damage` записаны. Второй объект скрипта `GameState` читает их с диска, плюс `last_kills` 4 и `last_floors` 5 |
| SV2 | Копия байтов слота, затем в слот пишется `{not json`. Второй объект: дверь закрыта, бытовая строка. Байты копии те же |
| SV3 | После удаления файла новый объект получает прежнюю строку ЖЭКа, не бытовую строку порчи |
| Дробная версия | `{"version":1.5}` не читается. Сохранённая версия — целое JSON-число |
