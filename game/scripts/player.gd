extends CharacterBody2D

signal hp_changed(current: int, maximum: int)
signal died

@export var speed: float = 180.0
@export var attack_damage: int = 25
@export var attack_cooldown: float = 0.4

var _attack_cd: float = 0.0
var _facing: Vector2 = Vector2.RIGHT

@onready var _attack_area: Area2D = $AttackArea
@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	add_to_group("player")
	hp_changed.emit(GameState.player_hp, GameState.player_max_hp)


func _physics_process(delta: float) -> void:
	if GameState.player_hp <= 0:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.1:
		_facing = dir.normalized()
		_attack_area.rotation = _facing.angle()
	velocity = dir * speed
	move_and_slide()
	if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0:
		_do_attack()


func _do_attack() -> void:
	_attack_cd = attack_cooldown
	_visual.color = Color(0.95, 0.85, 0.4)
	get_tree().create_timer(0.08).timeout.connect(func () -> void:
		if is_instance_valid(_visual):
			_visual.color = Color(0.35, 0.75, 0.55)
	)
	for body in _attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)


func take_damage(amount: int) -> void:
	if GameState.player_hp <= 0:
		return
	GameState.player_hp = maxi(0, GameState.player_hp - amount)
	hp_changed.emit(GameState.player_hp, GameState.player_max_hp)
	_visual.color = Color(0.9, 0.3, 0.3)
	get_tree().create_timer(0.1).timeout.connect(func () -> void:
		if is_instance_valid(_visual) and GameState.player_hp > 0:
			_visual.color = Color(0.35, 0.75, 0.55)
	)
	if GameState.player_hp <= 0:
		died.emit()
		GameState.finish_death()
