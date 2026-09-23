# test-report.md — combat_feel (E1)

Godot: `4.7.2.stable` (`godot` on PATH, linux headless).
Команды — эквивалент строк `game/AGENTS.md` для этой среды (бинарник Windows в репозитории не лежит).

## Прогон

| Команда | Результат |
|---|---|
| `godot --headless --path game -s res://scripts/combat_feel_smoke.gd` | `COMBAT: CF1 absorb ok`, `COMBAT: CF2 hit 18 ok`, `COMBAT_FEEL_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/full_smoke.gd` | `FULL_SMOKE_OK`, exit 0 (boot, 3 этажа, kill, extract, boon, death) |
| `godot --headless --path game -s res://scripts/loop_smoke.gd` | `LOOP_SMOKE_OK`, exit 0 |

## Пути

| Путь | Как проверяли |
|---|---|
| CF1 | Smoke: Shift в подготовке, игрок возвращён в зону 32 px, удар `absorbed`, HP тот же |
| CF2 | Следующий удар того же врага без dodge: `hit`, HP −18 |
| CF3 | `full_smoke` добивает врага через `take_damage`, `kills` растёт |
| CF4 | `full_smoke`: `take_damage(999)` → `death` |
| CF5 | `full_smoke` и `loop_smoke`: extract и крючок двери |

## Не гоняли

Окно редактора и живой ввод Shift. Headless не показывает янтарный цвет; цвет задан в `enemy.gd` на входе в `WINDUP`.
