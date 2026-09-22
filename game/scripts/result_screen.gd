extends Control

@onready var _title: Label = $Panel/Title
@onready var _body: Label = $Panel/Body
@onready var _boon_row: HBoxContainer = $Panel/BoonRow
@onready var _continue: Button = $Panel/Continue


func _ready() -> void:
	if GameState.last_result == "extract":
		_title.text = "Выход зарегистрирован"
		_body.text = "УК: покинут этаж %d ЭЖК №17.\nУбито: %d\n\nВыберите, что взять на следующий заход — это изменит следующую попытку." % [GameState.last_floors, GameState.last_kills]
	else:
		_title.text = "Протокол происшествия"
		_body.text = "Потеря связи на этаже %d.\nКонтактов до отключения: %d\n\nДаже после этого можно выбрать подготовку к следующей попытке." % [GameState.last_floors, GameState.last_kills]
	_continue.disabled = true
	_continue.text = "Сначала выберите находку"


func _on_boon_damage() -> void:
	_select("damage")


func _on_boon_maxhp() -> void:
	_select("maxhp")


func _on_boon_speed() -> void:
	_select("speed")


func _select(id: String) -> void:
	GameState.pick_boon(id)
	_continue.disabled = false
	_continue.text = "Вернуться домой"
	_body.text += "\n\nВыбрано для следующего захода: %s" % id


func _on_continue_pressed() -> void:
	if GameState.pending_boon == "none":
		return
	GameState.go_apartment()


func _process(_delta: float) -> void:
	pass
