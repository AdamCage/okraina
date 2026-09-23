extends CanvasLayer

signal chosen(offer_id: String)

const _Catalog := preload("res://scripts/offer_catalog.gd")


func _ready() -> void:
	layer = 20
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(host)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.045, 0.05, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(dim)
	var title := Label.new()
	title.text = "На тумбочке три вещи. Взять одну."
	title.position = Vector2(340, 150)
	title.size = Vector2(600, 40)
	host.add_child(title)
	for i in GameState.pending_offer_ids.size():
		var entry := _Catalog.get_by_id(GameState.pending_offer_ids[i])
		var button := Button.new()
		button.text = "%d   %s — %s" % [i + 1, entry.get("title", ""), entry.get("detail", "")]
		button.position = Vector2(340, 210 + i * 78)
		button.size = Vector2(600, 64)
		button.pressed.connect(_choose.bind(i))
		host.add_child(button)


func _input(event: InputEvent) -> void:
	if not GameState.floor_offer_open:
		return
	if event.is_action_pressed("offer_1"):
		_choose(0)
	elif event.is_action_pressed("offer_2"):
		_choose(1)
	elif event.is_action_pressed("offer_3"):
		_choose(2)


func _process(_delta: float) -> void:
	if not GameState.floor_offer_open:
		queue_free()


func _choose(index: int) -> void:
	if not GameState.floor_offer_open:
		return
	var id := GameState.pick_offer(index)
	if id == "":
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("apply_build"):
		player.apply_build()
	chosen.emit(id)
	queue_free()
