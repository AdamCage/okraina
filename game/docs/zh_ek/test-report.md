# test-report.md — zh_ek (E6)

Increment. Гоняли `zh_ek_smoke` и регрессию слота, этажей, боя, сборок, борды, полного прогона и петли.

Команда: `godot --headless --path game -s res://scripts/<smoke>.gd` (Godot 4.7.2).

| Смоук | Итог |
|---|---|
| `zh_ek_smoke` | `NOTICE_SMOKE_OK` — до запечатывания 25/180, `elevator` и скорость 162, `pot` и урон 33, стена «УК»/«Акт», `boxes` 162, целые слоты v1 и v2 |
| `slot_smoke` | `SLOT_SMOKE_OK` |
| `floors_smoke` | `FLOORS_SMOKE_OK` |
| `combat_feel_smoke` | `COMBAT_FEEL_OK` |
| `builds_smoke` | `BUILDS_SMOKE_OK` |
| `imageboard_smoke` | `BOARD_SMOKE_OK` |
| `full_smoke` | `FULL_SMOKE_OK` |
| `loop_smoke` | `LOOP_SMOKE_OK` |
