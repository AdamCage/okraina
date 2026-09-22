# DESIGN.md — vertical_slice

Спека: [`spec.md`](spec.md). Мир: `docs/world/LORE.md`.

## Цель и fantasy

Короткая смена «выйти из квартиры в гигахрущ и вернуться» с боем
и ощущением, что дом слегка не тот. Без разгадки мира.

## Loop

1. Hub (квартира) → решение выйти
2. Подъезд → этаж
3. Бой / движение / поиск EXIT
4. Смерть или extract → hub (+ крючок двери после первого extract)

## Systems

| Сущность | Правило |
|---|---|
| Player | HP 100; move 180 px/s; melee 25 dmg, CD 0.4s |
| Enemy | HP 40; chase; touch 12 dmg/s; 5–7 штук |
| ExitZone | body_entered player → extract |
| RunState | tracking kills, extracted flag, kitchen_door_unlocked |

FSM: `Hub` ↔ `Entrance` ↔ `Run` → `Result` → `Hub`

## UX

- Вход: Main загружает ApartmentHub
- HUD: HP полоска + строка «эт. 9 · ЭЖК №17» + ЖЭК-объявление
- Input: WASD/стрелки move; Space/LMB attack; E interact
- PC only в slice

## Lore (slice)

- Нельзя ломать: тон ЖЭКа; нет одного ответа на тайну
- Крючок двери: странность, не спойлер AUTHOR
- Текст примера: «В связи с появлением дверного проёма за кухней просьба не складировать банки.»

## Technical design

- Сцены под `game/scenes/`
- Autoload: `GameState.gd`
- CharacterBody2D player/enemy
- Camera2D follow player on RunFloor

## Scope

| Must | Should | Later |
|---|---|---|
| Launch, move, fight, die, extract, kitchen hook | ЖЭК ticker text | Loot, board, train, procgen, Perception |

Vertical slice: **одно окно Godot, один полный цикл hub→run→hub.**
