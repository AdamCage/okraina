class_name Anomaly
extends Node2D
## Аномалии Зоны: grav (гравиконцентрат), elektra (электра), zharka (жарка),
## fruit («плод»). Живут в группе "anomalies" на слое 7 — только Area2D,
## движение игрока/врагов не блокируют и сами его не касаются.
## У каждой аномалии ровно один артефакт: take_artifact() отдаёт id,
## после чего аномалия становится безвредной (dormant).

const SCRIPT_PATH := "res://scripts/anomaly.gd"
const LOOT_PATH := "res://scripts/loot.gd"
const DAMAGE_TEXT_SCRIPT := preload("res://scripts/damage_text.gd")
const ITEM_DB := preload("res://scripts/item_db.gd")

const ANOMALY_LAYER := 64        ## слой 7 «anomaly» = 1 << 6
const PLAYER_MASK := 2           ## Area2D ловит игрока (слой 2)
const HUM_DISTANCE := 600.0      ## ближе этого — гудим
const HUM_PERIOD := 2.6
const DETECTOR_MULT := 2.6       ## danger_for == 0 на radius * 2.6
const DMG_INTERVAL := 0.5        ## шаг дискретных тиков урона

const TYPES: Dictionary = {
	"grav": {
		"name": "Гравиконцентрат", "radius": 120.0, "dps": 12.0, "pull": 300.0,
		"color": Color(0.45, 0.36, 0.92), "energy": 0.9, "artifacts": ["artifact_grav"],
	},
	"elektra": {
		"name": "Электра", "radius": 110.0, "damage": 34.0, "period": 2.2, "charge": 0.55,
		"color": Color(0.42, 0.72, 1.0), "energy": 1.3, "artifacts": ["artifact_medusa"],
	},
	"zharka": {
		"name": "Жарка", "radius": 130.0, "dps": 9.0,
		"color": Color(1.0, 0.55, 0.20), "energy": 1.15, "artifacts": ["artifact_flower"],
	},
	"fruit": {
		"name": "«Плод»", "radius": 100.0, "dps": 6.0, "rad": 5.0,
		"color": Color(0.52, 1.0, 0.42), "energy": 1.0,
		"artifacts": ["artifact_fruit", "artifact_soul"],
	},
}

var anomaly_type: String = "grav"
var radius: float = 120.0
var detector_distance: float = 312.0     ## дистанция детектора: radius * 2.6
var artifact_id: String = ""
var dormant: bool = false                ## артефакт забран — аномалия спит

var _active: bool = true
var _taken: bool = false
var _anim_t: float = 0.0
var _anim_frame: int = 0
var _hum_t: float = 0.0
var _dmg_t: float = 0.0
var _tx_t: float = 0.0
var _zap_t: float = 0.0
var _zapping: bool = false
var _hurl_done: bool = false
var _pulse: float = 0.0
var _player: Node = null
var _player_pos: Vector2 = Vector2.ZERO
var _sprite: Sprite2D
var _light: PointLight2D
var _area: Area2D
var _shape: CollisionShape2D
var _loot_gd: GDScript = null
var _built: bool = false


func _ready() -> void:
	add_to_group("anomalies")
	_build()
	set_physics_process(true)


## setup(type_id, radius) — вызвать сразу после Anomaly.new().
func setup(type_id: String, radius_value: float = 0.0) -> void:
	anomaly_type = String(type_id) if TYPES.has(type_id) else "grav"
	var t: Dictionary = TYPES[anomaly_type]
	radius = radius_value if radius_value > 0.0 else float(t["radius"])
	detector_distance = radius * DETECTOR_MULT
	dormant = false
	_active = true
	_taken = false
	_hurl_done = false
	_zap_t = float(t.get("period", 2.2))
	var list: Array = t.get("artifacts", [])
	artifact_id = String(list[randi() % list.size()]) if not list.is_empty() else ""
	_build()


# ------------------------------------------------------------------ детектор/гейгер
func has_artifact() -> bool:
	return artifact_id != "" and not _taken


func is_dormant() -> bool:
	return dormant or not _active


## 1.0 в центре, 0.0 на detector_distance (radius * 2.6).
func danger_for(pos: Vector2) -> float:
	if is_dormant():
		return 0.0
	var d: float = global_position.distance_to(pos)
	return clampf(1.0 - d / maxf(1.0, detector_distance), 0.0, 1.0)


## Забрать артефакт: возвращает id (или "" если уже забрали).
func take_artifact() -> String:
	if not has_artifact():
		return ""
	var id: String = artifact_id
	_taken = true
	artifact_id = ""
	dormant = true
	_active = false
	_spawn_artifact(id)
	GameState.artifacts_found += 1
	Quests.notify("collect", id, 1)
	Sfx.play("artifact_taken", global_position, -2.0)
	_go_dormant()
	return id


func hazard_name() -> String:
	return String(TYPES.get(anomaly_type, {}).get("name", anomaly_type))


# ------------------------------------------------------------------ опасность
func _physics_process(delta: float) -> void:
	_pulse += delta
	_animate(delta)
	_hum(delta)
	_player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if _player == null or not is_instance_valid(_player):
		return
	if _player is Node2D:
		_player_pos = (_player as Node2D).global_position
	if _player.has_method("center"):
		var v: Variant = _player.call("center")
		if v is Vector2:
			_player_pos = v
	if not _active:
		return
	var dist: float = global_position.distance_to(_player_pos)
	if _type_is("grav"):
		_hazard_grav(delta, dist)
	elif _type_is("elektra"):
		_hazard_elektra(delta, dist)
	elif _type_is("zharka"):
		_hazard_burn(delta, dist)
	elif _type_is("fruit"):
		_hazard_fruit(delta, dist)
	_visual_glow(delta, dist)


func _type_is(id: String) -> bool:
	return anomaly_type == id


## Гравиконцентрат: тянет к центру, давит, а «на выходе» выбрасывает тело.
func _hazard_grav(delta: float, dist: float) -> void:
	var reach: float = radius * 1.6
	if dist > reach:
		return
	var to_center: Vector2 = (global_position - _player_pos).normalized()
	var falloff: float = 1.0 - dist / reach
	# тянем через velocity: игрок сам решает, как двигаться (не блокируем его)
	if _player is Node2D and not _player_is_dead():
		var pull: Vector2 = to_center * float(TYPES["grav"]["pull"]) * falloff * delta
		if _player is CharacterBody2D:
			var body := _player as CharacterBody2D
			body.velocity += pull
		elif _player is Node2D and _player.has_method("apply_pull"):
			_player.call("apply_pull", pull)
	if dist <= radius:
		if not _taken:
			_dmg_t -= delta
			if _dmg_t <= 0.0:
				_dmg_t = DMG_INTERVAL
				var amount: float = float(TYPES["grav"]["dps"]) * DMG_INTERVAL
				_damage_player(amount, "ГРАВИТАЦИЯ")
	else:
		_dmg_t = 0.0
	# «выброс»: тело, погибшее внутри, отбрасывает наружу
	if _player_is_dead() and dist < radius * 1.5 and not _hurl_done:
		_hurl_done = true
		if _player is CharacterBody2D:
			var p := _player as CharacterBody2D
			p.velocity += to_center * -1.0 * 620.0 + Vector2(0.0, -180.0)
		Sfx.play("anomaly_warp", global_position, -3.0)
		_fx("smoke_puff", _player_pos, 1.4, 0.4)


## Электра: накопление и разряд по площади.
func _hazard_elektra(delta: float, dist: float) -> void:
	var t: Dictionary = TYPES["elektra"]
	var period: float = float(t["period"])
	var charge: float = float(t["charge"])
	if _zap_t > 0.0:
		_zap_t -= delta
	_zapping = _zap_t <= charge
	if _zap_t <= 0.0:
		_zap_t = period
		if dist <= radius * 1.15 and not _player_is_dead():
			_damage_player(float(t["damage"]), "РАЗРЯД")
			_arc_to(_player_pos)
		Sfx.play("anomaly_zap", global_position, -4.0)
		_fx("spark", global_position, radius / 34.0, 0.22)
		for i in 4:
			var a: float = randf_range(0.0, TAU)
			_fx("spark", global_position + Vector2.RIGHT.rotated(a) * randf_range(10.0, radius),
				0.8, 0.18)


## Жарка: непрерывное горение по площади.
func _hazard_burn(delta: float, dist: float) -> void:
	if dist > radius:
		return
	if _player_is_dead():
		return
	_dmg_t -= delta
	if _dmg_t > 0.0:
		return
	_dmg_t = DMG_INTERVAL
	var amount: float = float(TYPES["zharka"]["dps"]) * DMG_INTERVAL
	_damage_player(amount, "ЖАР")


## «Плод»: кислотный всплеск — урон со временем плюс радиация.
func _hazard_fruit(delta: float, dist: float) -> void:
	if dist > radius:
		return
	if _player_is_dead():
		return
	var d: Dictionary = TYPES["fruit"]
	GameState.add_radiation(float(d["rad"]) * delta)
	_dmg_t -= delta
	if _dmg_t > 0.0:
		return
	_dmg_t = DMG_INTERVAL
	_damage_player(float(d["dps"]) * DMG_INTERVAL, "КИСЛОТА")
	DAMAGE_TEXT_SCRIPT.spawn(get_parent(), _player_pos + Vector2(0.0, -40.0),
		float(d["rad"]) * DMG_INTERVAL, "rad")


func _damage_player(amount: float, label: String) -> void:
	if amount <= 0.0 or _player == null or not is_instance_valid(_player):
		return
	if not _player.has_method("take_damage"):
		return
	var argc: int = argc_of(_player, "take_damage")
	if argc >= 3:
		_player.call("take_damage", amount, "phys", self)
	elif argc == 2:
		_player.call("take_damage", amount, self)
	else:
		_player.call("take_damage", amount)
	DAMAGE_TEXT_SCRIPT.info(get_parent(), _player_pos + Vector2(0.0, -56.0), label)


# ------------------------------------------------------------------ узлы и вид
func _build() -> void:
	_built = true
	# визуал
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	var tex: Texture2D = Assets.sheet("anomaly_" + anomaly_type, 0)
	if tex != null:
		_sprite.texture = tex
	_sprite.scale = Vector2.ONE * maxf(0.6, radius / 32.0)
	_sprite.modulate = Color(0.0, 0.0, 0.0, 0.0)
	# свет
	if _light == null:
		_light = PointLight2D.new()
		_light.z_index = 1
		_light.blend_mode = Light2D.BLEND_MODE_ADD
		add_child(_light)
	_light.texture = Assets.sprite("light_cone")
	_light.color = Color(TYPES.get(anomaly_type, {}).get("color", Color.WHITE))
	_light.energy = float(TYPES.get(anomaly_type, {}).get("energy", 1.0))
	_light.texture_scale = maxf(0.5, radius / 24.0)
	# зона (слой 7, только игрок) — движение не блокирует
	if _area == null:
		_area = Area2D.new()
		# monitoring/monitorable по умолчанию true — сеттеры тут не трогаем
		_area.collision_layer = ANOMALY_LAYER
		_area.collision_mask = PLAYER_MASK
		_shape = CollisionShape2D.new()
		_shape.shape = CircleShape2D.new()
		_area.add_child(_shape)
		add_child(_area)
	if _shape != null and _shape.shape is CircleShape2D:
		(_shape.shape as CircleShape2D).radius = radius
		_area.collision_layer = ANOMALY_LAYER
		_area.collision_mask = PLAYER_MASK
	_active = not dormant
	_visual_glow(0.0, 99999.0)


func _animate(delta: float) -> void:
	if _sprite == null:
		return
	_anim_t += delta
	var total: int = maxi(1, Assets.sheet_count("anomaly_" + anomaly_type))
	var frame: int = int(floor(_anim_t * 5.0)) % total
	if frame != _anim_frame:
		_anim_frame = frame
		_sprite.texture = Assets.sheet("anomaly_" + anomaly_type, frame)


## Гул — только когда игрок рядом (примерно 600 px).
func _hum(delta: float) -> void:
	_hum_t -= delta
	if _hum_t > 0.0:
		return
	_hum_t = HUM_PERIOD
	if is_dormant():
		return
	if _player != null and is_instance_valid(_player) \
			and global_position.distance_to(_player_pos) <= HUM_DISTANCE:
		Sfx.play("anomaly_hum", global_position, -16.0)


func _visual_glow(_delta: float, dist: float) -> void:
	if _sprite == null:
		return
	var col: Color = TYPES.get(anomaly_type, {}).get("color", Color.WHITE)
	if is_dormant():
		_sprite.modulate = Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.35)
		if _light != null:
			_light.energy = lerpf(_light.energy, 0.0, 0.1)
		return
	var pulse: float = 0.55 + 0.25 * sin(_pulse * 2.6)
	if _type_is("elektra") and _zapping:
		pulse = 1.0
	if _type_is("zharka"):
		pulse += 0.15 * sin(_pulse * 7.0)
	if dist <= radius * 1.6:
		pulse = minf(1.0, pulse + 0.15)
	_sprite.modulate = Color(col.r, col.g, col.b, clampf(pulse, 0.15, 1.0))
	if _light != null:
		_light.energy = float(TYPES.get(anomaly_type, {}).get("energy", 1.0)) * clampf(pulse, 0.2, 1.4)


## Электрическая дуга от центра к цели (визуал разряда).
func _arc_to(pos: Vector2) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.78, 0.92, 1.0, 0.95)
	line.z_index = 70
	line.top_level = true
	var pts := PackedVector2Array()
	var steps: int = 6
	for i in steps + 1:
		var t: float = float(i) / float(steps)
		var p: Vector2 = global_position.lerp(pos, t)
		p += Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(0.0, 12.0) \
			* (1.0 - absf(t - 0.5) * 1.4)
		pts.append(p)
	line.points = pts
	add_child(line)
	var tw: Tween = line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.28)
	tw.tween_callback(line.queue_free)


## Короткий спрайтовый эффект (кадры листа + затухание), сам себя удаляет.
func _fx(sheet_name: String, pos: Vector2, scale_v: float, life: float) -> void:
	var parent: Node = get_parent()
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var frames: int = maxi(1, Assets.sheet_count(sheet_name))
	var s := Sprite2D.new()
	s.texture = Assets.sheet(sheet_name, 0)
	s.z_index = 65
	s.scale = Vector2.ONE * maxf(0.05, scale_v)
	parent.add_child(s)
	s.global_position = pos
	var tw: Tween = s.create_tween()
	tw.set_parallel(true)
	for i in range(1, frames):
		tw.tween_callback(_set_frame.bind(s, sheet_name, i)).set_delay(life * float(i) / float(frames))
	tw.tween_property(s, "modulate:a", 0.0, life * 0.65).set_delay(life * 0.35)
	tw.chain().tween_callback(s.queue_free)


static func _set_frame(sprite: Sprite2D, sheet_name: String, frame: int) -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.texture = Assets.sheet(sheet_name, frame)


# ------------------------------------------------------------------ служебное
func _player_is_dead() -> bool:
	if _player == null or not is_instance_valid(_player):
		return true
	if _player.has_method("is_alive"):
		var v: Variant = _player.call("is_alive")
		if typeof(v) == TYPE_BOOL:
			return not bool(v)
	return GameState.is_dead


## Артефакт появляется как подбираемый предмет (Loot), иначе — сразу в сумку.
func _spawn_artifact(id: String) -> void:
	var parent: Node = get_parent()
	var gd: GDScript = _loot_script()
	if parent != null and is_instance_valid(parent) and gd != null and gd.has_method("spawn_drop"):
		gd.call("spawn_drop", parent, global_position, id, 1)
	else:
		GameState.add_item(id, 1, false)
	GameState.log_message.emit("Артефакт «%s» у вас в руках" % ITEM_DB.display_name(id), "good")


## Аномалия без артефакта больше не вредит: гаснет и «засыпает».
func _go_dormant() -> void:
	_active = false
	dormant = true
	if _area != null:
		# может вызываться прямо из физики (подбор артефакта) — только через deferred
		_area.set_deferred("monitoring", false)
	if _light != null:
		_light.energy = 0.0
	if not is_inside_tree():
		return
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	if _sprite != null:
		tw.tween_property(_sprite, "modulate:a", 0.3, 0.6)
	if _light != null:
		tw.tween_property(_light, "energy", 0.0, 0.6)


func _loot_script() -> GDScript:
	if _loot_gd == null and ResourceLoader.exists(LOOT_PATH):
		_loot_gd = load(LOOT_PATH) as GDScript
	return _loot_gd


static func _script() -> GDScript:
	return load(SCRIPT_PATH) as GDScript


## Сколько аргументов у метода (у Player и Enemy разные подписи take_damage).
static func argc_of(obj: Object, method: String) -> int:
	if obj == null:
		return 0
	for m in obj.get_method_list():
		if String(m.get("name", "")) == method:
			var args: Variant = m.get("args", [])
			if typeof(args) == TYPE_ARRAY:
				return (args as Array).size()
			return 0
	return 0
