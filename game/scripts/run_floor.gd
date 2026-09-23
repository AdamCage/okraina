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
var _offer_label: Label


func _ready() -> void:
	_obstacle.visible = false
	_obstacle_b.visible = false
	var preset := _preset_for_current_floor()
	_apply_preset(preset)
	_hud_notice.text = GameState.zh_ek_notice
	var boon_ru := _boon_ru(GameState.active_boon)
	_boon_label.text = "С собой: %s" % boon_ru
	_hud_info.offset_right = 1200
	if GameState.current_floor >= GameState.run_length:
		_exit_label.text = "ВЫХОД"
		_exit_hint.text = "Последний этаж забега. Жёлтая зона — выход во двор / другой район."
	else:
		_exit_label.text = "ДАЛЬШЕ"
		_exit_hint.text = "Жёлтая зона — дальше по дому. Этаж %d/%d." % [GameState.current_floor, GameState.run_length]
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = preset.player_spawn
	_world.add_child(player)
	player.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(GameState.player_hp, GameState.player_max_hp)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	cam.make_current()
	_spawn_enemies()
	_offer_label = Label.new()
	_offer_label.position = Vector2(24, 124)
	_offer_label.size = Vector2(900, 32)
	$HUD.add_child(_offer_label)
	GameState.roll_floor_offers()
	var panel := preload("res://scripts/offer_panel.gd").new()
	panel.chosen.connect(_on_offer_chosen)
	add_child(panel)
	_refresh_offer_label()


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


func _preset_for_current_floor() -> FloorPreset:
	var index := GameState.current_floor - 1
	if index < 0 or index >= GameState.preset_ids.size():
		push_error("RUN: no preset for floor %d" % GameState.current_floor)
		return FloorCatalog.all()[0]
	return FloorCatalog.get_by_id(GameState.preset_ids[index])


func _apply_preset(preset: FloorPreset) -> void:
	for c in _spawn_points.get_children():
		c.free()
	var drawn := _world.get_node_or_null("DrawnObstacles") as Node2D
	if drawn == null:
		drawn = Node2D.new()
		drawn.name = "DrawnObstacles"
		_world.add_child(drawn)
	for c in drawn.get_children():
		c.free()
	for rect in preset.obstacles:
		var block := ColorRect.new()
		block.position = rect.position
		block.size = rect.size
		block.color = Color(0.4, 0.42, 0.45)
		drawn.add_child(block)
	var count := mini(preset.spawn_points.size(), preset.spawn_kinds.size())
	for i in count:
		var marker := Marker2D.new()
		marker.position = preset.spawn_points[i]
		marker.set_meta("kind", preset.spawn_kinds[i])
		_spawn_points.add_child(marker)
	_floor_bg.color = preset.bg
	_exit_zone.position = preset.exit_pos
	_hud_info.text = "эт. %d/%d · ЭЖК №17 · %s · %s" % [
		GameState.current_floor,
		GameState.run_length,
		_zone_ru(preset.zone),
		preset.title,
	]
	var fp := "F%d:e%d:ex%.0f,%.0f:bg%.2f" % [
		GameState.current_floor,
		count,
		preset.exit_pos.x,
		preset.exit_pos.y,
		preset.bg.r,
	]
	GameState.record_floor_fingerprint(fp)


func _zone_ru(zone: String) -> String:
	match zone:
		"ordinary":
			return "обычные этажи"
		"shift":
			return "смещение"
		_:
			return "техзона"


func _spawn_enemies() -> void:
	for child in _spawn_points.get_children():
		var e := ENEMY_SCENE.instantiate() as CharacterBody2D
		e.kind = str(child.get_meta("kind", "tenant"))
		e.position = child.position
		_world.add_child(e)


func _on_offer_chosen(_offer_id: String) -> void:
	_refresh_offer_label()
	_on_hp_changed(GameState.player_hp, GameState.player_max_hp)


func _refresh_offer_label() -> void:
	if _offer_label == null:
		return
	if GameState.picked_offer_ids.is_empty():
		_offer_label.text = "На этаже: ещё ничего"
		return
	var names: PackedStringArray = PackedStringArray()
	for id in GameState.picked_offer_ids:
		var entry := preload("res://scripts/offer_catalog.gd").get_by_id(id)
		names.append(str(entry.get("title", id)))
	_offer_label.text = "На этаже: %s" % ", ".join(names)


func _on_hp_changed(current: int, maximum: int) -> void:
	_hud_hp.max_value = maximum
	_hud_hp.value = current


func _on_exit_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameState.on_exit_reached()
