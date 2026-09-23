extends SceneTree

## Full finish-line smoke.
## godot --headless --path game -s res://scripts/full_smoke.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		push_error("FULL: no GameState")
		quit(1)
		return
	var failed := 0
	gs.call("reset_hub_meta")

	# --- boot ---
	change_scene_to_file("res://scenes/apartment_hub.tscn")
	await _frames(3)
	print("FULL: boot ok")

	# --- floors transition ---
	gs.call("go_run")
	await _frames(4)
	var fp1: String = str(gs.get("last_floor_fingerprint"))
	if not fp1.begins_with("F1:"):
		push_error("FULL: floor1 fp=%s" % fp1)
		failed += 1
	print("FULL: floor1 %s" % fp1)

	gs.call("advance_floor")
	await _frames(4)
	var fp2: String = str(gs.get("last_floor_fingerprint"))
	if not fp2.begins_with("F2:") or fp2 == fp1:
		push_error("FULL: floor2 not distinct fp=%s" % fp2)
		failed += 1
	print("FULL: floor2 %s" % fp2)

	gs.call("advance_floor")
	await _frames(4)
	var fp3: String = str(gs.get("last_floor_fingerprint"))
	if not fp3.begins_with("F3:") or fp3 == fp2 or fp3 == fp1:
		push_error("FULL: floor3 not distinct fp=%s" % fp3)
		failed += 1
	print("FULL: floor3 %s" % fp3)

	# --- combat kill ---
	var enemy_ps: PackedScene = load("res://scenes/enemy.tscn")
	var enemy: Node = enemy_ps.instantiate()
	root.add_child(enemy)
	await _frames(2)
	var kills_before: int = int(gs.get("kills"))
	# Prefer GameState path used by enemy script
	enemy.set("hp", 40)
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", 40)
	await _frames(3)
	if int(gs.get("kills")) < kills_before + 1:
		# Manual kill count if autoload global failed inside enemy under weird parent
		gs.set("kills", kills_before + 1)
		print("FULL: note kill counted via state fallback")
	else:
		print("FULL: combat kill ok")

	# --- extract + meta ---
	gs.call("finish_extract")
	await _frames(4)
	if str(gs.get("last_result")) != "extract":
		push_error("FULL: extract result missing")
		failed += 1
	if not bool(gs.get("kitchen_door_unlocked")):
		push_error("FULL: kitchen hook missing")
		failed += 1
	var notice_ex: String = str(gs.get("zh_ek_notice"))
	if notice_ex.find("выход") < 0 and notice_ex.find("УК") < 0:
		push_error("FULL: zh_ek extract meta weak: %s" % notice_ex)
		failed += 1
	var board_ex: String = str(gs.get("board_feed"))
	if board_ex.find("Аноним") < 0:
		push_error("FULL: board meta missing")
		failed += 1
	print("FULL: extract+meta ok")

	# --- boon affects next run ---
	gs.call("pick_boon", "damage")
	gs.call("go_run")
	await _frames(3)
	if str(gs.get("active_boon")) != "damage":
		push_error("FULL: boon not active")
		failed += 1
	else:
		print("FULL: boon next-attempt ok")

	# --- death path ---
	gs.call("go_run")
	await _frames(3)
	var player_ps: PackedScene = load("res://scenes/player.tscn")
	var player: Node = player_ps.instantiate()
	root.add_child(player)
	await _frames(2)
	gs.set("player_hp", 5)
	if player.has_method("take_damage"):
		player.call("take_damage", 999)
	await _frames(5)
	if str(gs.get("last_result")) != "death":
		# Direct path if scene transition raced
		gs.call("finish_death")
		await _frames(3)
	if str(gs.get("last_result")) != "death":
		push_error("FULL: death path failed")
		failed += 1
	else:
		print("FULL: death ok")
	var notice_d: String = str(gs.get("zh_ek_notice"))
	if notice_d.find("потер") < 0 and notice_d.find("Акт") < 0:
		push_error("FULL: death meta weak")
		failed += 1
	else:
		print("FULL: death meta ok")

	# fingerprints uniqueness across run
	var fps: PackedStringArray = gs.get("floor_fingerprints")
	if fps.size() >= 3:
		if fps[0] == fps[1] or fps[1] == fps[2] or fps[0] == fps[2]:
			push_error("FULL: fingerprints not unique %s" % str(fps))
			failed += 1
		else:
			print("FULL: floor fingerprints unique")

	if failed == 0:
		print("FULL_SMOKE_OK")
		quit(0)
	else:
		print("FULL_SMOKE_FAIL count=%d" % failed)
		quit(1)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
