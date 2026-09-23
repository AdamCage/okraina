extends CanvasLayer

const _Board := preload("res://scripts/board_catalog.gd")

var _threads: Array[Dictionary] = []
var _index := -1
var _body: Label
var _check: Button
var _status: Label


func _ready() -> void:
	layer = 30
	_threads = _Board.threads_for(GameState.last_result, GameState.last_floors, GameState.last_kills)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_right = 1280
	root.offset_bottom = 720
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var title := Label.new()
	title.position = Vector2(48, 36)
	title.text = "/pod/  ·  /hr/ пока пуст"
	root.add_child(title)
	var y := 80.0
	for i in _threads.size():
		var row: Dictionary = _threads[i]
		var button := Button.new()
		button.position = Vector2(48, y)
		button.custom_minimum_size = Vector2(360, 36)
		button.text = "%s  %s" % [row["board"], row["title"]]
		var slot := i
		button.pressed.connect(func() -> void: _select(slot))
		root.add_child(button)
		y += 44.0
	_body = Label.new()
	_body.position = Vector2(440, 80)
	_body.size = Vector2(760, 220)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.text = "Выбери тред. 1, 2, 3 — посты /pod/."
	root.add_child(_body)
	_check = Button.new()
	_check.position = Vector2(440, 320)
	_check.custom_minimum_size = Vector2(220, 40)
	_check.text = "проверить"
	_check.disabled = true
	_check.pressed.connect(_on_check)
	root.add_child(_check)
	_status = Label.new()
	_status.position = Vector2(440, 372)
	_status.size = Vector2(700, 32)
	root.add_child(_status)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("offer_1"):
		_select(0)
	elif event.is_action_pressed("offer_2"):
		_select(1)
	elif event.is_action_pressed("offer_3"):
		_select(2)


func _select(index: int) -> void:
	if index < 0 or index >= _threads.size():
		return
	_index = index
	var row: Dictionary = _threads[index]
	_body.text = str(row["body"])
	_check.disabled = row["can_check"] != true
	_status.text = ""


func _on_check() -> void:
	if _index < 0:
		return
	var row: Dictionary = _threads[_index]
	if row["can_check"] != true:
		return
	if not GameState.pick_lead(str(row["id"])):
		return
	_status.text = "На следующий заход: %s" % GameState.lead_label()
