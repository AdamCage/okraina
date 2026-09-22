extends Control

@onready var _title: Label = $Panel/Title
@onready var _body: Label = $Panel/Body


func _ready() -> void:
	if GameState.last_result == "extract":
		_title.text = "Выход зарегистрирован"
		_body.text = "УК уведомляет: вы покинули этаж 9 через служебный проём.\nУбито: %d\n\nДома что-то изменилось." % GameState.kills
	else:
		_title.text = "Протокол происшествия"
		_body.text = "Гражданин обнаружен без признаков… связи на этаже 9.\nУбито до потери сознания: %d\n\nВы снова в квартире. Как обычно." % GameState.kills


func _on_continue_pressed() -> void:
	GameState.go_apartment()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack"):
		GameState.go_apartment()
