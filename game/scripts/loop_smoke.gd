extends SceneTree

## Automates hub → entrance → run → extract flags without input.
## godot --headless --path game -s res://scripts/loop_smoke.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		push_error("LOOP_SMOKE: GameState missing")
		quit(1)
		return

	change_scene_to_file("res://scenes/apartment_hub.tscn")
	await process_frame
	await process_frame
	await process_frame
	if root.get_child_count() < 1:
		push_error("LOOP_SMOKE: apartment failed")
		quit(1)
		return
	print("LOOP: apartment ok")

	gs.call("go_entrance")
	await process_frame
	await process_frame
	await process_frame
	print("LOOP: entrance ok")

	gs.call("go_run")
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	print("LOOP: run ok")

	gs.call("finish_extract")
	await process_frame
	await process_frame
	await process_frame
	if not bool(gs.get("kitchen_door_unlocked")):
		push_error("LOOP_SMOKE: kitchen not unlocked")
		quit(1)
		return
	print("LOOP: extract+hook ok")

	gs.call("go_apartment")
	await process_frame
	await process_frame
	await process_frame
	print("LOOP_SMOKE_OK")
	quit(0)
