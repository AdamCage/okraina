# test-report.md — run_builds (E2)

Godot: `4.7.2.stable`, linux headless.

## Прогон

| Команда | Результат |
|---|---|
| `godot --headless --path game -s res://scripts/builds_smoke.gd` | `BUILDS_SMOKE_OK`, exit 0. В прогоне выпали `habit` и `shoulder`, оба НЕРВ: стат шага меняется и держится на следующем этаже |
| `godot --headless --path game -s res://scripts/combat_feel_smoke.gd` | `COMBAT_FEEL_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/full_smoke.gd` | `FULL_SMOKE_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/loop_smoke.gd` | `LOOP_SMOKE_OK`, exit 0 |

## Пути

| Путь | Как проверяли |
|---|---|
| RB1 | `pick_offer(0)` меняет обещанный стат выпавшей id |
| RB2 | После `advance_floor` список и стат на месте, выбор этажа снова открыт |
| RB3 | `take_damage(999)` → `death`; `finish_extract` → `extract` |
| RB4 | Новый `go_run` обнуляет `picked_offer_ids` |

Клавиши 1/2/3 записаны в InputMap и в `offer_panel.gd`. Headless жмёт выбор через `pick_offer`, это путь спеки рядом с клавишей.
