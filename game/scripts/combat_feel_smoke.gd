extends SceneTree

## CF1: dodge during telegraph absorbs the strike while still in range.
## CF2: the next strike, without dodge, deals 18 once.
## godot --headless --path game -s res://scripts/combat_feel_smoke.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		push_error("COMBAT: no GameState")
		quit(1)
		return
	var failed := 0
	gs.set("player_hp", 100)
	gs.set("player_max_hp", 100)

	var player: Node = load("res://scenes/player.tscn").instantiate()
	var enemy: Node = load("res://scenes/enemy.tscn").instantiate()
	root.add_child(player)
	root.add_child(enemy)
	player.global_position = Vector2(200, 200)
	enemy.global_position = Vector2(230, 200)
	player.set("_facing", Vector2.RIGHT)
	await physics_frame
	await physics_frame

	if not await _wait_until(func() -> bool: return bool(enemy.call("is_telegraphing")), 90):
		push_error("COMBAT: telegraph did not start")
		quit(1)
		return
	var hp_before: int = int(gs.get("player_hp"))
	player.call("start_dodge")
	if not await _wait_until(func() -> bool: return not bool(player.call("is_dodging")), 40):
		push_error("COMBAT: dodge did not finish")
		quit(1)
		return
	player.global_position = enemy.global_position + Vector2(32, 0)
	var strikes_at_dodge: int = int(enemy.get("strikes_resolved"))
	if not await _wait_until(func() -> bool: return int(enemy.get("strikes_resolved")) > strikes_at_dodge, 90):
		push_error("COMBAT: strike did not resolve")
		quit(1)
		return
	if str(enemy.get("last_strike_result")) != "absorbed":
		push_error("COMBAT: CF1 result=%s" % str(enemy.get("last_strike_result")))
		failed += 1
	if int(gs.get("player_hp")) != hp_before:
		push_error("COMBAT: CF1 hp %s -> %s" % [hp_before, gs.get("player_hp")])
		failed += 1
	else:
		print("COMBAT: CF1 absorb ok")

	player.global_position = enemy.global_position + Vector2(32, 0)
	var hp_mid: int = int(gs.get("player_hp"))
	var strikes_mid: int = int(enemy.get("strikes_resolved"))
	if not await _wait_until(func() -> bool: return int(enemy.get("strikes_resolved")) > strikes_mid, 180):
		push_error("COMBAT: second strike missing")
		quit(1)
		return
	if str(enemy.get("last_strike_result")) != "hit":
		push_error("COMBAT: CF2 result=%s" % str(enemy.get("last_strike_result")))
		failed += 1
	if int(gs.get("player_hp")) != hp_mid - 18:
		push_error("COMBAT: CF2 hp %s -> %s" % [hp_mid, gs.get("player_hp")])
		failed += 1
	else:
		print("COMBAT: CF2 hit 18 ok")

	if failed == 0:
		print("COMBAT_FEEL_OK")
		quit(0)
	else:
		print("COMBAT_FEEL_FAIL count=%d" % failed)
		quit(1)


func _wait_until(pred: Callable, max_frames: int) -> bool:
	for _i in max_frames:
		if pred.call():
			return true
		await physics_frame
	return false
