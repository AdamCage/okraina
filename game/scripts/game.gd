extends Node2D
## Корневая сцена игры: качество рендера, сборка мира, игрок, враги, аномалии,
## освещение, UI (HUD/сумка/журнал/меню/касания), сохранения и пауза.

const ZONE_NAMES := {
	"kordon": "Кордон", "village": "Деревня", "factory": "Завод",
	"swamp": "Болото", "bunker": "Бункер", "field": "Аномальное поле",
}

var world: Node2D = null
var world_data: Dictionary = {}
var player: Player = null
var hud: Node = null
var inventory_ui: Node = null
var journal_ui: Node = null
var menu_ui: Node = null
var touch_ui: Node = null
var dialog: DialogUI = null
var fx_root: Node2D = null

var quality: String = "medium"
var glow_enabled: bool = true
var shake_amount: float = 0.0
var current_zone: String = ""
var run_active: bool = false

var _canvas_mod: CanvasModulate
var _env: WorldEnvironment
var _zone_timer: float = 0.0
var _activate_timer: float = 0.0
var _light_target: Color = Color(0.80, 0.82, 0.86)


func _ready() -> void:
	_setup_input()
	_apply_render_defaults()
	quality = _detect_quality()
	_build_environment()
	_build_ui()
	apply_quality(quality)
	if menu_ui != null and menu_ui.has_method("show_screen"):
		menu_ui.call("show_screen", "main")
	else:
		# если меню недоступно — сразу начинаем забег, чтобы игра была играбельна
		push_warning("Game: меню не найдено, стартую новый забег автоматически")
		new_game()
	Sfx.music("mus_menu_loop")
	set_process(true)


# ------------------------------------------------------------------ настройка
func _setup_input() -> void:
	var binds := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"attack": [KEY_CTRL], "interact": [KEY_F], "dodge": [KEY_SPACE],
		"sprint": [KEY_SHIFT], "reload": [KEY_R], "flashlight": [KEY_L],
		"use_heal": [KEY_H], "swap_weapon": [KEY_Q], "inventory": [KEY_I, KEY_E],
		"journal": [KEY_J], "pause": [KEY_ESCAPE], "map": [KEY_M],
	}
	for action in binds.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.22)
		for code in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
	if InputMap.has_action("attack"):
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mb)


## Разные рендер-профили для десктопа, телефона и браузера.
func _apply_render_defaults() -> void:
	var is_web: bool = OS.has_feature("web")
	Engine.max_fps = 60 if is_web else 0
	if is_web:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.set_default_clear_color(Color(0.03, 0.035, 0.04))


func _detect_quality() -> String:
	if not OS.has_feature("web") and not DisplayServer.is_touchscreen_available():
		return "high"
	var screen: Vector2i = DisplayServer.screen_get_size()
	var dpi: float = DisplayServer.screen_get_dpi()
	if screen.x * screen.y <= 1280 * 720 or dpi > 320.0:
		return "low"
	return "medium"


## Профили качества: зум камеры, свечение, сглаживание.
func apply_quality(name: String) -> void:
	quality = name
	var zoom: float = 1.3
	var glow: bool = true
	var msaa: int = Viewport.MSAA_2X
	match name:
		"low":
			zoom = 1.55
			glow = false
			msaa = Viewport.MSAA_DISABLED
		"medium":
			zoom = 1.42
			glow = true
			msaa = Viewport.MSAA_DISABLED
		_:
			zoom = 1.3
			glow = true
			msaa = Viewport.MSAA_2X
	# MSAA/HDR/glow в Compatibility недоступны — гасим, чтобы не ловить варнинги
	var method: String = RenderingServer.get_current_rendering_method()
	if method == "gl_compatibility":
		glow = false
		msaa = Viewport.MSAA_DISABLED
		if quality != "low":
			zoom = 1.42
	glow_enabled = glow and name != "low"
	get_viewport().msaa_2d = msaa
	# HDR 2D выключаем намеренно: в forward_plus он переводит канвас в линейное
	# пространство и картинка выходит заметно темнее (плюс на web-рендере
	# gl_compatibility HDR2D вообще недоступен), поэтому профили совпадают.
	get_viewport().use_hdr_2d = false
	if _env != null and _env.environment != null:
		_env.environment.glow_enabled = glow_enabled
	if player != null:
		var cam: Camera2D = player.camera()
		if cam != null:
			cam.zoom = Vector2(zoom, zoom)
	if hud != null and hud.has_method("set_quality"):
		hud.call("set_quality", name)


func _build_environment() -> void:
	_canvas_mod = CanvasModulate.new()
	_canvas_mod.color = _light_target
	add_child(_canvas_mod)
	# Мягкий направленный свет даёт объём нормал-мапам и «дневной» вид Зоны.
	var sun := DirectionalLight2D.new()
	sun.name = "Sun"
	sun.rotation = deg_to_rad(38.0)
	sun.energy = 0.55
	sun.color = Color(1.0, 0.97, 0.90)
	sun.shadow_enabled = false
	sun.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(sun)
	_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.32, 0.36)
	env.ambient_light_energy = 0.35
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.92
	_env.environment = env
	add_child(_env)


# ------------------------------------------------------------------ UI
## UI создаётся динамически: если файла нет, игра всё равно запустится.
func _new_from(path: String, label: String) -> Node:
	if not ResourceLoader.exists(path):
		push_warning("Game: нет скрипта " + path + " (" + label + ")")
		return null
	var scr: Variant = load(path)
	if scr == null:
		push_warning("Game: не удалось загрузить " + path)
		return null
	var node: Variant = (scr as GDScript).new()
	if node == null or not (node is Node):
		return null
	return node as Node


func _build_ui() -> void:
	dialog = DialogUI.new()
	dialog.setup(self)
	add_child(dialog)

	hud = _new_from("res://scripts/hud.gd", "HUD")
	if hud != null:
		add_child(hud)
		if hud.has_method("setup"):
			hud.call("setup", self)
	inventory_ui = _new_from("res://scripts/inventory_ui.gd", "инвентарь")
	if inventory_ui != null:
		add_child(inventory_ui)
		if inventory_ui.has_method("setup"):
			inventory_ui.call("setup", self)
	journal_ui = _new_from("res://scripts/journal_ui.gd", "журнал")
	if journal_ui != null:
		add_child(journal_ui)
		if journal_ui.has_method("setup"):
			journal_ui.call("setup", self)
	menu_ui = _new_from("res://scripts/menu_ui.gd", "меню")
	if menu_ui != null:
		add_child(menu_ui)
		if menu_ui.has_method("setup"):
			menu_ui.call("setup", self)
	touch_ui = _new_from("res://scripts/touch_ui.gd", "касания")
	if touch_ui != null:
		add_child(touch_ui)
		if touch_ui.has_method("setup"):
			touch_ui.call("setup", self)
		if touch_ui.has_method("set_enabled"):
			touch_ui.call("set_enabled", DisplayServer.is_touchscreen_available() or OS.has_feature("web"))


# ------------------------------------------------------------------ жизненный цикл
func new_game(seed_value: int = 0) -> void:
	GameState.reset_run(seed_value)
	Quests.reset()
	_build_world()
	run_active = true
	GameState.spawn_point = player.global_position
	if not Quests.start("q_awake"):
		Quests.start("q_dogs")
	Sfx.music("mus_raid_loop")
	Sfx.ambient("amb_zone_loop")
	GameState.log_message.emit("Добро пожаловать в Зону, сталкер", "quest")
	_hide_menus()


func continue_game() -> void:
	if not GameState.has_save() or not GameState.load_game():
		new_game()
		return
	_build_world()
	run_active = true
	Sfx.music("mus_raid_loop")
	Sfx.ambient("amb_zone_loop")
	GameState.log_message.emit("Загрузка сохранения", "info")
	_hide_menus()


func _hide_menus() -> void:
	if menu_ui != null:
		if menu_ui.has_method("hide_all"):
			menu_ui.call("hide_all")
		menu_ui.visible = false
	set_paused(false)


func to_menu() -> void:
	run_active = false
	Sfx.stop_all()
	Sfx.music("mus_menu_loop")
	if menu_ui != null and menu_ui.has_method("show_screen"):
		menu_ui.call("show_screen", "main")


func _free_run_nodes() -> void:
	for n in get_children():
		if n == _canvas_mod or n == _env or n is CanvasLayer:
			continue
		n.queue_free()
	player = null
	world = null
	world_data = {}
	fx_root = null


func _build_world() -> void:
	_free_run_nodes()
	world = _new_from("res://scripts/world.gd", "мир") as Node2D
	if world == null:
		push_error("Game: не удалось создать мир — создаю пустую сцену")
		world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)
	if world.has_method("generate"):
		var data: Variant = world.call("generate", GameState.world_seed)
		world_data = data if typeof(data) == TYPE_DICTIONARY else {}
	else:
		world_data = {}
	var spawn: Vector2 = world_data.get("spawn", Vector2(2048, 2048))

	player = Player.new()
	player.name = "Player"
	player.game = self
	world.add_child(player)
	player.global_position = spawn
	if touch_ui != null and touch_ui.has_method("bind_player"):
		touch_ui.call("bind_player", player)
	_sync_touch_binding()
	player.camera().make_current()
	_setup_camera_limits()
	_spawn_enemies()
	_spawn_anomalies()
	_seed_quest_containers()
	_add_ground_variation()
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.has_method("set_dialog"):
			npc.call("set_dialog", dialog)
	if not Quests.quest_completed.is_connected(_on_quest_completed):
		Quests.quest_completed.connect(_on_quest_completed)
	GameState.recompute()
	GameState.stats_changed.emit()
	if hud != null and hud.has_method("minimap_setup"):
		hud.call("minimap_setup", world_data.get("zones", {}),
			world_data.get("size_tiles", Vector2i(1, 1)), int(world_data.get("tile_size", 128)))
	set_process(true)


## Крупномасштабная «грязь» поверх тайлов: убирает вид повторяющейся плитки
## и добавляет Зоне пятнистость (один Sprite2D с повторяющейся текстурой).
func _add_ground_variation() -> void:
	var size_tiles: Vector2i = world_data.get("size_tiles", Vector2i.ZERO)
	var tile: int = int(world_data.get("tile_size", 128))
	if size_tiles == Vector2i.ZERO:
		return
	var tw: float = float(size_tiles.x * tile)
	var th: float = float(size_tiles.y * tile)
	var noise: ImageTexture = _make_value_noise_texture(256, int(GameState.world_seed) + 7)
	var layer := Sprite2D.new()
	layer.name = "GroundVariation"
	layer.texture = noise
	layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	layer.centered = false
	layer.scale = Vector2(tw / 256.0, th / 256.0)
	layer.modulate = Color(0.62, 0.60, 0.55, 0.16)
	layer.z_index = -8
	world.add_child(layer)
	var dirt := Sprite2D.new()
	dirt.name = "GroundVariation2"
	dirt.texture = noise
	dirt.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	dirt.centered = false
	dirt.scale = Vector2(tw / 512.0, th / 512.0)
	dirt.position = Vector2(140.0, 96.0)
	dirt.modulate = Color(0.30, 0.26, 0.20, 0.12)
	dirt.z_index = -7
	world.add_child(dirt)


## Простая тайлящаяся карта шума (сумма октав value-noise с интерполяцией).
func _make_value_noise_texture(size: int, noise_seed: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	var acc := PackedFloat32Array()
	acc.resize(size * size)
	acc.fill(0.0)
	var amp: float = 1.0
	var total: float = 0.0
	for octave in 3:
		var res: int = 4 * int(pow(2.0, float(octave)))
		var grid := PackedFloat32Array()
		grid.resize(res * res)
		rng.seed = noise_seed + octave * 977
		for i in res * res:
			grid[i] = rng.randf()
		var step: float = float(res) / float(size)
		for y in size:
			var fy: float = float(y) * step
			var y0: int = int(fy) % res
			var y1: int = (y0 + 1) % res
			var ty: float = _smooth01(fy - floor(fy))
			for x in size:
				var fx: float = float(x) * step
				var x0: int = int(fx) % res
				var x1: int = (x0 + 1) % res
				var tx: float = _smooth01(fx - floor(fx))
				var top: float = lerpf(grid[y0 * res + x0], grid[y0 * res + x1], tx)
				var bot: float = lerpf(grid[y1 * res + x0], grid[y1 * res + x1], tx)
				acc[y * size + x] += amp * lerpf(top, bot, ty)
		total += amp
		amp *= 0.5
	var img := Image.create(size, size, false, Image.FORMAT_L8)
	for y in size:
		for x in size:
			var v: float = clampf(acc[y * size + x] / maxf(total, 0.001), 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)


func _smooth01(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _setup_camera_limits() -> void:
	var size_tiles: Vector2i = world_data.get("size_tiles", Vector2i.ZERO)
	var tile: int = int(world_data.get("tile_size", 128))
	if size_tiles == Vector2i.ZERO or player == null:
		return
	var cam: Camera2D = player.camera()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = size_tiles.x * tile
	cam.limit_bottom = size_tiles.y * tile


## Спавн врагов. Дальние враги «спят» — на телефоне это обязательно.
func _spawn_enemies() -> void:
	for e in world_data.get("enemy_spawns", []):
		var d: Dictionary = e
		var node: Node = _new_from("res://scripts/enemy.gd", "враг")
		if node == null:
			return
		world.add_child(node)
		(node as Node2D).global_position = d.get("pos", Vector2.ZERO)
		if node.has_method("setup"):
			node.call("setup", String(d.get("type", "dog")), int(d.get("level", 1)))
		if bool(d.get("boss", false)) and node.get("boss") != null:
			node.set("boss", true)
		node.set_physics_process(false)
		if node is CanvasItem:
			(node as CanvasItem).visible = false


func _spawn_anomalies() -> void:
	for a in world_data.get("anomalies", []):
		var d: Dictionary = a
		var node: Node = _new_from("res://scripts/anomaly.gd", "аномалия")
		if node == null:
			return
		world.add_child(node)
		(node as Node2D).global_position = d.get("pos", Vector2.ZERO)
		if node.has_method("setup"):
			node.call("setup", String(d.get("type", "grav")), float(d.get("radius", 120.0)))


## Квестовые предметы кладём в конкретные контейнеры, чтобы цепочка не встала.
func _seed_quest_containers() -> void:
	var containers: Array = []
	for c in get_tree().get_nodes_in_group("containers"):
		containers.append(c)
	if containers.is_empty():
		return
	containers.sort_custom(func(a, b): return (a as Node2D).global_position.y > (b as Node2D).global_position.y)
	if containers[0].has_method("add_guaranteed"):
		containers[0].call("add_guaranteed", "key_underground")
	var placed: int = 0
	for i in range(containers.size() - 1, -1, -1):
		if not containers[i].has_method("add_guaranteed"):
			continue
		containers[i].call("add_guaranteed", "docs")
		placed += 1
		if placed >= 3:
			break


# ------------------------------------------------------------------ кадр
func _process(delta: float) -> void:
	if player != null:
		_zone_timer -= delta
		if _zone_timer <= 0.0:
			_zone_timer = 0.5
			_check_zone()
		_activate_timer -= delta
		if _activate_timer <= 0.0:
			_activate_timer = 0.7
			_update_activation()
			_update_danger()
	_auto_quality_check(delta)
	_touch_timer -= delta
	if _touch_timer <= 0.0:
		_touch_timer = 2.0
		_update_touch_visibility()
	if player != null:
		var cam: Camera2D = player.camera()
		if shake_amount > 0.0:
			shake_amount = maxf(0.0, shake_amount - delta * 3.0)
			cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amount * 18.0
		elif cam.offset != Vector2.ZERO:
			cam.offset = Vector2.ZERO
	_update_lighting(delta)


func shake(amount: float) -> void:
	shake_amount = minf(1.6, maxf(shake_amount, amount))


func _check_zone() -> void:
	var zone: String = ""
	if world != null and world.has_method("zone_at"):
		zone = String(world.call("zone_at", player.global_position))
	if zone == current_zone:
		return
	current_zone = zone
	if zone != "":
		Quests.notify("reach", zone, 1)
		GameState.log_message.emit("Локация: " + zone_name(zone), "info")
	match zone:
		"bunker":
			Sfx.ambient("amb_cave_loop")
		"factory":
			Sfx.ambient("amb_zone_loop")
		_:
			Sfx.ambient("amb_wind_loop")


func zone_name(zone: String) -> String:
	return String(ZONE_NAMES.get(zone, zone))


func _update_lighting(delta: float) -> void:
	match current_zone:
		"bunker":
			_light_target = Color(0.46, 0.47, 0.52)
		"factory":
			_light_target = Color(0.62, 0.63, 0.66)
		"swamp":
			_light_target = Color(0.68, 0.76, 0.68)
		"village":
			_light_target = Color(0.76, 0.78, 0.82)
		"field":
			_light_target = Color(0.78, 0.80, 0.86)
		_:
			_light_target = Color(0.80, 0.82, 0.86)
	_canvas_mod.color = _canvas_mod.color.lerp(_light_target, clampf(delta * 1.4, 0.0, 1.0))


## Активация врагов по расстоянию: экономит CPU на телефоне.
func _update_activation() -> void:
	if player == null:
		return
	var pos: Vector2 = player.global_position
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not (e is Node2D):
			continue
		var d: float = (e as Node2D).global_position.distance_to(pos)
		var want: bool = d < _activation_radius()
		if e.has_method("is_alive") and not bool(e.call("is_alive")):
			want = false
		if e.has_method("set_active"):
			e.call("set_active", want)
		else:
			e.set_physics_process(want)
			if e is CanvasItem:
				(e as CanvasItem).visible = want


## Тревожный эмбиент: чем ближе враг, тем громче.
func _update_danger() -> void:
	var nearest: float = 9999.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and e.has_method("is_alive"):
			if bool(e.call("is_alive")):
				nearest = minf(nearest, (e as Node2D).global_position.distance_to(player.global_position))
	var danger: float = 0.0
	if nearest < 900.0:
		danger = clampf(1.0 - nearest / 900.0, 0.0, 1.0) * 0.8
	var hp_ratio: float = GameState.hp / maxf(1.0, GameState.hp_max)
	if hp_ratio < 0.35:
		danger = maxf(danger, 1.0 - hp_ratio)
	Sfx.set_danger(danger, 1.2)


func on_player_died() -> void:
	Sfx.set_danger(0.0, 0.4)
	Sfx.music("")
	if menu_ui != null and menu_ui.has_method("show_screen"):
		menu_ui.call("show_screen", "death")


func set_paused(value: bool) -> void:
	get_tree().paused = value
	if hud != null:
		hud.visible = not value


func save_run() -> void:
	GameState.save_game()


## Автосохранение после каждого закрытого задания (в браузере это важно).
func _on_quest_completed(_id: String) -> void:
	if run_active:
		GameState.save_game()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var key := event as InputEventKey
	if not run_active:
		return
	match key.keycode:
		KEY_ESCAPE:
			set_paused(true)
			if menu_ui != null and menu_ui.has_method("show_screen"):
				menu_ui.call("show_screen", "pause")
		KEY_I, KEY_E:
			if inventory_ui != null and inventory_ui.has_method("toggle"):
				inventory_ui.call("toggle")
				get_viewport().set_input_as_handled()
		KEY_J:
			if journal_ui != null and journal_ui.has_method("toggle"):
				journal_ui.call("toggle")
				get_viewport().set_input_as_handled()
		KEY_F11:
			var mode: int = DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN
				else DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			pass


# ------------------------------------------------------------------ самотест
## Запуск: godot --headless --path . -- --selftest
##         godot --path . -- --selftest --shot   (окно + скриншоты для глаз)
func _run_selftest(shot: bool) -> void:
	var t0: float = Time.get_ticks_msec()
	print("=== ЗОНА: самотест ===")
	print("[asset report] ", Assets.report())
	new_game(20240923)
	await _wait(1.2)
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var anomalies: Array = get_tree().get_nodes_in_group("anomalies")
	var containers: Array = get_tree().get_nodes_in_group("containers")
	print("[world] размер карты: ", world_data.get("size_tiles", Vector2i.ZERO),
		" | зон: ", (world_data.get("zones", {}) as Dictionary).size())
	print("[world] врагов: ", enemies.size(), " | аномалий: ", anomalies.size(),
		" | контейнеров: ", containers.size())
	print("[world] игрок: ", player.global_position, " | зона: ", current_zone)
	print("[ui] hud=", hud != null, " bag=", inventory_ui != null, " journal=", journal_ui != null,
		" menu=", menu_ui != null, " touch=", touch_ui != null)
	print("[ui] узлов в дереве: ", get_tree().get_node_count())
	if shot:
		await _shot("game_shot_kordon.png")

	# бой: ставим врага вплотную (нож — ближний бой) и бьём
	if player.get("_touch_aim_fallback") != null:
		player.set("_touch_aim_fallback", true)   # в headless нет мыши — включаем автоприцел
	GameState.add_item("ammo_9x18", 120, true)
	var spawned: Array = []
	for i in 6:
		var e: Node = _new_from("res://scripts/enemy.gd", "враг")
		if e == null:
			break
		world.add_child(e)
		(e as Node2D).global_position = player.global_position + Vector2(46.0 + i * 10.0, 0.0)
		if e.has_method("setup"):
			e.call("setup", ["dog", "zombie", "mutant", "boar"][i % 4], 2)
		e.set_physics_process(true)
		spawned.append(e)
	await _wait(0.4)
	var alive_before: int = _alive_count()
	for i in 25:
		player.try_attack()
		await _wait(0.12)
	var alive_after: int = _alive_count()
	print("[combat] живых врагов рядом: ", alive_before, " -> ", alive_after,
		" (подставлено ", spawned.size(), ") | всего убийств: ", GameState.kills)
	GameState.add_item("ak", 1, true)
	GameState.add_item("ammo_545", 120, true)
	GameState.equip("ak")
	await _wait(0.3)
	for i in 30:
		player.try_attack()
		await _wait(0.1)
	print("[combat] после стрельбы: убийств ", GameState.kills,
		" | патронов в магазине ", player.mag_count(), "/", player.reserve_count())
	print("[loot] предметов на земле: ", get_tree().get_nodes_in_group("loot").size())
	_diag_tileset()
	if shot:
		await _shot("game_shot_combat.png")


	# урон игроку и аптечка (сначала выходим из драки и оживляем героя)
	player.global_position += Vector2(4200, 4200)
	await _wait(0.5)
	GameState.is_dead = false
	GameState.hp = GameState.hp_max
	if player.get("_dead") != null:
		player.set("_dead", false)
	player.take_damage(35.0)
	await _wait(0.2)
	print("[player] hp после урона: ", GameState.hp)
	GameState.add_item("medkit", 2, true)
	player.use_best_med()
	await _wait(0.2)
	print("[player] hp после аптечки: ", GameState.hp)

	# квесты: закрываем первую цель
	GameState.add_item("scrap", 5, true)
	Quests.notify("reach", "kordon", 1)
	await _wait(0.4)
	print("[quests] активные: ", Array(Quests.active), " | выполнено: ", GameState.quests_done)

	# аномалия + артефакт
	if anomalies.size() > 0:
		var a: Node = anomalies[0]
		player.global_position = (a as Node2D).global_position + Vector2(200, 0)
		await _wait(0.6)
		print("[anomaly] опасность рядом: ", a.call("danger_for", player.global_position),
			" | артефакт: ", a.get("artifact_id"))
		if shot:
			await _shot("game_shot_anomaly.png")


	# сохранение и загрузка
	GameState.save_game()
	var saved_ok: bool = GameState.has_save()
	print("[save] файл создан: ", saved_ok)

	if shot:
		player.global_position += Vector2(2600, 2200)
		await _wait(1.0)
		await _shot("game_shot_field.png")


	var ms: int = Time.get_ticks_msec() - t0
	print("[perf] кадров/с: ", Engine.get_frames_per_second(), " | fps-лимит: ", Engine.max_fps)
	print("[done] самотест завершён за ", ms, " мс | рендер: ", RenderingServer.get_current_rendering_method())
	print("=== ГОТОВО ===")
	get_tree().quit(0)


## Самотест: godot --headless --path . -- --selftest [--shot]
##           godot --headless --path . -- --playtest   (проверка всех игровых путей)
func _run_playtest(shot: bool = false) -> void:
	var t0: float = Time.get_ticks_msec()
	var checks: Array = []
	print("=== ЗОНА: плейтест ===")
	new_game(777001)
	await _wait(1.0)

	# 1. экраны интерфейса
	for screen in ["inventory", "journal"]:
		var ui: Node = inventory_ui if screen == "inventory" else journal_ui
		if ui != null and ui.has_method("toggle"):
			ui.call("toggle")
			await _wait(0.25)
			checks.append(["открыт экран " + screen, bool(ui.get("visible"))])
			if shot:
				await _shot("ui_" + screen + ".png")
			ui.call("toggle")
			await _wait(0.25)
		else:
			checks.append(["экран " + screen, false])
	if menu_ui != null and menu_ui.has_method("show_screen"):
		menu_ui.call("show_screen", "pause")
		await _wait(0.3)
		var pause_ok: bool = bool(menu_ui.visible) \
			and String(menu_ui.call("current_screen")) == "pause" \
			and get_tree().paused
		if shot:
			await _shot("ui_pause.png")
		checks.append(["экран паузы: слой меню видим, мир заморожен", pause_ok])
		menu_ui.call("show_screen", "settings")
		await _wait(0.3)
		var settings_ok: bool = bool(menu_ui.visible) \
			and String(menu_ui.call("current_screen")) == "settings"
		if shot:
			await _shot("ui_settings.png")
		checks.append(["экран настроек открыт поверх паузы", settings_ok])
		if menu_ui.has_method("hide_all"):
			menu_ui.call("hide_all")
		menu_ui.visible = false
		game_paused_off()
		checks.append(["меню закрыто, пауза снята",
			not bool(menu_ui.visible) and not get_tree().paused])
	else:
		checks.append(["экраны меню", false])

	# 2. диалог с NPC
	var npcs: Array = get_tree().get_nodes_in_group("npcs")
	var got_quest: bool = false
	if npcs.size() > 0:
		npcs[0].call("interact", player)
		await _wait(0.3)
		var was_open: bool = dialog.is_open()
		var before: int = Array(Quests.active).size()
		if was_open:
			dialog.choice.emit(0)   # первый вариант — взять задание
			await _wait(0.3)
		got_quest = was_open and Array(Quests.active).size() >= before
		if dialog.is_open():
			dialog.close()
	checks.append(["диалог NPC выдаёт задание", got_quest])

	# 3. обыск контейнера
	var containers: Array = get_tree().get_nodes_in_group("containers")
	var looted: bool = false
	if containers.size() > 0:
		var items_before: int = GameState.inventory.size()
		looted = bool(containers[0].call("open", player))
		await _wait(0.4)
		checks.append(["контейнер выдал лут", looted and get_tree().get_nodes_in_group("loot").size() > 0])
	else:
		checks.append(["контейнеры найдены", false])

	# 4. аномалия и артефакт
	var anomalies: Array = get_tree().get_nodes_in_group("anomalies")
	if anomalies.size() > 0:
		var an: Node = anomalies[0]
		player.global_position = (an as Node2D).global_position + Vector2(160, 0)
		var found_before: int = GameState.artifacts_found
		var art: String = String(an.call("take_artifact"))
		await _wait(0.4)
		var ok: bool = art != "" and GameState.artifacts_found >= found_before
		var picked: bool = false
		for l in get_tree().get_nodes_in_group("loot"):
			if String(l.get("item_id")) == art:
				picked = bool(l.call("pick_up", player))
				break
		checks.append(["артефакт из аномалии " + art, ok and (picked or GameState.count_total(art) > 0)])
	else:
		checks.append(["аномалии найдены", false])

	# 5. бой: убить врагов напрямую (проверка смерти, лута, опыта)
	var kills_before: int = GameState.kills
	var xp_before: float = GameState.xp + float(GameState.level) * 1000.0
	for i in 4:
		var e: Node = _new_from("res://scripts/enemy.gd", "враг")
		if e == null:
			break
		world.add_child(e)
		(e as Node2D).global_position = player.global_position + Vector2(90.0 + i * 30.0, 40.0)
		e.call("setup", ["dog", "zombie", "mutant", "boar"][i], 1)
		await _wait(0.1)
		e.call("take_damage", 999.0, player)
	await _wait(0.6)
	checks.append(["убийства засчитаны", GameState.kills > kills_before])
	checks.append(["лут с трупов", get_tree().get_nodes_in_group("loot").size() > 0])
	checks.append(["опыт начислен", (GameState.xp + float(GameState.level) * 1000.0) > xp_before])

	# 6. прокачка уровня
	var lvl_before: int = GameState.level
	GameState.add_xp(GameState.xp_next + 10.0)
	await _wait(0.3)
	checks.append(["уровень повышен", GameState.level > lvl_before])

	# 7. квест i цепочка: закрыть текущий и получить следующий
	var current: String = Quests.main_current()
	var next_ok: bool = false
	if current != "":
		Quests.complete(current)
		await _wait(0.4)
		next_ok = Array(Quests.active).size() > 0 or Quests.is_done(current)
	checks.append(["квест закрыт, цепочка идёт дальше", next_ok])

	# 8. сохранение и загрузка
	GameState.add_item("medkit", 3, true)
	var inv_before: int = GameState.count_item("medkit")
	GameState.save_game()
	GameState.inventory = []
	var loaded: bool = GameState.load_game()
	await _wait(0.3)
	checks.append(["сохранение/загрузка", loaded and GameState.count_item("medkit") == inv_before])

	# 9. медицина и радиация
	GameState.hp = 40.0
	GameState.add_item("medkit", 1, true)
	player.use_best_med()
	await _wait(0.2)
	checks.append(["аптечка лечит", GameState.hp > 40.0])
	GameState.add_radiation(30.0)
	var rad_before: float = GameState.radiation
	GameState.add_item("antidote", 1, true)
	GameState.use_item("antidote")
	checks.append(["антирад снимает облучение", GameState.radiation < rad_before])

	var failed: int = 0
	print("--- результаты ---")
	for c in checks:
		var ok: bool = bool(c[1])
		if not ok:
			failed += 1
		print("  [%s] %s" % ["OK " if ok else "ПРОВАЛ", c[0]])
	print("[playtest] проверок: %d, провалов: %d, время %d мс, узлов %d" % [
		checks.size(), failed, Time.get_ticks_msec() - t0, get_tree().get_node_count()])
	print("=== ПЛЕЙТЕСТ ЗАВЕРШЁН ===")
	get_tree().quit(0 if failed == 0 else 1)


func game_paused_off() -> void:
	set_paused(false)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Сколько врагов рядом ещё живо (в радиусе 700 px).
func _alive_count() -> int:
	var n: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not e.has_method("is_alive"):
			continue
		if (e as Node2D).global_position.distance_to(player.global_position) > 700.0:
			continue
		if bool(e.call("is_alive")):
			n += 1
	return n


## Радиус «бодрствования» врагов: на слабых устройствах меньше.
func _activation_radius() -> float:
	return 1400.0 if quality == "low" else 2100.0


## Показывать ли экранные стики: тач-устройство или узкое окно в браузере.
func _update_touch_visibility() -> void:
	if touch_ui == null or not touch_ui.has_method("set_enabled"):
		return
	var want: bool = DisplayServer.is_touchscreen_available()
	if not want and OS.has_feature("web"):
		# Размер окна браузера тут напрямую не виден: window_get_size() отдаёт
		# пиксели канвы (уже умноженные на devicePixelRatio), а get_visible_rect()
		# при stretch «canvas_items» + «expand» держит логическую ширину >= 1280 —
		# поэтому прежнее условие «ширина < 1200» не срабатывало никогда и на ПК
		# кнопок не было вовсе. Окно уже 16:9 узнаём по логической высоте: она
		# больше базовой ровно тогда, когда окно узкое (телефон, половина экрана).
		var base_h: float = float(ProjectSettings.get_setting(
			"display/window/size/viewport_height", 720))
		want = get_viewport().get_visible_rect().size.y > base_h + 0.5
	var current: bool = bool(touch_ui.call("is_enabled")) if touch_ui.has_method("is_enabled") else false
	if want != current:
		touch_ui.call("set_enabled", want)
	_sync_touch_binding()


## Игрок должен читать стики ровно тогда, когда слой касаний включён.
## Иначе на телефоне стики и кнопки касаний молча не работают (player.touch == null),
## а на десктопе, наоборот, включился бы автоприцел вместо мыши.
func _sync_touch_binding() -> void:
	if player == null or touch_ui == null:
		return
	var on: bool = bool(touch_ui.call("is_enabled")) if touch_ui.has_method("is_enabled") else true
	var bound: bool = player.get("touch") == touch_ui
	if on != bound:
		player.bind_touch(touch_ui if on else null)


var _touch_timer: float = 0.0


## Автопонижение качества, если устройство не тянет (важно для телефонов).
func _auto_quality_check(delta: float) -> void:
	if quality == "low" or not (OS.has_feature("web") or DisplayServer.is_touchscreen_available()):
		return
	var fps: float = float(Engine.get_frames_per_second())
	if fps <= 0.0:
		return
	if fps < 26.0:
		_low_fps_time += delta
	else:
		_low_fps_time = maxf(0.0, _low_fps_time - delta * 0.5)
	if _low_fps_time > 4.0:
		_low_fps_time = 0.0
		var from_name: String = quality
		apply_quality("low")
		GameState.log_message.emit("Качество снижено (%s → Низкое): %d FPS" % [from_name, int(fps)], "info")


var _low_fps_time: float = 0.0


## Диагностика коллизий тайлов: у стен должны быть полигоны.
func _diag_tileset() -> void:
	var layers: int = 0
	var polys: int = 0
	for n in world.get_children():
		if not (n is TileMapLayer):
			continue
		var tl := n as TileMapLayer
		if tl.tile_set == null:
			continue
		var phys: int = tl.tile_set.get_physics_layers_count()
		layers += phys
		if phys == 0:
			continue   # у слоя земли физики нет — у TileData нечего спрашивать
		var src := tl.tile_set.get_source(0) as TileSetAtlasSource
		if src == null or src.get_tiles_count() == 0:
			continue
		var td: TileData = src.get_tile_data(src.get_tile_id(0), 0)
		if td != null:
			polys = maxi(polys, td.get_collision_polygons_count(0))
	print("[tiles] слоёв физики: ", layers, " | полигонов у тайла стены: ", polys,
		" | ходить можно: ", world.call("is_walkable", player.global_position) if world.has_method("is_walkable") else "н/д")



func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://tools/gen/_out/" + file_name)
	print("[shot] ", file_name, " ", img.get_size(), " | средняя яркость: ",
		snappedf(_avg_brightness(img), 0.001), " (0..1)")
	_diag_visual()


## Средняя яркость картинки — численная проверка «не слишком ли темно».
func _avg_brightness(img: Image) -> float:
	var total: float = 0.0
	var count: int = 0
	var step: int = maxi(1, img.get_width() / 64)
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c: Color = img.get_pixel(x, y)
			total += (c.r + c.g + c.b) / 3.0
			count += 1
	return total / maxf(1.0, float(count))


## Ищем, что именно гасит картинку: CanvasModulate, оверлеи, свет.
func _diag_visual() -> void:
	var mods: Array = []
	var overlays: Array = []
	_collect_visuals(self, mods, overlays)
	for m in mods:
		print("[vis] CanvasModulate ", (m as Node).get_path(), " цвет=", (m as CanvasModulate).color)
	for o in overlays:
		var ci := o as CanvasItem
		print("[vis] оверлей ", ci.get_path(), " z=", ci.z_index, " видим=", ci.visible,
			" modulate=", ci.modulate)
	if world != null:
		print("[vis] мир modulate=", (world as CanvasItem).modulate,
			" self=", (world as CanvasItem).self_modulate)
		for c in world.get_children():
			if c is CanvasItem:
				print("[vis]   ", c.name, " класс=", c.get_class(), " modulate=",
					(c as CanvasItem).modulate, " self=", (c as CanvasItem).self_modulate,
					" z=", (c as CanvasItem).z_index)
	if _env != null and _env.environment != null:
		var e := _env.environment
		print("[vis] environment: bg=", e.background_mode, " glow=", e.glow_enabled,
			" threshold=", e.glow_hdr_threshold, " energy=", e.glow_intensity,
			" adjustment=", e.adjustment_enabled, " contrast=", e.adjustment_contrast,
			" brightness=", e.adjustment_brightness)
	if player != null:
		for c in player.get_children():
			if c is PointLight2D:
				var l := c as PointLight2D
				var tsize: String = str(l.texture.get_size()) if l.texture != null else "нет"
				print("[vis] свет ", l.get_path(), " энергия=", l.energy,
					" масштаб=", l.texture_scale, " видим=", l.visible, " текстура=", tsize)


func _collect_visuals(node: Node, mods: Array, overlays: Array) -> void:
	if node is CanvasModulate:
		mods.append(node)
	if node is ColorRect and (node as ColorRect).color.a > 0.05 and (node as ColorRect).size.x > 100.0:
		overlays.append(node)
	for c in node.get_children():
		_collect_visuals(c, mods, overlays)



func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		var args: PackedStringArray = OS.get_cmdline_user_args()
		if args.has("--selftest"):
			_run_selftest(args.has("--shot"))
		elif args.has("--playtest"):
			_run_playtest(args.has("--shot"))
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# В браузере уход в другую вкладку/приложение должен ставить игру на паузу.
		if run_active and not get_tree().paused and not OS.has_feature("editor"):
			set_paused(true)
			if menu_ui != null and menu_ui.has_method("show_screen"):
				menu_ui.call("show_screen", "pause")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if run_active:
			GameState.save_game()





