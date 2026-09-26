class_name Projectile
extends Area2D
## Пуля/болт/картечь. Одна реализация на всех: и игрок, и враги стреляют
## через статическую фабрику fire(parent, start, dir, cfg).
## Хит-слой выбирается через cfg["hit_mask"]: патрон игрока — 1|4 (мир+враги),
## пуля зомби — 1|2 (мир+игрок). Снаряд никого не толкает и не блокирует.
## Попадание считается рейкастом (нет «протыкания» тонких стен на скорости).

const SCRIPT_PATH := "res://scripts/projectile.gd"

const HITBOX_LAYER := 8          ## слой 4 «hitbox» = 1 << 3
const DEFAULT_SPEED := 1400.0
const DEFAULT_RANGE := 600.0
const DEFAULT_LIFE := 2.0        ## снаряд живёт не дольше 2 с
const TRAIL_POINTS := 8
const PHANTOM_DIST := 56.0       ## защита от «фантомных» overlap-пар движка

var speed: float = DEFAULT_SPEED
var damage: float = 10.0
var shooter: Node = null
var hit_mask: int = 1
var dir: Vector2 = Vector2.RIGHT
var gun_range: float = DEFAULT_RANGE
var life_max: float = DEFAULT_LIFE
var hurt_kind: String = "phys"   ## kind для Player.take_damage
var color: Color = Color(1.0, 0.86, 0.45)
var tracer_len: float = 16.0
var tracer_width: float = 3.0
var sprite_name: String = ""
var blood_on_hit: bool = true
var pierce: int = 0              ## сколько тел пробивает (0 — умирает на первом)

var life: float = 0.0
var traveled: float = 0.0
var dead: bool = false

var _trail: Line2D
var _tracer: Polygon2D
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _built: bool = false


func _ready() -> void:
	_ensure_children()
	add_to_group("projectiles")
	# monitoring/monitorable у новой Area2D уже true; менять их здесь нельзя —
	# снаряды рождаются прямо в _physics_process и движок блокирует эти сеттеры
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	set_physics_process(true)


# ------------------------------------------------------------------ контракт
## setup(start, dir, speed, damage, shooter, hit_mask) — базовый набор параметров.
func setup(start: Vector2, dir_vec: Vector2, speed_value: float, damage_value: float,
		shooter_node: Node, mask: int) -> void:
	_ensure_children()
	position = start
	dir = dir_vec.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	speed = maxf(1.0, speed_value)
	damage = damage_value
	shooter = shooter_node
	hit_mask = mask
	collision_mask = mask
	rotation = dir.angle()


## Дополнительные параметры (дальность, спрайт, цвет, пробитие) — до или после setup().
func configure(cfg: Dictionary) -> void:
	_ensure_children()
	if cfg.has("speed"):
		speed = maxf(1.0, float(cfg["speed"]))
	if cfg.has("damage"):
		damage = float(cfg["damage"])
	if cfg.has("hit_mask"):
		hit_mask = int(cfg["hit_mask"])
		collision_mask = hit_mask
	if cfg.has("gun_range"):
		gun_range = float(cfg["gun_range"])
	if cfg.has("life"):
		life_max = float(cfg["life"])
	if cfg.has("kind"):
		hurt_kind = String(cfg["kind"])
	if cfg.has("color"):
		color = cfg["color"]
	if cfg.has("size"):
		tracer_len = 16.0 * float(cfg["size"])
		tracer_width = 3.0 * clampf(float(cfg["size"]), 0.5, 2.0)
	if cfg.has("sprite"):
		sprite_name = String(cfg["sprite"])
	if cfg.has("blood"):
		blood_on_hit = bool(cfg["blood"])
	if cfg.has("pierce"):
		pierce = int(cfg["pierce"])
	if cfg.has("radius") and _shape != null:
		var c := _shape.shape as CircleShape2D
		if c != null:
			c.radius = float(cfg["radius"])
	_apply_look()


## Статическая фабрика: одна или несколько пуль (картечь) одним выстрелом.
## cfg: speed, damage, hit_mask, sfx, sprite, gun_range, pellets, spread,
##      size, color, kind, shooter, radius, muzzle, noise, pierce.
static func fire(parent: Node, start: Vector2, dir_vec: Vector2, cfg: Dictionary) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var base_dir: Vector2 = dir_vec.normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	var pellets: int = maxi(1, int(cfg.get("pellets", 1)))
	var spread: float = maxf(0.0, float(cfg.get("spread", 0.0)))
	for i in pellets:
		var d: Vector2 = base_dir
		if spread > 0.0 and pellets > 1:
			var t: float = float(i) / float(pellets - 1) - 0.5
			d = base_dir.rotated(spread * t + randf_range(-spread * 0.1, spread * 0.1))
		elif spread > 0.0:
			d = base_dir.rotated(randf_range(-spread * 0.5, spread * 0.5))
		_spawn_one(parent, start, d, cfg)
	# звук выстрела — один на весь залп
	if cfg.has("sfx"):
		Sfx.play(String(cfg["sfx"]), start, float(cfg.get("sfx_db", -3.0)))
	if bool(cfg.get("muzzle", true)):
		spawn_fx(parent, "muzzle_flash", start + base_dir * 12.0, float(cfg.get("size", 1.0)), 0.06,
			base_dir.angle())
	# выстрел слышит вся округа (враги сами проверяют радиус слышимости)
	if bool(cfg.get("noise", true)):
		alert_enemies(parent, start)


static func _spawn_one(parent: Node, start: Vector2, d: Vector2, cfg: Dictionary) -> void:
	var p: Variant = _script().new()
	parent.add_child(p)
	p.configure(cfg)
	p.setup(start, d, float(cfg.get("speed", DEFAULT_SPEED)), float(cfg.get("damage", 10.0)),
		cfg.get("shooter", null), int(cfg.get("hit_mask", 1)))


static func _script() -> GDScript:
	return load(SCRIPT_PATH) as GDScript


## Оповестить врагов о шуме выстрела (радиус проверяет сам враг).
static func alert_enemies(parent: Node, pos: Vector2) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	for e in parent.get_tree().get_nodes_in_group("enemies"):
		if e.has_method("hear_noise"):
			e.call("hear_noise", pos)


## Сколько аргументов у метода: Player.take_damage(a, kind, src) и
## Enemy.take_damage(a, from) имеют разные подписи.
static func method_argc(obj: Object, method: String) -> int:
	if obj == null:
		return 0
	for m in obj.get_method_list():
		if String(m.get("name", "")) == method:
			var args: Variant = m.get("args", [])
			if typeof(args) == TYPE_ARRAY:
				return (args as Array).size()
			return 0
	return 0


# ------------------------------------------------------------------ полёт
func _physics_process(delta: float) -> void:
	if dead:
		return
	life += delta
	if life >= life_max:
		_expire()
		return
	if not is_inside_tree():
		return
	var from: Vector2 = global_position
	var to: Vector2 = from + dir * speed * delta
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		position = to
		return
	var q := PhysicsRayQueryParameters2D.create(from, to, collision_mask)
	q.exclude = _exclude()
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.hit_from_inside = true
	var res: Dictionary = space.intersect_ray(q)
	if not res.is_empty():
		global_position = res.get("position", to)
		_impact(res.get("collider"), res.get("normal", Vector2.ZERO))
		return
	global_position = to
	traveled += from.distance_to(to)
	_update_trail()
	if traveled >= gun_range:
		_expire()


func _exclude() -> Array:
	var out: Array = []
	if is_instance_valid(self):
		out.append(get_rid())
	if shooter != null and is_instance_valid(shooter) and shooter is CollisionObject2D:
		out.append((shooter as CollisionObject2D).get_rid())
	return out


func _update_trail() -> void:
	if _trail == null:
		return
	_trail.add_point(global_position)
	while _trail.get_point_count() > TRAIL_POINTS:
		_trail.remove_point(0)


# ------------------------------------------------------------------ попадания
func _on_body_entered(body: Node2D) -> void:
	if dead or body == shooter:
		return
	if not _plausible_hit(body):
		return
	_impact(body, Vector2.ZERO)


func _on_area_entered(area: Area2D) -> void:
	if dead or area == self or area == shooter:
		return
	if not area.has_method("take_damage"):
		return
	if not _plausible_hit(area):
		return
	_impact(area, Vector2.ZERO)


## Страховка от «фантомных» пар: движок может один раз выдать body_entered для
## тела из другого конца карты, если Area2D родилась до первого шага физики.
## Настоящее попадание всегда рядом (снаряд летит не быстрее ~40 px за шаг).
func _plausible_hit(obj: Node) -> bool:
	if obj == null or not is_instance_valid(obj):
		return false
	if obj is Node2D:
		return (obj as Node2D).global_position.distance_to(global_position) <= PHANTOM_DIST
	return true


func _impact(collider: Variant, normal: Vector2) -> void:
	if dead:
		return
	if collider == null or collider == self or collider == shooter:
		return
	var pos: Vector2 = global_position
	var flesh: bool = collider.has_method("take_damage")
	if flesh:
		_apply_dmg(collider, pos)
		Sfx.play("hit_flesh", pos, -5.0)
		if blood_on_hit:
			spawn_fx(_fx_parent(), "blood_splat", pos, 0.8, 0.16, normal.angle())
	else:
		Sfx.play("hit_wall", pos, -6.0)
		spawn_fx(_fx_parent(), "spark", pos, 0.7, 0.14, normal.angle())
		spawn_fx(_fx_parent(), "smoke_puff", pos, 0.7, 0.3, 0.0)
	if flesh and pierce > 0:
		# пробитие: летим дальше, но слабее
		pierce -= 1
		damage *= 0.7
		return
	_expire()


func _apply_dmg(target: Object, _pos: Vector2) -> void:
	var argc: int = method_argc(target, "take_damage")
	if argc >= 3:
		target.call("take_damage", damage, hurt_kind, shooter)
	elif argc == 2:
		target.call("take_damage", damage, shooter)
	else:
		target.call("take_damage", damage)


func _expire() -> void:
	if dead:
		return
	dead = true
	if _trail != null:
		_trail.visible = false
	queue_free()




# ------------------------------------------------------------------ вид
func _ensure_children() -> void:
	if _built:
		return
	_built = true
	collision_layer = HITBOX_LAYER
	collision_mask = hit_mask

	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	_shape.shape = circle
	add_child(_shape)

	_tracer = Polygon2D.new()
	_tracer.color = color
	_tracer.z_index = 55
	add_child(_tracer)

	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = tracer_width
	_trail.default_color = Color(color.r, color.g, color.b, 0.5)
	_trail.gradient = _make_gradient(color)
	_trail.z_index = 50
	add_child(_trail)
	_apply_look()


func _make_gradient(col: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.set_color(1, Color(col.r, col.g, col.b, 0.85))
	return g


func _apply_look() -> void:
	if _tracer != null:
		var h: float = tracer_width * 0.5
		_tracer.polygon = PackedVector2Array([
			Vector2(-tracer_len * 0.5, -h), Vector2(tracer_len * 0.5, -h),
			Vector2(tracer_len * 0.5, h), Vector2(-tracer_len * 0.5, h),
		])
		_tracer.color = color
	if _trail != null:
		_trail.width = tracer_width
		_trail.default_color = Color(color.r, color.g, color.b, 0.5)
	# спрайт-снаряд создаём лениво: cfg.sprite может прийти уже после _ready
	if sprite_name != "" and _sprite == null and _built and Assets.has_sprite(sprite_name):
		_sprite = Sprite2D.new()
		_sprite.texture = Assets.sprite(sprite_name)
		_sprite.z_index = 56
		add_child(_sprite)
	if _sprite != null:
		_sprite.modulate = color


## Короткий спрайтовый эффект (кадры листа + затухание), сам себя удаляет.
static func spawn_fx(parent: Node, sheet_name: String, pos: Vector2, scale_v: float = 1.0,
		life: float = 0.16, rot: float = 0.0) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var frames: int = maxi(1, Assets.sheet_count(sheet_name))
	var s := Sprite2D.new()
	s.texture = Assets.sheet(sheet_name, 0)
	s.z_index = 60
	s.rotation = rot
	s.scale = Vector2.ONE * maxf(0.05, scale_v)
	parent.add_child(s)
	s.global_position = pos
	var tw: Tween = s.create_tween()
	tw.set_parallel(true)
	for i in range(1, frames):
		tw.tween_callback(_set_frame.bind(s, sheet_name, i)).set_delay(life * float(i) / float(frames))
	tw.tween_property(s, "modulate:a", 0.0, life * 0.6).set_delay(life * 0.4)
	tw.tween_property(s, "scale", Vector2.ONE * maxf(0.05, scale_v) * 1.4, life)
	tw.chain().tween_callback(s.queue_free)


static func _set_frame(sprite: Sprite2D, sheet_name: String, frame: int) -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.texture = Assets.sheet(sheet_name, frame)

func _fx_parent() -> Node:
	var p: Node = get_parent()
	return p if p != null else self

