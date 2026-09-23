extends SceneTree

const _Slot := preload("res://scripts/slot_store.gd")

## ZK1 the next run takes the notice, the run before the seal does not.
## ZK2 the apartment line names the office and the floor.
## ZK3 whole version 1 and 2 slots migrate and their bytes stay put.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		push_error("NOTICE: no GameState")
		quit(1)
		return
	var failed := 0
	gs.call("reset_hub_meta")
	gs.call("go_run")
	await _frames(4)
	var player := get_first_node_in_group("player")
	if player == null or int(player.get("attack_damage")) != 25 or not is_equal_approx(float(player.get("speed")), 180.0):
		push_error("NOTICE: before seal %s" % (player.get("speed") if player != null else "none"))
		failed += 1
	else:
		print("NOTICE: before seal 25/180")

	gs.set("floors_reached", 1)
	gs.set("kills", 0)
	gs.call("finish_extract")
	await _frames(3)
	if str(gs.get("notice_id")) != "elevator":
		push_error("NOTICE: elevator id %s" % gs.get("notice_id"))
		failed += 1
	var wall := str(gs.get("zh_ek_notice"))
	if wall.find("УК") < 0 or wall.find("1") < 0:
		push_error("NOTICE: elevator wall %s" % wall)
		failed += 1
	else:
		print("NOTICE: ZK2 extract wall")
	var other: Node = load("res://autoload/game_state.gd").new()
	root.add_child(other)
	await process_frame
	if str(other.get("notice_id")) != "elevator":
		push_error("NOTICE: reloaded %s" % other.get("notice_id"))
		failed += 1
	else:
		print("NOTICE: elevator reloaded")
	other.free()

	gs.call("go_run")
	await _frames(4)
	player = get_first_node_in_group("player")
	if player == null or not is_equal_approx(float(player.get("speed")), 162.0) or int(player.get("attack_damage")) != 25:
		push_error("NOTICE: weight %s/%s" % [player.get("speed") if player != null else "none", player.get("attack_damage") if player != null else "none"])
		failed += 1
	elif str(gs.get("notice_id")) != "elevator":
		push_error("NOTICE: go_run cleared notice")
		failed += 1
	else:
		print("NOTICE: weight 162")

	gs.set("floors_reached", 1)
	gs.set("kills", 1)
	gs.call("finish_extract")
	await _frames(3)
	if str(gs.get("notice_id")) != "pot":
		push_error("NOTICE: pot id %s" % gs.get("notice_id"))
		failed += 1
	gs.call("go_run")
	await _frames(4)
	player = get_first_node_in_group("player")
	if player == null or int(player.get("attack_damage")) != 33 or not is_equal_approx(float(player.get("speed")), 180.0):
		push_error("NOTICE: bonus %s/%s" % [player.get("attack_damage") if player != null else "none", player.get("speed") if player != null else "none"])
		failed += 1
	else:
		print("NOTICE: ZK1 pot 33")

	gs.set("floors_reached", 2)
	gs.set("kills", 0)
	gs.call("finish_death")
	await _frames(3)
	var death_wall := str(gs.get("zh_ek_notice"))
	if str(gs.get("notice_id")) != "seal" or death_wall.find("Акт") < 0 or death_wall.find("2") < 0:
		push_error("NOTICE: seal wall %s %s" % [gs.get("notice_id"), death_wall])
		failed += 1
	else:
		print("NOTICE: ZK2 death wall")
	gs.call("go_run")
	await _frames(4)
	player = get_first_node_in_group("player")
	if player == null or int(player.get("attack_damage")) != 33:
		push_error("NOTICE: seal damage")
		failed += 1

	gs.set("floors_reached", 0)
	gs.set("kills", 0)
	gs.call("finish_death")
	await _frames(3)
	if str(gs.get("notice_id")) != "boxes":
		push_error("NOTICE: boxes id %s" % gs.get("notice_id"))
		failed += 1
	gs.call("go_run")
	await _frames(4)
	player = get_first_node_in_group("player")
	if player == null or not is_equal_approx(float(player.get("speed")), 162.0):
		push_error("NOTICE: boxes speed")
		failed += 1
	else:
		print("NOTICE: boxes 162")

	failed += await _old_slot(2, "pod_truth", true)
	failed += await _old_slot(1, "", true)

	gs.call("reset_hub_meta")
	_drop("user://slot_notice_copy.json")
	if failed == 0:
		print("NOTICE_SMOKE_OK")
		quit(0)
		return
	print("NOTICE_SMOKE_FAIL count=%d" % failed)
	quit(1)


func _old_slot(version: int, lead_id: String, kitchen: bool) -> int:
	var raw := {
		"version": version,
		"pending_boon": "maxhp",
		"active_boon": "none",
		"extracted_once": true,
		"kitchen_door_unlocked": kitchen,
		"last_result": "death",
		"last_kills": 2,
		"last_floors": 4,
		"zh_ek_notice": "тест жэк",
		"board_feed": "Аноним тест",
		"notice_id": "bikes",
	}
	if version >= 2:
		raw["lead_id"] = lead_id
	var text := JSON.stringify(raw)
	var slot_path := ProjectSettings.globalize_path(_Slot.PATH)
	var slot_file := FileAccess.open(slot_path, FileAccess.WRITE)
	slot_file.store_string(text)
	slot_file.close()
	var copy_path := ProjectSettings.globalize_path("user://slot_notice_copy.json")
	var copy_file := FileAccess.open(copy_path, FileAccess.WRITE)
	copy_file.store_string(text)
	copy_file.close()
	var lifted: Node = load("res://autoload/game_state.gd").new()
	root.add_child(lifted)
	await process_frame
	var lead_ok: bool = str(lifted.get("lead_id")) == lead_id
	var notice_ok: bool = str(lifted.get("notice_id")) == ""
	var door_ok: bool = lifted.get("kitchen_door_unlocked") == kitchen
	var boon_ok: bool = str(lifted.get("pending_boon")) == "maxhp"
	var bytes_ok: bool = FileAccess.get_file_as_string(slot_path) == text and FileAccess.get_file_as_string(copy_path) == text
	lifted.free()
	if not lead_ok or not notice_ok or not door_ok or not boon_ok or not bytes_ok:
		push_error("NOTICE: v%d lead=%s notice=%s door=%s boon=%s bytes=%s" % [version, lead_ok, notice_ok, door_ok, boon_ok, bytes_ok])
		return 1
	print("NOTICE: ZK3 v%d migrated" % version)
	return 0


func _drop(path: String) -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(path.get_file()):
		dir.remove(path.get_file())


func _frames(n: int) -> void:
	for _i in n:
		await process_frame
