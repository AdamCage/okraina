extends SceneTree

## Проба: как в этой сборке движка реально доставляются InputEventScreenTouch и
## как ведут себя фильтры мыши при наложении Control'ов. Нужна, чтобы проверить
## мобильный путь (тап по диалогу) в headless и выбрать режим «ловушки» кликов:
## STOP / PASS / IGNORE.
##
## Запуск: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/_touch_pipe.gd


class Pipe extends Control:
	var tag: String = ""
	var log: Array = []

	func _ready() -> void:
		position = Vector2.ZERO
		size = get_viewport().get_visible_rect().size
		print("[pipe]     узел \"%s\": rect=%s filter=%d" % [tag, str(get_global_rect()), mouse_filter])

	func _gui_input(event: InputEvent) -> void:
		log.append(tag + "/gui/" + describe_event(event))

	func _unhandled_input(event: InputEvent) -> void:
		log.append(tag + "/unhandled/" + describe_event(event))

	static func describe_event(event: InputEvent) -> String:
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			return "touch%d%s" % [t.index, "+down" if t.pressed else "-up"]
		if event is InputEventScreenDrag:
			return "drag%d" % (event as InputEventScreenDrag).index
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			return "mouse%d%s" % [mb.button_index, "+down" if mb.pressed else "-up"]
		if event is InputEventMouseMotion:
			return "motion"
		if event is InputEventKey:
			return "key%d%s" % [(event as InputEventKey).keycode, "+down" if (event as InputEventKey).pressed else "-up"]
		return event.get_class()


var low: Pipe = null
var top: Pipe = null
var layer: CanvasLayer = null
var btn: Button = null
var btn_hits: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	layer = CanvasLayer.new()
	layer.layer = 10
	root.add_child(layer)
	low = _make("нижний")
	top = _make("верхний")           # добавлен позже -> ближе к экрану
	btn = Button.new()
	btn.name = "кнопка"
	btn.text = "ОК"
	btn.position = Vector2(500, 500)
	btn.size = Vector2(160, 48)
	btn.pressed.connect(func() -> void: btn_hits += 1)
	layer.add_child(btn)
	for i in 3:
		await process_frame
	print("[pipe] root.size=%s visible=%s | низ=%s верх=%s" % [
		str(root.size), str(root.get_visible_rect()), str(low.size), str(top.size)])
	var p := Vector2(300, 300)

	top.mouse_filter = Control.MOUSE_FILTER_STOP
	_phase("1. верхний STOP, нижний STOP: клик мышью")
	_mouse(p)
	await process_frame
	print(_dump())

	top.mouse_filter = Control.MOUSE_FILTER_PASS
	_phase("2. верхний PASS, нижний STOP: клик мышью")
	_mouse(p)
	await process_frame
	print(_dump())

	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase("3. верхний IGNORE, нижний STOP: клик мышью")
	_mouse(p)
	await process_frame
	print(_dump())

	low.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase("4. оба IGNORE: клик мышью")
	_mouse(p)
	await process_frame
	print(_dump())

	_phase("5. оба IGNORE: тап (push_input ScreenTouch)")
	_touch_push(p)
	await process_frame
	print(_dump())

	low.mouse_filter = Control.MOUSE_FILTER_STOP
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	_phase("6. верхний STOP: тап (push_input ScreenTouch)")
	_touch_push(p)
	await process_frame
	print(_dump())

	_phase("7. верхний STOP: тап (Input.parse_input_event ScreenTouch)")
	_touch_input(p)
	await process_frame
	print(_dump())

	_phase("8. верхний PASS: тап (push_input ScreenTouch)")
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	_touch_push(p)
	await process_frame
	print(_dump())

	_phase("9. верхний STOP: клик мышью (Input.parse_input_event)")
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	_mouse_input(p)
	await process_frame
	print(_dump())

	low.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase("10. настоящая Button в CanvasLayer: клик мышью (push_input)")
	_mouse(btn.position + btn.size * 0.5)
	await process_frame
	print("[pipe]     нажатий Button: ", btn_hits, " | " + _dump().replace("\n", " / "))

	_phase("11. настоящая Button: тап (push_input ScreenTouch)")
	_touch_push(btn.position + btn.size * 0.5)
	await process_frame
	print("[pipe]     нажатий Button: ", btn_hits, " | " + _dump().replace("\n", " / "))

	quit(0)


func _make(tag: String) -> Pipe:
	var c := Pipe.new()
	c.name = tag
	c.tag = tag
	layer.add_child(c)
	return c


func _phase(title: String) -> void:
	low.log.clear()
	top.log.clear()
	print("[pipe] --- ", title)


func _dump() -> String:
	return "[pipe]     нижний: " + str(low.log) + "\n[pipe]     верхний: " + str(top.log)


func _mouse(p: Vector2) -> void:
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


func _mouse_input(p: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p
	down.global_position = p
	Input.parse_input_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = p
	up.global_position = p
	Input.parse_input_event(up)


func _touch_push(p: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = p
	root.push_input(down)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = p
	root.push_input(up)


func _touch_input(p: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = p
	Input.parse_input_event(down)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = p
	Input.parse_input_event(up)
