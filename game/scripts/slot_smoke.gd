extends SceneTree

## SV1: a second GameState reads the flag from disk.
## SV2: corrupting the slot leaves a copied good file intact.
## SV3: a missing file is a new game, not the bad-folder line.
## godot --headless --path game -s res://scripts/slot_smoke.gd

const COPY_NAME := "slot_copy.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		push_error("SLOT: no GameState")
		quit(1)
		return
	var failed := 0
	gs.call("reset_hub_meta")
	_remove_copy()

	gs.set("kitchen_door_unlocked", true)
	gs.set("pending_boon", "damage")
	gs.set("last_result", "extract")
	gs.set("last_kills", 4)
	gs.set("last_floors", 5)
	if gs.call("save_slot") != true:
		push_error("SLOT: save failed")
		quit(1)
		return
	var other: Node = load("res://autoload/game_state.gd").new()
	root.add_child(other)
	await process_frame
	if other.get("kitchen_door_unlocked") != true or str(other.get("pending_boon")) != "damage":
		push_error("SLOT: SV1 door=%s boon=%s" % [other.get("kitchen_door_unlocked"), other.get("pending_boon")])
		failed += 1
	elif int(other.get("last_kills")) != 4 or int(other.get("last_floors")) != 5:
		push_error("SLOT: SV1 counts")
		failed += 1
	else:
		print("SLOT: SV1 second instance")
	other.free()

	var slot_path := ProjectSettings.globalize_path(SlotStore.PATH)
	var good := FileAccess.get_file_as_bytes(slot_path)
	var copy_path := ProjectSettings.globalize_path("user://%s" % COPY_NAME)
	var copy_file := FileAccess.open(copy_path, FileAccess.WRITE)
	if copy_file == null:
		push_error("SLOT: copy open failed")
		quit(1)
		return
	copy_file.store_buffer(good)
	copy_file.close()
	var bad := FileAccess.open(slot_path, FileAccess.WRITE)
	bad.store_string("{not json")
	bad.close()
	var broken: Node = load("res://autoload/game_state.gd").new()
	root.add_child(broken)
	await process_frame
	if broken.get("kitchen_door_unlocked") == true or str(broken.get("zh_ek_notice")) != SlotStore.BAD_NOTICE:
		push_error("SLOT: SV2 notice=%s" % broken.get("zh_ek_notice"))
		failed += 1
	elif FileAccess.get_file_as_bytes(copy_path) != good:
		push_error("SLOT: SV2 copy changed")
		failed += 1
	else:
		print("SLOT: SV2 copy intact")
	broken.free()

	SlotStore.wipe_slot()
	var fresh: Node = load("res://autoload/game_state.gd").new()
	root.add_child(fresh)
	await process_frame
	if str(fresh.get("zh_ek_notice")) != SlotStore.DEFAULT_NOTICE or str(fresh.get("zh_ek_notice")) == SlotStore.BAD_NOTICE:
		push_error("SLOT: SV3 notice=%s" % fresh.get("zh_ek_notice"))
		failed += 1
	elif fresh.get("kitchen_door_unlocked") == true:
		push_error("SLOT: SV3 door unlocked")
		failed += 1
	else:
		print("SLOT: SV3 missing file")
	fresh.free()

	# Fractional version is corrupt. Integer-looking JSON float 1.0 still loads.
	gs.call("reset_hub_meta")
	gs.set("kitchen_door_unlocked", true)
	gs.call("save_slot")
	var raw := FileAccess.get_file_as_string(slot_path)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY or not SlotStore._whole_number(parsed.get("version")):
		push_error("SLOT: saved version is not a whole number")
		failed += 1
	else:
		print("SLOT: saved version is a whole number")
	var fraction := FileAccess.open(slot_path, FileAccess.WRITE)
	fraction.store_string("{\"version\":1.5}")
	fraction.close()
	var fractional: Node = load("res://autoload/game_state.gd").new()
	root.add_child(fractional)
	await process_frame
	if str(fractional.get("zh_ek_notice")) != SlotStore.BAD_NOTICE:
		push_error("SLOT: fractional version loaded")
		failed += 1
	else:
		print("SLOT: fractional version rejected")
	fractional.free()

	gs.call("reset_hub_meta")
	_remove_copy()
	if failed == 0:
		print("SLOT_SMOKE_OK")
		quit(0)
		return
	print("SLOT_SMOKE_FAIL count=%d" % failed)
	quit(1)


func _remove_copy() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(COPY_NAME):
		dir.remove(COPY_NAME)
