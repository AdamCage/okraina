class_name Player
extends CharacterBody2D
## Игрок-сталкер: движение (клавиатура/виртуальный стик), стрельба и ближний бой,
## рывок, фонарь, обыск контейнеров, подбор лута, радиация, здоровье и силы.

const WALK_SPEED := 168.0
const SPRINT_SPEED := 232.0
const DASH_SPEED := 560.0
const DASH_TIME := 0.20
const DASH_COST := 26.0
const STAMINA_REGEN := 17.0
const STAMINA_ATTACK := 4.0
const RADIUS := 15.0
const PICKUP_RADIUS := 74.0
const INTERACT_RADIUS := 96.0
const STEP_DISTANCE := 86.0
const CRIT_CHANCE := 0.12
const CRIT_MULT := 1.7

var game: Node = null
var touch: Node = null

var power: float = 1.0
var aim_dir: Vector2 = Vector2.RIGHT
var is_dashing: bool = false
var flashlight_on: bool = true
var _dash_time: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _cooldown: float = 0.0
var _mag: int = 0
var _reload_time: float = 0.0
var _anim_time: float = 0.0
var _anim_state: String = "idle"
var _hurt_time: float = 0.0
var _step_accum: float = 0.0
var _dead: bool = false
var _nearby_loot: Array = []
var _nearby_interact: Array = []
var _attack_time: float = 0.0

var _sprite: Sprite2D
var _shadow: Sprite2D
var _body_shape: CollisionShape2D
var _pickup_area: Area2D
var _interact_area: Area2D
var _light_pivot: Node2D
var _flashlight: PointLight2D
var _glow: PointLight2D
var _camera: Camera2D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4                      # мир + враги (сквозь своих не проходим иначе)
	_build_nodes()
	GameState.stats_changed.connect(_on_stats_changed)
	GameState.player_died.connect(_on_death)
	_on_stats_changed()


func _build_nodes() -> void:
	_shadow = Sprite2D.new()
	_shadow.texture = Assets.sprite("soft_shadow")
	_shadow.position = Vector2(0, 3)
	add_child(_shadow)

	_sprite = Sprite2D.new()
	_sprite.texture = Assets.sheet("stalker_idle", 0)
	_sprite.offset = Vector2(0, -Assets.SHEET_ANCHOR.y + Assets.SHEET_FRAME * 0.5)
	add_child(_sprite)

	_body_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	_body_shape.shape = circle
	_body_shape.position = Vector2(0, -6)
	add_child(_body_shape)

	_light_pivot = Node2D.new()
	add_child(_light_pivot)

	var glow_tex := _radial_texture()
	_glow = PointLight2D.new()
	_glow.texture = glow_tex
	_glow.color = Color(1.0, 0.90, 0.74)
	_glow.energy = 0.95
	_glow.texture_scale = 4.4
	add_child(_glow)

	_flashlight = PointLight2D.new()
	_flashlight.texture = Assets.sprite("light_cone")
	_flashlight.color = Color(1.0, 0.95, 0.82)
	_flashlight.energy = 1.5
	_flashlight.texture_scale = 1.25
	_flashlight.shadow_enabled = false
	_flashlight.visible = true
	_light_pivot.add_child(_flashlight)

	_pickup_area = Area2D.new()
	_pickup_area.collision_layer = 0
	_pickup_area.collision_mask = 16
	var pshape := CollisionShape2D.new()
	var pcircle := CircleShape2D.new()
	pcircle.radius = PICKUP_RADIUS
	pshape.shape = pcircle
	_pickup_area.add_child(pshape)
	_pickup_area.area_entered.connect(_on_pickup_entered)
	_pickup_area.area_exited.connect(_on_pickup_exited)
	add_child(_pickup_area)

	_interact_area = Area2D.new()
	_interact_area.collision_layer = 0
	_interact_area.collision_mask = 32
	var ishape := CollisionShape2D.new()
	var icircle := CircleShape2D.new()
	icircle.radius = INTERACT_RADIUS
	ishape.shape = icircle
	_interact_area.add_child(ishape)
	_interact_area.body_entered.connect(_on_interact_entered)
	_interact_area.body_exited.connect(_on_interact_exited)
	add_child(_interact_area)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 7.0
	_camera.zoom = Vector2(1.35, 1.35)
	_camera.limit_smoothed = true
	add_child(_camera)
	_camera.make_current()


func _radial_texture() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d: float = Vector2(x - 64, y - 64).length() / 64.0
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func camera() -> Camera2D:
	return _camera


func center() -> Vector2:
	return global_position + Vector2(0, -6)


func is_alive() -> bool:
	return not _dead and not GameState.is_dead


func aim_dir_now() -> Vector2:
	return aim_dir


## Уровень прокачки: 1.0 на первом уровне, +5% за уровень.
func refresh_power() -> void:
	power = 1.0 + 0.05 * float(GameState.level - 1)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_hurt_time = maxf(0.0, _hurt_time - delta)
	_attack_time = maxf(0.0, _attack_time - delta)
	_check_weapon_change()   # смена оружия должна сразу наполнять магазин
	if _dead or GameState.is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		move_and_slide()
		_set_anim("dead", delta)
		return
	_update_aim()
	var wish: Vector2 = _read_move()
	if not is_dashing and wish.length() > 0.05:
		aim_dir = wish.normalized() if _touch_mode() and _aim_input().length() < 0.05 else aim_dir
	_update_dash(delta, wish)
	if is_dashing:
		velocity = _dash_dir * DASH_SPEED
	else:
		var speed: float = (SPRINT_SPEED if _sprint_held() else WALK_SPEED) * GameState.speed_mult
		var target: Vector2 = wish * speed
		velocity = velocity.move_toward(target, (1800.0 if wish.length() > 0.05 else 2400.0) * delta)
	move_and_slide()
	_distance_walked(delta)
	_animate(delta, velocity.length())
	_footsteps(delta, velocity.length())
	_regen(delta)
	_geiger(delta)
	_handle_attack()
	if _flashlight != null:
		_flashlight.visible = flashlight_on and GameState.has_light
	_light_pivot.rotation = aim_dir.angle()


func _touch_mode() -> bool:
	return touch != null and (DisplayServer.is_touchscreen_available() or OS.has_feature("web"))


func _read_move() -> Vector2:
	var v := Vector2.ZERO
	if InputMap.has_action("move_left"):
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	else:
		var x: float = (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
		var y: float = (1.0 if Input.is_key_pressed(KEY_S) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) else 0.0)
		v = Vector2(x, y)
	var stick: Variant = touch.get("move_vector") if touch != null else null
	if stick is Vector2 and (stick as Vector2).length() > 0.08:
		v = stick
	if v.length() > 1.0:
		v = v.normalized()
	return v


func _aim_input() -> Vector2:
	if touch == null:
		return Vector2.ZERO
	var a: Variant = touch.get("aim_vector")
	if a is Vector2 and (a as Vector2).length() > 0.12:
		return (a as Vector2).normalized()
	return Vector2.ZERO


func _sprint_held() -> bool:
	if touch != null and bool(touch.get("sprint_held") if touch.get("sprint_held") != null else false):
		return GameState.stamina > 6.0
	if InputMap.has_action("sprint"):
		return Input.is_action_pressed("sprint") and GameState.stamina > 6.0
	return Input.is_key_pressed(KEY_SHIFT) and GameState.stamina > 6.0


func _update_aim() -> void:
	var stick: Vector2 = _aim_input()
	if stick != Vector2.ZERO:
		aim_dir = stick
		return
	if _touch_mode() or _touch_aim_fallback:
		var target := _nearest_enemy(520.0)
		if target != null:
			aim_dir = (target.center() - center()).normalized()
		return
	var mp: Vector2 = get_global_mouse_position()
	var d: Vector2 = mp - center()
	if d.length() > 12.0:
		aim_dir = d.normalized()


var _touch_aim_fallback: bool = false
var _invuln: float = 0.0


func _update_dash(delta: float, wish: Vector2) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	if is_dashing:
		_dash_time -= delta
		if _dash_time <= 0.0:
			is_dashing = false
			collision_mask = 1 | 4
		return
	var want_dash: bool = false
	if InputMap.has_action("dodge"):
		want_dash = Input.is_action_just_pressed("dodge")
	else:
		want_dash = Input.is_key_pressed(KEY_SPACE) and not _space_latch
		_space_latch = Input.is_key_pressed(KEY_SPACE)
	if touch != null and bool(touch.get("consume_dodge") if touch.get("consume_dodge") != null else false):
		want_dash = true
	if not want_dash:
		return
	if GameState.stamina < DASH_COST:
		Sfx.ui("ui_deny")
		return
	GameState.stamina = maxf(0.0, GameState.stamina - DASH_COST)
	is_dashing = true
	_dash_time = DASH_TIME
	_dash_dir = wish.normalized() if wish.length() > 0.05 else aim_dir
	_invuln = DASH_TIME + 0.08
	collision_mask = 1
	Sfx.play("melee_swing", Vector2.INF, -6.0, 1.4)
	GameState.stats_changed.emit()


var _space_latch: bool = false


# ------------------------------------------------------------------ анимация
func _set_anim(name: String, delta: float) -> void:
	_anim_time += delta
	var fps: float = 8.0
	if name == "walk" or name == "run":
		fps = 9.0
	elif name == "idle":
		fps = 4.0
	elif name == "attack":
		fps = 14.0
	elif name == "hurt":
		fps = 12.0
	var sheet: String = "stalker_" + ("walk" if name == "run" else name)
	var count: int = Assets.sheet_count(sheet)
	var frame: int = 0
	if name == "dead":
		frame = 0
	else:
		frame = int(_anim_time * fps) % maxi(1, count)
	_sprite.texture = Assets.sheet(sheet, frame)
	if name == "attack" or name == "dead":
		_sprite.flip_h = aim_dir.x < 0.0
	_sprite.modulate = Color(1.0, 1.0, 1.0)
	if _hurt_time > 0.0:
		_sprite.modulate = Color(1.0, 0.45, 0.42)


func _animate(delta: float, speed: float) -> void:
	var st: String = "idle"
	if _attack_time > 0.0:
		st = "attack"
	elif _hurt_time > 0.0:
		st = "hurt"
	elif speed > 18.0:
		st = "run" if speed > WALK_SPEED * 1.05 else "walk"
	_set_anim(st, delta)
	if st == "idle" or st == "walk" or st == "run":
		_sprite.flip_h = aim_dir.x < -0.15


# ------------------------------------------------------------------ мелочи
func _distance_walked(delta: float) -> void:
	GameState.distance_walked += velocity.length() * delta


func _footsteps(delta: float, speed: float) -> void:
	if speed < 24.0:
		_step_accum = 0.0
		return
	_step_accum += speed * delta
	if _step_accum >= STEP_DISTANCE:
		_step_accum = 0.0
		Sfx.step(_surface())


func _surface() -> String:
	if game == null:
		return "gravel"
	var w: Variant = game.get("world")
	if w != null and w.has_method("zone_at"):
		var z: String = String(w.call("zone_at", global_position))
		if z == "bunker" or z == "factory":
			return "metal"
		if z == "swamp" or z == "village":
			return "grass"
	return "gravel"


func _regen(delta: float) -> void:
	GameState.stamina = minf(GameState.stamina_max, GameState.stamina + (STAMINA_REGEN + GameState.stamina_regen) * delta)
	if GameState.regen > 0.0 and GameState.hp < GameState.hp_max:
		GameState.hp = minf(GameState.hp_max, GameState.hp + GameState.regen * delta)
		GameState.stats_changed.emit()


var _geiger_timer: float = 0.0


func _geiger(delta: float) -> void:
	if not GameState.has_geiger:
		return
	_geiger_timer -= delta
	if _geiger_timer > 0.0:
		return
	var level: float = clampf(GameState.radiation / maxf(1.0, GameState.rad_max), 0.0, 1.0)
	var near: float = _nearest_anomaly_danger()
	var d: float = maxf(level, near)
	_geiger_timer = lerpf(2.6, 0.10, d)
	if d > 0.04:
		Sfx.play("geiger_click", Vector2.INF, -10.0 + d * 4.0, randf_range(0.9, 1.15))


func _nearest_anomaly_danger() -> float:
	var best: float = 0.0
	for a in get_tree().get_nodes_in_group("anomalies"):
		if a.has_method("danger_for"):
			best = maxf(best, float(a.call("danger_for", global_position)))
	return best


func _nearest_enemy(max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not e.has_method("is_alive"):
			continue
		if not bool(e.call("is_alive")):
			continue
		var d: float = (e as Node2D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _on_stats_changed() -> void:
	refresh_power()
	if _flashlight != null:
		_flashlight.visible = flashlight_on and GameState.has_light


func _on_death() -> void:
	if _dead:
		return
	_dead = true
	_set_anim("dead", 0.0)
	Sfx.play("player_die", Vector2.INF)
	if game != null and game.has_method("on_player_died"):
		game.call("on_player_died")


# ------------------------------------------------------------------ оружие
func weapon_id() -> String:
	return String(GameState.equipment.get("weapon", ""))


func weapon_data() -> Dictionary:
	var id: String = weapon_id()
	if id == "" or not ItemDB.has(id):
		return {"name": "Кулаки", "mode": "melee", "dmg": 9.0, "rate": 1.8, "reach": 54.0,
			"sfx": "melee_swing"}
	return ItemDB.get_item(id)


func weapon_name() -> String:
	return String(weapon_data().get("name", "Кулаки"))


func mag_size() -> int:
	return int(weapon_data().get("mag", 0))


func mag_count() -> int:
	return _mag


func reserve_count() -> int:
	var cal: String = String(weapon_data().get("caliber", ""))
	if cal == "":
		return 0
	var id: String = _ammo_item_for(cal)
	return GameState.count_item(id) if id != "" else 0


func _ammo_item_for(caliber: String) -> String:
	for id in ItemDB.all_ids():
		var d: Dictionary = ItemDB.ITEMS[id]
		if int(d.get("kind", -1)) == ItemDB.Kind.AMMO and String(d.get("caliber", "")) == caliber:
			return String(id)
	return ""


func _check_weapon_change() -> void:
	var id: String = weapon_id()
	if id == _last_weapon:
		return
	_last_weapon = id
	_mag = 0
	if String(weapon_data().get("mode", "melee")) == "gun" and reserve_count() > 0:
		_mag = mini(mag_size(), GameState.count_item(_ammo_item_for(String(weapon_data().get("caliber", "")))))
		GameState.remove_item(_ammo_item_for(String(weapon_data().get("caliber", ""))), _mag)


var _last_weapon: String = ""


func handle_attack_input(held: bool, pressed: bool) -> void:
	if _dead or GameState.is_dead:
		return
	var d: Dictionary = weapon_data()
	var auto: bool = bool(d.get("auto", false))
	if auto and held:
		try_attack()
	elif pressed:
		try_attack()


## Атака текущим оружием (ближний бой или выстрел).
func try_attack() -> void:
	if _dead or GameState.is_dead or _cooldown > 0.0:
		return
	_check_weapon_change()
	var d: Dictionary = weapon_data()
	if String(d.get("mode", "melee")) == "melee":
		_melee_attack(d)
	else:
		_shoot(d)


func _melee_attack(d: Dictionary) -> void:
	_cooldown = 1.0 / maxf(0.2, float(d.get("rate", 2.0)))
	_attack_time = 0.26
	GameState.stamina = maxf(0.0, GameState.stamina - STAMINA_ATTACK)
	Sfx.play(String(d.get("sfx", "melee_swing")), Vector2.INF, -4.0)
	var reach: float = float(d.get("reach", 56.0))
	var params := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = reach * 0.5
	params.shape = shape
	params.transform = Transform2D(0.0, center() + aim_dir * reach * 0.55)
	params.collision_mask = 4
	params.collide_with_areas = false
	var hits: Array = get_world_2d().direct_space_state.intersect_shape(params, 12)
	var any: bool = false
	for h in hits:
		var c: Object = h.get("collider")
		if c != null and c.has_method("take_damage"):
			_deal_damage(c, d)
			any = true
	if any:
		Sfx.play("melee_hit", center())
	_alert_enemies(420.0)
	GameState.stats_changed.emit()


func _shoot(d: Dictionary) -> void:
	var caliber: String = String(d.get("caliber", ""))
	var ammo_id: String = _ammo_item_for(caliber)
	if _mag <= 0:
		start_reload(true)
		return
	_cooldown = 1.0 / maxf(0.3, float(d.get("rate", 3.0)))
	_attack_time = 0.18
	if ammo_id != "":
		_mag -= 1
	var pellets: int = maxi(1, int(d.get("pellets", 1)))
	var spread: float = float(d.get("spread", 0.05))
	var speed: float = float(d.get("speed", 1400.0))
	var range_px: float = float(d.get("gun_range", 600.0))
	Sfx.play(String(d.get("sfx", "shot_pm")), Vector2.INF, -2.0)
	_spawn_fx("muzzle_flash", center() + aim_dir * 22.0, range_px)
	for i in pellets:
		var ang: float = aim_dir.angle() + randf_range(-spread, spread)
		var dir := Vector2.RIGHT.rotated(ang)
		var p := Projectile.new()
		get_parent().add_child(p)
		p.setup(center() + dir * 20.0, dir, speed, float(d.get("dmg", 10.0)) * power * randf_range(0.92, 1.08),
			self, 1 | 4)
	_alert_enemies(range_px)
	GameState.stats_changed.emit()


## Предупреждаем врагов о выстреле (они умеют реагировать на шум).
func _alert_enemies(radius: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and e.has_method("hear_noise"):
			if (e as Node2D).global_position.distance_to(global_position) <= radius * 1.6:
				e.call("hear_noise", global_position)


func _deal_damage(target: Object, d: Dictionary) -> void:
	var dmg: float = float(d.get("dmg", 10.0)) * power * randf_range(0.9, 1.1)
	var crit: bool = randf() < CRIT_CHANCE
	if crit:
		dmg *= CRIT_MULT
	DamageText.spawn(get_parent(), (target as Node2D).global_position + Vector2(0, -28),
		dmg, "crit" if crit else "phys")
	if target.has_method("take_damage"):
		target.call("take_damage", dmg, self)


func start_reload(forced: bool = false) -> void:
	var d: Dictionary = weapon_data()
	if String(d.get("mode", "melee")) != "gun":
		return
	var cal: String = String(d.get("caliber", ""))
	var ammo_id: String = _ammo_item_for(cal)
	if ammo_id == "" or _mag >= mag_size():
		if forced:
			Sfx.ui("ui_deny")
			GameState.log_message.emit("Нет патронов: " + cal, "bad")
		return
	if _reload_time > 0.0:
		return
	_reload_time = 1.5
	set_process(true)


func _finish_reload() -> void:
	var d: Dictionary = weapon_data()
	var ammo_id: String = _ammo_item_for(String(d.get("caliber", "")))
	var need: int = mag_size() - _mag
	var have: int = GameState.count_item(ammo_id)
	var take: int = mini(need, have)
	if take > 0:
		GameState.remove_item(ammo_id, take)
		_mag += take
		Sfx.ui("ui_click", 0.8)
	GameState.stats_changed.emit()


func _process(delta: float) -> void:
	if _reload_time > 0.0:
		_reload_time -= delta
		if _reload_time <= 0.0:
			_reload_time = 0.0
			_finish_reload()
			set_process(false)


# ------------------------------------------------------------------ ввод
func _handle_attack() -> void:
	var held: bool = false
	var pressed: bool = false
	if InputMap.has_action("attack"):
		held = Input.is_action_pressed("attack")
		pressed = Input.is_action_just_pressed("attack")
	else:
		held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		pressed = held and not _mouse_latch
		_mouse_latch = held
	if touch != null:
		var th: Variant = touch.get("attack_held")
		var is_held: bool = th is bool and bool(th)
		if is_held:
			held = true
			if not _touch_attack_latch:
				pressed = true
		_touch_attack_latch = is_held
	handle_attack_input(held, pressed)


var _mouse_latch: bool = false
var _touch_attack_latch: bool = false


func bind_touch(t: Node) -> void:
	touch = t
	if touch == null:
		_touch_aim_fallback = false     # слой касаний выключен — прицел снова по мыши
		return
	if touch.has_signal("action_pressed") and not touch.is_connected("action_pressed", _on_touch_action):
		touch.connect("action_pressed", _on_touch_action)
	_touch_aim_fallback = true


func _on_touch_action(action: String) -> void:
	match action:
		"use":
			do_interact()
		"heal":
			use_best_med()
		"swap":
			swap_weapon()
		"light":
			toggle_flashlight()
		_:
			pass


func _unhandled_input(event: InputEvent) -> void:
	if _dead or GameState.is_dead:
		return
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var key := event as InputEventKey
	if key.echo:
		return
	match key.keycode:
		KEY_F:
			do_interact()
		KEY_R:
			start_reload(true)
		KEY_L:
			toggle_flashlight()
		KEY_Q:
			swap_weapon()
		KEY_H:
			use_best_med()
		_:
			return
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ действия
func do_interact() -> void:
	if _dead or GameState.is_dead:
		return
	var itr: Node = _nearest_interactable()
	var loot: Node = _nearest_loot()
	if itr != null:
		var d: float = (itr as Node2D).global_position.distance_to(global_position)
		if loot == null or d <= 118.0:
			if itr.has_method("interact"):
				itr.call("interact", self)
			elif itr.has_method("open"):
				itr.call("open", self)
			return
	if loot != null:
		loot.call("pick_up", self)


## Подсказка для HUD: что произойдёт по F.
func interact_hint() -> String:
	var itr: Node = _nearest_interactable()
	if itr != null:
		if itr.has_method("interact_hint"):
			return "%s (F)" % String(itr.call("interact_hint"))
		if itr.has_method("open"):
			return "%s (F)" % ("Пусто" if bool(itr.get("opened")) else "Обыскать")
	var loot: Node = _nearest_loot()
	if loot != null:
		return "%s x%d (F)" % [ItemDB.display_name(String(loot.get("item_id"))),
			int(loot.get("item_count"))]
	if _mag <= 0 and String(weapon_data().get("mode", "melee")) == "gun" and reserve_count() > 0:
		return "Перезарядить (R)"
	return ""


func use_best_med() -> void:
	if GameState.is_dead:
		return
	var order := ["medkit", "bandage", "vodka", "canned", "bread", "energy_drink", "antidote"]
	for id in order:
		if GameState.count_item(id) > 0 and GameState.use_item(id):
			Sfx.ui("ui_click")
			return
	Sfx.ui("ui_deny")
	GameState.log_message.emit("Нет аптечек", "bad")


func swap_weapon() -> void:
	var weapons: Array = []
	for slot in GameState.inventory:
		var id: String = String(slot["id"])
		if ItemDB.kind_of(id) == ItemDB.Kind.WEAPON and not weapons.has(id):
			weapons.append(id)
	if weapons.is_empty():
		Sfx.ui("ui_deny")
		GameState.log_message.emit("Второго оружия нет", "bad")
		return
	var cur: String = weapon_id()
	var idx: int = weapons.find(cur)
	var next: String = String(weapons[(idx + 1) % weapons.size()])
	if GameState.equip(next):
		Sfx.ui("ui_click")
		GameState.log_message.emit("В руках: " + weapon_name(), "info")


func toggle_flashlight() -> void:
	if not GameState.has_light:
		Sfx.ui("ui_deny")
		GameState.log_message.emit("Нет фонаря", "bad")
		return
	flashlight_on = not flashlight_on
	Sfx.ui("ui_click", 1.2 if flashlight_on else 0.9)


func _nearest_loot() -> Node:
	var best: Node = null
	var best_d: float = PICKUP_RADIUS + 40.0
	for l in _nearby_loot:
		if not is_instance_valid(l):
			continue
		var d: float = (l as Node2D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = l
	return best


func _nearest_interactable() -> Node:
	var best: Node = null
	var best_d: float = INTERACT_RADIUS + 40.0
	for b in _nearby_interact:
		if not is_instance_valid(b):
			continue
		if b is Node2D:
			var d: float = (b as Node2D).global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = b
	return best


func _on_pickup_entered(a: Node) -> void:
	if not _nearby_loot.has(a):
		_nearby_loot.append(a)
	# мелочь подбирается сама — на телефоне это экономит десятки тапов
	var id: String = String(a.get("item_id") if a.get("item_id") != null else "")
	if id != "":
		var k: int = ItemDB.kind_of(id)
		if k == ItemDB.Kind.AMMO or k == ItemDB.Kind.MED or k == ItemDB.Kind.FOOD:
			a.call("pick_up", self)


func _on_pickup_exited(a: Node) -> void:
	_nearby_loot.erase(a)


func _on_interact_entered(b: Node) -> void:
	if not _nearby_interact.has(b):
		_nearby_interact.append(b)


func _on_interact_exited(b: Node) -> void:
	_nearby_interact.erase(b)


# ------------------------------------------------------------------ урон
func take_damage(amount: float, kind: String = "phys", src: Node = null) -> void:
	if not is_alive():
		return
	if _invuln > 0.0 and kind == "phys":
		return
	GameState.apply_damage(amount, kind)
	_hurt_time = 0.24
	Sfx.play("player_hurt", Vector2.INF, -3.0)
	DamageText.spawn(get_parent(), center() + Vector2(0, -34), amount, "phys")
	if game != null and game.has_method("shake"):
		game.call("shake", 0.45)


## Короткий эффект из листа анимации (дульная вспышка и т.п.).
func _spawn_fx(sheet_name: String, pos: Vector2, _range: float = 0.0) -> void:
	if not Assets.has_sprite(sheet_name):
		return
	var count: int = maxi(1, Assets.sheet_count(sheet_name))
	var frames := SpriteFrames.new()
	frames.add_animation("fx")
	frames.set_animation_speed("fx", 16.0)
	frames.set_animation_loop("fx", false)
	for i in count:
		frames.add_frame("fx", Assets.sheet(sheet_name, i))
	var asp := AnimatedSprite2D.new()
	asp.sprite_frames = frames
	asp.global_position = pos
	asp.rotation = aim_dir.angle()
	asp.z_index = 6
	get_parent().add_child(asp)
	asp.play("fx")
	var tw := asp.create_tween()
	tw.tween_interval(float(count) / 16.0 + 0.06)
	tw.tween_callback(asp.queue_free)






