extends Node2D

@onready var _hint: Label = $UI/Hint


func _ready() -> void:
	_hint.text = "Подъезд 32 · ЭЖК №17\nE или кнопка — подняться на этаж"


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		GameState.go_run()


func _on_enter_floor_pressed() -> void:
	GameState.go_run()
