extends SceneTree

## Самотест мира: генерирует локацию фиксированным сидом, печатает статистику,
## проверяет зоны, спавн и лут, рисует миникарту в tools/gen/_out/minimap.png.
## Запуск:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/t_world.gd
##
## Скрипт намеренно не ссылается на автолоады напрямую (в режиме -s глобальные
## имена автолоадов недоступны) — все данные берутся из возвращённого словаря.

const SEED := 20250923
const MINIMAP_PATH := "res://tools/gen/_out/minimap.png"
const MINIMAP_PPT := 4          ## пикселей на тайл в миникарте (260x200 -> 1040x800)

var _fails: int = 0
var _checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Тест мира «ЗОНА» =================================")
	var t0: int = Time.get_ticks_msec()
	var world_script: Script = load("res://scripts/world.gd")
	_check(world_script != null, "scripts/world.gd компилируется")
	if world_script == null:
		_finish(t0)
		return
	var world: Node2D = world_script.new()
	root.add_child(world)
	var data: Dictionary = world.call("generate", SEED)
	var total_ms: int = Time.get_ticks_msec() - t0
	_report(world, data, total_ms)
	_check_layout(world, data)
	var img: Image = _save_minimap(world)
	_check(determinism_ok(world_script, img), "мир детерминирован по сиду")
	print("Итог: проверок ", _checks, ", провалов ", _fails)
	_finish(t0)


func _finish(t0: int) -> void:
	print("Полное время теста, мс: ", Time.get_ticks_msec() - t0)
	print("TEST_WORLD_DONE fails=", _fails)
	quit(1 if _fails > 0 else 0)


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[ok] ", what)
	else:
		_fails += 1
		print("[FAIL] ", what)


# ---------------------------------------------------------------- статистика
func _report(world: Node2D, data: Dictionary, total_ms: int) -> void:
	var size_tiles: Vector2i = data["size_tiles"]
	var ts: int = int(data["tile_size"])
	var ground: Node = world.get_node_or_null("ground")
	var walls: Node = world.get_node_or_null("walls")
	var ground_cells: int = (ground as TileMapLayer).get_used_cells().size() if ground != null else 0
	var wall_cells: int = (walls as TileMapLayer).get_used_cells().size() if walls != null else 0
	print("--- мир: ", size_tiles.x, "x", size_tiles.y, " тайлов по ", ts, " px = ",
		size_tiles.x * ts, "x", size_tiles.y * ts, " px")
	print("--- время генерации, мс: ", data["generation_ms"], " (тест целиком: ", total_ms, ")")
	print("--- тайлов земли: ", ground_cells, ", тайлов стен: ", wall_cells)
	print("--- слои TileMapLayer: ground=", ground != null, ", walls=", walls != null)
	var props: int = get_nodes_in_group("props").size()
	var solid: int = 0
	for c in get_nodes_in_group("props"):
		if c is StaticBody2D:
			solid += 1
	print("--- пропов: ", props, " (из них с коллизией: ", solid, "), декалей: ", data["decals"])
	print("--- контейнеров: ", get_nodes_in_group("containers").size(),
		", NPC: ", get_nodes_in_group("npcs").size())
	var hist: Dictionary = world.call("material_histogram")
	var mat_line := ""
	for k in hist.keys():
		mat_line += String(k) + "=" + str(hist[k]) + " "
	print("--- материалы земли: ", mat_line)
	_report_spawns(data)
	var zone_line := ""
	for zid in data["zones"].keys():
		var r: Rect2 = data["zones"][zid]
		zone_line += String(zid) + "[" + str(int(r.position.x)) + "," + str(int(r.position.y)) \
			+ " " + str(int(r.size.x)) + "x" + str(int(r.size.y)) + "] "
	print("--- зоны, px: ", zone_line)
	print("[world] генерация мс=", data["generation_ms"], " земля=", ground_cells,
		" стены=", wall_cells, " пропы=", props, " декали=", data["decals"],
		" враги=", (data["enemy_spawns"] as Array).size(),
		" аномалии=", (data["anomalies"] as Array).size(),
		" лут=", (data["loot_spots"] as Array).size())


func _report_spawns(data: Dictionary) -> void:
	var by_type: Dictionary = {}
	var by_level: Dictionary = {}
	var bosses := 0
	var min_dist := 1.0e12
	var spawn: Vector2 = data["spawn"]
	for e in data["enemy_spawns"]:
		var t: String = String(e["type"])
		by_type[t] = int(by_type.get(t, 0)) + 1
		var lv: int = int(e["level"])
		by_level[lv] = int(by_level.get(lv, 0)) + 1
		if bool(e["boss"]):
			bosses += 1
		min_dist = minf(min_dist, spawn.distance_to(e["pos"]))
	print("--- врагов: ", (data["enemy_spawns"] as Array).size(), ", боссов ", bosses,
		", по типам ", by_type, ", по уровням ", by_level,
		", ближайший к спавну ", int(min_dist), " px")
	var anom_types: Dictionary = {}
	var rmin := 1.0e12
	var rmax := 0.0
	for a in data["anomalies"]:
		var at: String = String(a["type"])
		anom_types[at] = int(anom_types.get(at, 0)) + 1
		rmin = minf(rmin, float(a["radius"]))
		rmax = maxf(rmax, float(a["radius"]))
	print("--- аномалий: ", (data["anomalies"] as Array).size(), " ", anom_types,
		", радиус ", int(rmin), "..", int(rmax))
	var tiers: Dictionary = {}
	for l in data["loot_spots"]:
		var t2: int = int(l["tier"])
		tiers[t2] = int(tiers.get(t2, 0)) + 1
	print("--- точек лута: ", (data["loot_spots"] as Array).size(), " по тирам ", tiers)


# ------------------------------------------------------------------ проверки
func _check_layout(world: Node2D, data: Dictionary) -> void:
	var zones: Dictionary = data["zones"]
	for zid in ["kordon", "village", "factory", "bunker", "swamp", "anomaly_field"]:
		_check(zones.has(zid), "зона «" + String(zid) + "» есть в данных")
	var spawn: Vector2 = data["spawn"]
	_check(bool(world.call("is_walkable", spawn)),
		"точка спавна проходима " + str(spawn))
	_check(String(world.call("zone_at", spawn)) == "kordon",
		"спавн стоит на кордоне (zone_at=" + String(world.call("zone_at", spawn)) + ")")
	_check(not bool(world.call("is_walkable", Vector2(-40.0, -40.0))),
		"за границей карты пройти нельзя")
	_check(String(world.call("zone_at", Vector2(-40.0, -40.0))) == "",
		"zone_at вне карты возвращает пустую строку")
	var enemies: Array = data["enemy_spawns"]
	_check(enemies.size() >= 90 and enemies.size() <= 140,
		"врагов 90..140 (факт " + str(enemies.size()) + ")")
	var min_dist := 1.0e12
	var bosses := 0
	var levels_hi := 0
	for e in enemies:
		min_dist = minf(min_dist, spawn.distance_to(e["pos"]))
		if bool(e["boss"]):
			bosses += 1
		if int(e["level"]) >= 5:
			levels_hi += 1
	_check(min_dist >= 700.0, "ближайший враг не ближе 700 px (факт " + str(int(min_dist)) + ")")
	_check(bosses >= 2, "боссы есть (факт " + str(bosses) + ")")
	_check(levels_hi >= 10, "в глубине Зоны враги 5-6 уровня (факт " + str(levels_hi) + ")")
	var anomalies: Array = data["anomalies"]
	_check(anomalies.size() >= 14 and anomalies.size() <= 22,
		"аномалий 14..22 (факт " + str(anomalies.size()) + ")")
	var radii_ok := true
	for a in anomalies:
		var rr: float = float(a["radius"])
		if rr < 90.0 or rr > 190.0:
			radii_ok = false
	_check(radii_ok, "радиусы аномалий 90..190")
	var loot: Array = data["loot_spots"]
	_check(loot.size() >= 40 and loot.size() <= 60,
		"точек лута 40..60 (факт " + str(loot.size()) + ")")
	_check(get_nodes_in_group("containers").size() >= 30,
		"контейнеров >= 30 (факт " + str(get_nodes_in_group("containers").size()) + ")")
	_check(get_nodes_in_group("npcs").size() >= 2,
		"Сидорович и Бармен на месте (факт " + str(get_nodes_in_group("npcs").size()) + ")")
	# в каждой зоне — спавн врага и не сплошная стена
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for zid in zones.keys():
		var r: Rect2 = zones[zid]
		var in_zone := 0
		for e in enemies:
			if r.has_point(e["pos"]):
				in_zone += 1
		_check(in_zone >= 1, "в зоне «" + String(zid) + "» есть спавн врага (" + str(in_zone) + ")")
		var walk := 0
		for i in 80:
			var p := Vector2(rng.randf_range(r.position.x, r.end.x),
				rng.randf_range(r.position.y, r.end.y))
			if bool(world.call("is_walkable", p)):
				walk += 1
		_check(walk >= 20, "зона «" + String(zid) + "» не глухая: проходимо " + str(walk) + "/80")
		var rp: Vector2 = world.call("random_point", zid, rng)
		_check(bool(world.call("is_walkable", rp)),
			"random_point(«" + String(zid) + "») проходима " + str(rp))
	# связи между зонами: между центрами зон есть проходимые точки по прямой
	_check(_roads_walkable(world, zones), "между зонами есть проходимые дороги")
	# коллизия стен: источник добавлен в TileSet до create_tile
	var wall_layer: TileMapLayer = world.get_node_or_null("walls")
	var ground_layer: TileMapLayer = world.get_node_or_null("ground")
	var wts: TileSet = wall_layer.tile_set if wall_layer != null else null
	var gts: TileSet = ground_layer.tile_set if ground_layer != null else null
	_check(wts != null and wts.get_physics_layers_count() == 1,
		"у TileSet стен один физический слой")
	_check(wts != null and wts.get_physics_layer_collision_layer(0) == 1,
		"слой коллизии стен = 1 (world)")
	if wts != null:
		var wsrc := wts.get_source(0) as TileSetAtlasSource
		var wtd: TileData = wsrc.get_tile_data(Vector2i(0, 0), 0)
		_check(wtd != null and wtd.get_collision_polygons_count(0) > 0,
			"у тайла стены есть коллизионный полигон")
	_check(gts == null or gts.get_physics_layers_count() == 0,
		"у земли нет физических слоёв")
	# стена реально перекрывает: tile в стене не проходим
	var wall_cell: Vector2i = (wall_layer as TileMapLayer).get_used_cells()[0]
	_check(not bool(world.call("is_walkable",
		(wall_layer as TileMapLayer).map_to_local(wall_cell))),
		"тайл стены не проходим")
	# интерьеры: полы домов, цехов и бункеров должны быть проходимы
	var fs: Dictionary = world.call("floor_stats")
	var fl: int = int(fs["floor_tiles"])
	var fw: int = int(fs["floor_walkable"])
	print("--- интерьеры: тайлов пола ", fl, ", из них проходимо ", fw,
		" (", int(100.0 * float(fw) / maxf(1.0, float(fl))), "%)")
	_check(fl >= 2000, "полов внутри построек достаточно (факт " + str(fl) + ")")
	_check(fw >= int(float(fl) * 0.85),
		"интерьеры проходимы: " + str(fw) + "/" + str(fl))


## Проверяет, что лучи между центрами соседних зон не упираются в сплошную стену.
func _roads_walkable(world: Node2D, zones: Dictionary) -> bool:
	var pairs: Array = [["kordon", "village"], ["kordon", "bunker"],
		["village", "factory"], ["village", "swamp"], ["factory", "anomaly_field"]]
	for pair in pairs:
		var a: Rect2 = zones[pair[0]]
		var b: Rect2 = zones[pair[1]]
		var pa: Vector2 = a.position + a.size * 0.5
		var pb: Vector2 = b.position + b.size * 0.5
		var steps := 60
		var blocked := 0
		for i in steps + 1:
			var p: Vector2 = pa.lerp(pb, float(i) / float(steps))
			if not bool(world.call("is_walkable", p)):
				blocked += 1
		if blocked > steps / 2:
			print("    (прямая ", pair[0], "->", pair[1], ": перекрыто ", blocked, "/", steps, ")")
			return false
	return true


# ----------------------------------------------------------------- миникарта
func _save_minimap(world: Node2D) -> Image:
	var img: Image = world.call("debug_minimap", MINIMAP_PPT)
	_check(img != null, "debug_minimap вернул изображение")
	if img == null:
		return null
	var err: int = img.save_png(MINIMAP_PATH)
	_check(err == OK, "миникарта сохранена: " + ProjectSettings.globalize_path(MINIMAP_PATH))
	print("--- миникарта: ", img.get_width(), "x", img.get_height(), " px, легенда: ")
	print("    жёлтый рельеф = пустошь/трава, серый = бетон/гравий, тёмный = асфальт,")
	print("    почти белый = стены, светло-голубой = заборы, зелёный = токсичная вода,")
	print("    рамки зон цветные, малиновые кольца = аномалии, красные точки = враги,")
	print("    жёлтые точки = лут, синие = NPC, зелёная = точка спавна игрока.")
	return img


## Один и тот же сид должен давать тот же мир, другой сид — другой.
func determinism_ok(world_script: Script, img: Image) -> bool:
	if img == null:
		return false
	var hash_a: int = hash(img.get_data())
	var world2: Node2D = world_script.new()
	root.add_child(world2)
	var data2: Dictionary = world2.call("generate", SEED)
	var img2: Image = world2.call("debug_minimap", MINIMAP_PPT)
	var hash_b: int = hash(img2.get_data()) if img2 != null else 0
	print("--- хеш миникарты: сид ", SEED, " = ", hash_a, ", повтор = ", hash_b)
	root.remove_child(world2)
	world2.free()
	var world3: Node2D = world_script.new()
	root.add_child(world3)
	world3.call("generate", SEED + 1)
	var img3: Image = world3.call("debug_minimap", MINIMAP_PPT)
	var hash_c: int = hash(img3.get_data()) if img3 != null else 0
	print("--- хеш миникарты: сид ", SEED + 1, " = ", hash_c)
	root.remove_child(world3)
	world3.free()
	return hash_a == hash_b and hash_a != hash_c and not (data2 as Dictionary).is_empty()





