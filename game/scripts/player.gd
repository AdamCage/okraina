extends CharacterBody2D

signal hp_changed(current: int, maximum: int)
signal died

@export var speed: float = 180.0
@export var attack_damage: int = 25
@export var attack_cooldown: float = 0.4

const DODGE_STEP_SEC := 0.16
const DODGE_SPEED := 520.0
const DODGE_COOLDOWN_SEC := 0.70
const COVER_SEC := 0.50
const STRIKE_RANGE := 56.0

var _attack_cd: float = 0.0
var _facing: Vector2 = Vector2.RIGHT
var _dodge_cd: float = 0.0
var _dodge_cooldown_sec: float = DODGE_COOLDOWN_SEC
var _dodge_speed: float = DODGE_SPEED
var _dodge_left: float = 0.0
var _dodge_dir: Vector2 = Vector2.RIGHT
var _iframe: bool = false
var _iframe_left: float = 0.0
var _cover_left: float = 0.0
var _covered: Array[int] = []

@onready var _attack_area: Area2D = $AttackArea
@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	add_to_group("player")
	apply_build()


func apply_build() -> void:
	attack_damage = 25 + GameState.boon_damage_bonus() + GameState.offer_damage
	speed = 180.0 * GameState.boon_speed_mult() * GameState.offer_speed_mult
	attack_cooldown = maxf(0.20, 0.40 * GameState.offer_attack_cd_mult)
	_dodge_cooldown_sec = maxf(0.25, DODGE_COOLDOWN_SEC + GameState.offer_dodge_cd)
	_dodge_speed = DODGE_SPEED + GameState.offer_dodge_speed
	hp_changed.emit(GameState.player_hp, GameState.player_max_hp)


func _physics_process(delta: float) -> void:
	if GameState.player_hp <= 0:
		return
	if GameState.floor_offer_open:
		velocity = Vector2.ZERO
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	if Input.is_action_just_pressed("dodge"):
		start_dodge()
	_tick_cover(delta)
	if _dodge_left > 0.0:
		var step := minf(delta, _dodge_left)
		_dodge_left -= step
		if delta > 0.0:
			velocity = _dodge_dir * _dodge_speed * (step / delta)
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		if _dodge_left <= 0.0:
			_paint_idle()
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.1:
		_facing = dir.normalized()
		_attack_area.rotation = _facing.angle()
	velocity = dir * speed
	move_and_slide()
	if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0:
		_do_attack()


func start_dodge() -> void:
	if GameState.player_hp <= 0 or _dodge_cd > 0.0:
		return
	_dodge_cd = _dodge_cooldown_sec
	_dodge_left = DODGE_STEP_SEC
	_dodge_dir = _facing
	_iframe = true
	_iframe_left = DODGE_STEP_SEC
	_covered.clear()
	_cover_left = 0.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node.has_method("is_telegraphing") or not node.is_telegraphing():
			continue
		var zone := float(STRIKE_RANGE)
		if node.get("strike_range") != null:
			zone = float(node.strike_range)
		if node.global_position.distance_to(global_position) > zone:
			continue
		_covered.append(node.get_instance_id())
	if not _covered.is_empty():
		_cover_left = COVER_SEC
	_visual.color = Color(0.75, 0.9, 1.0)


func is_dodging() -> bool:
	return _dodge_left > 0.0


func receive_strike(amount: int, enemy_id: int) -> bool:
	if _covered.has(enemy_id):
		_covered.erase(enemy_id)
		return true
	if _iframe:
		return true
	take_damage(amount)
	return false


func _tick_cover(delta: float) -> void:
	if _iframe_left > 0.0:
		_iframe_left = maxf(0.0, _iframe_left - delta)
		if _iframe_left <= 0.0:
			call_deferred("_end_iframe")
	if _cover_left > 0.0:
		_cover_left = maxf(0.0, _cover_left - delta)
		if _cover_left <= 0.0:
			call_deferred("_end_cover")


func _end_iframe() -> void:
	if _iframe_left <= 0.0:
		_iframe = false


func _end_cover() -> void:
	if _cover_left <= 0.0:
		_covered.clear()


func _do_attack() -> void:
	_attack_cd = attack_cooldown
	_visual.color = Color(0.95, 0.85, 0.4)
	get_tree().create_timer(0.08).timeout.connect(func () -> void:
		if is_instance_valid(_visual) and _dodge_left <= 0.0:
			_paint_idle()
	)
	for body in _attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)


func take_damage(amount: int) -> void:
	if _iframe or GameState.player_hp <= 0:
		return
	GameState.player_hp = maxi(0, GameState.player_hp - amount)
	hp_changed.emit(GameState.player_hp, GameState.player_max_hp)
	_visual.color = Color(0.9, 0.3, 0.3)
	get_tree().create_timer(0.1).timeout.connect(func () -> void:
		if is_instance_valid(_visual) and GameState.player_hp > 0 and _dodge_left <= 0.0:
			_paint_idle()
	)
	if GameState.player_hp <= 0:
		died.emit()
		GameState.finish_death()


func _paint_idle() -> void:
	_visual.color = Color(0.35, 0.75, 0.55)
