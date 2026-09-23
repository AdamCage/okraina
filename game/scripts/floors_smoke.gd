extends SceneTree

## RF1–RF2: seeds 1 and 2, and seed 1 again.
## RF3: both enemy kinds die.
## RF4: the last floor extracts; an earlier floor does not.
## Meter: zone 72 arms the dodge; an early press does not cover the 0.85s strike.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		push_error("FLOORS: no GameState")
		quit(1)
		return
	var failed := 0
	if int(gs.get("next_run_seed")) != -1:
		push_error("FLOORS: next_run_seed did not start at -1")
		failed += 1

	var seed1 := FloorCatalog.sequence(1)
	var seed2 := FloorCatalog.sequence(2)
	var seed1_again := FloorCatalog.sequence(1)
	if not _plan_is(seed1, 4, ["dryer", "corridor", "lift", "pipes"]):
		push_error("FLOORS: RF1 seed1 %s" % str(seed1))
		failed += 1
	elif not _plan_is(seed2, 5, ["hall", "skipped", "corridor", "lift", "switchboard"]):
		push_error("FLOORS: RF1 seed2 %s" % str(seed2))
		failed += 1
	elif _ids(seed1) == _ids(seed2):
		push_error("FLOORS: RF1 sequences matched")
		failed += 1
	else:
		print("FLOORS: RF1 seeds differ")
	if _ids(seed1) != _ids(seed1_again) or int(seed1["length"]) != int(seed1_again["length"]):
		push_error("FLOORS: RF2 seed1 drifted")
		failed += 1
	else:
		print("FLOORS: RF2 same seed")

	if FloorCatalog.all().size() != 8:
		push_error("FLOORS: catalog %d" % FloorCatalog.all().size())
		failed += 1
	for tech_id in ["switchboard", "pipes"]:
		var tech := FloorCatalog.get_by_id(tech_id)
		if tech == null or not tech.spawn_kinds.has("meter"):
			push_error("FLOORS: %s has no meter" % tech_id)
			failed += 1

	gs.set("next_run_seed", 1)
	gs.call("go_run")
	await _frames(4)
	if int(gs.get("run_seed")) != 1 or int(gs.get("run_length")) != 4:
		push_error("FLOORS: live seed/length %s %s" % [gs.get("run_seed"), gs.get("run_length")])
		failed += 1
	var live: Array = gs.get("preset_ids")
	if live.is_empty() or str(live[0]) != "dryer":
		push_error("FLOORS: live ids %s" % str(live))
		failed += 1
	if int(gs.get("next_run_seed")) != -1:
		push_error("FLOORS: override was not cleared")
		failed += 1
	var scene := current_scene
	var exit_label := scene.get_node("World/ExitZone/ExitLabel") as Label
	var hint := scene.get_node("HUD/ExitHint") as Label
	var info := scene.get_node("HUD/Info") as Label
	if exit_label.text != "ДАЛЬШЕ":
		push_error("FLOORS: zone label %s" % exit_label.text)
		failed += 1
	if hint.text.find("дальше по дому") < 0 or hint.text.find("1/4") < 0:
		push_error("FLOORS: hint %s" % hint.text)
		failed += 1
	if info.text.find("Сушилка") < 0 or info.text.find("обычные этажи") < 0:
		push_error("FLOORS: info %s" % info.text)
		failed += 1
	if not str(gs.get("last_floor_fingerprint")).begins_with("F1:"):
		push_error("FLOORS: fingerprint %s" % gs.get("last_floor_fingerprint"))
		failed += 1
	else:
		print("FLOORS: floor 1 dryer")

	gs.call("on_exit_reached")
	await _frames(4)
	if int(gs.get("current_floor")) != 2 or str(gs.get("last_result")) == "extract":
		push_error("FLOORS: early exit extracted floor=%s result=%s" % [gs.get("current_floor"), gs.get("last_result")])
		failed += 1
	else:
		print("FLOORS: early exit advances")

	gs.set("current_floor", int(gs.get("run_length")))
	gs.call("on_exit_reached")
	await _frames(4)
	if str(gs.get("last_result")) != "extract":
		push_error("FLOORS: RF4 result=%s" % gs.get("last_result"))
		failed += 1
	else:
		print("FLOORS: RF4 last floor extracts")

	change_scene_to_file("res://scenes/apartment_hub.tscn")
	await _frames(3)
	gs.set("floor_offer_open", false)
	gs.set("player_hp", 100)
	gs.set("player_max_hp", 100)
	if not await _kill(gs, "tenant"):
		push_error("FLOORS: tenant kill")
		failed += 1
	if not await _kill(gs, "meter"):
		push_error("FLOORS: meter kill")
		failed += 1
	else:
		print("FLOORS: RF3 both kinds dead")

	if not await _zone_arms_meter():
		push_error("FLOORS: meter at 64px did not arm dodge")
		failed += 1
	else:
		print("FLOORS: meter zone 72 arms dodge")
	if not await _meter_strike(true):
		push_error("FLOORS: early dodge should not cover meter")
		failed += 1
	else:
		print("FLOORS: early meter strike hits")
	if not await _meter_strike(false):
		push_error("FLOORS: late dodge should cover meter")
		failed += 1
	else:
		print("FLOORS: late meter strike absorbed")

	if failed == 0:
		print("FLOORS_SMOKE_OK")
		quit(0)
		return
	print("FLOORS_SMOKE_FAIL count=%d" % failed)
	quit(1)


func _plan_is(plan: Dictionary, length: int, ids: Array) -> bool:
	if int(plan["length"]) != length:
		return false
	return _ids(plan) == ids


func _ids(plan: Dictionary) -> Array:
	var out: Array = []
	for id in plan["ids"]:
		out.append(str(id))
	return out


func _kill(gs: Node, kind: String) -> bool:
	var enemy: Node = load("res://scenes/enemy.tscn").instantiate()
	enemy.set("kind", kind)
	root.add_child(enemy)
	await _frames(2)
	if kind == "meter":
		if not is_equal_approx(float(enemy.get("windup_sec")), 0.85):
			return false
		if not is_equal_approx(float(enemy.get("strike_range")), 72.0):
			return false
		if int(enemy.get("strike_damage")) != 12:
			return false
	else:
		if int(enemy.get("strike_damage")) != 18:
			return false
	var before: int = int(gs.get("kills"))
	enemy.call("take_damage", 999)
	await _frames(2)
	return int(gs.get("kills")) == before + 1


func _zone_arms_meter() -> bool:
	var player: Node = load("res://scenes/player.tscn").instantiate()
	var meter: Node = load("res://scenes/enemy.tscn").instantiate()
	meter.set("kind", "meter")
	root.add_child(player)
	root.add_child(meter)
	player.global_position = Vector2(200, 200)
	meter.global_position = Vector2(264, 200)
	await physics_frame
	if not bool(meter.call("is_telegraphing")):
		meter.call("_begin_windup")
	await process_frame
	Input.action_press("dodge")
	player.call("_physics_process", 0.016)
	Input.action_release("dodge")
	var covered: Array = player.get("_covered")
	var armed := covered.has(meter.get_instance_id())
	player.queue_free()
	meter.queue_free()
	await _frames(2)
	return armed


func _meter_strike(early: bool) -> bool:
	var gs := root.get_node("GameState")
	gs.set("player_hp", 100)
	gs.set("floor_offer_open", false)
	var player: Node = load("res://scenes/player.tscn").instantiate()
	var meter: Node = load("res://scenes/enemy.tscn").instantiate()
	meter.set("kind", "meter")
	player.set("_facing", Vector2.RIGHT)
	root.add_child(player)
	root.add_child(meter)
	_stick(player, meter)
	await physics_frame
	if not bool(meter.call("is_telegraphing")):
		meter.call("_begin_windup")
	var pressed := false
	var result := ""
	for _i in 80:
		_stick(player, meter)
		var left := float(meter.get("_phase_left"))
		var due := early or (left <= 0.45 and left > 0.0)
		if not pressed and due and bool(meter.call("is_telegraphing")):
			await process_frame
			Input.action_press("dodge")
			player.call("_physics_process", 0.016)
			Input.action_release("dodge")
			pressed = true
		_stick(player, meter)
		await physics_frame
		result = str(meter.get("last_strike_result"))
		if result != "":
			break
	var hp := int(gs.get("player_hp"))
	player.queue_free()
	meter.queue_free()
	await _frames(2)
	if not pressed:
		return false
	if early:
		return result == "hit" and hp == 88
	return result == "absorbed" and hp == 100


func _stick(player: Node, meter: Node) -> void:
	player.global_position = Vector2(400, 300)
	meter.global_position = Vector2(432, 300)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame
