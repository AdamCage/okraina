extends Node

## Runtime state. Hub meta also lives in user://slot.json. See game/docs/save_slot/.

const SCENE_APARTMENT := "res://scenes/apartment_hub.tscn"
const SCENE_ENTRANCE := "res://scenes/entrance.tscn"
const SCENE_RUN := "res://scenes/run_floor.tscn"
const SCENE_RESULT := "res://scenes/result_screen.tscn"

const FLOOR_MIN := 4
const FLOOR_MAX := 6
const _SlotStore := preload("res://scripts/slot_store.gd")

var player_hp: int = 100
var player_max_hp: int = 100
var base_max_hp: int = 100
var kills: int = 0
var current_floor: int = 1
var floors_reached: int = 1
var extracted_once: bool = false
var kitchen_door_unlocked: bool = false
var last_result: String = "" # "death" | "extract"
var last_kills: int = 0
var last_floors: int = 0
## Pending choice after a run; becomes active_boon on next go_run.
var pending_boon: String = "none" # none | damage | maxhp | speed
var active_boon: String = "none"
var zh_ek_notice: String = _SlotStore.DEFAULT_NOTICE
var board_feed: String = _SlotStore.DEFAULT_BOARD
## For tests: fingerprint of last built floor layout.
var last_floor_fingerprint: String = ""
var floor_fingerprints: PackedStringArray = PackedStringArray()
var floor_offer_open: bool = false
var pending_offer_ids: Array[String] = []
var picked_offer_ids: Array[String] = []
var offer_damage: int = 0
var offer_speed_mult: float = 1.0
var offer_attack_cd_mult: float = 1.0
var offer_max_hp: int = 0
var offer_dodge_cd: float = 0.0
var offer_dodge_speed: float = 0.0
var next_run_seed: int = -1
var run_seed: int = 0
var run_length: int = FLOOR_MIN
var preset_ids: Array[String] = []

const _OfferCatalog := preload("res://scripts/offer_catalog.gd")


func _ready() -> void:
	_SlotStore.load_into(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_slot()


func save_slot() -> bool:
	return _SlotStore.save_from(self)


func reset_hub_meta() -> void:
	_SlotStore.wipe_slot()
	pending_boon = "none"
	active_boon = "none"
	extracted_once = false
	kitchen_door_unlocked = false
	last_result = ""
	last_kills = 0
	last_floors = 0
	zh_ek_notice = _SlotStore.DEFAULT_NOTICE
	board_feed = _SlotStore.DEFAULT_BOARD


func apply_boon_for_run() -> void:
	active_boon = pending_boon
	_apply_max_hp()
	player_hp = player_max_hp


func clear_run_offers() -> void:
	picked_offer_ids = []
	pending_offer_ids = []
	floor_offer_open = false
	_recompute_offers()


func roll_floor_offers() -> void:
	var pool: Array[String] = []
	for entry in _OfferCatalog.all():
		var id := str(entry["id"])
		if not picked_offer_ids.has(id):
			pool.append(id)
	if pool.size() < 3:
		pool.clear()
		for entry in _OfferCatalog.all():
			pool.append(str(entry["id"]))
	pool.shuffle()
	pending_offer_ids = []
	var seen := {}
	for id in pool:
		if seen.has(id):
			continue
		seen[id] = true
		pending_offer_ids.append(id)
		if pending_offer_ids.size() == 3:
			break
	floor_offer_open = pending_offer_ids.size() == 3


func pick_offer(index: int) -> String:
	if not floor_offer_open or index < 0 or index >= pending_offer_ids.size():
		return ""
	var id := pending_offer_ids[index]
	picked_offer_ids.append(id)
	_recompute_offers()
	_apply_max_hp()
	var entry := _OfferCatalog.get_by_id(id)
	var heal := int(entry.get("heal", 0))
	if bool(entry.get("fill", false)):
		player_hp = player_max_hp
	elif heal > 0:
		player_hp = mini(player_max_hp, player_hp + heal)
	else:
		player_hp = mini(player_hp, player_max_hp)
	floor_offer_open = false
	pending_offer_ids = []
	return id


func _apply_max_hp() -> void:
	var bonus := 40 if active_boon == "maxhp" else 0
	player_max_hp = base_max_hp + bonus + offer_max_hp


func _recompute_offers() -> void:
	offer_damage = 0
	offer_speed_mult = 1.0
	offer_attack_cd_mult = 1.0
	offer_max_hp = 0
	offer_dodge_cd = 0.0
	offer_dodge_speed = 0.0
	for id in picked_offer_ids:
		var entry := _OfferCatalog.get_by_id(id)
		offer_damage += int(entry.get("damage", 0))
		offer_max_hp += int(entry.get("max_hp", 0))
		offer_speed_mult *= float(entry.get("speed_mult", 1.0))
		offer_attack_cd_mult *= float(entry.get("attack_cd_mult", 1.0))
		offer_dodge_cd += float(entry.get("dodge_cd", 0.0))
		offer_dodge_speed += float(entry.get("dodge_speed", 0.0))


func boon_damage_bonus() -> int:
	return 20 if active_boon == "damage" else 0


func boon_speed_mult() -> float:
	return 1.45 if active_boon == "speed" else 1.0


func pick_boon(id: String) -> void:
	pending_boon = id


func _seal_run_stats() -> void:
	last_kills = kills
	last_floors = floors_reached
	_refresh_hub_meta()


func _refresh_hub_meta() -> void:
	if last_result == "extract":
		zh_ek_notice = "УК: зафиксирован выход жильца с этажа %d ЭЖК №17. Велосипеды на площадках по-прежнему запрещены. Убито «вредителей»: %d." % [last_floors, last_kills]
		board_feed = "Аноним %s\n>> кто-то вышел с %d-го. пикрил жёлтую дверь\n\nАноним\nцарствие небесное тем кто остался на -0" % [_time_tag(), last_floors]
	elif last_result == "death":
		zh_ek_notice = "Акт: потеря связи с жильцом на этаже %d. Просьба не перекрывать эвакуационные проёмы коробками. Зафиксировано контактов: %d." % [last_floors, last_kills]
		board_feed = "Аноним %s\nоп опять лёг на %d этаже лол\n\nАноним\n/hr/ советует не идти налево после щитовой" % [_time_tag(), last_floors]


func _time_tag() -> String:
	return "%02d:%02d" % [Time.get_time_dict_from_system()["hour"], Time.get_time_dict_from_system()["minute"]]


func record_floor_fingerprint(fp: String) -> void:
	last_floor_fingerprint = fp
	floor_fingerprints.append(fp)


func go_apartment() -> void:
	player_hp = player_max_hp
	get_tree().call_deferred("change_scene_to_file", SCENE_APARTMENT)


func go_entrance() -> void:
	get_tree().call_deferred("change_scene_to_file", SCENE_ENTRANCE)


func go_run() -> void:
	clear_run_offers()
	apply_boon_for_run()
	if next_run_seed >= 0:
		run_seed = next_run_seed
	else:
		run_seed = int(randi())
	next_run_seed = -1
	var plan := FloorCatalog.sequence(run_seed)
	run_length = int(plan["length"])
	preset_ids = []
	for id in plan["ids"]:
		preset_ids.append(str(id))
	current_floor = 1
	floors_reached = 1
	kills = 0
	floor_fingerprints = PackedStringArray()
	get_tree().call_deferred("change_scene_to_file", SCENE_RUN)


func advance_floor() -> void:
	if current_floor >= run_length:
		finish_extract()
		return
	current_floor += 1
	floors_reached = current_floor
	# Small recover between floors
	player_hp = mini(player_max_hp, player_hp + 20)
	get_tree().call_deferred("change_scene_to_file", SCENE_RUN)


func on_exit_reached() -> void:
	if current_floor >= run_length:
		finish_extract()
	else:
		advance_floor()


func finish_death() -> void:
	last_result = "death"
	_seal_run_stats()
	get_tree().call_deferred("change_scene_to_file", SCENE_RESULT)


func finish_extract() -> void:
	last_result = "extract"
	extracted_once = true
	kitchen_door_unlocked = true
	_seal_run_stats()
	get_tree().call_deferred("change_scene_to_file", SCENE_RESULT)
