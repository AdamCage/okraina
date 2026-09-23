class_name SlotStore
extends RefCounted

const PATH := "user://slot.json"
const VERSION := 3
const LEAD_IDS: Array[String] = ["", "pod_truth", "pod_lie", "pod_troll"]
const NOTICE_IDS: Array[String] = ["", "bikes", "elevator", "pot", "boxes", "bulb", "seal"]
const V1_KEYS: Array[String] = [
	"version",
	"pending_boon",
	"active_boon",
	"extracted_once",
	"kitchen_door_unlocked",
	"last_result",
	"last_kills",
	"last_floors",
	"zh_ek_notice",
	"board_feed",
]
const V2_KEYS: Array[String] = [
	"version",
	"pending_boon",
	"active_boon",
	"extracted_once",
	"kitchen_door_unlocked",
	"last_result",
	"last_kills",
	"last_floors",
	"zh_ek_notice",
	"board_feed",
	"lead_id",
]
const BAD_NOTICE := "Папка с документами не читается. Завели новую карточку жильца."
const DEFAULT_NOTICE := "В связи с повторным появлением лестничных площадок между 14-м и 15-м этажами просьба не оставлять там велосипеды."
const DEFAULT_BOARD := " /pod/ — пока тихо. Аноны спят или зависли в лифте."
const BOONS: Array[String] = ["none", "damage", "maxhp", "speed"]
const RESULTS: Array[String] = ["", "death", "extract"]
const KEYS: Array[String] = [
	"version",
	"pending_boon",
	"active_boon",
	"extracted_once",
	"kitchen_door_unlocked",
	"last_result",
	"last_kills",
	"last_floors",
	"zh_ek_notice",
	"board_feed",
	"lead_id",
	"notice_id",
]


static func save_from(gs: Node) -> bool:
	var data := {
		"version": VERSION,
		"pending_boon": str(gs.get("pending_boon")),
		"active_boon": str(gs.get("active_boon")),
		"extracted_once": _flag(gs.get("extracted_once")),
		"kitchen_door_unlocked": _flag(gs.get("kitchen_door_unlocked")),
		"last_result": str(gs.get("last_result")),
		"last_kills": int(gs.get("last_kills")),
		"last_floors": int(gs.get("last_floors")),
		"zh_ek_notice": str(gs.get("zh_ek_notice")),
		"board_feed": str(gs.get("board_feed")),
		"lead_id": str(gs.get("lead_id")),
		"notice_id": str(gs.get("notice_id")),
	}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


static func load_into(gs: Node) -> String:
	if not FileAccess.file_exists(PATH):
		return "missing"
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		_apply_bad(gs)
		return "bad"
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_apply_bad(gs)
		return "bad"
	var migrated := migrate(parsed)
	if migrated.is_empty() or not _valid(migrated):
		_apply_bad(gs)
		return "bad"
	gs.set("pending_boon", str(migrated["pending_boon"]))
	gs.set("active_boon", str(migrated["active_boon"]))
	gs.set("extracted_once", _flag(migrated["extracted_once"]))
	gs.set("kitchen_door_unlocked", _flag(migrated["kitchen_door_unlocked"]))
	gs.set("last_result", str(migrated["last_result"]))
	gs.set("last_kills", int(migrated["last_kills"]))
	gs.set("last_floors", int(migrated["last_floors"]))
	gs.set("zh_ek_notice", str(migrated["zh_ek_notice"]))
	gs.set("board_feed", str(migrated["board_feed"]))
	gs.set("lead_id", str(migrated["lead_id"]))
	gs.set("notice_id", str(migrated["notice_id"]))
	return "ok"


static func migrate(raw: Dictionary) -> Dictionary:
	if not _whole_number(raw.get("version", null)):
		return {}
	var version := int(raw["version"])
	if version == 1:
		if not _valid_v1(raw):
			return {}
		var from_v1 := raw.duplicate()
		from_v1["version"] = VERSION
		from_v1["lead_id"] = ""
		from_v1["notice_id"] = ""
		return from_v1
	if version == 2:
		if not _valid_v2(raw):
			return {}
		var from_v2 := raw.duplicate()
		from_v2["version"] = VERSION
		from_v2["notice_id"] = ""
		return from_v2
	if version == VERSION:
		return raw
	return {}


static func wipe_slot() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("slot.json")


static func _valid(data: Dictionary) -> bool:
	for key in KEYS:
		if not data.has(key):
			return false
	if not _whole_number(data["version"]) or int(data["version"]) != VERSION:
		return false
	if typeof(data["pending_boon"]) != TYPE_STRING or not BOONS.has(str(data["pending_boon"])):
		return false
	if typeof(data["active_boon"]) != TYPE_STRING or not BOONS.has(str(data["active_boon"])):
		return false
	if typeof(data["extracted_once"]) != TYPE_BOOL:
		return false
	if typeof(data["kitchen_door_unlocked"]) != TYPE_BOOL:
		return false
	if typeof(data["last_result"]) != TYPE_STRING or not RESULTS.has(str(data["last_result"])):
		return false
	if not _whole_number(data["last_kills"]) or int(data["last_kills"]) < 0:
		return false
	if not _whole_number(data["last_floors"]) or int(data["last_floors"]) < 0:
		return false
	if typeof(data["zh_ek_notice"]) != TYPE_STRING:
		return false
	if typeof(data["board_feed"]) != TYPE_STRING:
		return false
	if typeof(data["lead_id"]) != TYPE_STRING or not LEAD_IDS.has(str(data["lead_id"])):
		return false
	if typeof(data["notice_id"]) != TYPE_STRING or not NOTICE_IDS.has(str(data["notice_id"])):
		return false
	return true


static func _valid_v2(data: Dictionary) -> bool:
	for key in V2_KEYS:
		if not data.has(key):
			return false
	if not _whole_number(data["version"]) or int(data["version"]) != 2:
		return false
	if typeof(data["pending_boon"]) != TYPE_STRING or not BOONS.has(str(data["pending_boon"])):
		return false
	if typeof(data["active_boon"]) != TYPE_STRING or not BOONS.has(str(data["active_boon"])):
		return false
	if typeof(data["extracted_once"]) != TYPE_BOOL:
		return false
	if typeof(data["kitchen_door_unlocked"]) != TYPE_BOOL:
		return false
	if typeof(data["last_result"]) != TYPE_STRING or not RESULTS.has(str(data["last_result"])):
		return false
	if not _whole_number(data["last_kills"]) or int(data["last_kills"]) < 0:
		return false
	if not _whole_number(data["last_floors"]) or int(data["last_floors"]) < 0:
		return false
	if typeof(data["zh_ek_notice"]) != TYPE_STRING:
		return false
	if typeof(data["board_feed"]) != TYPE_STRING:
		return false
	if typeof(data["lead_id"]) != TYPE_STRING or not LEAD_IDS.has(str(data["lead_id"])):
		return false
	return true


static func _valid_v1(data: Dictionary) -> bool:
	for key in V1_KEYS:
		if not data.has(key):
			return false
	if not _whole_number(data["version"]) or int(data["version"]) != 1:
		return false
	if typeof(data["pending_boon"]) != TYPE_STRING or not BOONS.has(str(data["pending_boon"])):
		return false
	if typeof(data["active_boon"]) != TYPE_STRING or not BOONS.has(str(data["active_boon"])):
		return false
	if typeof(data["extracted_once"]) != TYPE_BOOL:
		return false
	if typeof(data["kitchen_door_unlocked"]) != TYPE_BOOL:
		return false
	if typeof(data["last_result"]) != TYPE_STRING or not RESULTS.has(str(data["last_result"])):
		return false
	if not _whole_number(data["last_kills"]) or int(data["last_kills"]) < 0:
		return false
	if not _whole_number(data["last_floors"]) or int(data["last_floors"]) < 0:
		return false
	if typeof(data["zh_ek_notice"]) != TYPE_STRING:
		return false
	if typeof(data["board_feed"]) != TYPE_STRING:
		return false
	return true


static func _flag(value) -> bool:
	return value == true


static func _whole_number(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_equal_approx(value, floorf(float(value)))
	return false


static func _apply_bad(gs: Node) -> void:
	gs.set("pending_boon", "none")
	gs.set("active_boon", "none")
	gs.set("extracted_once", false)
	gs.set("kitchen_door_unlocked", false)
	gs.set("last_result", "")
	gs.set("last_kills", 0)
	gs.set("last_floors", 0)
	gs.set("board_feed", DEFAULT_BOARD)
	gs.set("zh_ek_notice", BAD_NOTICE)
	gs.set("lead_id", "")
	gs.set("notice_id", "")
