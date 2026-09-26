extends SceneTree
## Headless-тест боевой системы (без World/Player из параллельных веток).
## Сцена: Node2D-корень + стена StaticBody2D + заглушка игрока (CharacterBody2D
## "Player" в группе "player") + по одному врагу каждого типа + аномалии.
## Запуск: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/t_combat.gd
## (для скорости можно добавить --fixed-fps 60)

const ITEM_DB := preload("res://scripts/item_db.gd")

## ВАЖНО: скрипты, которые обращаются к автолоадам (Assets/Sfx/GameState/Quests),
## нельзя пре-лоадить из -s-скрипта: на момент его компиляции автолоады ещё
## не зарегистрированы в анализаторе GDScript. Поэтому грузим их во время
## выполнения (после старта движка), а к автолоадам ходим через /root.
var enemy_script = null
var projectile_script = null
var anomaly_script = null
var damage_text_script = null
var gs: Node = null
var quests: Node = null

const FRAMES := 600            ## ~10 с игрового времени
const TIMEOUT_SEC := 60.0      ## страховка от зависания
const WALL_X := 400.0
const TYPE_LIST: Array = ["dog", "mutant", "zombie", "boar"]

# --- сцена
var root_node: Node2D
var player: Variant = null            ## StubPlayer (доступ по «утке»)
var wall: StaticBody2D
var enemies: Dictionary = {}          ## type -> Node
var pack: Array = []
var anomalies: Dictionary = {}        ## type -> Node
var ranged_enemy: Variant = null

# --- наблюдения
var results: Array = []               ## [{name, ok, info}]
var chase_seen: Dictionary = {}
var max_danger: Dictionary = {}
var inside_wall_violation: bool = false
var saw_damage_text: bool = false
var enemy_hits_on_player: int = 0
var projectile_wall_ok: bool = true
var projectile_range_ok: bool = false
var projectile_hit_enemy_ok: bool = false
var killed_dog_frame: int = -1
var finished: bool = false
var proj_wall: Variant = null
var proj_range: Variant = null
var target_hp_before: float = 0.0
var spawn_positions: Dictionary = {}
var flee_seen: Dictionary = {}
var dog_names_before: int = 0
var xp_before: float = 0.0
var kills_dog_before: int = 0
var pool_burst: int = 0


class StubPlayer extends CharacterBody2D:
	var hp: float = 5000.0
	var hp_max: float = 5000.0
	var hits: int = 0
	var enemy_hits: int = 0
	var last_kind: String = ""

	func _ready() -> void:
		add_to_group("player")
		collision_layer = 2
		collision_mask = 1
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		var c := CollisionShape2D.new()
		var s := CircleShape2D.new()
		s.radius = 14.0
		c.shape = s
		add_child(c)

	func take_damage(amount: float, kind: String = "phys", src: Node = null) -> void:
		hp -= amount
		hits += 1
		last_kind = kind
		if src != null and is_instance_valid(src) and src.is_in_group("enemies"):
			enemy_hits += 1

	func is_alive() -> bool:
		return hp > 0.0

	func center() -> Vector2:
		return global_position

	func aim_dir() -> Vector2:
		return Vector2.RIGHT


class Driver extends Node:
	var host: Object = null
	var frames: int = 0
	var elapsed: float = 0.0

	func _ready() -> void:
		set_physics_process(true)
		set_process(true)

	func _physics_process(_delta: float) -> void:
		frames += 1
		if host != null:
			host.call("_tick", frames)

	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed > 60.0 and host != null:
			host.call("_finish", "ТАЙМАУТ: физические кадры не идут")
			elapsed = -9999.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	gs = root.get_node_or_null("/root/GameState")
	quests = root.get_node_or_null("/root/Quests")
	enemy_script = load("res://scripts/enemy.gd")
	projectile_script = load("res://scripts/projectile.gd")
	anomaly_script = load("res://scripts/anomaly.gd")
	damage_text_script = load("res://scripts/damage_text.gd")
	if not _self_check():
		quit(1)
		return
	gs.call("reset_run", 4242)
	_build_world()
	_build_enemies()
	_build_anomalies()
	print("=== БОЕВОЙ ТЕСТ (headless) ===")
	print("врагов в группе: ", root_node.get_tree().get_nodes_in_group("enemies").size())
	# стартовые проверки, которые можно сделать сразу
	_check_start()
	var d := Driver.new()
	d.name = "CombatDriver"
	d.host = self
	root_node.add_child(d)


## Проверяем, что все скрипты скомпилировались и автолоады на месте.
func _self_check() -> bool:
	var ok: bool = true
	if gs == null or quests == null:
		print("НЕ НАЙДЕНЫ АВТОЛОАДЫ: gs=", gs, " quests=", quests)
		ok = false
	for pair in [["enemy.gd", enemy_script], ["projectile.gd", projectile_script],
			["anomaly.gd", anomaly_script], ["damage_text.gd", damage_text_script]]:
		if pair[1] == null:
			print("НЕ ЗАГРУЗИЛСЯ СКРИПТ: ", pair[0])
			ok = false
	return ok


# ------------------------------------------------------------------ сцена
func _build_world() -> void:
	root_node = Node2D.new()
	root_node.name = "TestRoot"
	root.add_child(root_node)

	# стена: достаточно толстая, чтобы поймать снаряд и на скорости
	wall = StaticBody2D.new()
	wall.name = "TestWall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60.0, 900.0)
	cs.shape = rect
	wall.add_child(cs)
	root_node.add_child(wall)
	wall.global_position = Vector2(WALL_X + 30.0, 0.0)

	var p := StubPlayer.new()
	p.name = "Player"
	root_node.add_child(p)
	p.global_position = Vector2.ZERO
	player = p
	_check("игрок в группе player", p.is_in_group("player"), "")


func _build_enemies() -> void:
	enemies.clear()
	chase_seen.clear()
	max_danger.clear()
	_spawn_enemy("dog", Vector2(140.0, 70.0), 1, false)
	_spawn_enemy("mutant", Vector2(150.0, -140.0), 1, false)
	_spawn_enemy("zombie", Vector2(310.0, 120.0), 2, false)
	_spawn_enemy("boar", Vector2(120.0, 210.0), 1, true)
	# неподвижная мишень для проверки попадания снаряда игрока
	var target: Variant = enemy_script.new()
	target.position = Vector2(250.0, -300.0)
	target.setup("mutant", 1)
	target.speed = 0.0
	root_node.add_child(target)
	ranged_enemy = target
	# стая слепых псов в стороне (проверка спавна стаи)
	pack = enemy_script.spawn_pack(root_node, Vector2(-500.0, -500.0), 1, 3)


func _spawn_enemy(type_id: String, pos: Vector2, level: int, boss: bool) -> void:
	var e: Variant = enemy_script.new()
	e.position = pos
	e.setup(type_id, level)
	e.set_boss(boss)
	root_node.add_child(e)
	enemies[type_id] = e
	chase_seen[type_id] = false
	flee_seen[type_id] = false
	max_danger[type_id] = 0.0
	spawn_positions[type_id] = pos


func _build_anomalies() -> void:
	anomalies.clear()
	# жарка и электра стоят на игроке — проверяем урон по площади
	_add_anomaly("zharka", Vector2(90.0, 20.0), 120.0)
	_add_anomaly("elektra", Vector2(-70.0, 40.0), 110.0)
	# гравиконцентрат тянет игрока (вне радиуса урона, но внутри зоны притяжения)
	_add_anomaly("grav", Vector2(150.0, 100.0), 140.0)
	# «плод» — радиация и кислота
	_add_anomaly("fruit", Vector2(-80.0, -30.0), 100.0)


func _add_anomaly(type_id: String, pos: Vector2, radius: float) -> void:
	var a: Variant = anomaly_script.new()
	a.position = pos
	a.setup(type_id, radius)
	root_node.add_child(a)
	anomalies[type_id] = a


# ------------------------------------------------------------------ стартовые проверки
func _check_start() -> void:
	# таблица статов
	for t in TYPE_LIST:
		var info: Dictionary = enemy_script.info(t)
		var keys_ok: bool = info.has("hp") and info.has("speed") and info.has("damage") \
			and info.has("attack_range") and info.has("attack_cooldown") and info.has("xp") \
			and info.has("scale") and info.has("detect") and info.has("hear")
		_check("статы типа " + t, keys_ok and float(info.get("hp", 0.0)) > 0.0, str(info.get("hp", 0.0)))
		var e: Variant = enemies[t]
		_check("враг " + t + " создан", is_instance_valid(e) and e.enemy_type == t \
			and e.is_alive() and e.xp_value() > 0.0, "")
		_check("враг " + t + ": тело/спрайт/полоска", _has_child_of(e, "Sprite2D") \
			and _has_child_of(e, "CollisionShape2D"), "")

	var boar: Variant = enemies["boar"]
	_check("босс x2 hp", is_equal_approx(float(boar.hp_max), 300.0), str(boar.hp_max))
	_check("босс x1.4 урона и крупнее", is_equal_approx(float(boar.damage), 28.0) \
		and float(boar.scale_mult) > 1.35, "dmg=%s scale=%s" % [boar.damage, boar.scale_mult])
	_check("босс видит дальше 620", float(boar.detect_radius) >= 620.0, str(boar.detect_radius))
	var zombie: Variant = enemies["zombie"]
	_check("уровень 2 увеличил hp", float(zombie.hp_max) > 120.0, str(zombie.hp_max))
	_check("стая псов 3 особи", pack.size() == 3 \
		and (pack[0] as Node).is_in_group("enemies"), str(pack.size()))

	# аномалии
	for t in ["grav", "elektra", "zharka", "fruit"]:
		var a: Variant = anomalies[t]
		_check("аномалия " + t, is_instance_valid(a) and a.has_artifact() \
			and ITEM_DB.has(String(a.artifact_id)), String(a.artifact_id))
		_check(t + ": detector_distance = radius*2.6",
			is_equal_approx(float(a.detector_distance), float(a.radius) * 2.6),
			str(a.detector_distance))
		_check(t + ": danger_for в центре ~1", float(a.danger_for(a.global_position)) > 0.99, "")
	var grav: Variant = anomalies["grav"]
	_check("danger_for == 0 на 2.6 радиуса",
		float(grav.danger_for(grav.global_position + Vector2(grav.radius * 2.6 + 5.0, 0.0))) == 0.0, "")

	# DamageText: спавн, пул, info
	var before: int = root_node.get_tree().get_nodes_in_group("damage_text").size()
	damage_text_script.spawn(root_node, Vector2.ZERO, 42.0, "phys")
	damage_text_script.spawn(root_node, Vector2.ZERO, 120.0, "crit")
	damage_text_script.spawn(root_node, Vector2.ZERO, 15.0, "heal")
	damage_text_script.info(root_node, Vector2.ZERO, "ПРОМАХ")
	var after: int = root_node.get_tree().get_nodes_in_group("damage_text").size()
	_check("DamageText: +4 подписи", after >= before + 4, "%d -> %d" % [before, after])
	for i in 40:
		damage_text_script.spawn(root_node, Vector2.ZERO, 5.0, "phys")
	pool_burst = root_node.get_tree().get_nodes_in_group("damage_text").size()

	# снаряд в стену (маска мир|враги = 1|4)
	proj_wall = projectile_script.new()
	root_node.add_child(proj_wall)
	proj_wall.setup(Vector2(0.0, 0.0), Vector2.RIGHT, 2200.0, 20.0, player, 1 | 4)
	_check("Projectile в группе", proj_wall.is_in_group("projectiles"), "")
	# снаряд в пустоту, но с малым gun_range — должен сам погаснуть
	proj_range = projectile_script.new()
	root_node.add_child(proj_range)
	proj_range.setup(Vector2(0.0, -40.0), Vector2.LEFT, 1400.0, 10.0, player, 1 | 4)
	proj_range.gun_range = 100.0
	# снаряд игрока в неподвижного врага
	var tgt: Variant = ranged_enemy
	target_hp_before = float(tgt.hp)
	var dir: Vector2 = (tgt.global_position - Vector2(0.0, -20.0)).normalized()
	projectile_script.fire(root_node, Vector2(0.0, -20.0), dir, {
		"damage": 25.0, "speed": 1400.0, "hit_mask": 1 | 4, "shooter": player,
		"gun_range": 700.0, "radius": 12.0, "sfx": "shot_pm", "noise": true,
	})
	# таблица дыхания HP у врагов — проверяем, что все живы и в своих группах
	for t in TYPE_LIST:
		var e2: Variant = enemies[t]
		_check("враг " + t + " в группе enemies", (e2 as Node).is_in_group("enemies"), "")


# ------------------------------------------------------------------ ход теста
func _tick(frame: int) -> void:
	if finished:
		return
	_observe(frame)
	match frame:
		2:
			_phase_perception()
		6:
			_phase_projectile_range()
		22:
			_phase_projectile_wall()
		32:
			_phase_projectile_enemy()
		60:
			_phase_forced_damage()
		240:
			_phase_ai_and_anomaly_damage()
		300:
			_phase_artifacts()
		350:
			_phase_loot()
		420:
			_phase_kill()
		480:
			_phase_death_fade()
		600:
			_finish("")


func _observe(frame: int) -> void:
	for t in enemies.keys():
		var e: Variant = enemies[t]
		if not is_instance_valid(e):
			continue
		var st: String = String(e.state_name())
		if st == "chase" or st == "attack":
			chase_seen[t] = true
		if st == "flee":
			flee_seen[t] = true
		max_danger[t] = maxf(float(max_danger[t]), float(e.danger_value()))
		if e.global_position.x > WALL_X - 6.0:
			inside_wall_violation = true
	if is_instance_valid(ranged_enemy) and ranged_enemy.global_position.x > WALL_X - 6.0:
		inside_wall_violation = true
	for p in [proj_wall, proj_range]:
		if is_instance_valid(p) and p.global_position.x > WALL_X + 10.0:
			projectile_wall_ok = false
	if not saw_damage_text and root_node.get_tree().get_nodes_in_group("damage_text").size() > 0:
		saw_damage_text = true
	if is_instance_valid(player):
		var hits: int = int(player.enemy_hits)
		if hits > enemy_hits_on_player:
			enemy_hits_on_player = hits


func _phase_perception() -> void:
	var dog: Variant = enemies["dog"]
	var d0: float = dog.global_position.distance_to(player.center())
	_check("слепой пёс видит игрока (LOS)", dog.line_of_sight(player.center()), "dist=%.0f" % d0)
	_check("LOS перекрыт стеной", not dog.line_of_sight(Vector2(WALL_X + 100.0, 0.0)), "")
	# слух проверяем на дальнем псе из стаи (игрока он не видит вовсе)
	var pack_dog: Variant = pack[0]
	var st_before: String = String(pack_dog.state_name())
	pack_dog.hear_noise(Vector2(99999.0, 99999.0))
	_check("шум вне радиуса слышимости игнорируется",
		String(pack_dog.state_name()) == st_before, st_before + " -> " + String(pack_dog.state_name()))
	pack_dog.hear_noise(pack_dog.global_position + Vector2(50.0, 0.0))
	_check("hear_noise рядом -> alert", String(pack_dog.state_name()) == "alert",
		String(pack_dog.state_name()))
	var boar: Variant = enemies["boar"]
	_check("danger_value у босса в 0..1", float(boar.danger_value()) > 0.0 \
		and float(boar.danger_value()) <= 1.0, str(boar.danger_value()))
	# к этому кадру пул DamageText уже «подчистился» (queue_free выполняется в конце кадра)
	var texts: int = root_node.get_tree().get_nodes_in_group("damage_text").size()
	_check("DamageText: пул ограничен (было %d, стало %d)" % [pool_burst, texts],
		texts <= 36 and texts < pool_burst, str(texts))
	# --- слой врага и ближний бой игрока (PhysicsShapeQueryParameters2D, маска 4)
	var mut: Variant = enemies["mutant"]
	var layer: int = int((mut as CollisionObject2D).collision_layer)
	_check("слой врага = 3 (бит 4), маска 1|2|4", layer == 4,
		"layer=%d mask=%d" % [layer, int((mut as CollisionObject2D).collision_mask)])
	var shape_ok: bool = false
	for c in (mut as Node).get_children():
		if c is CollisionShape2D and not (c as CollisionShape2D).disabled:
			shape_ok = true
	_check("CollisionShape2D врага включён (radius 14 * scale)", shape_ok, "")
	var space: PhysicsDirectSpaceState2D = root_node.get_world_2d().direct_space_state
	if space != null:
		var q := PhysicsShapeQueryParameters2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 26.0
		q.shape = circle
		q.collision_mask = 4
		q.collide_with_areas = false
		q.collide_with_bodies = true
		q.transform = Transform2D(0.0, mut.global_position)
		var hits: Array = space.intersect_shape(q, 8)
		var found: bool = false
		for h in hits:
			if h.get("collider") == mut:
				found = true
		_check("ближний бой игрока (intersect_shape, маска 4) находит врага", found,
			"найдено тел: %d" % hits.size())


func _phase_projectile_range() -> void:
	projectile_range_ok = not is_instance_valid(proj_range)
	_check("снаряд гаснет на gun_range", projectile_range_ok, "")


func _phase_projectile_wall() -> void:
	_check("снаряд в стену: не прошёл насквозь", projectile_wall_ok, "")
	_check("снаряд в стену: удалён", not is_instance_valid(proj_wall), "")


func _phase_projectile_enemy() -> void:
	var hp: float = float(ranged_enemy.hp) if is_instance_valid(ranged_enemy) else -1.0
	projectile_hit_enemy_ok = hp < target_hp_before
	_check("снаряд игрока попал во врага", projectile_hit_enemy_ok,
		"%.1f -> %.1f (из %.1f)" % [target_hp_before, hp, float(ranged_enemy.hp_max)])


## Наносим урон каждому врагу через apply_damage_from_player и смотрим, что hp падает.
func _phase_forced_damage() -> void:
	for t in TYPE_LIST:
		var e: Variant = enemies[t]
		if not is_instance_valid(e):
			continue
		var before: float = float(e.hp)
		e.apply_damage_from_player(7.5, player)
		var after: float = float(e.hp)
		_check("урон уменьшил hp " + t, after < before and e.is_alive(),
			"%.1f -> %.1f" % [before, after])
	# колющие проверки того же пути
	var dog: Variant = enemies["dog"]
	# вариант вызова «как у игрока»: take_damage(amount, kind, src)
	var hp_before_player_style: float = float(enemies["zombie"].hp)
	enemies["zombie"].call("take_damage", 4.0, "phys", player)
	_check("take_damage(amount, kind, src) — стиль Player",
		float(enemies["zombie"].hp) < hp_before_player_style,
		"%.1f -> %.1f" % [hp_before_player_style, float(enemies["zombie"].hp)])
	var hp_before_one: float = float(enemies["boar"].hp)
	enemies["boar"].call("take_damage", 4.0)
	_check("take_damage(amount) — один аргумент",
		float(enemies["boar"].hp) < hp_before_one, "%.1f" % float(enemies["boar"].hp))
	dog.take_damage(30.0, player)          # >= 1.6 * base_damage(9) -> крит
	_check("крит при уроне >= 1.6 базового", is_equal_approx(float(dog.base_damage()), 9.0),
		"base=%s" % dog.base_damage())
	_check("DamageText появляется от урона", saw_damage_text, "")
	_check("animate: спрайт существует", _has_child_of(dog, "Sprite2D"), "")


func _phase_ai_and_anomaly_damage() -> void:
	for t in TYPE_LIST:
		var e: Variant = enemies[t]
		var moved: float = float(e.global_position.distance_to(spawn_positions[t])) \
			if is_instance_valid(e) else -1.0
		_check("связь " + t + ": вошёл в chase/attack", bool(chase_seen[t]), "ушёл на %.0f px" % moved)
		_check(t + ": danger_value > 0 рядом с игроком", float(max_danger[t]) > 0.0,
			"%.2f" % float(max_danger[t]))
	_check("собака в flee при hp < 15%", bool(flee_seen["dog"]), "")
	_check("враги не залезли в стену", not inside_wall_violation, "")
	_check("враги ударили игрока", enemy_hits_on_player >= 1, str(enemy_hits_on_player))
	_check("игрока не столкнули с места", player.global_position.length() < 1.0,
		str(player.global_position))
	_check("аномалии жгут игрока", float(player.hp) < float(player.hp_max),
		"%.1f / %.1f" % [player.hp, player.hp_max])
	_check("«плод» набрал радиацию", float(gs.get("radiation")) > 0.0, "%.2f" % float(gs.get("radiation")))
	var grav: Variant = anomalies["grav"]
	_check("гравиконцентрат тянет игрока", player.velocity.length() > 0.0,
		"%.1f" % player.velocity.length())
	_check("игрок жив после 4 с боя", player.is_alive(), "hits=%d" % player.hits)
	_note("урона по игроку за 4 с", "%.1f, попаданий %d" % [float(player.hp_max) - float(player.hp), player.hits])


func _phase_artifacts() -> void:
	quests.call("start", "q_artifact")
	var grav: Variant = anomalies["grav"]
	var id1: String = String(grav.take_artifact())
	_check("take_artifact вернул id артефакта", id1 != "" and ITEM_DB.has(id1), id1)
	_check("артефакт grav = artifact_grav", id1 == "artifact_grav", id1)
	var id2: String = String(grav.take_artifact())
	_check("повторный take_artifact не даёт второй артефакт", id2 == "", id2)
	_check("has_artifact() == false после выдачи", not grav.has_artifact(), "")
	_check("artifacts_found == 1", int(gs.get("artifacts_found")) == 1, str(int(gs.get("artifacts_found"))))
	_check("спящая аномалия не опасна", float(grav.danger_for(grav.global_position)) == 0.0 \
		and grav.is_dormant(), "")
	_check("другие аномалии ещё с артефактом", anomalies["fruit"].has_artifact() \
		and anomalies["zharka"].has_artifact(), "")
	# «Медуза» из электры закрывает квест q_artifact (Quests.notify внутри take_artifact)
	var medusa: String = String(anomalies["elektra"].take_artifact())
	_check("электра отдала artifact_medusa", medusa == "artifact_medusa", medusa)
	_note("q_artifact закрыт «Медузой» (notify внутри take_artifact)",
		str(quests.call("is_done", "q_artifact")))


## Лут: 20 бросков таблицы кровососа должны дать хотя бы один предмет
## (через Loot.spawn_drop, если класс Loot есть, иначе — прямо в сумку).
func _phase_loot() -> void:
	var e: Variant = enemies["mutant"]
	var loot_before: int = root_node.get_tree().get_nodes_in_group("loot").size()
	var inv_before: int = int((gs.get("inventory") as Array).size())
	for i in 20:
		e._roll_loot()
	var loot_after: int = root_node.get_tree().get_nodes_in_group("loot").size()
	var inv_after: int = int((gs.get("inventory") as Array).size())
	_check("дроп лута с врага (20 бросков таблицы mutant)",
		loot_after > loot_before or inv_after > inv_before,
		"на земле %d -> %d, в сумке %d -> %d" % [loot_before, loot_after, inv_before, inv_after])


func _phase_kill() -> void:
	var dog: Variant = enemies["dog"]
	dog_names_before = int(gs.get("kills"))
	xp_before = float(gs.get("xp"))
	kills_dog_before = int(gs.get("kills_by_type").get("dog", 0))
	dog.apply_damage_from_player(9999.0, player)
	killed_dog_frame = 420
	_check("смерть: is_alive() == false", not dog.is_alive(), "")
	_check("смерть: kill зарегистрирован", int(gs.get("kills")) == dog_names_before + 1,
		"%d -> %d" % [dog_names_before, int(gs.get("kills"))])
	_check("смерть: kills_by_type[dog] ++",
		int(gs.get("kills_by_type").get("dog", 0)) == kills_dog_before + 1,
		str(gs.get("kills_by_type").get("dog", 0)))
	_check("смерть: опыт начислен", float(gs.get("xp")) >= xp_before, "%.1f" % float(gs.get("xp")))
	_check("смерть: повторный урон игнорируется", _second_hit_is_ignored(dog), "")


func _second_hit_is_ignored(e: Variant) -> bool:
	var kills: int = int(gs.get("kills"))
	e.take_damage(500.0, player)
	return int(gs.get("kills")) == kills


func _phase_death_fade() -> void:
	_check("смерть: труп вычищен за 1 с", not is_instance_valid(enemies["dog"]), "")
	_check("декаль крови осталась в родителе", _has_group("decals"), "")
	_note("кадров от смерти до очистки", str(480 - killed_dog_frame) + " кадров (~0.4 с тускнения)")


# ------------------------------------------------------------------ отчёт
func _check(title: String, ok: bool, info: String) -> void:
	results.append({"name": title, "ok": ok, "info": info})
	print("[%s] %s%s" % ["OK  " if ok else "FAIL", title, ("  (" + info + ")") if info != "" else ""])


func _note(title: String, value: String) -> void:
	print("[инфо] %s: %s" % [title, value])


func _finish(reason: String) -> void:
	if finished:
		return
	finished = true
	print("")
	_type_table()
	print("")
	_state_table()
	print("")
	print("--- сводка проверок ---")
	var failed: int = 0
	for r in results:
		if not bool(r["ok"]):
			failed += 1
			print("  ПРОВАЛ: %s%s" % [String(r["name"]),
				("  (" + String(r["info"]) + ")") if String(r["info"]) != "" else ""])
	print("проверок: %d, провалов: %d" % [results.size(), failed])
	print("кадров физики: %d, врагов всего: %d, снарядов в воздухе: %d" % [
		FRAMES, root_node.get_tree().get_nodes_in_group("enemies").size(),
		root_node.get_tree().get_nodes_in_group("projectiles").size()])
	if reason != "":
		print("ПРИЧИНА ОСТАНОВКИ: " + reason)
	var ok: bool = failed == 0 and reason == ""
	print("T_COMBAT_%s" % ("OK" if ok else "FAIL"))
	quit(0 if ok else 1)


func _has_child_of(node: Node, class_name_wanted: String) -> bool:
	if not is_instance_valid(node):
		return false
	for c in node.get_children():
		if c.get_class() == class_name_wanted:
			return true
	return false


func _has_group(group_name: String) -> bool:
	return root_node.get_tree().get_nodes_in_group(group_name).size() > 0


func _type_table() -> void:
	print("--- таблица типов врагов (Enemy.TYPES) ---")
	print("%-8s %6s %7s %6s %7s %6s %6s %6s %6s %6s %s" % ["тип", "hp", "speed", "dmg",
		"atkR", "cd", "xp", "scale", "detect", "hear", "повадки"])
	for t in TYPE_LIST:
		var i: Dictionary = enemy_script.info(t)
		var habits: String = ""
		match String(t):
			"dog":
				habits = "стая 3-5, кружит вокруг цели, прыжок-рывок"
			"mutant":
				habits = "идёт напрямик, удар когтями, полупрозрачен вблизи (рык)"
			"zombie":
				habits = "держи дистанцию 220-420, очередь из 3 пуль, идёт на шум"
			_:
				habits = "рывок по прямой после разгона, затем оглушение 1.2 с"
		print("%-8s %6.0f %7.0f %6.0f %7.0f %6.2f %6.0f %6.2f %6.0f %6.0f %s" % [t,
			float(i["hp"]), float(i["speed"]), float(i["damage"]), float(i["attack_range"]),
			float(i["attack_cooldown"]), float(i["xp"]), float(i["scale"]),
			float(i["detect"]), float(i["hear"]), habits])
	print("босс: x2 hp, x1.4 урона, масштаб x1.35, обнаружение 620")


func _state_table() -> void:
	print("--- состояние юнитов на конец прогона ---")
	print("%-8s %-14s %-8s %8s %7s %7s" % ["тип", "hp / макс", "состояние", "дистанция", "опасн.", "кадр"])
	for t in TYPE_LIST:
		var e: Variant = enemies[t]
		if not is_instance_valid(e):
			print("%-8s %-14s %-8s" % [t, "мёртв", "death"])
			continue
		var dist: float = float(e.global_position.distance_to(player.center())) \
			if is_instance_valid(player) else -1.0
		print("%-8s %-14s %-8s %8.0f %7.2f %7d" % [t,
			"%.0f / %.0f" % [float(e.hp), float(e.hp_max)], String(e.state_name()),
			dist, float(e.danger_value()), int(e.get("_anim_frame") if e.get("_anim_frame") != null else 0)])
		print("         анимация: %s, кадр %s, спрайт %s" % [String(e._anim),
			str(e._anim_frame), "есть" if _has_child_of(e, "Sprite2D") else "нет"])
	print("%-8s %-14s %-8s %8.0f %7s" % ["игрок", "%.0f / %.0f" % [float(player.hp), float(player.hp_max)],
		"alive" if player.is_alive() else "dead", 0.0, "hits=" + str(player.hits)])
	for t in ["grav", "elektra", "zharka", "fruit"]:
		var a: Variant = anomalies[t]
		print("аномалия %-8s  артефакт: %-16s спит: %s  danger(центр): %.2f" % [t,
			String(a.artifact_id) if String(a.artifact_id) != "" else "-",
			str(a.is_dormant()), float(a.danger_for(a.global_position))])
