# test-report.md — imageboard (E5)

Godot: `4.7.2.stable`, linux headless.

## Прогон

| Команда | Результат |
|---|---|
| `godot --headless --path game -s res://scripts/imageboard_smoke.gd` | `BOARD_SMOKE_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/slot_smoke.gd` | `SLOT_SMOKE_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/floors_smoke.gd` | `FLOORS_SMOKE_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/combat_feel_smoke.gd` | `COMBAT_FEEL_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/builds_smoke.gd` | `BUILDS_SMOKE_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/full_smoke.gd` | `FULL_SMOKE_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/loop_smoke.gd` | `LOOP_SMOKE_OK`, exit 0 |

## Пути

| Путь | Как проверяли |
|---|---|
| IB1 | Итог `extract`, этаж 5, убийств 4. Правдивый тред повторяет три поля. Ложный — death, этаж 6, убийств 7. `steady` даёт урон 31, `drag` скорость 153 |
| IB2 | `pod_troll` и `go_run` ставят кулдаун 0.34 с, `lead_id` на месте. Подпись на этаже «Сверился» после правдивого выбора |
| IB3 | Второй объект `GameState` читает `pod_troll` |
| IB4 | Целый JSON версии 1 с дверью и `maxhp` читается, `lead_id` пустой, байты слота и копии не меняются при чтении |
| Экран | Квартира открывает узел `BoardPanel` и закрывает его |
| Пустой итог | Правда не называет этаж. Если в записи уже этаж 9 и 30 убийств, ложь говорит 10 и 33 |
