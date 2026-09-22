extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var _world: Node2D = $World
@onready var _floor_bg: ColorRect = $World/Floor
@onready var _spawn_points: Node2D = $World/SpawnPoints
@onready var _exit_zone: Area2D = $World/ExitZone
@onready var _exit_visual: ColorRect = $World/ExitZone/ExitVisual
@onready var _exit_label: Label = $World/ExitZone/ExitLabel
@onready var _obstacle: ColorRect = $World/Obstacle
@onready var _obstacle_b: ColorRect = $World/ObstacleB
@onready var _hud_hp: ProgressBar = $HUD/HPBar
@onready var _hud_info: Label = $HUD/Info
@onready var _hud_notice: Label = $HUD/Notice
@onready var _exit_hint: Label = $HUD/ExitHint
@onready var _boon_label: Label = $HUD/BoonLabel


func _ready() -> void:
	_apply_floor_layout(GameState.current_floor)
	_hud_notice.text = GameState.zh_ek_notice
	var boon_ru := _boon_ru(GameState.active_boon)
	_boon_label.text = "С собой: %s" % boon_ru
	_exit_hint.text = "Жёлтая зона — дальше по дому. Этаж %d/%d." % [GameState.current_floor, GameState.MAX_FLOORS]
	if GameState.current_floor >= GameState.MAX_FLOORS:
		_exit_hint.text = "Последний этаж забега. Жёлтая зона — выход во двор / другой район."
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = _player_spawn_for_floor(GameState.current_floor)
	_world.add_child(player)
	player.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(GameState.player_hp, GameState.player_max_hp)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	cam.make_current()
	_spawn_enemies()


func _boon_ru(id: String) -> String:
	match id:
		"damage":
			return "Перегрузка (+урон)"
		"maxhp":
			return "Аптечка (+HP)"
		"speed":
			return "Лёгкие ноги (+скорость)"
		_:
			return "ничего"


func _player_spawn_for_floor(floor_i: int) -> Vector2:
	match floor_i:
		1:
			return Vector2(160, 360)
		2:
			return Vector2(200, 560)
		_:
			return Vector2(640, 360)


func _apply_floor_layout(floor_i: int) -> void:
	# Clear old spawn markers
	for c in _spawn_points.get_children():
		c.free()
	var enemy_count := 0
	var exit_pos := Vector2.ZERO
	var bg := Color(0.16, 0.17, 0.19)
	match floor_i:
		1:
			# Open hall, exit NE
			bg = Color(0.17, 0.19, 0.18)
			_obstacle.visible = true
			_obstacle.position = Vector2(520, 280)
			_obstacle.size = Vector2(240, 80)
			_obstacle_b.visible = false
			exit_pos = Vector2(1120, 120)
			_exit_label.text = "ДАЛЬШЕ ↑"
			enemy_count = 4
			_add_spawns([Vector2(700, 180), Vector2(900, 200), Vector2(1000, 400), Vector2(850, 520)])
		2:
			# L-corridor feel, exit south
			bg = Color(0.14, 0.16, 0.22)
			_obstacle.visible = true
			_obstacle.position = Vector2(280, 120)
			_obstacle.size = Vector2(720, 100)
			_obstacle_b.visible = true
			_obstacle_b.position = Vector2(280, 120)
			_obstacle_b.size = Vector2(120, 420)
			exit_pos = Vector2(1000, 620)
			_exit_label.text = "ДАЛЬШЕ ↓"
			enemy_count = 6
			_add_spawns([
				Vector2(500, 320), Vector2(700, 360), Vector2(900, 300),
				Vector2(1100, 280), Vector2(600, 500), Vector2(800, 480)
			])
		_:
			# Tight center rooms, exit west
			bg = Color(0.22, 0.17, 0.15)
			_obstacle.visible = true
			_obstacle.position = Vector2(400, 200)
			_obstacle.size = Vector2(160, 320)
			_obstacle_b.visible = true
			_obstacle_b.position = Vector2(720, 200)
			_obstacle_b.size = Vector2(160, 320)
			exit_pos = Vector2(140, 360)
			_exit_label.text = "ВЫХОД ←"
			enemy_count = 7
			_add_spawns([
				Vector2(360, 160), Vector2(920, 160), Vector2(360, 560), Vector2(920, 560),
				Vector2(640, 160), Vector2(500, 360), Vector2(780, 360)
			])
	_floor_bg.color = bg
	_exit_zone.position = exit_pos
	_hud_info.text = "эт. %d/%d · ЭЖК №17 · %s" % [floor_i, GameState.MAX_FLOORS, _floor_name(floor_i)]
	var fp := "F%d:e%d:ex%.0f,%.0f:bg%.2f" % [floor_i, enemy_count, exit_pos.x, exit_pos.y, bg.r]
	GameState.record_floor_fingerprint(fp)


func _floor_name(floor_i: int) -> String:
	match floor_i:
		1:
			return "обычные этажи"
		2:
			return "смещение"
		_:
			return "техзона / выход"


func _add_spawns(points: Array) -> void:
	for p in points:
		var m := Marker2D.new()
		m.position = p
		_spawn_points.add_child(m)


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
		GameState.on_exit_reached()
