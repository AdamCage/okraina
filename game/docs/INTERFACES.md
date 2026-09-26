# Контракты интерфейсов («ЗОНА: Пикник на обочине»)

Проект: Godot **4.7.2**, рендер `forward_plus` (веб: `gl_compatibility`, мобильные: `mobile`).
Скрипты — GDScript с `class_name`, тексты интерфейса **на русском**. Слои физики:
1 `world`, 2 `player`, 3 `enemy`, 4 `hitbox`, 5 `loot`, 6 `interact`, 7 `anomaly`.

## Автолоады (уже написаны — читайте файлы)

### `Assets` (`autoload/assets.gd`)
- `ground_tex(mat:i, variant:i=0)`, `ground_normal(...)`, `wall_tex(style, variant)`,
  `wall_normal(...)`, `decal_tex(idx)`, `decal_normal(idx)` — тайлы 128x128.
- `Assets.GROUND_MATS` / `WALL_STYLES` / `DECAL_NAMES`; `ground_index("dirt")`, `wall_index`, `decal_index`.
- `sheet(name, frame)` — кадр листа анимации 64x64 (`Assets.SHEETS` — имя -> кадров,
  `Assets.SHEET_FRAME = 64`, `Assets.SHEET_ANCHOR = Vector2(32,58)` — точка «ног»).
- `sprite(name)` / `has_sprite(name)` / `sprite_size(name)` / `Assets.SPRITE_NAMES` — пропы и оверлеи.
- `ui(name)` / `has_ui(name)` — элементы интерфейса (`assets/ui/*.png`).
- `font("title"|"body"|"small", size)`, `font_title`, `font_body`; `placeholder()`.
- `sound(name)`, `has_sound(name)`, `report()`.

### `GameState` (`autoload/game_state.gd`)
- Поля: `hp, hp_max, stamina, stamina_max, radiation, level, xp, xp_next, money, armor,
  rad_resist, regen, stamina_regen, speed_mult, has_light, has_detector, has_zoom,
  has_geiger, inventory: Array[{id,count}], equipment{weapon,armor,helmet,artifact_1..3},
  kills, kills_by_type, is_dead, play_time, world_seed`.
- `add_item(id,count,silent)=bool`, `remove_item`, `count_item`, `count_total`, `has_item`,
  `equip(id)`, `unequip(slot)`, `use_item(id)`, `apply_damage(amount,kind="phys")`,
  `heal`, `add_radiation`, `add_money`, `add_xp`, `register_kill(type_id)`,
  `total_weight()`, `max_weight()`, `recompute()`, `reset_run(seed)`,
  `save_game()`/`load_game()`/`has_save()`.
- Сигналы: `stats_changed`, `inventory_changed`, `money_changed(int)`, `leveled_up(int)`,
  `player_died`, `log_message(text, kind)` где kind = `info|good|bad|quest`.

### `Quests` (`autoload/quests.gd`)
- `start(id)`, `notify(kind, target, amount)` (kind: `kill|collect|reach|loot`),
  `is_active(id)`, `is_done(id)`, `title(id)`, `tracker_lines()`, `journal_entries()`,
  `main_current()`, `MAIN_CHAIN`.
- Сигналы: `quest_started(id)`, `quest_updated(id)`, `quest_completed(id)`,
  `objective_completed(quest_id, index)`.

### `Sfx` (`autoload/sfx.gd`)
- `play(name, pos=Vector2.INF, volume_db=0.0, pitch=1.0)`, `ui(name)`, `step(surface)`,
  `ambient(name)`, `ambient_stop()`, `set_danger(0..1)`, `music(name)`, `stop_all()`.

### `ItemDB` (`scripts/item_db.gd`, глобальный класс)
- `ItemDB.get_item(id) -> Dictionary` (name, desc, kind, icon, weight, value, stack;
  для оружия — dmg/rate/spread/gun_range/mag/caliber/mode/sfx/reach/speed/pellets;
  броня — armor/hp_bonus/radiation/speed; аптечки — heal/stamina/rad_heal;
  артефакты — regen/rad_resist/speed/light/hp_bonus/armor/radiation),
  `ItemDB.Kind.*`, `icon(id)`, `display_name(id)`, `max_stack(id)`, `is_equipable(id)`,
  `is_usable(id)`, `kind_name(kind)`, `all_ids()`.

## Контракты игровых классов

### `Player` (`scripts/player.gd`) — ведущий агент
`class_name Player extends CharacterBody2D`, группа `"player"`.
- `take_damage(amount: float, kind: String = "phys", src: Node = null)`
- `is_alive() -> bool`, `center() -> Vector2`, `aim_dir() -> Vector2`, `power: float`

### `Enemy` (`scripts/enemy.gd`)
`class_name Enemy extends CharacterBody2D`, группа `"enemies"`.
- `setup(type_id: String, level: int)` — вызвать сразу после `Enemy.new()`.
  Типы: `dog`, `mutant`, `zombie`, `boar`; листы `Assets.sheet("<type>_idle|_walk|_attack")`.
- `take_damage(amount: float, from: Node = null)`, `is_alive() -> bool`, `center() -> Vector2`,
  `enemy_type: String`, `xp_value() -> float`.
- Игрока ищет как `get_tree().get_first_node_in_group("player")`.
- При смерти: `GameState.register_kill(enemy_type)`, `GameState.add_xp(xp_value())`,
  `Loot.spawn_drop(...)` (бросок лута), `DamageText.spawn(...)`, `queue_free()`.

### `Projectile` (`scripts/projectile.gd`)
`class_name Projectile extends Area2D`;
`setup(start: Vector2, dir: Vector2, speed: float, damage: float, shooter: Node, hit_mask: int)`.
Маски: бит слоя = `1 << (номер-1)`, т.е. world = 1, player = 2, enemy = 4, loot = 16, interact = 32.

### `Anomaly` (`scripts/anomaly.gd`)
`class_name Anomaly extends Node2D`, группа `"anomalies"`.
- `setup(type_id: String, radius: float)`, типы `grav`, `elektra`, `zharka`, `fruit`
  (листы `anomaly_<type>`, 4 кадра).
- Для детектора и гейгера: `danger_for(pos: Vector2) -> float` (0..1),
  `artifact_id: String`, `has_artifact() -> bool`, `take_artifact() -> String`.

### `DamageText` (`scripts/damage_text.gd`)
`class_name DamageText`; `static DamageText.spawn(parent: Node, pos: Vector2, amount: float, kind: String = "phys")`,
kind: `phys|crit|heal|rad|xp`.

### `World` (`scripts/world.gd`)
`class_name World extends Node2D`; `generate(world_seed: int) -> Dictionary`.
Внутри создаёт: TileMapLayer «ground» (`Assets.ground_tex`), TileMapLayer «walls» (`Assets.wall_tex`,
коллизия), декали (`Assets.decal_tex`), пропы (StaticBody2D + спрайт + коллизия),
контейнеры (`Container.new(); setup(tier)`), NPC (`Npc.new(); setup("sidorovich","Сидорович")`).
Возвращает:
```
{
  "spawn": Vector2,
  "zones": {"kordon": Rect2, "village": Rect2, "factory": Rect2, "bunker": Rect2, "swamp": Rect2},
  "enemy_spawns": [{"type": "dog", "pos": Vector2, "level": 1, "boss": false}],
  "anomalies": [{"type": "grav", "pos": Vector2, "radius": 120.0}],
  "loot_spots": [{"pos": Vector2, "tier": 1}],
  "size_tiles": Vector2i, "tile_size": 128
}
```

### `LootContainer` (`scripts/container.gd`) — ведущий агент
`class_name LootContainer extends StaticBody2D` (имя именно такое: `Container` конфликтует
с нативным классом Godot); `setup(tier: int, kind: String = "crate")`
(kind: `crate` | `barrel` | `sack` | `safe`);
`open(player: Node) -> bool` (выдаёт лут, `Quests.notify("loot","",1)`, `GameState.containers_looted += 1`),
`add_guaranteed(item_id: String)`, `interact_hint() -> String`, `opened: bool`, группа `"containers"`.

### `Loot` (`scripts/loot.gd`) — ведущий агент
`class_name Loot extends Area2D`; `static Loot.spawn_drop(parent: Node, pos: Vector2, id: String, count: int = 1)`;
внутри — иконка `Assets.ui(ItemDB.icon(id))`, подбор по F/касанию.

### `Npc` (`scripts/npc.gd`) — ведущий агент
`class_name Npc extends StaticBody2D`; `setup(id, display_name)` (id: `sidorovich`, `barman`);
`interact(player: Node)` — диалог и выдача квеста.

### UI (`Control`/`CanvasLayer`-скрипты, узлы строятся в `_ready`, .tscn не нужны)
- `scripts/hud.gd` — `class_name Hud extends CanvasLayer`; `setup(game: Node)`.
- `scripts/inventory_ui.gd` — `class_name InventoryUI extends CanvasLayer`; `setup(game)`, `toggle()`.
- `scripts/journal_ui.gd` — `class_name JournalUI extends CanvasLayer`; `setup(game)`, `toggle()`.
- `scripts/menu_ui.gd` — `class_name MenuUI extends CanvasLayer`; `setup(game)`;
  экраны: главное меню, пауза, настройки, смерть, статистика.
- `scripts/touch_ui.gd` — `class_name TouchUI extends CanvasLayer`; `setup(game)`; виртуальный стик + кнопки.

`game.gd` создаёт мир, игрока, врагов (из `world_data["enemy_spawns"]`), аномалии
(из `world_data["anomalies"]`) и подключает UI.

