extends SceneTree

## Проба: доходят ли реальные клавиатурные и тач-события до обработчиков игры.
## Запуск: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/_key_probe.gd

var game: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/game.tscn")
	game = scene.instantiate()
	root.add_child(game)
	for i in 8:
		await process_frame
	game.call("new_game", 777001)
	for i in 30:
		await process_frame

	var inv: Node = game.get("inventory_ui")
	var journal: Node = game.get("journal_ui")
	var player: Node = game.get("player")
	var touch: Node = game.get("touch_ui")
	print("[probe] inv=", inv, " journal=", journal, " touch=", touch)

	# --- клавиатура: I открывает сумку?
	_key(KEY_I, true)
	await process_frame
	_key(KEY_I, false)
	for i in 4:
		await process_frame
	print("[probe] после KEY_I: inventory.is_open=", inv.call("is_open"), " visible=", (inv as Node).get("visible"))

	# --- клавиатура: E закрывает сумку?
	_key(KEY_E, true)
	await process_frame
	_key(KEY_E, false)
	for i in 4:
		await process_frame
	print("[probe] после KEY_E: inventory.is_open=", inv.call("is_open"))

	# --- клавиатура: J открывает журнал?
	_key(KEY_J, true)
	await process_frame
	_key(KEY_J, false)
	for i in 4:
		await process_frame
	print("[probe] после KEY_J: journal.is_open=", journal.call("is_open"))
	_key(KEY_J, true)
	await process_frame
	_key(KEY_J, false)
	for i in 4:
		await process_frame

	# --- клавиатура: F рядом с NPC открывает диалог?
	var npcs: Array = get_nodes_in_group("npcs")
	print("[probe] NPC в группе: ", npcs.size())
	if npcs.size() > 0:
		var npc: Node2D = npcs[0]
		(player as Node2D).global_position = npc.global_position + Vector2(40, 0)
		for i in 10:
			await process_frame
		print("[probe] interact_hint=", player.call("interact_hint"),
			" nearby_interact=", (player.get("_nearby_interact") as Array).size())
		_key(KEY_F, true)
		await process_frame
		_key(KEY_F, false)
		for i in 6:
			await process_frame
		var dialog: Node = game.get("dialog")
		print("[probe] после KEY_F: dialog.is_open=", dialog.call("is_open"))

	# --- тач: включён ли слой и читает ли игрок стик
	print("[probe] touch.enabled=", touch.get("enabled"), " player.touch=", player.get("touch"))
	touch.call("set_enabled", true)
	for i in 2:
		await process_frame
	_touch(1, Vector2(300, 400), true)
	await process_frame
	_touch_drag(1, Vector2(360, 400))
	for i in 2:
		await process_frame
	print("[probe] touch.move_vector=", touch.get("move_vector"),
		" player._read_move=", player.call("_read_move"))
	_touch(1, Vector2(360, 400), false)
	for i in 2:
		await process_frame

	quit(0)


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _touch_drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	Input.parse_input_event(ev)
