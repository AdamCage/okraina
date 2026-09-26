extends SceneTree

## Разведка: доходит ли настоящий mouse-клик до кнопок главного меню.
## Запуск: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/_menu_click.gd

var game: Node = null
var btn: Control = null
var events: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/game.tscn")
	game = scene.instantiate()
	root.add_child(game)
	for i in 6:
		await process_frame

	print("[t] viewport rect: ", root.get_visible_rect())
	var menu: Variant = game.get("menu_ui")
	print("[t] menu=", menu, " visible=", (menu as Node).visible if menu != null else "n/a")
	if menu != null:
		print("[t] describe=", (menu as Node).call("describe"))

	var box: Node = _find_by_name(root, "MainButtons")
	print("[t] MainButtons box=", box)
	if box == null or box.get_child_count() == 0:
		print("[t] НЕТ КНОПОК — стоп")
		quit(1)
		return
	btn = box.get_child(0) as Control
	print("[t] btn text=", (btn as Button).text, " disabled=", (btn as Button).disabled,
		" rect=", btn.get_global_rect(), " filter=", btn.mouse_filter,
		" visible=", btn.is_visible_in_tree())
	btn.gui_input.connect(_on_gui)
	(btn as Button).pressed.connect(_on_pressed)

	print("[t] window size=", root.size, " visible_rect=", root.get_visible_rect(),
		" ds=", DisplayServer.window_get_size(), " name=", DisplayServer.get_name())

	var pos: Vector2 = btn.get_global_rect().get_center()
	print("[t] клик в (канвас) ", pos, " -> ",
		"попадает: ", (btn as Button).get_global_rect().has_point(pos))

	# координаты события — в оконном пространстве (stretch-масштаб)
	var win_size: Vector2 = Vector2(root.size)
	var canvas_size: Vector2 = root.get_visible_rect().size
	var win_pos: Vector2 = pos * (win_size / canvas_size)
	print("[t] оконные координаты клика: ", win_pos, " (окно ", win_size, ", канвас ", canvas_size, ")")

	# A: Input.parse_input_event
	events.clear()
	_push_parse(win_pos, true)
	await process_frame
	_push_parse(win_pos, false)
	for i in 6:
		await process_frame
	print("[t] A Input.parse_input_event -> gui=", events, " screen=", (menu as Node).call("current_screen"))

	# B: root.push_input (motion + press + release)
	events.clear()
	_push_view(win_pos, true)
	for i in 6:
		await process_frame
	print("[t] B Window.push_input     -> gui=", events, " screen=", (menu as Node).call("current_screen"))

	for i in 40:
		await process_frame

	print("[t] gui_input события: ", events)
	print("[t] menu visible=", (menu as Node).visible, " screen=", (menu as Node).call("current_screen"))
	print("[t] run_active=", game.get("run_active"), " world=", game.get("world"), " player=", game.get("player"))
	quit(0)


func _on_gui(e: InputEvent) -> void:
	var s: String = e.get_class()
	if e is InputEventMouseButton:
		s += " left=" + str((e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
			+ " pressed=" + str((e as InputEventMouseButton).pressed) \
			+ " pos=" + str((e as InputEventMouseButton).position)
	elif e is InputEventMouseMotion:
		s += " pos=" + str((e as InputEventMouseMotion).position)
	events.append(s)


func _on_pressed() -> void:
	print("[t] СИГНАЛ pressed СРАБОТАЛ")


func _push_parse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _push_view(pos: Vector2, full_cycle: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion)
	if not full_cycle:
		return
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	root.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	root.push_input(up)


func _find_by_name(n: Node, wanted: String) -> Node:
	if n.name == wanted:
		return n
	for c in n.get_children():
		var r: Node = _find_by_name(c, wanted)
		if r != null:
			return r
	return null
