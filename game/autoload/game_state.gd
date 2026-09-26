extends Node
## Состояние забега: характеристики героя, инвентарь, прогресс, сохранение.
## Автолоад GameState. Все изменения проходят через сигналы — UI слушает их.

signal stats_changed                      ## hp/силы/радиация/уровень/броня
signal inventory_changed                  ## содержимое сумки
signal money_changed(amount: int)
signal leveled_up(new_level: int)
signal player_died
signal log_message(text: String, kind: String)   ## kind: "info"/"good"/"bad"/"quest"

const MAX_SLOTS := 40
const BASE_HP := 100.0
const BASE_STAMINA := 100.0
const BASE_CARRY := 60.0

# --- прогресс
var level: int = 1
var xp: float = 0.0
var xp_next: float = 120.0
var money: int = 600

# --- здоровье / силы / радиация
var hp: float = BASE_HP
var stamina: float = BASE_STAMINA
var radiation: float = 0.0
var hp_max: float = BASE_HP
var stamina_max: float = BASE_STAMINA
var rad_max: float = 100.0

# --- производные бонусы от снаряжения (пересчитывается в recompute())
var armor: float = 0.0            ## % снижения урона
var rad_resist: float = 0.0       ## % снижения набора радиации
var regen: float = 0.0            ## hp/с
var stamina_regen: float = 0.0
var speed_mult: float = 1.0
var carry_bonus: float = 0.0
var has_light: bool = false
var has_detector: bool = false
var has_zoom: bool = false
var has_geiger: bool = false

# --- инвентарь: [{id: String, count: int}]
var inventory: Array = []
var equipment: Dictionary = {
	"weapon": "", "armor": "", "helmet": "",
	"artifact_1": "", "artifact_2": "", "artifact_3": "",
}

# --- статистика забега
var kills: int = 0
var kills_by_type: Dictionary = {}
var artifacts_found: int = 0
var containers_looted: int = 0
var quests_done: int = 0
var distance_walked: float = 0.0
var play_time: float = 0.0
var world_seed: int = 0
var is_dead: bool = false
var difficulty: float = 1.0
var spawn_point: Vector2 = Vector2.ZERO


func reset_run(world_seed_value: int = 0) -> void:
	world_seed = world_seed_value if world_seed_value != 0 else randi()
	level = 1
	xp = 0.0
	xp_next = 120.0
	money = 600
	hp_max = BASE_HP
	stamina_max = BASE_STAMINA
	hp = hp_max
	stamina = stamina_max
	radiation = 0.0
	inventory = []
	equipment = {
		"weapon": "", "armor": "", "helmet": "",
		"artifact_1": "", "artifact_2": "", "artifact_3": "",
	}
	kills = 0
	kills_by_type = {}
	artifacts_found = 0
	containers_looted = 0
	quests_done = 0
	distance_walked = 0.0
	play_time = 0.0
	is_dead = false
	_add_item_raw("knife", 1)
	_add_item_raw("pm", 1)
	_add_item_raw("ammo_9x18", 60)
	_add_item_raw("bandage", 4)
	_add_item_raw("vodka", 2)
	_add_item_raw("canned", 2)
	equipment["weapon"] = "pm"
	equipment["armor"] = "armor_leather"
	equipment["artifact_1"] = ""
	recompute()
	inventory_changed.emit()


# ------------------------------------------------------------------ предметы
func _add_item_raw(id: String, count: int = 1) -> void:
	var max_stack: int = ItemDB.max_stack(id)
	var left: int = count
	for slot in inventory:
		if left <= 0:
			break
		if String(slot["id"]) == id and int(slot["count"]) < max_stack:
			var room: int = max_stack - int(slot["count"])
			var put: int = mini(room, left)
			slot["count"] = int(slot["count"]) + put
			left -= put
	while left > 0 and inventory.size() < MAX_SLOTS:
		var put2: int = mini(max_stack, left)
		inventory.append({"id": id, "count": put2})
		left -= put2


## Положить предмет. false — нет места.
func add_item(id: String, count: int = 1, silent: bool = false) -> bool:
	if not ItemDB.has(id):
		push_warning("GameState.add_item: неизвестный предмет " + id)
		return false
	if count_item(id) + count > MAX_SLOTS * ItemDB.max_stack(id):
		return false
	_add_item_raw(id, count)
	if not silent:
		log_message.emit("Получено: %s x%d" % [ItemDB.display_name(id), count], "good")
	inventory_changed.emit()
	return true


## Убрать предмет; true если всего хватило.
func remove_item(id: String, count: int = 1) -> bool:
	if count_item(id) < count:
		return false
	var left: int = count
	for i in range(inventory.size() - 1, -1, -1):
		if left <= 0:
			break
		var slot: Dictionary = inventory[i]
		if String(slot["id"]) == id:
			var take: int = mini(int(slot["count"]), left)
			slot["count"] = int(slot["count"]) - take
			left -= take
			if int(slot["count"]) <= 0:
				inventory.remove_at(i)
	inventory_changed.emit()
	return true


func count_item(id: String) -> int:
	var total: int = 0
	for slot in inventory:
		if String(slot["id"]) == id:
			total += int(slot["count"])
	return total


## Сколько предметов всего: в сумке + надето (для целей «собрать N»).
func count_total(id: String) -> int:
	var total: int = count_item(id)
	for slot in equipment.keys():
		if String(equipment[slot]) == id:
			total += 1
	return total



func has_item(id: String, count: int = 1) -> bool:
	return count_item(id) >= count


## Надеть снаряжение. false — предмет не надевается или его нет.
func equip(id: String) -> bool:
	if id == "" or not ItemDB.is_equipable(id):
		return false
	if not remove_item(id, 1):
		return false
	var slot: String = _slot_for(id)
	var old: String = String(equipment.get(slot, ""))
	equipment[slot] = id
	if old != "":
		_add_item_raw(old, 1)
	recompute()
	log_message.emit("Надето: " + ItemDB.display_name(id), "info")
	inventory_changed.emit()
	return true


## Снять экипированный предмет в сумку.
func unequip(slot: String) -> bool:
	var id: String = String(equipment.get(slot, ""))
	if id == "":
		return false
	equipment[slot] = ""
	_add_item_raw(id, 1)
	recompute()
	inventory_changed.emit()
	return true


func _slot_for(id: String) -> String:
	match ItemDB.kind_of(id):
		ItemDB.Kind.WEAPON:
			return "weapon"
		ItemDB.Kind.ARMOR:
			return "armor"
		ItemDB.Kind.HELMET:
			return "helmet"
		ItemDB.Kind.ARTIFACT:
			for i in range(1, 4):
				if String(equipment.get("artifact_%d" % i, "")) == "":
					return "artifact_%d" % i
			return "artifact_1"
		_:
			return ""


## Применить предмет. true при успехе.
func use_item(id: String) -> bool:
	var data: Dictionary = ItemDB.get_item(id)
	if data.is_empty():
		return false
	if ItemDB.kind_of(id) == ItemDB.Kind.ARTIFACT:
		return equip(id)
	if not ItemDB.is_usable(id):
		return false
	if not remove_item(id, 1):
		return false
	heal(float(data.get("heal", 0.0)))
	stamina = minf(stamina_max, stamina + float(data.get("stamina", 0.0)))
	radiation = maxf(0.0, radiation - float(data.get("rad_heal", 0.0)))
	log_message.emit("Использовано: %s" % ItemDB.display_name(id), "info")
	stats_changed.emit()
	return true


## Пересчёт производных характеристик от экипировки.
func recompute() -> void:
	var armor_sum: float = 0.0
	var rad_sum: float = 0.0
	var regen_sum: float = 0.0
	var stam_sum: float = 0.0
	var hp_bonus: float = 0.0
	var speed: float = 1.0
	has_light = false
	has_detector = false
	has_zoom = false
	has_geiger = false
	for slot in equipment.keys():
		var id: String = String(equipment[slot])
		if id == "":
			continue
		var d: Dictionary = ItemDB.get_item(id)
		armor_sum += float(d.get("armor", 0.0))
		rad_sum += float(d.get("radiation", 0.0)) - float(d.get("rad_resist", 0.0))
		regen_sum += float(d.get("regen", 0.0))
		stam_sum += float(d.get("stamina_regen", 0.0))
		hp_bonus += float(d.get("hp_bonus", 0.0))
		speed *= float(d.get("speed", 1.0))
		_flag_equip(String(d.get("equip", "")))
	for slot in inventory:   # гаджеты в сумке тоже работают
		_flag_equip(String(ItemDB.get_item(String(slot["id"])).get("equip", "")))
	armor = clampf(armor_sum, 0.0, 70.0)
	rad_resist = clampf(rad_sum, -60.0, 90.0)
	regen = regen_sum
	stamina_regen = stam_sum
	speed_mult = clampf(speed, 0.7, 1.25)
	var new_max: float = BASE_HP + hp_bonus + float(level - 1) * 12.0
	if not is_equal_approx(new_max, hp_max):
		var ratio: float = hp / maxf(1.0, hp_max)
		hp_max = new_max
		hp = clampf(hp_max * ratio, 1.0, hp_max)
	stamina_max = BASE_STAMINA + float(level - 1) * 6.0
	stats_changed.emit()


func _flag_equip(kind: String) -> void:
	match kind:
		"light": has_light = true
		"detector": has_detector = true
		"zoom": has_zoom = true
		"geiger": has_geiger = true


## Входящий урон: броня снижает только физический.
func apply_damage(amount: float, kind: String = "phys") -> void:
	if is_dead:
		return
	var dmg: float = amount
	if kind == "phys":
		dmg *= 1.0 - armor / 100.0
	hp = maxf(0.0, hp - dmg)
	stats_changed.emit()
	if hp <= 0.0 and not is_dead:
		is_dead = true
		player_died.emit()


func heal(amount: float) -> void:
	if amount > 0.0:
		hp = minf(hp_max, hp + amount)
		stats_changed.emit()


func add_radiation(amount: float) -> void:
	radiation = clampf(radiation + amount * (1.0 - rad_resist / 100.0), 0.0, rad_max)
	stats_changed.emit()


func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	money_changed.emit(money)


func add_xp(amount: float) -> void:
	xp += amount
	var leveled: bool = false
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = round(xp_next * 1.35 + 40.0)
		leveled = true
		log_message.emit("Новый уровень: %d" % level, "good")
		leveled_up.emit(level)
	if leveled:
		recompute()
		hp = hp_max
		stamina = stamina_max
	stats_changed.emit()


func register_kill(type_id: String) -> void:
	kills += 1
	kills_by_type[type_id] = int(kills_by_type.get(type_id, 0)) + 1
	Quests.notify("kill", type_id, 1)


func total_weight() -> float:
	var w: float = 0.0
	for slot in inventory:
		w += ItemDB.weight(String(slot["id"])) * int(slot["count"])
	return w


func max_weight() -> float:
	return BASE_CARRY + carry_bonus + float(level - 1) * 2.0


func _process(delta: float) -> void:
	if not is_dead and not get_tree().paused:
		play_time += delta


# ------------------------------------------------------------------ сохранение
const SAVE_PATH := "user://zone_save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var data := {
		"version": 1,
		"world_seed": world_seed,
		"level": level, "xp": xp, "xp_next": xp_next, "money": money,
		"hp": hp, "hp_max": hp_max, "stamina": stamina, "radiation": radiation,
		"inventory": inventory, "equipment": equipment,
		"kills": kills, "kills_by_type": kills_by_type,
		"artifacts_found": artifacts_found, "containers_looted": containers_looted,
		"quests_done": quests_done, "play_time": play_time,
		"spawn_point": [spawn_point.x, spawn_point.y],
		"quests": Quests.save_data(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	log_message.emit("Игра сохранена", "info")
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	world_seed = int(d.get("world_seed", randi()))
	level = int(d.get("level", 1))
	xp = float(d.get("xp", 0.0))
	xp_next = float(d.get("xp_next", 120.0))
	money = int(d.get("money", 600))
	radiation = float(d.get("radiation", 0.0))
	inventory = d.get("inventory", [])
	equipment = d.get("equipment", {"weapon": "", "armor": "", "helmet": "",
		"artifact_1": "", "artifact_2": "", "artifact_3": ""})
	kills = int(d.get("kills", 0))
	kills_by_type = d.get("kills_by_type", {})
	artifacts_found = int(d.get("artifacts_found", 0))
	containers_looted = int(d.get("containers_looted", 0))
	quests_done = int(d.get("quests_done", 0))
	play_time = float(d.get("play_time", 0.0))
	var sp: Variant = d.get("spawn_point", [0.0, 0.0])
	if typeof(sp) == TYPE_ARRAY and (sp as Array).size() == 2:
		spawn_point = Vector2(float(sp[0]), float(sp[1]))
	is_dead = false
	recompute()
	hp_max = float(d.get("hp_max", hp_max))
	hp = clampf(float(d.get("hp", hp_max)), 1.0, hp_max)
	stamina = float(d.get("stamina", stamina_max))
	Quests.restore_data(d.get("quests", {}))
	stats_changed.emit()
	inventory_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))




