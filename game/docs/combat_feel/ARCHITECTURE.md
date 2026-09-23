# ARCHITECTURE.md — combat_feel

Спека: [`spec.md`](spec.md).

## 1. Обзор

```text
InputMap dodge / attack
    → player.gd (шаг, cover id, AttackArea)
    → enemy.gd (chase → windup → strike → recover)
    → GameState.player_hp / kills / finish_death
```

Сцены те же: `player.tscn`, `enemy.tscn`, спавн из `run_floor`.
Новый autoload не заводится. Export presets не меняются.

## 2. Контракты данных

| Поле | Кто пишет | Смысл |
|---|---|---|
| `GameState.player_hp` | `player.take_damage` | Удар 18 или внешний урон. Закрытый удар не пишет |
| `enemy.phase` | `enemy.gd` | `CHASE` / `WINDUP` / `RECOVER` |
| `enemy.last_strike_result` | `enemy.gd` | `absorbed` / `hit` / `out_of_range` |
| `_covered` | `player.start_dodge` | id врагов, чья текущая подготовка закрыта |

Сохранения на диск нет.

## 3. Карта

| Скрипт | Ответственность |
|---|---|
| `player.gd` | Шаг 0.16 с, перезарядка 0.70 с с кадра нажатия, `receive_strike` |
| `enemy.gd` | Подготовка 0.50 с (янтарный), удар 18 в 56 px, откат 0.40 с |
| `combat_feel_smoke.gd` | CF1 и CF2 |
| `project.godot` | Действие `dodge` = Shift |

## 4. Поток удара

1. Дистанция ≤ 56 px → `WINDUP`, цвет янтарный, скорость 0.
2. `start_dodge` запоминает id таких врагов и держит список 0.50 с.
   Список снимается отложенно, в следующий кадр после конца окна,
   чтобы удар в кадр истечения ещё считался закрытым.
3. Конец подготовки: `receive_strike`. Id в списке → `absorbed`, HP цел.
   Иначе `take_damage(18)`.
4. `RECOVER` 0.40 с, затем снова погоня.

Шаг без подготовки даёт неуязвимость только на 0.16 с (`_iframe`),
тоже снятую отложенно в конце кадра.

## 5. Краевые случаи

- Повторный dodge до конца 0.70 с игнорируется, в том числе во время шага.
- `take_damage` во время `_iframe` не меняет HP. Смерть в smoke идёт без шага.
- Враг вне 56 px в кадр удара даёт `out_of_range`.

## 6. Платформы

PC: одна клавиша. Touch-кнопка на то же действие — E11, здесь не делается.
