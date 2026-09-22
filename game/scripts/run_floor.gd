extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var _world: Node2D = $World
@onready var _spawn_points: Node2D = $World/SpawnPoints
@onready var _hud_hp: ProgressBar = $HUD/HPBar
@onready var _hud_info: Label = $HUD/Info
@onready var _hud_notice: Label = $HUD/Notice
@onready var _exit_hint: Label = $HUD/ExitHint


func _ready() -> void:
	_hud_notice.text = GameState.zh_ek_notice
	_hud_info.text = "эт. 9 · ЭЖК №17 · выход отмечен жёлтым"
	_exit_hint.text = "Доберитесь до жёлтой зоны или умрите — оба исхода ведут домой."
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = Vector2(200, 360)
	_world.add_child(player)
	player.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(GameState.player_hp, GameState.player_max_hp)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	cam.make_current()
	_spawn_enemies()


func _spawn_enemies() -> void:
	for child in _spawn_points.get_children():
		var e := ENEMY_SCENE.instantiate() as CharacterBody2D
		e.position = child.position
		_world.add_child(e)


func _on_hp_changed(current: int, maximum: int) -> void:
	_hud_hp.max_value = maximum
	_hud_hp.value = current


func _on_exit_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameState.finish_extract()
