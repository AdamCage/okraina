# test-report.md — vertical_slice

Дата: 2026-09-22
Godot: `C:\projects\okraina\tools\godot\Godot_v4.7.2-stable_win64_console.exe` (4.7.2, gitignored)

## Что гоняли

| Прогон | Команда | Результат |
|---|---|---|
| Import | `godot --headless --path game --import` | OK |
| Main boot | `godot --headless --path game --quit-after 3` | EXIT 0 (после deferred change_scene) |
| Smoke files/actors | `godot --headless --path game -s res://scripts/smoke_test.gd` | `SMOKE_OK` EXIT 0 |
| Loop hub→run→extract→hook | `godot --headless --path game -s res://scripts/loop_smoke.gd` | `LOOP_SMOKE_OK` EXIT 0 |

## User paths

| Path | Статус |
|---|---|
| VS1 Launch | OK (main + apartment) |
| VS2 Enter run | OK (loop_smoke) |
| VS3 Combat | Частично: damage/kill API в smoke; melee overlap не автотестился в headless input |
| VS4 Death | API `finish_death` есть; полный headless death path не гонялся отдельно |
| VS5 Extract | OK (loop_smoke + kitchen flag) |
| VS6 Hook | OK flag `kitchen_door_unlocked`; текст осмотра — ручной play |

## Намеренно не гоняли

- Оконный playtest с клавиатурой (нет интерактивного агента)
- Android / export
- Полный combat balance

## Красное

Нет на момент отчёта.
