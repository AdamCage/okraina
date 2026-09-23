extends SceneTree

const _Board := preload("res://scripts/board_catalog.gd")

## IB1 truth matches the recorded run and the lie does not.
## IB2 the troll still starts a run.
## IB3 a second GameState reads lead_id.
## IB4 a whole version-1 slot migrates and a copy stays intact.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		push_error("BOARD: no GameState")
		quit(1)
		return
	var failed := 0
	gs.call("reset_hub_meta")
	gs.set("last_result", "extract")
	gs.set("last_floors", 5)
	gs.set("last_kills", 4)
	var threads: Array = _Board.threads_for("extract", 5, 4)
	var truth: Dictionary = threads[0]
	var lie: Dictionary = threads[1]
	var troll: Dictionary = threads[2]
	if str(truth["claims_result"]) != "extract" or int(truth["claims_floors"]) != 5 or int(truth["claims_kills"]) != 4:
		push_error("BOARD: truth %s" % str(truth))
		failed += 1
	elif str(lie["claims_result"]) == "extract" or int(lie["claims_floors"]) == 5 or int(lie["claims_kills"]) == 4:
		push_error("BOARD: lie matched %s" % str(lie))
		failed += 1
	elif str(troll["body"]) != _Board.TROLL_BODY:
		push_error("BOARD: troll body")
		failed += 1
	else:
		print("BOARD: IB1 claims")

	if gs.call("pick_lead", "hr_note") == true:
		push_error("BOARD: hr accepted a lead")
		failed += 1
	if gs.call("pick_lead", "pod_truth") != true:
		push_error("BOARD: truth pick failed")
		failed += 1
	gs.call("go_run")
	await _frames(4)
	var player := get_first_node_in_group("player")
	if player == null or int(player.get("attack_damage")) != 31:
		push_error("BOARD: steady damage %s" % (player.get("attack_damage") if player != null else "none"))
		failed += 1
	else:
		print("BOARD: steady 31")
	var lead_text := ""
	var scene := current_scene
	if scene != null:
		for node in scene.get_node("HUD").get_children():
			if node is Label and str(node.text) == "Сверился":
				lead_text = str(node.text)
	if lead_text != "Сверился":
		push_error("BOARD: floor label missing")
		failed += 1

	if gs.call("pick_lead", "pod_lie") != true:
		push_error("BOARD: lie pick failed")
		failed += 1
	gs.call("go_run")
	await _frames(4)
	player = get_first_node_in_group("player")
	if player == null or not is_equal_approx(float(player.get("speed")), 153.0):
		push_error("BOARD: drag speed %s" % (player.get("speed") if player != null else "none"))
		failed += 1
	else:
		print("BOARD: drag 153")

	if gs.call("pick_lead", "pod_troll") != true:
		push_error("BOARD: troll pick failed")
		failed += 1
	gs.call("go_run")
	await _frames(4)
	player = get_first_node_in_group("player")
	if player == null or not is_equal_approx(float(player.get("attack_cooldown")), 0.34):
		push_error("BOARD: rush cd %s" % (player.get("attack_cooldown") if player != null else "none"))
		failed += 1
	elif str(gs.get("lead_id")) != "pod_troll":
		push_error("BOARD: go_run cleared lead")
		failed += 1
	else:
		print("BOARD: IB2 troll run")

	var other: Node = load("res://autoload/game_state.gd").new()
	root.add_child(other)
	await process_frame
	if str(other.get("lead_id")) != "pod_troll":
		push_error("BOARD: IB3 lead %s" % other.get("lead_id"))
		failed += 1
	else:
		print("BOARD: IB3 reloaded")
	other.free()

	var slot_path := ProjectSettings.globalize_path(SlotStore.PATH)
	var v1 := {
		"version": 1,
		"pending_boon": "maxhp",
		"active_boon": "none",
		"extracted_once": true,
		"kitchen_door_unlocked": true,
		"last_result": "death",
		"last_kills": 2,
		"last_floors": 4,
		"zh_ek_notice": "тест жэк",
		"board_feed": "Аноним тест",
	}
	var v1_text := JSON.stringify(v1)
	var slot_file := FileAccess.open(slot_path, FileAccess.WRITE)
	slot_file.store_string(v1_text)
	slot_file.close()
	var copy_path := ProjectSettings.globalize_path("user://slot_v1_copy.json")
	var copy_file := FileAccess.open(copy_path, FileAccess.WRITE)
	copy_file.store_string(v1_text)
	copy_file.close()
	var lifted: Node = load("res://autoload/game_state.gd").new()
	root.add_child(lifted)
	await process_frame
	if lifted.get("kitchen_door_unlocked") != true or str(lifted.get("pending_boon")) != "maxhp" or str(lifted.get("lead_id")) != "":
		push_error("BOARD: IB4 door=%s boon=%s lead=%s" % [lifted.get("kitchen_door_unlocked"), lifted.get("pending_boon"), lifted.get("lead_id")])
		failed += 1
	elif FileAccess.get_file_as_string(copy_path) != v1_text:
		push_error("BOARD: IB4 copy changed")
		failed += 1
	elif FileAccess.get_file_as_string(slot_path) != v1_text:
		push_error("BOARD: IB4 slot rewritten on read")
		failed += 1
	else:
		print("BOARD: IB4 v1 migrated")
	lifted.free()

	var quiet: Array = _Board.threads_for("", 9, 30)
	if int(quiet[0]["claims_floors"]) != -1:
		push_error("BOARD: quiet truth named a floor")
		failed += 1
	elif int(quiet[1]["claims_floors"]) != 10 or int(quiet[1]["claims_kills"]) != 33:
		push_error("BOARD: quiet lie %s" % str(quiet[1]))
		failed += 1
	else:
		print("BOARD: empty result lie offset")

	change_scene_to_file("res://scenes/apartment_hub.tscn")
	await _frames(3)
	var hub := current_scene
	if hub == null or not hub.has_method("_toggle_board"):
		push_error("BOARD: hub missing")
		failed += 1
	else:
		hub.call("_toggle_board")
		await _frames(2)
		if hub.get_node_or_null("BoardPanel") == null:
			push_error("BOARD: panel did not open")
			failed += 1
		else:
			print("BOARD: panel open")
			hub.call("_toggle_board")
	gs.call("reset_hub_meta")
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("slot_v1_copy.json"):
		dir.remove("slot_v1_copy.json")
	if failed == 0:
		print("BOARD_SMOKE_OK")
		quit(0)
		return
	print("BOARD_SMOKE_FAIL count=%d" % failed)
	quit(1)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame
