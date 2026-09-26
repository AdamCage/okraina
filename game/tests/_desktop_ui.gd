extends SceneTree

## Проба: доходят ли настоящие mouse-клики до кнопок инвентаря и вариантов диалога NPC.
## Запуск: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/_desktop_ui.gd

var game: Node = null
var clicks: Array = []
var choices: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/game.tscn")
	game = scene.instantiate()
	root.add_child(game)
	for i in 8:
		await process_frame
	game.call("new_game", 424002)
	for i in 30:
		await process_frame

	var player: Node = game.get("player")
	var inv: Node = game.get("inventory_ui")

	# ---------------- инвентарь: клик по слоту и по кнопке действия
	_key(KEY_I, true)
	await process_frame
	_key(KEY_I, false)
	for i in 6:
		await process_frame
	var grid: Node = inv.get("_grid")
	var slot: Button = null
	if grid != null:
		for c in grid.get_children():
			if c is Button and String(c.get_meta("item_id", "")) != "":
				slot = c as Button
				break
	print("[dui] инвентарь открыт=", inv.call("is_open"), " grid=", grid != null, " слот=", slot)
	if slot != null:
		slot.pressed.connect(func(): clicks.append("slot"))
		_click_at(slot.get_global_rect().get_center())
		for i in 6:
			await process_frame
		print("[dui] после клика по слоту: sel=", (inv.call("selected_item") as Dictionary).get("id", "<нет>"),
			" сигналы=", clicks)
	var action_btn: Button = null
	var act: Array = inv.get("_act_buttons")
	for b in act:
		var bb: Button = b as Button
		if bb != null and not bb.disabled:
			action_btn = bb
			break
	if action_btn != null:
		var tag: String = "action" + str(action_btn.get_meta("action_id"))
		action_btn.pressed.connect(func(): clicks.append(tag))
		print("[dui] клик по кнопке '", action_btn.text, "' rect=", action_btn.get_global_rect())
		_click_at(action_btn.get_global_rect().get_center())
		for i in 6:
			await process_frame
		print("[dui] после клика по кнопке действия: сигналы=", clicks)
	else:
		print("[dui] доступных кнопок действий нет")
	_key(KEY_I, true)
	await process_frame
	_key(KEY_I, false)
	for i in 6:
		await process_frame

	# ---------------- диалог NPC: клик по варианту ответа
	var dialog: Node = game.get("dialog")
	dialog.connect("choice", func(i: int): choices.append(i))
	var npcs: Array = get_nodes_in_group("npcs")
	print("[dui] NPC: ", npcs.size())
	if npcs.size() > 0:
		var npc: Node2D = npcs[0]
		(player as Node2D).global_position = npc.global_position + Vector2(40, 0)
		for i in 10:
			await process_frame
		_key(KEY_F, true)
		await process_frame
		_key(KEY_F, false)
		for i in 8:
			await process_frame
		print("[dui] диалог открыт=", dialog.call("is_open"))
		# проматываем реплики пробелом до вариантов ответа
		var guard: int = 0
		while dialog.call("is_open") and _option_buttons(dialog).is_empty() and guard < 20:
			_key(KEY_SPACE, true)
			await process_frame
			_key(KEY_SPACE, false)
			for i in 4:
				await process_frame
			guard += 1
		var opts: Array = _option_buttons(dialog)
		print("[dui] вариантов ответа: ", opts.size(), " (прогонов пробела ", guard, ")")
		if not opts.is_empty():
			var opt: Button = opts[0] as Button
			opt.pressed.connect(func(): clicks.append("option0"))
			print("[dui] клик по варианту 1: rect=", opt.get_global_rect())
			_click_at(opt.get_global_rect().get_center())
			for i in 8:
				await process_frame
			print("[dui] после клика: сигналы=", clicks, " choice=", choices,
				" диалог открыт=", dialog.call("is_open"))
	quit(0)


func _option_buttons(dialog: Node) -> Array:
	var box: Node = dialog.get("_options_box")
	var out: Array = []
	if box == null:
		return out
	for c in box.get_children():
		if c is Button:
			out.append(c)
	return out


func _all_buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button:
		out.append(n)
	for c in n.get_children():
		out += _all_buttons(c)
	return out


func _click_at(canvas_pos: Vector2) -> void:
	var win_size: Vector2 = Vector2(root.size)
	var canvas_size: Vector2 = root.get_visible_rect().size
	var p: Vector2 = canvas_pos * (win_size / canvas_size)
	var motion := InputEventMouseMotion.new()
	motion.position = p
	motion.global_position = p
	root.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p
	down.global_position = p
	root.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = p
	up.global_position = p
	root.push_input(up)


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _find_by_name(n: Node, wanted: String) -> Node:
	if n.name == wanted:
		return n
	for c in n.get_children():
		var r: Node = _find_by_name(c, wanted)
		if r != null:
			return r
	return null
