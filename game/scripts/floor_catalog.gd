class_name FloorCatalog
extends RefCounted

const ZONE_ORDER: Array[String] = ["ordinary", "shift", "tech"]
const PATHS: Array[String] = [
	"res://resources/floors/hall.tres",
	"res://resources/floors/dryer.tres",
	"res://resources/floors/stroller.tres",
	"res://resources/floors/corridor.tres",
	"res://resources/floors/skipped.tres",
	"res://resources/floors/lift.tres",
	"res://resources/floors/switchboard.tres",
	"res://resources/floors/pipes.tres",
]
const WEIGHTS := {
	"first": {"ordinary": 1, "shift": 0, "tech": 0},
	"middle": {"ordinary": 0, "shift": 1, "tech": 0},
	"last": {"ordinary": 0, "shift": 0, "tech": 1},
}


static func all() -> Array[FloorPreset]:
	var out: Array[FloorPreset] = []
	for path in PATHS:
		var preset := load(path) as FloorPreset
		if preset != null:
			out.append(preset)
	return out


static func get_by_id(id: String) -> FloorPreset:
	for preset in all():
		if preset.id == id:
			return preset
	return null


static func sequence(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var length := 4 + int(rng.randi() % 3)
	var ids: Array[String] = []
	var used := {}
	for i in length:
		var slot := "first" if i == 0 else ("last" if i == length - 1 else "middle")
		var zone := _zone(rng, slot)
		var pool: Array[String] = []
		for id in _ids_for_zone(zone):
			if not used.has(id):
				pool.append(id)
		if pool.is_empty():
			pool = _ids_for_zone(zone)
		var pick: String = pool[int(rng.randi() % pool.size())]
		used[pick] = true
		ids.append(pick)
	return {"length": length, "ids": ids}


static func _ids_for_zone(zone: String) -> Array[String]:
	var ids: Array[String] = []
	for preset in all():
		if preset.zone == zone:
			ids.append(preset.id)
	return ids


static func _zone(rng: RandomNumberGenerator, slot: String) -> String:
	var weights: Dictionary = WEIGHTS[slot]
	var total := 0
	for zone in ZONE_ORDER:
		total += int(weights[zone])
	var roll := int(rng.randi() % total)
	var acc := 0
	for zone in ZONE_ORDER:
		acc += int(weights[zone])
		if roll < acc:
			return zone
	return ZONE_ORDER[0]
