class_name Enemy
extends CharacterBody2D
## Враг Зоны: слепой пёс, кровосос, зомбированный сталкер, мутировавший кабан.
## Конечный автомат: idle -> patrol -> alert -> chase -> attack -> flee -> death.
## Никаких NavigationMesh: рулевое управление + объезд препятствий рейкастами
## («усы») + расталкивание своих. Слой 3 (enemy), маска 1|2|4 (мир, игрок, враги).
## Глобальный кэш имён классов в headless может быть не обновлён, поэтому вместо
## имён классов используются preload/load по пути.

const SCRIPT_PATH := "res://scripts/enemy.gd"
const PROJECTILE_SCRIPT := preload("res://scripts/projectile.gd")
const DAMAGE_TEXT_SCRIPT := preload("res://scripts/damage_text.gd")
const LOOT_PATH := "res://scripts/loot.gd"

const ENEMY_LAYER := 4           ## слой 3 «enemy» = 1 << 2
const ENEMY_MASK := 1 | 2 | 4    ## мир + игрок + враги (чтобы не проходить сквозь друг друга)
const LOS_MASK := 1 | 4          ## мир (1) + враги (4): проверка прямой видимости
const BODY_RADIUS := 14.0
const CRIT_MULT := 1.6           ## «сильный» удар: >= 1.6 базового урона врага
const KNOCKBACK := 170.0
const SEP_RADIUS := 46.0
const SEP_FORCE := 95.0
const AVOID_LEN := 34.0
const AVOID_FORCE := 150.0
const ALERT_TIME := 0.6
const LOSE_TIME := 3.5           ## сколько враг помнит цель без прямой видимости
const DANGER_NEAR := 260.0       ## ближе этого полоска hp видна всегда

enum State { IDLE, PATROL, ALERT, CHASE, ATTACK, FLEE, DEAD }

## Таблица типов: hp, speed, damage, attack_range, attack_cooldown, xp, scale,
## detect (радиус обнаружения), hear (радиус слышимости) и особенности поведения.
const TYPES: Dictionary = {
	"dog": {
		"name": "Слепой пёс",
		"hp": 40.0, "speed": 170.0, "damage": 9.0, "attack_range": 36.0,
		"attack_cooldown": 1.1, "xp": 18.0, "scale": 0.85, "detect": 420.0, "hear": 300.0,
		"pack": [3, 5], "flee_hp": 0.15, "ranged": false, "orbit": 118.0,
		"loot": {"bandage": 0.25, "scrap": 0.35, "medkit": 0.06},
	},
	"mutant": {
		"name": "Кровосос",
		"hp": 220.0, "speed": 95.0, "damage": 26.0, "attack_range": 42.0,
		"attack_cooldown": 1.6, "xp": 70.0, "scale": 1.15, "detect": 420.0, "hear": 300.0,
		"flee_hp": 0.0, "ranged": false, "invis": 0.25, "invis_range": 195.0,
		"loot": {"medkit": 0.30, "vodka": 0.20, "artifact_flower": 0.05},
	},
	"zombie": {
		"name": "Зомбированный сталкер",
		"hp": 120.0, "speed": 65.0, "damage": 12.0, "attack_range": 420.0,
		"attack_range_min": 220.0, "attack_cooldown": 2.4, "xp": 45.0, "scale": 1.0,
		"detect": 420.0, "hear": 300.0, "ranged": true, "burst": 3, "flee_hp": 0.25,
		"loot": {"ammo_9x18": 0.45, "ammo_545": 0.30, "scrap": 0.30, "docs": 0.06},
	},
	"boar": {
		"name": "Мутировавший кабан",
		"hp": 150.0, "speed": 62.0, "damage": 20.0, "attack_range": 40.0,
		"attack_cooldown": 2.2, "xp": 40.0, "scale": 1.05, "detect": 420.0, "hear": 300.0,
		"flee_hp": 0.0, "ranged": false, "charge_speed": 520.0, "charge_range": 330.0,
		"charge_windup": 0.6, "charge_max": 290.0, "stun": 1.2,
		"loot": {"canned": 0.30, "bread": 0.25, "scrap": 0.30},
	},
}

const BOSS_MODS: Dictionary = {
	"hp_mult": 2.0, "dmg_mult": 1.4, "scale_mult": 1.35, "detect": 620.0,
}

const SOUND_ALERT: Dictionary = {
	"dog": "dog_bark", "mutant": "mutant_roar", "zombie": "zombie_moan", "boar": "boar_snort",
}
const SOUND_ATTACK: Dictionary = {
	"dog": "melee_swing", "mutant": "melee_swing", "zombie": "shot_ak", "boar": "melee_swing",
}
const SOUND_DIE := "creature_die"

## Кэш кадров листов: sheet#frame -> текстура (общий для всех врагов).
static var _frame_cache: Dictionary = {}

# --- характеристики (значения по умолчанию — «пёс»; переписываются в setup())
var enemy_type: String = "dog"
var level: int = 1
var is_boss: bool = false
var state: int = State.IDLE
var hp: float = 40.0
var hp_max: float = 40.0
var speed: float = 170.0
var damage: float = 9.0
var attack_range: float = 36.0
var attack_range_min: float = 0.0
var attack_cooldown: float = 1.1
var detect_radius: float = 420.0
var hear_radius: float = 300.0
var scale_mult: float = 0.85
var xp_base: float = 18.0
var ranged: bool = false
var burst_count: int = 0

# --- таймеры и внутреннее состояние
var _state_t: float = 0.0
var _atk_cd: float = 0.0
var _attack_t: float = 0.0
var _attack_time: float = 0.0
var _attack_hit_at: float = 0.1
var _attack_hit_done: bool = false
var _flash_t: float = 0.0
var _hit_count: int = 0
var _redraw_t: float = 0.0
var _knock: Vector2 = Vector2.ZERO
var _desired: Vector2 = Vector2.ZERO   ## «желаемая» скорость от ИИ (без добавок)
var _sep: Vector2 = Vector2.ZERO
var _sep_t: float = 0.0
var _avoid: Vector2 = Vector2.ZERO
var _avoid_t: float = 0.0
var _wall_contact: bool = false
var _alpha: float = 1.0
var _roar_cd: float = 0.0

# --- анимация
var _anim: String = "idle"
var _anim_t: float = 0.0
var _anim_frame: int = 0
var _facing: Vector2 = Vector2.RIGHT

# --- восприятие
var _player: Node = null
var _player_pos: Vector2 = Vector2.ZERO
var _dist: float = 99999.0
var _see: bool = false
var _last_seen: float = 0.0
var _last_known: Vector2 = Vector2.ZERO
var _target_pos: Vector2 = Vector2.INF
var _noise: Vector2 = Vector2.ZERO
var _noise_t: float = 0.0
var _alert_pos: Vector2 = Vector2.INF

# --- патруль и типа-специфичное
var _patrol_home: Vector2 = Vector2.ZERO
var _patrol_point: Vector2 = Vector2.ZERO
var _home_set: bool = false
var _orbit_sign: float = 1.0
var _lunge_t: float = 0.0
var _burst_left: int = 0
var _burst_t: float = 0.0
var _charge_phase: int = 0
var _charge_dir: Vector2 = Vector2.RIGHT
var _charge_dist: float = 0.0
var _stun_t: float = 0.0
var _boss_applied: bool = false

# --- узлы
var _sprite: Sprite2D
var _shadow: Sprite2D
var _shape: CollisionShape2D
var _dead: bool = false
var _loot_gd: GDScript = null


func _ready() -> void:
	add_to_group("enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = ENEMY_LAYER
	collision_mask = ENEMY_MASK
	_build_body()
	_patrol_home = global_position
	_patrol_point = global_position
	set_physics_process(true)
	queue_redraw()


## setup(type_id, level) — вызывать сразу после Enemy.new().
func setup(type_id: String, level_value: int = 1) -> void:
	var t: Dictionary = TYPES.get(type_id, TYPES["dog"])
	enemy_type = String(type_id) if TYPES.has(type_id) else "dog"
	level = maxi(1, level_value)
	var lv: float = float(level - 1)
	hp_max = float(t["hp"]) * (1.0 + 0.12 * lv)
	damage = float(t["damage"]) * (1.0 + 0.10 * lv)
	speed = float(t["speed"])
	attack_range = float(t["attack_range"])
	attack_range_min = float(t.get("attack_range_min", 0.0))
	attack_cooldown = float(t["attack_cooldown"])
	detect_radius = float(t["detect"])
	hear_radius = float(t["hear"])
	scale_mult = float(t["scale"])
	xp_base = float(t["xp"]) * (1.0 + 0.18 * lv)
	ranged = bool(t.get("ranged", false))
	burst_count = int(t.get("burst", 0))
	hp = hp_max
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0
	_patrol_home = global_position
	_patrol_point = global_position
	_build_body()
	if _shape != null and _shape.shape is CircleShape2D:
		(_shape.shape as CircleShape2D).radius = BODY_RADIUS * clampf(scale_mult, 0.8, 1.5)
	set_anim("idle")


## Босс: x2 hp, x1.4 урона, крупнее и «слышит» дальше.
func set_boss(value: bool) -> void:
	is_boss = value
	if not value or _boss_applied:
		return
	_boss_applied = true
	hp_max *= float(BOSS_MODS["hp_mult"])
	hp = hp_max
	damage *= float(BOSS_MODS["dmg_mult"])
	scale_mult *= float(BOSS_MODS["scale_mult"])
	detect_radius = maxf(detect_radius, float(BOSS_MODS["detect"]))
	_build_body()
	if _shape != null and _shape.shape is CircleShape2D:
		(_shape.shape as CircleShape2D).radius = BODY_RADIUS * clampf(scale_mult, 0.8, 1.6)
	queue_redraw()


# ------------------------------------------------------------------ контракт
## Контракт: take_damage(amount, from). Дополнительно терпим «игровой» вариант
## take_damage(amount, kind, src): если второй аргумент не Node, источник берём
## из третьего, чтобы удар ножом по своим правилам всё равно наносил урон.
func take_damage(amount: float, from: Variant = null, src_alt: Variant = null) -> void:
	if _dead or amount <= 0.0:
		return
	var source: Node = _as_node(from)
	if source == null:
		source = _as_node(src_alt)
	hp -= amount
	_hit_count += 1
	_flash_t = 0.08
	modulate = Color(1.0, 0.35, 0.35, _alpha)
	Sfx.play("hit_flesh", global_position, -4.0)
	var crit: bool = amount >= base_damage() * CRIT_MULT
	var txt_pos: Vector2 = global_position + Vector2(0.0, -Assets.SHEET_ANCHOR.y * scale_mult)
	DAMAGE_TEXT_SCRIPT.spawn(get_parent(), txt_pos, amount, "crit" if crit else "phys")
	if source != null and is_instance_valid(source) and source is Node2D:
		var src := source as Node2D
		var away: Vector2 = global_position - src.global_position
		if away.length_squared() < 0.01:
			away = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		_knock = away.normalized() * KNOCKBACK
	if hp <= 0.0:
		die()
		return
	_last_known = _target_of(source)
	if state == State.IDLE or state == State.PATROL:
		_alert_pos = _last_known
		_set_state(State.ALERT, 0.25)
	queue_redraw()


static func _as_node(v: Variant) -> Node:
	var n: Node = null
	if v is Node:
		n = v
	return n


## Псевдоним take_damage — код игрока может звать любой из двух.
func apply_damage_from_player(amount: float, from: Variant = null) -> void:
	take_damage(amount, from)


func is_alive() -> bool:
	return not _dead and hp > 0.0


func center() -> Vector2:
	return global_position


func xp_value() -> float:
	return xp_base * (2.0 if is_boss else 1.0)


## 0..1 — насколько враг «давит» на игрока рядом (для тревожного эмбиента/UI).
func danger_value() -> float:
	if _dead:
		return 0.0
	var near: float = 1.0 - clampf(_dist / maxf(1.0, detect_radius * 1.15), 0.0, 1.0)
	if near <= 0.0:
		return 0.0
	var health: float = clampf(hp / maxf(1.0, hp_max), 0.0, 1.0)
	var aggro: float = 0.15
	match state:
		State.ATTACK:
			aggro = 1.0
		State.CHASE, State.FLEE:
			aggro = 0.85
		State.ALERT:
			aggro = 0.7
		State.PATROL:
			aggro = 0.35
	var value: float = near * (0.55 + 0.45 * health) * aggro * (1.35 if is_boss else 1.0)
	return clampf(value, 0.0, 1.0)


## Базовый урон врага — порог для «критического» числа урона в take_damage().
func base_damage() -> float:
	return damage


func health_fraction() -> float:
	return clampf(hp / maxf(1.0, hp_max), 0.0, 1.0)


func state_name() -> String:
	match state:
		State.IDLE:
			return "idle"
		State.PATROL:
			return "patrol"
		State.ALERT:
			return "alert"
		State.CHASE:
			return "chase"
		State.ATTACK:
			return "attack"
		State.FLEE:
			return "flee"
		_:
			return "death"


## Шум: игрок выстрелил, что-то упало — враг идёт проверять в радиусе слышимости.
func hear_noise(pos: Vector2) -> void:
	if _dead or not is_inside_tree():
		return
	if pos == Vector2.INF:
		return
	var d: float = global_position.distance_to(pos)
	if d > hear_radius:
		return
	_noise = pos
	_noise_t = 4.0
	if state == State.IDLE or state == State.PATROL:
		_alert_pos = pos
		_set_state(State.ALERT, ALERT_TIME)
		Sfx.play(String(SOUND_ALERT.get(enemy_type, SOUND_DIE)), global_position, -8.0)


## Прямая видимость: мир (слой 1) и другие враги (слой 3) перекрывают обзор.
func line_of_sight(target: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters2D.create(global_position, target, LOS_MASK)
	q.exclude = [get_rid()]
	q.collide_with_areas = false
	q.collide_with_bodies = true
	return space.intersect_ray(q).is_empty()


# ------------------------------------------------------------------ главный цикл
func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _home_set:
		_home_set = true
		_patrol_home = global_position
		_patrol_point = global_position
	_tick(delta)
	_perceive(delta)
	_update_target()
	if _stun_t > 0.0:
		# оглушён (кабан после рывка) — только тормозим
		_stun_t -= delta
		_desired = _desired.move_toward(Vector2.ZERO, 900.0 * delta)
	else:
		match state:
			State.IDLE:
				_st_idle(delta)
			State.PATROL:
				_st_patrol(delta)
			State.ALERT:
				_st_alert(delta)
			State.CHASE:
				_st_chase(delta)
			State.ATTACK:
				_st_attack(delta)
			State.FLEE:
				_st_flee(delta)
			_:
				_desired = Vector2.ZERO
	_apply_motion(delta)
	_post_move()
	_update_anim(delta)
	_update_visual(delta)


func _tick(delta: float) -> void:
	_state_t -= delta
	_atk_cd -= delta
	_attack_t -= delta
	_lunge_t -= delta
	_roar_cd -= delta
	_flash_t -= delta
	if _noise_t > 0.0:
		_noise_t -= delta
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 0.25
		queue_redraw()
	if _burst_left > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst_t = 0.13
			_burst_left -= 1
			_fire_bullet()


func _perceive(delta: float) -> void:
	_player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if _player == null or not is_instance_valid(_player):
		_see = false
		_dist = 99999.0
		_last_seen += delta
		return
	_player_pos = _target_of(_player)
	_dist = global_position.distance_to(_player_pos)
	if not _player_is_alive():
		_see = false
		_last_seen += delta
		return
	var bonus: float = 1.3 if (state == State.CHASE or state == State.ATTACK) else 1.0
	if _dist <= detect_radius * bonus:
		_see = line_of_sight(_player_pos)
	else:
		_see = false
	if not _see:
		_last_seen += delta


func _update_target() -> void:
	if _see:
		_last_known = _player_pos
		_last_seen = 0.0
		_target_pos = _last_known
		return
	if _noise_t > 0.0:
		_last_known = _noise
		_target_pos = _noise
		return
	_target_pos = _last_known if _last_seen < LOSE_TIME else Vector2.INF


# ------------------------------------------------------------------ состояния
func _st_idle(delta: float) -> void:
	_desired = _desired.move_toward(Vector2.ZERO, 420.0 * delta)
	if _see or _noise_t > 0.0:
		_to_alert()
		return
	if _state_t <= 0.0:
		_pick_patrol_point()
		_set_state(State.PATROL, randf_range(4.0, 8.0))


func _st_patrol(delta: float) -> void:
	if _see or _noise_t > 0.0:
		_to_alert()
		return
	var to_pt: Vector2 = _patrol_point - global_position
	if to_pt.length() < 18.0 or _state_t <= 0.0:
		_set_state(State.IDLE, randf_range(1.0, 2.6))
		_desired = _desired.move_toward(Vector2.ZERO, 380.0 * delta)
		return
	_steer_velocity(to_pt.normalized() * speed * 0.55, delta)


func _st_alert(delta: float) -> void:
	_desired = _desired.move_toward(Vector2.ZERO, 620.0 * delta)
	_face(_alert_pos if _alert_pos.is_finite() else _last_known)
	if _state_t <= 0.0:
		_set_state(State.CHASE)


func _st_chase(delta: float) -> void:
	if _player == null or not _player_is_alive():
		_set_state(State.IDLE, randf_range(0.5, 1.5))
		return
	if _flee_met():
		_set_state(State.FLEE, 3.0)
		return
	if _target_pos == Vector2.INF:
		_set_state(State.IDLE, randf_range(0.5, 1.5))
		return
	if not _see:
		# идём к шуму/последнему известному месту
		var to_t: Vector2 = _target_pos - global_position
		if to_t.length() > 24.0:
			_steer_velocity(to_t.normalized() * speed * 0.9, delta)
		else:
			_desired = _desired.move_toward(Vector2.ZERO, 300.0 * delta)
			if _noise_t <= 0.0:
				_set_state(State.IDLE, randf_range(0.4, 1.2))
		return
	match enemy_type:
		"dog":
			_ai_dog(delta)
		"mutant":
			_ai_mutant(delta)
		"zombie":
			_ai_zombie(delta)
		_:
			_ai_boar(delta)
	_face(_target_pos)


func _st_attack(delta: float) -> void:
	var elapsed: float = _attack_time - _attack_t
	if not _attack_hit_done and elapsed >= _attack_hit_at:
		_attack_hit_done = true
		_attack_land()
	match enemy_type:
		"dog":
			_steer_velocity((_player_pos - global_position).normalized() * speed * 2.0, delta)
		"mutant":
			_steer_velocity((_player_pos - global_position).normalized() * speed * 1.35, delta)
		"boar":
			_attack_boar(delta)
		_:
			_desired = _desired.move_toward(Vector2.ZERO, 700.0 * delta)
	if _attack_t <= 0.0:
		_set_state(State.CHASE)


func _st_flee(delta: float) -> void:
	var away: Vector2 = global_position - _player_pos
	if away.length_squared() < 1.0:
		away = Vector2.LEFT
	_steer_velocity(away.normalized() * speed * 1.05, delta)
	if _state_t <= 0.0:
		if _flee_met():
			_set_state(State.FLEE, 2.0)
		elif _see:
			_set_state(State.CHASE)
		else:
			_set_state(State.IDLE, randf_range(0.3, 1.0))


func _set_state(new_state: int, time_value: float = -1.0) -> void:
	state = new_state
	_state_t = maxf(0.0, time_value)


func _to_alert() -> void:
	_alert_pos = _last_known if _last_known != Vector2.ZERO else _target_pos
	if not _alert_pos.is_finite():
		_alert_pos = _player_pos if _see else global_position
	_set_state(State.ALERT, ALERT_TIME * 1.5)
	if _see:
		Sfx.play(String(SOUND_ALERT.get(enemy_type, SOUND_DIE)), global_position, -7.0)


# ------------------------------------------------------------------ повадки типов
## Слепой пёс: кружит вокруг цели, выискивая момент для прыжка.
func _ai_dog(delta: float) -> void:
	var orbit: float = float(TYPES["dog"]["orbit"])
	var to_p: Vector2 = _player_pos - global_position
	if _atk_cd <= 0.0 and _dist <= attack_range:
		_begin_attack(0.28, 0.12)
		return
	if _dist > orbit * 1.35:
		_steer_velocity(to_p.normalized() * speed, delta)
		return
	var radial: Vector2 = to_p.normalized()
	var tangent: Vector2 = radial.rotated(PI * 0.5 * _orbit_sign)
	_steer_velocity((tangent + radial * 0.18).normalized() * speed * 0.92, delta)
	if _atk_cd <= 0.0 and _lunge_t <= 0.0 and _dist < orbit * 1.6:
		_lunge_t = randf_range(1.0, 2.2)
		_orbit_sign = -_orbit_sign
		_begin_attack(0.45, 0.22)


## Кровосос: идёт напрямик, удар когтями; вблизи становится полупрозрачным
## (телеграфируем рыком).
func _ai_mutant(delta: float) -> void:
	var to_p: Vector2 = _player_pos - global_position
	var invis_r: float = float(TYPES["mutant"]["invis_range"])
	if _dist <= invis_r and _roar_cd <= 0.0:
		_roar_cd = 7.0
		Sfx.play("mutant_roar", global_position, -3.0)
	if _atk_cd <= 0.0 and _dist <= attack_range:
		_begin_attack(0.65, 0.34)
		return
	_steer_velocity(to_p.normalized() * speed, delta)


## Зомбированный сталкер: держит дистанцию 220..420 и стреляет очередями.
func _ai_zombie(delta: float) -> void:
	var to_p: Vector2 = _player_pos - global_position
	if _dist < attack_range_min:
		_steer_velocity(-to_p.normalized() * speed, delta)
		return
	if _dist > attack_range:
		_steer_velocity(to_p.normalized() * speed, delta)
		return
	var radial: Vector2 = to_p.normalized()
	var tangent: Vector2 = radial.rotated(PI * 0.5 * _orbit_sign)
	_steer_velocity((radial * 0.25 + tangent * 0.75).normalized() * speed * 0.6, delta)
	if _atk_cd <= 0.0 and _burst_left <= 0:
		_begin_attack(0.9, 0.3)


## Мутировавший кабан: разгон-рывок по прямой, затем оглушение.
func _ai_boar(delta: float) -> void:
	var t: Dictionary = TYPES["boar"]
	var to_p: Vector2 = _player_pos - global_position
	if _atk_cd <= 0.0 and _dist <= float(t["charge_range"]):
		_charge_phase = 0
		_charge_dir = to_p.normalized()
		_begin_attack(float(t["charge_windup"]) + 2.0, float(t["charge_windup"]))
		return
	if _dist <= attack_range and _atk_cd <= 0.0:
		_begin_attack(0.5, 0.25)
		return
	_steer_velocity(to_p.normalized() * speed, delta)


## Фаза рывка кабана: 0 — разгон, 1 — полёт, 2 — отдышка.
func _attack_boar(delta: float) -> void:
	var t: Dictionary = TYPES["boar"]
	if _charge_phase == 0:
		_desired = _desired.move_toward(Vector2.ZERO, 900.0 * delta)
		var to_p: Vector2 = _player_pos - global_position
		if to_p.length() > 1.0:
			_charge_dir = to_p.normalized()
		return
	if _charge_phase == 1:
		_desired = _charge_dir * float(t["charge_speed"])
		_charge_dist += _desired.length() * delta
		_attack_t = maxf(_attack_t, 0.04)
		if _charge_dist >= float(t["charge_max"]):
			_end_charge()
		return
	_desired = _desired.move_toward(Vector2.ZERO, 700.0 * delta)


func _end_charge() -> void:
	if _charge_phase != 1:
		return
	_charge_phase = 2
	_stun_t = float(TYPES["boar"].get("stun", 1.2))
	_attack_t = 0.0
	_attack_time = 0.0
	_attack_hit_done = true
	_set_state(State.CHASE, _stun_t)


func _begin_attack(windup: float, hit_at: float) -> void:
	_attack_time = maxf(0.05, windup)
	_attack_t = _attack_time
	_attack_hit_at = clampf(hit_at, 0.0, _attack_time)
	_attack_hit_done = false
	_atk_cd = attack_cooldown + _attack_time
	_set_state(State.ATTACK, _attack_time)
	if enemy_type != "zombie":
		Sfx.play(String(SOUND_ATTACK.get(enemy_type, "melee_swing")), global_position, -6.0)


func _attack_land() -> void:
	match enemy_type:
		"zombie":
			_start_burst()
		"boar":
			_charge_phase = 1
			_charge_dist = 0.0
			Sfx.play("boar_snort", global_position, -4.0)
		_:
			if _see and _dist <= attack_range * 1.8 and _player_is_alive():
				_deal_damage(_player)
				Sfx.play("melee_hit", global_position, -4.0)
				PROJECTILE_SCRIPT.spawn_fx(get_parent(), "blood_splat", _player_pos, 0.7, 0.16, 0.0)


func _start_burst() -> void:
	if burst_count <= 0:
		return
	_burst_left = burst_count
	_burst_t = 0.0


## Очередь из ржавого АК: три пули с малым разбросом.
func _fire_bullet() -> void:
	if not is_inside_tree():
		return
	var muzzle: Vector2 = global_position + Vector2(0.0, -22.0 * scale_mult)
	var aim: Vector2 = _player_pos + Vector2(0.0, -14.0) if _player != null else muzzle + _facing * 100.0
	var d: Vector2 = (aim - muzzle).normalized()
	if d == Vector2.ZERO:
		d = _facing
	PROJECTILE_SCRIPT.fire(get_parent(), muzzle + d * 18.0, d, {
		"speed": 950.0, "damage": damage, "hit_mask": 1 | 2, "gun_range": 560.0,
		"shooter": self, "spread": 0.09, "sfx": "shot_ak", "sfx_db": -8.0,
		"noise": false, "muzzle": true, "color": Color(1.0, 0.82, 0.42),
		"sprite": "spark", "size": 0.9,
	})


func _flee_met() -> bool:
	var f: float = float(TYPES.get(enemy_type, {}).get("flee_hp", 0.0))
	return f > 0.0 and health_fraction() < f


# ------------------------------------------------------------------ урон и цели
func _deal_damage(target: Object) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	var argc: int = PROJECTILE_SCRIPT.method_argc(target, "take_damage")
	if argc >= 3:
		target.call("take_damage", damage, "phys", self)
	elif argc == 2:
		target.call("take_damage", damage, self)
	else:
		target.call("take_damage", damage)


func _steer_velocity(want: Vector2, delta: float) -> void:
	_desired = _desired.move_toward(want, 1400.0 * delta)


func _face(pos: Vector2) -> void:
	var d: Vector2 = pos - global_position
	if d.length_squared() > 1.0:
		_facing = d.normalized()


func _target_of(node: Node) -> Vector2:
	if node == null or not is_instance_valid(node):
		return _last_known
	if node.has_method("center"):
		var v: Variant = node.call("center")
		if v is Vector2:
			return v
	if node is Node2D:
		return (node as Node2D).global_position
	return _last_known


func _player_is_alive() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player.has_method("is_alive"):
		var v: Variant = _player.call("is_alive")
		if typeof(v) == TYPE_BOOL:
			return bool(v)
	return true


func _pick_patrol_point() -> void:
	var a: float = randf_range(0.0, TAU)
	_patrol_point = _patrol_home + Vector2.RIGHT.rotated(a) * randf_range(70.0, 240.0)


# ------------------------------------------------------------------ движение
func _apply_motion(delta: float) -> void:
	_knock = _knock.move_toward(Vector2.ZERO, 700.0 * delta)
	_sep_t -= delta
	if _sep_t <= 0.0:
		_sep_t = 0.1
		_sep = _separation()
	_avoid_t -= delta
	if _avoid_t <= 0.0:
		_avoid_t = 0.08
		_avoid = _avoidance()
	# суммируем только здесь: желаемая скорость + расталкивание + объезд + отдача
	var total: Vector2 = _desired + _sep + _avoid + _knock
	var cap: float = maxf(speed * 3.0, 620.0)
	velocity = total.limit_length(cap)
	move_and_slide()


## Расталкивание своих: враги не слипаются в одну точку.
func _separation() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	var push: Vector2 = Vector2.ZERO
	var n: int = 0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other) or not (other is Node2D):
			continue
		var o := other as Node2D
		var d: Vector2 = global_position - o.global_position
		var l: float = d.length()
		if l > 0.5 and l < SEP_RADIUS:
			push += d / l * (1.0 - l / SEP_RADIUS)
			n += 1
			if n >= 6:
				break
	if n == 0:
		return Vector2.ZERO
	return push * SEP_FORCE


## Объезд препятствий «усами»: два луча вперёд под углом (слой мира).
func _avoidance() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return Vector2.ZERO
	var forward: Vector2 = velocity
	if forward.length() < 6.0:
		forward = _facing
	forward = forward.normalized()
	var steer: Vector2 = Vector2.ZERO
	for a in [0.6, -0.6]:
		var d: Vector2 = forward.rotated(a)
		var q := PhysicsRayQueryParameters2D.create(global_position,
			global_position + d * AVOID_LEN, 1)
		q.exclude = [get_rid()]
		q.collide_with_areas = false
		q.collide_with_bodies = true
		if not space.intersect_ray(q).is_empty():
			steer += d.rotated(-PI * 0.5 * signf(a)) * AVOID_FORCE
	return steer


## Контакты после move_and_slide(): рывок кабана заканчивается на стене или на теле.
func _post_move() -> void:
	var count: int = get_slide_collision_count()
	if count == 0:
		return
	for i in count:
		var col: Object = get_slide_collision(i).get_collider()
		if col == null:
			continue
		if enemy_type == "boar" and _charge_phase == 1 and col.has_method("take_damage"):
			if col.is_in_group("player"):
				_deal_damage(col)
				_end_charge()
				return
	if enemy_type == "boar" and _charge_phase == 1:
		_end_charge()


# ------------------------------------------------------------------ анимация и вид
func set_anim(name: String) -> void:
	if _anim == name:
		return
	_anim = name
	_anim_t = 0.0
	_anim_frame = 0
	_apply_frame()


func _update_anim(delta: float) -> void:
	var want: String = "idle"
	if state == State.ATTACK:
		want = "attack"
	elif velocity.length() > 14.0:
		want = "walk"
	set_anim(want)
	_anim_t += delta
	var fps: float = 6.0
	if want == "walk":
		fps = 10.0
	elif want == "attack":
		fps = 12.0
	if is_boss:
		fps *= 0.85
	var total: int = maxi(1, Assets.sheet_count("%s_%s" % [enemy_type, want]))
	var frame: int = int(floor(_anim_t * fps)) % total
	if frame != _anim_frame:
		_anim_frame = frame
		_apply_frame()


func _apply_frame() -> void:
	if _sprite == null:
		return
	_sprite.texture = frame_tex("%s_%s" % [enemy_type, _anim], _anim_frame)
	_sprite.flip_h = _facing.x < -0.05


## Общий кэш текстур кадров (листы 64x64, Assets.SHEETS).
static func frame_tex(sheet: String, frame: int) -> Texture2D:
	var key: String = sheet + "#" + str(frame)
	if not _frame_cache.has(key):
		_frame_cache[key] = Assets.sheet(sheet, frame)
	return _frame_cache[key]


func _update_visual(delta: float) -> void:
	var want_alpha: float = 1.0
	if enemy_type == "mutant" and (
			_dist <= float(TYPES["mutant"]["invis_range"])
			and (state == State.CHASE or state == State.ATTACK)):
		want_alpha = float(TYPES["mutant"]["invis"])
	_alpha = lerpf(_alpha, want_alpha, clampf(delta * 3.0, 0.0, 1.0))
	if _flash_t > 0.0:
		modulate = Color(1.0, 0.35, 0.35, _alpha)
	else:
		modulate = Color(1.0, 1.0, 1.0, _alpha)


func _build_body() -> void:
	if _shadow == null:
		_shadow = Sprite2D.new()
		_shadow.texture = Assets.sprite("soft_shadow")
		_shadow.z_index = -2
		add_child(_shadow)
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.shape = CircleShape2D.new()
		add_child(_shape)
	if _shape.shape is CircleShape2D:
		(_shape.shape as CircleShape2D).radius = BODY_RADIUS * clampf(scale_mult, 0.8, 1.6)
	# «ноги» кадра (Assets.SHEET_ANCHOR) ставим в origin тела
	_sprite.offset = Vector2(Assets.SHEET_FRAME * 0.5, Assets.SHEET_FRAME * 0.5) - Assets.SHEET_ANCHOR
	_sprite.scale = Vector2.ONE * scale_mult
	_shadow.scale = Vector2(0.95, 0.5) * clampf(scale_mult, 0.7, 1.2)
	_shadow.position = Vector2(0.0, -3.0)
	_shadow.modulate = Color(0.0, 0.0, 0.0, 0.40)
	_apply_frame()


## Полоска hp: видна после первого попадания или когда игрок ближе 260 px.
func _hp_bar_visible() -> bool:
	if is_boss or _hit_count > 0:
		return true
	if _player != null and is_instance_valid(_player):
		return _dist <= DANGER_NEAR
	return false


func _draw() -> void:
	if _dead or not _hp_bar_visible():
		return
	var w: float = 54.0 if is_boss else 36.0
	var h: float = 4.0
	var y: float = -Assets.SHEET_ANCHOR.y * scale_mult - 14.0
	var frac: float = health_fraction()
	draw_rect(Rect2(-w * 0.5 - 1.0, y - 1.0, w + 2.0, h + 2.0), Color(0.0, 0.0, 0.0, 0.72))
	draw_rect(Rect2(-w * 0.5, y, w, h), Color(0.12, 0.02, 0.02, 0.9))
	var col: Color = Color(0.85, 0.22, 0.18) if frac > 0.35 else Color(0.95, 0.52, 0.12)
	if is_boss:
		col = Color(0.80, 0.22, 0.78)
	draw_rect(Rect2(-w * 0.5, y, w * maxf(0.0, frac), h), col)


# ------------------------------------------------------------------ смерть и лут
func die() -> void:
	if _dead:
		return
	_dead = true
	state = State.DEAD
	hp = 0.0
	_desired = Vector2.ZERO
	_burst_left = 0
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	queue_redraw()
	# register_kill уже уведомляет Quests.notify("kill", ...) — дублировать не надо
	GameState.register_kill(enemy_type)
	GameState.add_xp(xp_value())
	Sfx.play(SOUND_DIE, global_position, -3.0)
	_spawn_blood_decal()
	_roll_loot()
	if not is_inside_tree():
		queue_free()
		return
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	if _sprite != null:
		tw.tween_property(_sprite, "scale", _sprite.scale * Vector2(1.12, 0.74), 0.4)
		tw.tween_property(_sprite, "rotation", randf_range(-0.5, 0.5), 0.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(queue_free)


## Кровавый декаль: в родителя, со случайным поворотом и масштабом, живёт ~30 с.
func _spawn_blood_decal() -> void:
	var parent: Node = get_parent()
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var d := Sprite2D.new()
	d.texture = Assets.decal_tex(Assets.decal_index("blood_a"))
	d.z_index = -1
	d.modulate = Color(1.0, 1.0, 1.0, 0.85)
	parent.add_child(d)
	d.add_to_group("decals")
	d.global_position = global_position + Vector2(0.0, -4.0)
	d.rotation = randf_range(0.0, TAU)
	d.scale = Vector2.ONE * randf_range(0.7, 1.25)
	var tree: SceneTree = get_tree()
	if tree != null:
		var decal: Sprite2D = d
		tree.create_timer(30.0).timeout.connect(func() -> void:
			if is_instance_valid(decal):
				decal.queue_free())


## Бросок лута по таблице типа. Если класс Loot ещё не в проекте — предмет
## уходит прямо в сумку, чтобы добыча не пропадала.
func _roll_loot() -> void:
	var parent: Node = get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var table: Variant = TYPES.get(enemy_type, {}).get("loot", {})
	if typeof(table) != TYPE_DICTIONARY:
		return
	var gd: GDScript = _loot_script()
	for key in (table as Dictionary).keys():
		var chance: float = float((table as Dictionary)[key]) * (3.0 if is_boss else 1.0)
		if randf() >= chance:
			continue
		var item_id: String = String(key)
		var count: int = 1
		if item_id.begins_with("ammo_"):
			count = randi_range(5, 16)
		elif item_id == "scrap":
			count = randi_range(1, 3)
		if gd != null and gd.has_method("spawn_drop"):
			gd.call("spawn_drop", parent, global_position, item_id, count)
		else:
			GameState.add_item(item_id, count, true)


func _loot_script() -> GDScript:
	if _loot_gd == null and ResourceLoader.exists(LOOT_PATH):
		_loot_gd = load(LOOT_PATH) as GDScript
	return _loot_gd


# ------------------------------------------------------------------ утилиты
static func _script() -> GDScript:
	return load(SCRIPT_PATH) as GDScript


## Таблица типа — для стат-таблиц/UI/тестов.
static func info(type_id: String) -> Dictionary:
	return TYPES.get(type_id, {})


## Стая слепых псов (3..5 особей) вокруг точки — для world.gd/game.gd.
static func spawn_pack(parent: Node, pos: Vector2, level: int = 1, count: int = 0) -> Array:
	var out: Array = []
	if parent == null or not is_instance_valid(parent):
		return out
	var n: int = count if count > 0 else randi_range(3, 5)
	for i in n:
		var e: Variant = _script().new()
		parent.add_child(e)
		e.setup("dog", level)
		var a: float = TAU * float(i) / float(n) + randf_range(-0.3, 0.3)
		e.global_position = pos + Vector2.RIGHT.rotated(a) * randf_range(45.0, 120.0)
		out.append(e)
	return out
