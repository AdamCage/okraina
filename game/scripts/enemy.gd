extends CharacterBody2D

@export var max_hp: int = 40
@export var speed: float = 90.0
@export var touch_dps: float = 12.0

var hp: int
var _touch_acc: float = 0.0

@onready var _visual: ColorRect = $Visual


func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var to_player := player.global_position - global_position
	if to_player.length() > 4.0:
		velocity = to_player.normalized() * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	if to_player.length() < 28.0:
		_touch_acc += touch_dps * delta
		while _touch_acc >= 1.0:
			_touch_acc -= 1.0
			if player.has_method("take_damage"):
				player.take_damage(1)


func take_damage(amount: int) -> void:
	hp -= amount
	_visual.color = Color(1, 1, 1)
	get_tree().create_timer(0.05).timeout.connect(func () -> void:
		if is_instance_valid(_visual):
			_visual.color = Color(0.55, 0.2, 0.25)
	)
	if hp <= 0:
		GameState.kills += 1
		queue_free()
