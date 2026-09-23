# test-report.md — run_floors (E3)

Increment. Гоняли headless-смоук дельты и регрессию боя, находок, полного цикла.
Godot: `4.7.2.stable`, linux headless.

## Прогон

| Команда | Результат |
|---|---|
| `godot --headless --path game -s res://scripts/floors_smoke.gd` | `FLOORS_SMOKE_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/combat_feel_smoke.gd` | `COMBAT_FEEL_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/builds_smoke.gd` | `BUILDS_SMOKE_OK`, exit 0 |
| `godot --headless --path game -s res://scripts/full_smoke.gd` | `FULL_SMOKE_OK`, exit 0. Отпечатки `F1:` / `F2:` / `F3:` различаются |
| `godot --headless --path game -s res://scripts/loop_smoke.gd` | `LOOP_SMOKE_OK`, exit 0 |

## Пути

| Путь | Как проверяли |
|---|---|
| RF1 | `sequence(1)` = dryer, corridor, lift, pipes. `sequence(2)` = hall, skipped, corridor, lift, switchboard. Списки не равны |
| RF2 | Повторный `sequence(1)` совпал с первым |
| RF3 | `tenant` и `meter` убиты, `kills` вырос на каждом. У `meter` подготовка 0.85 с, зона 72, урон 12 |
| RF4 | На этаже 1 жёлтая зона переводит на этаж 2. На `run_length` она даёт `extract` |
| Зона шага | `meter` на дистанции 64 попадает в список закрытия шага |
| Ранний шаг | Нажатие в начале подготовки 0.85 с: удар `hit`, HP 100→88 |
| Поздний шаг | Нажатие, когда до удара ≤ 0.45 с: удар `absorbed`, HP 100 |

Живой этаж seed 1 открылся пресетом «Сушилка», подпись зоны «ДАЛЬШЕ», подсказка «1/4» и «дальше по дому».
