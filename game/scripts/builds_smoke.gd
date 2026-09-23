extends SceneTree

## RB1 pick changes the promised stat. RB2 it survives the next floor.
## RB3 death and extract. RB4 the next go_run starts empty.
## godot --headless --path game -s res://scripts/builds_smoke.gd

const _Catalog := preload("res://scripts/offer_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		push_error("BUILDS: no GameState")
		quit(1)
		return
	var failed := 0
	if _Catalog.all().size() != 10:
		push_error("BUILDS: pool %d" % _Catalog.all().size())
		failed += 1

	gs.call("go_run")
	if not await _wait_choice(gs):
		push_error("BUILDS: floor 1 choice missing")
		quit(1)
		return
	var pending: Array = gs.get("pending_offer_ids")
	if pending.size() != 3:
		push_error("BUILDS: pending %s" % str(pending))
		failed += 1
	var player := get_first_node_in_group("player")
	var id := str(pending[0])
	if str(gs.call("pick_offer", 0)) != id:
		push_error("BUILDS: pick failed")
		failed += 1
	player.call("apply_build")
	if not _stat_matches(id, player, gs, true):
		push_error("BUILDS: RB1 stat %s" % id)
		failed += 1
	else:
		print("BUILDS: RB1 %s ok" % id)

	gs.call("advance_floor")
	if not await _wait_choice(gs):
		push_error("BUILDS: floor 2 choice missing")
		quit(1)
		return
	var kept: Array = gs.get("picked_offer_ids")
	if kept.size() != 1 or str(kept[0]) != id:
		push_error("BUILDS: RB2 list %s" % str(kept))
		failed += 1
	var player2 := get_first_node_in_group("player")
	if not _stat_matches(id, player2, gs, false):
		push_error("BUILDS: RB2 stat dropped %s" % id)
		failed += 1
	else:
		print("BUILDS: RB2 kept ok")

	gs.call("go_run")
	if not await _wait_choice(gs):
		push_error("BUILDS: fresh run choice missing")
		quit(1)
		return
	if (gs.get("picked_offer_ids") as Array).size() != 0:
		push_error("BUILDS: RB4 leaked")
		failed += 1
	else:
		print("BUILDS: RB4 clear ok")

	gs.call("pick_offer", 0)
	var victim := get_first_node_in_group("player")
	victim.call("apply_build")
	gs.set("player_hp", 5)
	victim.call("take_damage", 999)
	await _frames(5)
	if str(gs.get("last_result")) != "death":
		push_error("BUILDS: RB3 death")
		failed += 1
	else:
		print("BUILDS: RB3 death ok")

	gs.call("go_run")
	if not await _wait_choice(gs):
		push_error("BUILDS: extract setup missing")
		quit(1)
		return
	gs.call("pick_offer", 0)
	gs.call("finish_extract")
	await _frames(4)
	if str(gs.get("last_result")) != "extract":
		push_error("BUILDS: RB3 extract")
		failed += 1
	else:
		print("BUILDS: RB3 extract ok")

	var filled := false
	for _attempt in 24:
		gs.call("go_run")
		if not await _wait_choice(gs):
			push_error("BUILDS: tap_water setup missing")
			quit(1)
			return
		var offered: Array = gs.get("pending_offer_ids")
		var index := offered.find("tap_water")
		if index < 0:
			continue
		gs.set("player_hp", 60)
		if str(gs.call("pick_offer", index)) != "tap_water":
			push_error("BUILDS: tap_water pick")
			failed += 1
		elif int(gs.get("player_max_hp")) != 120 or int(gs.get("player_hp")) != 120:
			push_error("BUILDS: tap_water wounded %s/%s" % [gs.get("player_hp"), gs.get("player_max_hp")])
			failed += 1
		else:
			print("BUILDS: tap_water fills to new max")
		filled = true
		break
	if not filled:
		push_error("BUILDS: tap_water never offered")
		failed += 1

	if failed == 0:
		print("BUILDS_SMOKE_OK")
		quit(0)
		return
	print("BUILDS_SMOKE_FAIL count=%d" % failed)
	quit(1)


func _stat_matches(id: String, player: Node, gs: Node, check_heal: bool) -> bool:
	var entry := _Catalog.get_by_id(id)
	if entry.is_empty() or player == null:
		return false
	var ok := true
	if entry.has("damage"):
		ok = ok and int(player.get("attack_damage")) == 25 + int(entry["damage"])
	if entry.has("max_hp"):
		ok = ok and int(gs.get("player_max_hp")) == 100 + int(entry["max_hp"])
		if check_heal:
			if bool(entry.get("fill", false)):
				ok = ok and int(gs.get("player_hp")) == int(gs.get("player_max_hp"))
			else:
				var heal := int(entry.get("heal", 0))
				var expect := mini(100 + int(entry["max_hp"]), 100 + heal)
				ok = ok and int(gs.get("player_hp")) == expect
	if entry.has("speed_mult"):
		ok = ok and is_equal_approx(float(player.get("speed")), 180.0 * float(entry["speed_mult"]))
	if entry.has("attack_cd_mult"):
		var expect := maxf(0.20, 0.40 * float(entry["attack_cd_mult"]))
		ok = ok and is_equal_approx(float(player.get("attack_cooldown")), expect)
	if entry.has("dodge_cd"):
		var expect := maxf(0.25, 0.70 + float(entry["dodge_cd"]))
		ok = ok and is_equal_approx(float(player.get("_dodge_cooldown_sec")), expect)
	if entry.has("dodge_speed"):
		ok = ok and is_equal_approx(float(player.get("_dodge_speed")), 520.0 + float(entry["dodge_speed"]))
	return ok


func _wait_choice(gs: Node) -> bool:
	for _i in 40:
		var pending: Array = gs.get("pending_offer_ids")
		if bool(gs.get("floor_offer_open")) and pending.size() == 3 and get_first_node_in_group("player") != null:
			return true
		await process_frame
	return false


func _frames(n: int) -> void:
	for _i in n:
		await process_frame
