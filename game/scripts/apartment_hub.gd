extends Node2D

@onready var _hint: Label = $UI/Hint
@onready var _notice: Label = $UI/Notice
@onready var _board: Label = $UI/Board
@onready var _door_panel: ColorRect = $KitchenDoor
@onready var _door_label: Label = $KitchenDoor/DoorLabel
@onready var _door_area: Area2D = $KitchenDoor/DoorArea


func _ready() -> void:
	_notice.text = GameState.zh_ek_notice
	_board.text = "/pod/ локальный тред\n\n%s" % GameState.board_feed
	_hint.text = "WASD — ходить · E — взаимодействие · выйти во двор → подъезд"
	if GameState.pending_boon != "none":
		_hint.text += "\nНа следующий заход выбрано: %s" % GameState.pending_boon
	_door_panel.visible = GameState.kitchen_door_unlocked
	if GameState.kitchen_door_unlocked:
		_door_label.text = "Дверь за кухней\n[E]"
		_hint.text = "Дверь за кухней на месте. E — осмотреть. ЖЭК и /pod/ обновились после забега."


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		if GameState.kitchen_door_unlocked and _player_near_door():
			_inspect_door()
		elif $ExitZone.get_overlapping_bodies().size() > 0:
			GameState.go_entrance()


func _player_near_door() -> bool:
	return _door_area.get_overlapping_bodies().size() > 0


func _inspect_door() -> void:
	_hint.text = "За кухней раньше не было двери. На старом форуме кто-то спрашивал про неё. Год в шапке треда — 2002."


func _on_exit_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_hint.text = "E — выйти в подъезд"


func _on_leave_pressed() -> void:
	GameState.go_entrance()
