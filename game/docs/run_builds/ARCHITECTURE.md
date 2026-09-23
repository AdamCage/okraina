# ARCHITECTURE.md — run_builds

Спека: [`spec.md`](spec.md).

## 1. Обзор

```text
run_floor._ready
    → GameState.roll_floor_offers()
    → offer_panel (клавиши 1/2/3)
    → GameState.pick_offer()
    → player.apply_build()
```

Новый autoload не заводится. Список живёт в `GameState` до следующего `go_run`.

## 2. Данные

| Поле | Смысл |
|---|---|
| `pending_offer_ids` | Три id, пока выбор открыт |
| `picked_offer_ids` | Уже взятое в этом забеге |
| `offer_*` | Пересчёт списка, не приращение поверх старого |
| `floor_offer_open` | Пока true, игрок и враг не крутят физику |

Каталог — `offer_catalog.gd`, не сцена.

## 3. Карта

| Скрипт | Ответственность |
|---|---|
| `offer_catalog.gd` | 10 находок и их числа |
| `offer_panel.gd` | Три кнопки и действия `offer_1`…`offer_3` |
| `game_state.gd` | Ролл, выбор, лечение один раз, сброс на `go_run` |
| `player.gd` | `apply_build` читает пересчёт |
| `builds_smoke.gd` | RB1–RB4 |

## 4. Порядок лечения

`pick_offer` сначала пересчитывает максимум HP, потом один раз прибавляет `heal` этой id. Следующий этаж зовёт только `apply_build` и заново не лечит.

## 5. Платформы

PC: клавиши 1, 2, 3. Touch-кнопок нет.
