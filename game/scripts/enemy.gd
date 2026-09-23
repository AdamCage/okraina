extends CharacterBody2D

enum Phase { CHASE, WINDUP, RECOVER }

const RECOVER_SEC := 0.40

@export var kind: String = "tenant"
@export var max_hp: int = 40
@export var speed: float = 90.0

var hp: int
var phase: Phase = Phase.CHASE
var strikes_resolved: int = 0
var last_strike_result: String = ""
var windup_sec: float = 0.50
var strike_range: float = 56.0
var strike_damage: int = 18
var _phase_left: float = 0.0
var _chase_color: Color = Color(0.55, 0.2, 0.25)
var _windup_color: Color = Color(0.95, 0.72, 0.18)

@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	_apply_kind()
	hp = max_hp
	add_to_group("enemies")
	_paint_chase()


func _apply_kind() -> void:
	if kind == "meter":
		speed = 60.0
		windup_sec = 0.85
		strike_range = 72.0
		strike_damage = 12
		_chase_color = Color(0.15, 0.45, 0.55)
		_windup_color = Color(0.35, 0.85, 1.0)
	else:
		kind = "tenant"
		speed = 90.0
		windup_sec = 0.50
		strike_range = 56.0
		strike_damage = 18
		_chase_color = Color(0.55, 0.2, 0.25)
		_windup_color = Color(0.95, 0.72, 0.18)


func is_telegraphing() -> bool:
	return phase == Phase.WINDUP


func _physics_process(delta: float) -> void:
	if GameState.floor_offer_open:
		velocity = Vector2.ZERO
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	match phase:
		Phase.CHASE:
			_chase(player)
		Phase.WINDUP:
			_hold(delta, player)
		Phase.RECOVER:
			_hold(delta, player)
		_:
			pass


func _chase(player: Node2D) -> void:
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var to_player := player.global_position - global_position
	if to_player.length() <= strike_range:
		_begin_windup()
		return
	velocity = to_player.normalized() * speed
	move_and_slide()


func _begin_windup() -> void:
	phase = Phase.WINDUP
	_phase_left = windup_sec
	velocity = Vector2.ZERO
	_visual.color = _windup_color


func _hold(delta: float, player: Node2D) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_phase_left -= delta
	if _phase_left > 0.0:
		return
	if phase == Phase.WINDUP:
		_resolve_strike(player)
		phase = Phase.RECOVER
		_phase_left = RECOVER_SEC
		get_tree().create_timer(0.05).timeout.connect(func () -> void:
			if is_instance_valid(_visual) and phase != Phase.WINDUP:
				_paint_chase()
		)
	else:
		phase = Phase.CHASE
		_paint_chase()


func _resolve_strike(player: Node2D) -> void:
	strikes_resolved += 1
	_visual.color = Color(1, 1, 1)
	if player == null or player.global_position.distance_to(global_position) > strike_range:
		last_strike_result = "out_of_range"
		return
	if player.has_method("receive_strike"):
		if player.receive_strike(strike_damage, get_instance_id()):
			last_strike_result = "absorbed"
		else:
			last_strike_result = "hit"
		return
	last_strike_result = "hit"
	if player.has_method("take_damage"):
		player.take_damage(strike_damage)


func take_damage(amount: int) -> void:
	hp -= amount
	_visual.color = Color(1, 1, 1)
	get_tree().create_timer(0.05).timeout.connect(func () -> void:
		if is_instance_valid(_visual) and hp > 0:
			if phase == Phase.WINDUP:
				_visual.color = _windup_color
			else:
				_paint_chase()
	)
	if hp <= 0:
		GameState.kills += 1
		queue_free()


func _paint_chase() -> void:
	_visual.color = _chase_color
