# ARCHITECTURE.md — vertical_slice

## Сцены

```
main.tscn → GameState.go_apartment()
apartment_hub.tscn  (Player instance, ExitZone, KitchenDoor)
entrance.tscn
run_floor.tscn      (spawns Player + Enemies, ExitZone → extract)
result_screen.tscn  → apartment
```

## Autoload

- `GameState` — HP, kills, kitchen_door_unlocked, scene transitions

## Физика / группы

- Player `collision_layer=2`, group `player`
- Enemy `collision_layer=4`, group `enemies`
- AttackArea mask=4 (enemy)
- ExitZone mask=2 (player)

## Сигналы

- Player `hp_changed`, `died`
- ExitZone `body_entered` → extract / hint

## Данные

Нет `.tres` в slice; константы в скриптах / DESIGN.md.
