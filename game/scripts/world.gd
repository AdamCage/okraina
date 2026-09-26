class_name World
extends Node2D
## Одна большая процедурная локация Зоны (260x200 тайлов по 128 px).
## Земля и стены — TileMapLayer с TileSet, собранным в рантайме из атласов
## Assets; декали — AtlasTexture-спрайты; пропы — StaticBody2D.
## generate() возвращает данные спавна для game.gd (враги, аномалии, лут, зоны).
## Всё детерминировано: один и тот же world_seed даёт один и тот же мир.

const TILE := 128              ## сторона тайла в пикселях (см. Assets.TILE)
const W := 260                 ## ширина карты в тайлах
const H := 200                 ## высота карты в тайлах
const BORDER := 3              ## толщина непроходимой опушки по краям карты
const SAFE_RADIUS := 700.0     ## ближе этого к точке спавна врагов не ставим

## Идентификаторы зон: индекс в сетке зон = позиция в списке + 1 (0 — «глушь»).
const ZONE_IDS: PackedStringArray = [
	"kordon", "village", "swamp", "factory", "bunker", "anomaly_field", "forest", "rail",
]

## Прямоугольники зон в тайлах (x, y, w, h).
const ZONE_TILES: Array = [
	Rect2i(16, 140, 44, 36),     # kordon  — блокпост на юго-западе
	Rect2i(50, 44, 58, 58),      # village — брошенная деревня
	Rect2i(8, 8, 40, 40),        # swamp   — токсичное болото
	Rect2i(168, 56, 68, 70),     # factory — завод
	Rect2i(104, 146, 48, 42),    # bunker  — бетонный бункер
	Rect2i(112, 78, 44, 46),     # anomaly_field — аномальное поле
	Rect2i(64, 106, 38, 24),     # forest  — южный лес
	Rect2i(56, 130, 196, 10),    # rail    — железная дорога
]

# --- материалы земли (индексы в Assets.GROUND_MATS) ---
# Индексы заполняются в _init_indices(): в инициализаторах полей GDScript
# запрещает вызовы методов автолоадов.
var M_ASPHALT: int = 0
var M_DIRT: int = 0
var M_GRASS: int = 0
var M_GRASS_TOX: int = 0
var M_CONCRETE: int = 0
var M_GRAVEL: int = 0
var M_MUD: int = 0
var M_METAL: int = 0
var M_BUNKER: int = 0
var M_WATER_TOX: int = 0
var M_ASH: int = 0
var M_RAILBED: int = 0

# --- стили стен (индексы в Assets.WALL_STYLES) ---
var S_CONCRETE: int = 0
var S_BRICK: int = 0
var S_PLASTER: int = 0
var S_METAL: int = 0
var S_CONTAINER: int = 0
var S_WOOD: int = 0
var S_BUNKER: int = 0
var S_TILES: int = 0
var S_FENCE: int = 0
var S_RUBBLE: int = 0

# --- декали (индексы в Assets.DECAL_NAMES) ---
var D_CRACK: int = 0
var D_CRACK_BIG: int = 0
var D_RUBBLE: int = 0
var D_MOSS: int = 0
var D_PUDDLE: int = 0
var D_PUDDLE_TOX: int = 0
var D_BLOOD_A: int = 0
var D_BLOOD_B: int = 0
var D_BLOOD_C: int = 0
var D_SCORCH: int = 0
var D_TIRE: int = 0
var D_BONES: int = 0
var D_BULLETS: int = 0
var D_OIL: int = 0
var D_LEAVES: int = 0
var D_TUFT: int = 0

## Кэш автолоада Assets.
## Глобальные имена автолоадов не видны при --check-only, поэтому ссылку на
## синглтон берём из дерева сцены — в игре и в headless-тестах это тот же узел.
var _assets_cache: Node = null


func _assets() -> Node:
	if _assets_cache == null:
		var loop: MainLoop = Engine.get_main_loop()
		if loop is SceneTree:
			_assets_cache = (loop as SceneTree).root.get_node_or_null("Assets")
		if _assets_cache == null:
			_assets_cache = load("res://autoload/assets.gd").new()
	return _assets_cache


## Кэширует индексы тайлов/декалей из автолоада Assets (один раз за прогон).
func _init_indices() -> void:
	M_ASPHALT = _assets().ground_index("asphalt")
	M_DIRT = _assets().ground_index("dirt")
	M_GRASS = _assets().ground_index("grass_dry")
	M_GRASS_TOX = _assets().ground_index("grass_toxic")
	M_CONCRETE = _assets().ground_index("concrete")
	M_GRAVEL = _assets().ground_index("gravel")
	M_MUD = _assets().ground_index("mud")
	M_METAL = _assets().ground_index("metal_floor")
	M_BUNKER = _assets().ground_index("bunker_tile")
	M_WATER_TOX = _assets().ground_index("water_toxic")
	M_ASH = _assets().ground_index("ash")
	M_RAILBED = _assets().ground_index("railbed")
	S_CONCRETE = _assets().wall_index("concrete")
	S_BRICK = _assets().wall_index("brick")
	S_PLASTER = _assets().wall_index("plaster")
	S_METAL = _assets().wall_index("metal")
	S_CONTAINER = _assets().wall_index("container")
	S_WOOD = _assets().wall_index("wood")
	S_BUNKER = _assets().wall_index("bunker")
	S_TILES = _assets().wall_index("tiles")
	S_FENCE = _assets().wall_index("fence")
	S_RUBBLE = _assets().wall_index("rubble")
	D_CRACK = _assets().decal_index("crack")
	D_CRACK_BIG = _assets().decal_index("crack_big")
	D_RUBBLE = _assets().decal_index("rubble")
	D_MOSS = _assets().decal_index("moss")
	D_PUDDLE = _assets().decal_index("puddle")
	D_PUDDLE_TOX = _assets().decal_index("puddle_toxic")
	D_BLOOD_A = _assets().decal_index("blood_a")
	D_BLOOD_B = _assets().decal_index("blood_b")
	D_BLOOD_C = _assets().decal_index("blood_c")
	D_SCORCH = _assets().decal_index("scorch")
	D_TIRE = _assets().decal_index("tire")
	D_BONES = _assets().decal_index("bones")
	D_BULLETS = _assets().decal_index("bullets")
	D_OIL = _assets().decal_index("oil")
	D_LEAVES = _assets().decal_index("leaves")
	D_TUFT = _assets().decal_index("tuft")

# ---------------------------------------------------------------- состояние
var rng := RandomNumberGenerator.new()
var world_seed := 0
var generation_ms := 0
var spawn_point := Vector2.ZERO
var zones: Dictionary = {}
var enemy_spawns: Array = []
var anomalies: Array = []
var loot_spots: Array = []
var prop_count := 0
var decal_count := 0
var container_count := 0
var npc_count := 0

var ground_layer: TileMapLayer
var wall_layer: TileMapLayer
var decal_root: Node2D
var overlay_root: Node2D
var object_root: Node2D

var _mat: PackedByteArray          ## материал земли на тайл
var _wall: PackedByteArray         ## стиль стены + 1 (0 — стены нет)
var _road: PackedByteArray         ## 1 — дорога или тропа
var _floor: PackedByteArray        ## 1 — пол внутри постройки
var _zone: PackedByteArray         ## индекс зоны + 1 (0 — глушь)
var _solid: Array = []             ## Rect2 коллизий пропов (для is_walkable)
var _lairs: Array = []             ## точки спавна врагов (кровь у логова)
var _taken: Array = []             ## Rect2i занятой застройки
var _noise_a: FastNoiseLite
var _noise_b: FastNoiseLite
var _noise_c: FastNoiseLite
var _wall_ready := false
var _pending_npcs: Array = []         ## [{id, name, pos}] — создаются в конце
var _pending_containers: Array = []   ## [{pos, tier, kind}]
var _boss_spots: Array = []           ## [{pos, type, level, zone}]
var _prop_points: Array = []          ## Vector2 — позиции пропов (для миникарты)
var _tree_points: Array = []          ## Vector2 — позиции деревьев (для миникарты)
var _container_points: Array = []     ## Vector2 — позиции контейнеров

# ---------------------------------------------------------------- утилиты
func _idx(x: int, y: int) -> int:
	return y * W + x


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H


func tile_center(t: Vector2i) -> Vector2:
	return Vector2((float(t.x) + 0.5) * float(TILE), (float(t.y) + 0.5) * float(TILE))


func world_to_tile(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / float(TILE))), int(floor(pos.y / float(TILE))))


## Индекс зоны в сетке по её идентификатору (0 — «глушь»).
func zone_index(id: String) -> int:
	return ZONE_IDS.find(id) + 1


## Стабильный хеш координат: варианты тайлов не «дрожат» между запусками.
func _hash2(x: int, y: int) -> int:
	var h: int = x * 374761393 + y * 668265263 + world_seed * 2147483647 + 1442695040
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 15))


func _variant_of(x: int, y: int, count: int) -> int:
	if count <= 1:
		return 0
	return _hash2(x, y) % count


func _set_mat(x: int, y: int, mat: int) -> void:
	if _in_bounds(x, y):
		_mat[_idx(x, y)] = mat


func _mat_at(x: int, y: int) -> int:
	return _mat[_idx(x, y)] if _in_bounds(x, y) else M_DIRT


func _set_mat_rect(r: Rect2i, mat: int) -> void:
	for y in range(maxi(0, r.position.y), mini(H, r.position.y + r.size.y)):
		for x in range(maxi(0, r.position.x), mini(W, r.position.x + r.size.x)):
			_mat[_idx(x, y)] = mat


func _set_wall(x: int, y: int, style: int) -> void:
	if _in_bounds(x, y):
		_wall[_idx(x, y)] = style + 1


func _wall_at(x: int, y: int) -> int:
	return _wall[_idx(x, y)] if _in_bounds(x, y) else 0


func _set_wall_rect(r: Rect2i, style: int) -> void:
	for y in range(maxi(0, r.position.y), mini(H, r.position.y + r.size.y)):
		for x in range(maxi(0, r.position.x), mini(W, r.position.x + r.size.x)):
			_wall[_idx(x, y)] = style + 1


func _zone_at_tile(x: int, y: int) -> int:
	return _zone[_idx(x, y)] if _in_bounds(x, y) else 0


## Есть ли стена в тайле (с учётом выхода за карту — там тоже стена).
func _blocked(x: int, y: int) -> bool:
	if not _in_bounds(x, y):
		return true
	return _wall[_idx(x, y)] != 0


## Свободен ли тайл для постановки объекта: без стен, не на дороге и не в поле.
func _free_tile(x: int, y: int) -> bool:
	if _blocked(x, y):
		return false
	if _road[_idx(x, y)] != 0:
		return false
	return not _overlaps_solid(tile_center(Vector2i(x, y)), 40.0)


func _overlaps_solid(pos: Vector2, radius: float) -> bool:
	var box := Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	for r in _solid:
		if (r as Rect2).intersects(box):
			return true
	return false


func _taken_rect(r: Rect2i, grow: int) -> bool:
	var g := r.grow(grow)
	for t in _taken:
		if (t as Rect2i).intersects(g):
			return true
	return false

# ---------------------------------------------------------------- узлы сцены
## Создаёт TileMapLayer «ground»/«walls» с TileSet, собранным в рантайме.
func _setup_nodes() -> void:
	y_sort_enabled = true
	if ground_layer == null:
		ground_layer = TileMapLayer.new()
		ground_layer.name = "ground"
		ground_layer.tile_set = _build_tileset(_assets().ground, false)
		ground_layer.z_index = -10
		add_child(ground_layer)
	if wall_layer == null:
		wall_layer = TileMapLayer.new()
		wall_layer.name = "walls"
		wall_layer.tile_set = _build_tileset(_assets().wall, true)
		wall_layer.z_index = -2
		add_child(wall_layer)
		var src := wall_layer.tile_set.get_source(0) as TileSetAtlasSource
		_wall_ready = src != null and src.get_tiles_count() > 0
	if decal_root == null:
		decal_root = Node2D.new()
		decal_root.name = "decals"
		decal_root.z_index = -6
		add_child(decal_root)
	if overlay_root == null:
		overlay_root = Node2D.new()
		overlay_root.name = "overlays"
		overlay_root.z_index = -4
		add_child(overlay_root)
	if object_root == null:
		object_root = Node2D.new()
		object_root.name = "objects"
		object_root.y_sort_enabled = true
		add_child(object_root)


## TileSet из целого атласа: регион 128x128 => (колонка = вариант, строка = материал).
func _build_tileset(tex: Texture2D, with_collision: bool) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	if with_collision:
		ts.add_physics_layer(0)
		ts.set_physics_layer_collision_layer(0, 1)
		ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = tex if tex != null else _assets().placeholder()
	src.texture_region_size = Vector2i(TILE, TILE)
	var cols: int = int(src.texture.get_width() / TILE)
	var rows: int = int(src.texture.get_height() / TILE)
	# Источник обязан попасть в TileSet ДО create_tile: TileData берёт число
	# физических слоёв у TileSet в момент создания тайла, иначе коллизии нет.
	ts.add_source(src, 0)
	for r in rows:
		for c in cols:
			var coord := Vector2i(c, r)
			src.create_tile(coord)
			if with_collision:
				var td: TileData = src.get_tile_data(coord, 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-62.0, -64.0), Vector2(62.0, -64.0),
					Vector2(62.0, 64.0), Vector2(-62.0, 64.0),
				]))
	return ts


# ------------------------------------------------------------- точка входа
## Строит мир целиком и возвращает словарь данных для game.gd.
func generate(seed_value: int) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	world_seed = seed_value
	_init_indices()
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	_reset_state()
	_reset_grid()
	_setup_noise()
	_setup_nodes()
	_clear_world_nodes()
	_mark_zones()
	_paint_terrain()
	_paint_roads()
	_paint_trails()
	_paint_railway()
	_build_kordon()
	_build_village()
	_build_factory()
	_build_bunker()
	_build_swamp()
	_build_anomaly_field()
	_paint_border()
	_upload_ground()
	_upload_walls()
	_scatter_props()
	_place_objects()
	_plan_spawns()
	_scatter_decals()
	_add_overlays()
	if not is_walkable(spawn_point):
		spawn_point = _nearest_walkable(spawn_point)
	generation_ms = Time.get_ticks_msec() - t0
	var data := {
		"spawn": spawn_point,
		"zones": zones,
		"enemy_spawns": enemy_spawns,
		"anomalies": anomalies,
		"loot_spots": loot_spots,
		"size_tiles": Vector2i(W, H),
		"tile_size": TILE,
		"world_seed": world_seed,
		"generation_ms": generation_ms,
		"props": prop_count,
		"decals": decal_count,
		"containers": container_count,
		"npcs": npc_count,
	}
	print("[world] seed=", world_seed, " зон=", zones.size(), " врагов=", enemy_spawns.size(),
		" аномалий=", anomalies.size(), " лута=", loot_spots.size(),
		" пропов=", prop_count, " декалей=", decal_count,
		" контейнеров=", container_count, " NPC=", npc_count, " мс=", generation_ms)
	return data


func _reset_state() -> void:
	spawn_point = Vector2.ZERO
	zones = {}
	enemy_spawns = []
	anomalies = []
	loot_spots = []
	_solid.clear()
	_lairs.clear()
	_taken.clear()
	_pending_npcs.clear()
	_pending_containers.clear()
	_boss_spots.clear()
	_prop_points.clear()
	_tree_points.clear()
	_container_points.clear()
	prop_count = 0
	decal_count = 0
	container_count = 0
	npc_count = 0


func _reset_grid() -> void:
	_mat = PackedByteArray()
	_mat.resize(W * H)
	_mat.fill(M_DIRT)
	_wall = PackedByteArray()
	_wall.resize(W * H)
	_wall.fill(0)
	_road = PackedByteArray()
	_road.resize(W * H)
	_road.fill(0)
	_floor = PackedByteArray()
	_floor.resize(W * H)
	_floor.fill(0)
	_zone = PackedByteArray()
	_zone.resize(W * H)
	_zone.fill(0)


func _clear_world_nodes() -> void:
	for c in get_children():
		if c == ground_layer or c == wall_layer or c == decal_root \
				or c == overlay_root or c == object_root:
			continue
		remove_child(c)
		c.queue_free()
	for root_node in [decal_root, overlay_root, object_root]:
		if root_node == null:
			continue
		for c in root_node.get_children():
			root_node.remove_child(c)
			c.queue_free()
	if ground_layer != null:
		ground_layer.clear()
	if wall_layer != null:
		wall_layer.clear()


func _setup_noise() -> void:
	_noise_a = FastNoiseLite.new()
	_noise_a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_a.seed = world_seed + 101
	_noise_a.frequency = 0.018
	_noise_b = FastNoiseLite.new()
	_noise_b.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_b.seed = world_seed + 202
	_noise_b.frequency = 0.06
	_noise_c = FastNoiseLite.new()
	_noise_c.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_c.seed = world_seed + 303
	_noise_c.frequency = 0.085


## Размечает прямоугольники зон (мировые координаты + индекс в сетке).
func _mark_zones() -> void:
	for i in ZONE_TILES.size():
		var r: Rect2i = ZONE_TILES[i]
		zones[ZONE_IDS[i]] = Rect2(Vector2(r.position) * float(TILE), Vector2(r.size) * float(TILE))
		for y in range(maxi(0, r.position.y), mini(H, r.position.y + r.size.y)):
			for x in range(maxi(0, r.position.x), mini(W, r.position.x + r.size.x)):
				_zone[_idx(x, y)] = i + 1


# ------------------------------------------------------------ выгрузка тайлов
func _upload_ground() -> void:
	if ground_layer == null:
		return
	var cols: int = _assets().GROUND_COLS
	for y in H:
		for x in W:
			var m: int = _mat[_idx(x, y)]
			ground_layer.set_cell(Vector2i(x, y), 0, Vector2i(_variant_of(x, y, cols), m))


## Индексы зон (позиция в ZONE_IDS + 1).
const ZONE_KORDON := 1
const ZONE_VILLAGE := 2
const ZONE_SWAMP := 3
const ZONE_FACTORY := 4
const ZONE_BUNKER := 5
const ZONE_ANOMALY := 6
const ZONE_FOREST := 7
const ZONE_RAIL := 8


# ------------------------------------------------------------- поверхность
## Базовая заливка: материал по зоне + шум, переходы между зонами рваные.
func _paint_terrain() -> void:
	for y in H:
		for x in W:
			_mat[_idx(x, y)] = _terrain_mat(x, y)


func _terrain_mat(x: int, y: int) -> int:
	var z: int = _zone_at_tile(x, y)
	var m: int = _zone_base_mat(z, x, y)
	return _blend_zone_mat(z, x, y, m)


## Материал по «характеру» зоны. Шум берётся со смещением (джиттер), поэтому
## границы пятен получаются рваными, а не по линейке.
func _zone_base_mat(z: int, x: int, y: int) -> int:
	var b: float = _noise_b.get_noise_2d(float(x + int(_noise_b.get_noise_2d(float(x), float(y)) * 3.0)), float(y))
	var c: float = _noise_c.get_noise_2d(float(x), float(y + b * 4.0))
	var a: float = _noise_a.get_noise_2d(float(x), float(y))
	match z:
		ZONE_SWAMP:
			if c > 0.2:
				return M_WATER_TOX
			if c > 0.02 or b < -0.4:
				return M_MUD
			if b > 0.5:
				return M_GRASS
			return M_GRASS_TOX
		ZONE_VILLAGE:
			if b < -0.35:
				return M_DIRT
			if b > 0.62:
				return M_GRAVEL
			return M_GRASS
		ZONE_FACTORY:
			if c > 0.52:
				return M_ASH
			if b < -0.12:
				return M_CONCRETE
			return M_GRAVEL
		ZONE_BUNKER:
			if c > 0.45:
				return M_ASH
			if b > 0.34:
				return M_CONCRETE
			return M_GRAVEL
		ZONE_KORDON:
			if b > 0.46:
				return M_CONCRETE
			if b < -0.3:
				return M_GRASS
			return M_DIRT
		ZONE_ANOMALY:
			if c > 0.24 or b > 0.22:
				return M_ASH
			return M_DIRT
		ZONE_FOREST:
			return M_GRASS if b > -0.12 else M_DIRT
		ZONE_RAIL:
			return M_GRAVEL
		_:
			if c > 0.56:
				return M_ASH
			if a < -0.22:
				return M_DIRT
			if b > 0.64:
				return M_GRAVEL
			return M_GRASS


## Стыки зон: у самой границы иногда заимствуем материал соседа — так глушь
## переходит в болото или в бетон завода без резкой линии.
func _blend_zone_mat(z: int, x: int, y: int, base: int) -> int:
	var offs: Array = [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]
	for o in offs:
		var zi: int = _zone_at_tile(x + o.x, y + o.y)
		if zi == 0 or zi == z:
			continue
		var blend: float = _noise_b.get_noise_2d(float(x + o.x * 3), float(y + o.y * 3))
		if blend > 0.22:
			return _zone_base_mat(zi, x, y)
	return base


# ------------------------------------------------------- дороги и железка
## Асфальтовые дороги между зонами с гравийными обочинами.
func _paint_roads() -> void:
	var roads: Array = [
		# кордон -> деревня
		[Vector2i(34, 148), Vector2i(36, 124), Vector2i(52, 108), Vector2i(64, 98), Vector2i(76, 86)],
		# кордон -> бункер
		[Vector2i(44, 152), Vector2i(86, 154), Vector2i(116, 150), Vector2i(128, 149)],
		# деревня -> аномальное поле
		[Vector2i(96, 94), Vector2i(110, 102), Vector2i(124, 112), Vector2i(132, 120)],
		# деревня -> завод
		[Vector2i(104, 58), Vector2i(136, 66), Vector2i(168, 80)],
		# восточная магистраль вдоль железной дороги
		[Vector2i(58, 126), Vector2i(140, 120), Vector2i(176, 112), Vector2i(172, 104)],
		# завод -> бункер
		[Vector2i(198, 122), Vector2i(202, 148), Vector2i(154, 150), Vector2i(130, 149)],
		# аномальное поле -> железная дорога
		[Vector2i(130, 124), Vector2i(126, 134)],
	]
	for pts in roads:
		_paint_path(pts, 1)


## Тропы (узкие, гравий) — от дорог в глушь, чтобы мир не был «пустым».
func _paint_trails() -> void:
	var trails: Array = [
		[Vector2i(60, 148), Vector2i(30, 158)],
		[Vector2i(64, 98), Vector2i(72, 66), Vector2i(60, 52)],
		[Vector2i(188, 98), Vector2i(214, 88)],
		[Vector2i(132, 120), Vector2i(150, 108), Vector2i(168, 104)],
		[Vector2i(86, 154), Vector2i(84, 130), Vector2i(74, 116)],
		# тропа к болоту: от деревни на северо-запад, в туман
		[Vector2i(56, 58), Vector2i(46, 50), Vector2i(40, 38), Vector2i(34, 30)],
	]
	for pts in trails:
		_paint_path(pts, 0)


## Растеризация ломаной: half_width=1 — дорога (3 тайла), 0 — тропа (1 тайл).
func _paint_path(points: Array, half_width: int) -> void:
	for i in range(points.size() - 1):
		var a: Vector2i = points[i]
		var b: Vector2i = points[i + 1]
		var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
		for s in steps + 1:
			var t: float = 0.0 if steps == 0 else float(s) / float(steps)
			var px: int = int(round(lerpf(float(a.x), float(b.x), t)))
			var py: int = int(round(lerpf(float(a.y), float(b.y), t)))
			_stamp_path(px, py, half_width)


func _stamp_path(cx: int, cy: int, half_width: int) -> void:
	var r: int = maxi(0, half_width)
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if not _in_bounds(x, y):
				continue
			if _wall[_idx(x, y)] != 0:
				continue
			_mat[_idx(x, y)] = M_ASPHALT if r > 0 else M_GRAVEL
			_road[_idx(x, y)] = 1
	if half_width > 0:
		# обочина: гравий по краям дороги
		for y in range(cy - r - 1, cy + r + 2):
			for x in range(cx - r - 1, cx + r + 2):
				if not _in_bounds(x, y) or _road[_idx(x, y)] != 0:
					continue
				if _mat[_idx(x, y)] in [M_GRASS, M_DIRT, M_GRASS_TOX]:
					_mat[_idx(x, y)] = M_GRAVEL


## Железная дорога: две насыпи railbed + гравий по бокам. Дорог не перекрывает.
func _paint_railway() -> void:
	var y0: int = 133
	for x in range(56, 252):
		for y in range(y0 - 2, y0 + 4):
			if not _in_bounds(x, y) or _road[_idx(x, y)] != 0:
				continue
			_mat[_idx(x, y)] = M_RAILBED if (y == y0 or y == y0 + 1) else M_GRAVEL
		_road[_idx(x, y0)] = 1
		_road[_idx(x, y0 + 1)] = 1


## Непроходимая опушка по краю карты: игрок не выйдет за пределы локации.
func _paint_border() -> void:
	for y in H:
		for x in W:
			var edge: bool = x < BORDER or y < BORDER or x >= W - BORDER or y >= H - BORDER
			if not edge:
				continue
			var v: int = _hash2(x, y) % 3
			var style: int = S_RUBBLE if v == 0 else (S_CONCRETE if v == 1 else S_FENCE)
			_wall[_idx(x, y)] = style + 1
			_mat[_idx(x, y)] = M_GRAVEL if v != 0 else M_DIRT

# ------------------------------------------------------------- постройки
## Строит дом/цех: периметр стен, пол внутри, проёмы шириной 2+ тайла.
## r — внешний прямоугольник вместе со стенами. Возвращает внутренний Rect2i,
## либо пустой Rect2i, если место занято (дорога или другая постройка).
func _build_room(r: Rect2i, wall_style: int, floor_mat: int,
		doors: Array, ruin: bool = false) -> Rect2i:
	if r.size.x < 5 or r.size.y < 5:
		return Rect2i()
	if _taken_rect(r, 2) or _has_road(r, 1):
		return Rect2i()
	# только периметр: вся плита заливается стенами не должна — внутри пол
	for x in range(r.position.x, r.end.x):
		_set_wall(x, r.position.y, wall_style)
		_set_wall(x, r.end.y - 1, wall_style)
	for y in range(r.position.y, r.end.y):
		_set_wall(r.position.x, y, wall_style)
		_set_wall(r.end.x - 1, y, wall_style)
	var inner := r.grow(-1)
	if inner.size.x < 3 or inner.size.y < 3:
		return Rect2i()
	_set_mat_rect(inner, floor_mat)
	for y in range(inner.position.y, inner.position.y + inner.size.y):
		for x in range(inner.position.x, inner.position.x + inner.size.x):
			_floor[_idx(x, y)] = 1
	# проёмы: каждая запись [сторона (0-3), ширина, доля вдоль стены]
	for d in doors:
		_open_wall(r, int(d[0]), int(d[1]), float(d[2]) if d.size() > 2 else 0.5)
	if ruin:
		_ruin_room(r, inner)
	_taken.append(r.grow(2))
	return inner


## Вырезает проём в стене постройки: сторона 0=N, 1=E, 2=S, 3=W.
func _open_wall(r: Rect2i, side: int, width: int, at: float) -> void:
	var w: int = maxi(2, width)
	var frac: float = clampf(at, 0.15, 0.85)
	if side == 0 or side == 2:
		var y: int = r.position.y if side == 0 else r.position.y + r.size.y - 1
		var cx: int = r.position.x + int(round(float(r.size.x - 1) * frac))
		for i in w:
			_set_wall(clampi(cx - w / 2 + i, r.position.x, r.position.x + r.size.x - 1), y, -1)
	else:
		var x: int = r.position.x if side == 3 else r.position.x + r.size.x - 1
		var cy: int = r.position.y + int(round(float(r.size.y - 1) * frac))
		for i in w:
			_set_wall(x, clampi(cy - w / 2 + i, r.position.y, r.position.y + r.size.y - 1), -1)


## Разрушения: дыры в стенах и «протоптанный» пол внутри.
func _ruin_room(r: Rect2i, inner: Rect2i) -> void:
	for i in rng.randi_range(2, 5):
		var side: int = rng.randi_range(0, 3)
		if side == 0 or side == 2:
			var y: int = r.position.y if side == 0 else r.position.y + r.size.y - 1
			var x: int = rng.randi_range(r.position.x + 1, r.position.x + r.size.x - 2)
			_set_wall(x, y, -1)
			if rng.randf() < 0.5:
				_set_wall(x + 1, y, -1)
		else:
			var xx: int = r.position.x if side == 3 else r.position.x + r.size.x - 1
			var yy: int = rng.randi_range(r.position.y + 1, r.position.y + r.size.y - 2)
			_set_wall(xx, yy, -1)
			if rng.randf() < 0.5:
				_set_wall(xx, yy + 1, -1)
	for i in rng.randi_range(3, 7):
		var px: int = rng.randi_range(inner.position.x, inner.position.x + inner.size.x - 1)
		var py: int = rng.randi_range(inner.position.y, inner.position.y + inner.size.y - 1)
		_set_mat(px, py, M_DIRT if rng.randf() < 0.6 else M_GRAVEL)


## Есть ли дорога в прямоугольнике (с запасом grow) — под застройку не годится.
func _has_road(r: Rect2i, grow: int) -> bool:
	var g := r.grow(grow)
	for y in range(maxi(0, g.position.y), mini(H, g.position.y + g.size.y)):
		for x in range(maxi(0, g.position.x), mini(W, g.position.x + g.size.x)):
			if _road[_idx(x, y)] != 0:
				return true
	return false


## Линия стены нужного стиля между двумя тайлами.
func _wall_line(a: Vector2i, b: Vector2i, style: int) -> void:
	var pt := Vector2i(a.x, a.y)
	_set_wall(pt.x, pt.y, style)
	var dx: int = signi(b.x - a.x)
	var dy: int = signi(b.y - a.y)
	while pt != b:
		if pt.x != b.x:
			pt.x += dx
		if pt.y != b.y:
			pt.y += dy
		_set_wall(pt.x, pt.y, style)

# ------------------------------------------------------------- пропы и декали
## Ориентировочные размеры пропов на случай, если спрайт ещё не сгенерирован.
const PROP_SIZES: Dictionary = {
	"barrel_rust": Vector2(48, 64), "barrel_toxic": Vector2(48, 64),
	"crate_wood": Vector2(56, 56), "crate_metal": Vector2(56, 56),
	"car_wreck": Vector2(240, 120), "bus_wreck": Vector2(320, 140),
	"tree_dead": Vector2(140, 220), "tree_pine": Vector2(160, 260),
	"bush_dry": Vector2(90, 70), "rock_a": Vector2(120, 90), "rock_b": Vector2(90, 70),
	"tent": Vector2(150, 120), "campfire": Vector2(70, 60), "power_pole": Vector2(70, 260),
	"grave": Vector2(60, 80), "well": Vector2(130, 140), "sign_radiation": Vector2(60, 110),
	"bunker_door": Vector2(200, 140), "fence_panel": Vector2(128, 90),
	"pipe_ruin": Vector2(170, 90), "tree_pine_s": Vector2(120, 190),
}


## Размер пропа: у реального спрайта, иначе — паспортный из таблицы выше.
func _prop_size(name: String) -> Vector2:
	if _assets().has_sprite(name):
		var s: Vector2 = _assets().sprite_size(name)
		if s.x > 8.0 and s.y > 8.0:
			return s
	var nominal: Variant = PROP_SIZES.get(name, Vector2(64, 64))
	return nominal


## Проп: спрайт «стоит» на точке (offset вверх), коллизия — у основания.
## solid=false — куст или мелочь, сквозь которые можно пройти.
func _add_prop(name: String, pos: Vector2, scale_f: float = 1.0, solid: bool = true) -> void:
	if prop_count >= 470:
		return
	var size: Vector2 = _prop_size(name) * scale_f
	var node: Node2D
	if solid:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		node = body
	else:
		node = Node2D.new()
	node.name = "prop_" + name
	node.position = pos
	var spr := Sprite2D.new()
	spr.name = "sprite"
	spr.texture = _assets().sprite(name)
	spr.scale = Vector2(scale_f, scale_f)
	spr.offset = Vector2(0.0, -size.y * 0.5)
	node.add_child(spr)
	if solid:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(maxf(18.0, size.x * 0.5), maxf(20.0, size.y * 0.16))
		var col := CollisionShape2D.new()
		col.name = "shape"
		col.shape = shape
		col.position = Vector2(0.0, -shape.size.y * 0.5)
		node.add_child(col)
		_solid.append(Rect2(pos - shape.size * 0.5 - Vector2(0.0, shape.size.y), shape.size))
	node.add_to_group("props")
	add_child(node)
	prop_count += 1
	if name.begins_with("tree"):
		_tree_points.append(pos)
	else:
		_prop_points.append(pos)
# ------------------------------------------------------------------ кордон
## Блокпост: забор с воротами, КПП, палатки, колодец и два NPC рядом со спавном.
func _build_kordon() -> void:
	var fence := Rect2i(20, 144, 34, 26)
	# забор по периметру, ворота — там, где проходят дорога и тропа
	_wall_line(Vector2i(fence.position.x, fence.position.y),
		Vector2i(fence.end.x - 1, fence.position.y), S_FENCE)
	_wall_line(Vector2i(fence.position.x, fence.end.y - 1),
		Vector2i(fence.end.x - 1, fence.end.y - 1), S_FENCE)
	_wall_line(Vector2i(fence.position.x, fence.position.y),
		Vector2i(fence.position.x, fence.end.y - 1), S_FENCE)
	_wall_line(Vector2i(fence.end.x - 1, fence.position.y),
		Vector2i(fence.end.x - 1, fence.end.y - 1), S_FENCE)
	for i in 3:
		_set_wall(33 + i, fence.position.y, -1)       # север: дорога в деревню
		_set_wall(fence.end.x - 1, 151 + i, -1)       # восток: дорога в бункер
		_set_wall(30 + i, fence.end.y - 1, -1)        # юг: выход к дороге
		_set_wall(fence.position.x, 158 + i, -1)      # запад: тропа в глушь
	_set_mat_rect(Rect2i(26, 148, 12, 9), M_CONCRETE)
	_wall_line(Vector2i(24, 150), Vector2i(24, 156), S_CONCRETE)
	_wall_line(Vector2i(48, 146), Vector2i(48, 152), S_CONCRETE)
	_set_wall_rect(Rect2i(26, 146, 3, 1), S_CONTAINER)
	# точка спавна игрока — в паре тайлов от Сидоровича и Бармена
	spawn_point = tile_center(Vector2i(27, 162))
	_add_prop("tent", tile_center(Vector2i(23, 148)))
	_add_prop("tent", tile_center(Vector2i(41, 166)), 0.9)
	_add_prop("campfire", tile_center(Vector2i(31, 158)))
	_add_prop("well", tile_center(Vector2i(44, 148)))
	_add_prop("power_pole", tile_center(Vector2i(22, 152)))
	_add_prop("power_pole", tile_center(Vector2i(50, 148)))
	_add_prop("power_pole", tile_center(Vector2i(50, 164)))
	_add_prop("sign_radiation", tile_center(Vector2i(36, 145)))
	_add_prop("fence_panel", tile_center(Vector2i(46, 146)))
	_add_prop("barrel_rust", tile_center(Vector2i(35, 150)), 0.9)
	_add_prop("barrel_rust", tile_center(Vector2i(36, 151)), 0.9)
	_add_prop("crate_wood", tile_center(Vector2i(38, 149)))
	_add_prop("crate_metal", tile_center(Vector2i(39, 150)))
	_add_prop("car_wreck", tile_center(Vector2i(29, 152)))
	_add_prop("bush_dry", tile_center(Vector2i(21, 166)), 1.0, false)
	_add_prop("bush_dry", tile_center(Vector2i(52, 156)), 1.0, false)
	_add_loot(tile_center(Vector2i(32, 153)), 1)
	_add_loot(tile_center(Vector2i(42, 149)), 1)
	_add_loot(tile_center(Vector2i(24, 156)), 1)
	_add_loot(tile_center(Vector2i(45, 165)), 2)
	_pending_npcs.append({"id": "sidorovich", "name": "Сидорович",
		"pos": tile_center(Vector2i(30, 162))})
	_pending_npcs.append({"id": "barman", "name": "Бармен",
		"pos": tile_center(Vector2i(34, 164))})


# ----------------------------------------------------------------- деревня
## Брошенная деревня: 14 домов (пол + проёмы), заборы, колодцы, могилы, хабар.
func _build_village() -> void:
	var rect: Rect2i = ZONE_TILES[ZONE_VILLAGE - 1]
	var styles: Array = [S_PLASTER, S_BRICK, S_WOOD, S_PLASTER, S_BRICK, S_RUBBLE]
	var interiors: Array = []
	var tries := 0
	while interiors.size() < 14 and tries < 150:
		tries += 1
		var w: int = rng.randi_range(7, 11)
		var h: int = rng.randi_range(6, 9)
		var bx: int = rng.randi_range(rect.position.x + 2, rect.end.x - w - 2)
		var by: int = rng.randi_range(rect.position.y + 2, rect.end.y - h - 2)
		var bld := Rect2i(bx, by, w, h)
		var style: int = styles[rng.randi() % styles.size()]
		var ruin: bool = rng.randf() < 0.45
		var floor_mat: int = M_CONCRETE if rng.randf() < 0.55 else M_DIRT
		var side: int = rng.randi_range(0, 3)
		var doors: Array = [[side, rng.randi_range(2, 3), rng.randf_range(0.3, 0.7)]]
		if rng.randf() < 0.4:
			doors.append([(side + 2) % 4, 2, rng.randf_range(0.3, 0.7)])
		var inner := _build_room(bld, style, floor_mat, doors, ruin)
		if inner.size.x > 0:
			interiors.append(inner)
	# начинка домов: ящики, бочки, трубы и хабар
	for inner in interiors:
		var ir: Rect2i = inner
		var px: int = rng.randi_range(ir.position.x, ir.end.x - 1)
		var py: int = rng.randi_range(ir.position.y, ir.end.y - 1)
		if rng.randf() < 0.75:
			_add_prop("crate_wood", tile_center(Vector2i(px, py)), rng.randf_range(0.8, 1.05))
		if rng.randf() < 0.5:
			var qx: int = rng.randi_range(ir.position.x, ir.end.x - 1)
			var qy: int = rng.randi_range(ir.position.y, ir.end.y - 1)
			var bname: String = "barrel_toxic" if rng.randf() < 0.35 else "barrel_rust"
			_add_prop(bname, tile_center(Vector2i(qx, qy)), 0.9)
		if rng.randf() < 0.3:
			var rx: int = rng.randi_range(ir.position.x, ir.end.x - 1)
			var ry: int = rng.randi_range(ir.position.y, ir.end.y - 1)
			_add_prop("pipe_ruin", tile_center(Vector2i(rx, ry)), rng.randf_range(0.7, 1.0))
		if rng.randf() < 0.65:
			var lx: int = rng.randi_range(ir.position.x, ir.end.x - 1)
			var ly: int = rng.randi_range(ir.position.y, ir.end.y - 1)
			var lpos := tile_center(Vector2i(lx, ly))
			_add_loot(lpos, _tier_for(lpos))
			if rng.randf() < 0.85:
				_pending_containers.append({
					"pos": tile_center(Vector2i(clampi(lx + 2, 0, W - 1), ly)),
					"tier": rng.randi_range(1, 2), "kind": "crate",
				})
	# склады и ящики в огородах между домами
	for i in 12:
		var yard: Vector2 = _random_walkable_in(rect, 40)
		if yard == Vector2.INF:
			continue
		_pending_containers.append({"pos": yard, "tier": rng.randi_range(1, 2),
			"kind": "crate" if rng.randf() < 0.6 else "sack"})
	# заборы между домами, колодцы, могилы, столбы
	for i in 5:
		var fx: int = rng.randi_range(rect.position.x + 3, rect.end.x - 10)
		var fy: int = rng.randi_range(rect.position.y + 3, rect.end.y - 6)
		var horiz: bool = rng.randf() < 0.5
		var ln: int = rng.randi_range(5, 9)
		if horiz:
			_wall_line(Vector2i(fx, fy), Vector2i(fx + ln, fy), S_WOOD)
		else:
			_wall_line(Vector2i(fx, fy), Vector2i(fx, fy + ln), S_WOOD)
	_add_prop("well", tile_center(Vector2i(rect.position.x + 26, rect.position.y + 12)))
	_add_prop("well", tile_center(Vector2i(rect.position.x + 12, rect.position.y + 44)))
	_add_prop("power_pole", tile_center(Vector2i(rect.position.x + 6, rect.position.y + 20)))
	_add_prop("power_pole", tile_center(Vector2i(rect.position.x + 30, rect.position.y + 28)))
	_add_prop("power_pole", tile_center(Vector2i(rect.position.x + 20, rect.position.y + 46)))
	_add_prop("sign_radiation", tile_center(Vector2i(rect.position.x + 8, rect.position.y + 10)))
	for i in 6:
		var gx: int = rect.position.x + 4 + i * 2
		var gy: int = rect.position.y + 6 + (i % 2)
		_add_prop("grave", tile_center(Vector2i(gx, gy)), rng.randf_range(0.85, 1.1))
	_add_loot(tile_center(Vector2i(rect.position.x + 4, rect.position.y + 52)), 2)
	_add_prop("tent", tile_center(Vector2i(rect.position.x + 40, rect.position.y + 52)), 0.9)
	_add_prop("campfire", tile_center(Vector2i(rect.position.x + 38, rect.position.y + 54)))


# ------------------------------------------------------------------- завод
## Завод: четыре цеха, контейнерные стены, трубы, краны из металлолома.
func _build_factory() -> void:
	var rect: Rect2i = ZONE_TILES[ZONE_FACTORY - 1]
	var shops: Array = [
		[Rect2i(174, 60, 18, 14), S_CONCRETE, M_CONCRETE, true],
		[Rect2i(200, 58, 26, 18), S_METAL, M_METAL, false],
		[Rect2i(176, 92, 18, 14), S_CONCRETE, M_CONCRETE, true],
		[Rect2i(206, 96, 22, 16), S_METAL, M_METAL, false],
	]
	var interiors: Array = []
	for s in shops:
		var r: Rect2i = s[0]
		var doors: Array = [[1, 4, 0.5], [3, 3, 0.4]]
		var inner := _build_room(r, int(s[1]), int(s[2]), doors, bool(s[3]))
		if inner.size.x > 0:
			interiors.append(inner)
	# босс — в самом большом цехе
	if interiors.size() > 1:
		var boss_room: Rect2i = interiors[1]
		_boss_spots.append({"pos": tile_center(Vector2i(
			boss_room.position.x + boss_room.size.x / 2,
			boss_room.position.y + boss_room.size.y / 2)), "type": "mutant",
			"level": 6, "zone": ZONE_FACTORY})
	# контейнерный двор на северо-востоке завода
	for i in 4:
		var cy: int = 78 + i * 4
		_wall_line(Vector2i(196, cy), Vector2i(196 + rng.randi_range(5, 11), cy), S_CONTAINER)
	# трубы и краны из металлолома
	for i in 5:
		var px: int = rng.randi_range(rect.position.x + 6, rect.end.x - 4)
		var py: int = rng.randi_range(rect.position.y + 8, rect.end.y - 6)
		_add_prop("pipe_ruin", tile_center(Vector2i(px, py)), rng.randf_range(0.9, 1.4))
	for i in 4:
		var cx: int = rng.randi_range(rect.position.x + 8, rect.end.x - 6)
		var cyy: int = rng.randi_range(rect.position.y + 10, rect.end.y - 8)
		var cpos := tile_center(Vector2i(cx, cyy))
		_add_prop("crate_metal", cpos, 1.0)
		_add_prop("pipe_ruin", cpos + Vector2(90.0, -30.0), 0.8)
		_add_prop("crate_wood", cpos + Vector2(-70.0, 40.0), 0.9)
	# бочки, топливные лужи, техника
	for i in 16:
		var bx: int = rng.randi_range(rect.position.x + 4, rect.end.x - 3)
		var by: int = rng.randi_range(rect.position.y + 4, rect.end.y - 3)
		if not _free_tile(bx, by):
			continue
		var bname: String = "barrel_toxic" if rng.randf() < 0.45 else "barrel_rust"
		_add_prop(bname, tile_center(Vector2i(bx, by)), rng.randf_range(0.85, 1.1))
	for i in 3:
		var vx: int = rng.randi_range(rect.position.x + 6, rect.end.x - 4)
		var vy: int = rng.randi_range(rect.position.y + 6, rect.end.y - 4)
		_add_prop("car_wreck", tile_center(Vector2i(vx, vy)), rng.randf_range(0.9, 1.1))
	for i in 9:
		var lx: int = rng.randi_range(rect.position.x + 4, rect.end.x - 3)
		var ly: int = rng.randi_range(rect.position.y + 4, rect.end.y - 3)
		if not _free_tile(lx, ly):
			continue
		_add_loot(tile_center(Vector2i(lx, ly)), rng.randi_range(2, 3))
	for i in 10:
		var sx: int = rng.randi_range(rect.position.x + 5, rect.end.x - 4)
		var sy: int = rng.randi_range(rect.position.y + 5, rect.end.y - 4)
		if not _free_tile(sx, sy):
			continue
		_pending_containers.append({"pos": tile_center(Vector2i(sx, sy)),
			"tier": 3, "kind": "safe" if rng.randf() < 0.4 else "crate"})


# ------------------------------------------------------------------ бункер
## Бетонный бункер на юге: кольцо внешних стен, вход-коридор с севера,
## плиточный пол по всему комплексу, четыре зала и босс внутри.
func _build_bunker() -> void:
	var outer := Rect2i(108, 152, 40, 34)
	var inner := outer.grow(-1)
	# только периметр: внутри — пол и залы, а не сплошная плита бетона
	_wall_line(Vector2i(outer.position.x, outer.position.y),
		Vector2i(outer.end.x - 1, outer.position.y), S_CONCRETE)
	_wall_line(Vector2i(outer.position.x, outer.end.y - 1),
		Vector2i(outer.end.x - 1, outer.end.y - 1), S_CONCRETE)
	_wall_line(Vector2i(outer.position.x, outer.position.y),
		Vector2i(outer.position.x, outer.end.y - 1), S_CONCRETE)
	_wall_line(Vector2i(outer.end.x - 1, outer.position.y),
		Vector2i(outer.end.x - 1, outer.end.y - 1), S_CONCRETE)
	_set_mat_rect(inner, M_BUNKER)
	_mark_floor_rect(inner)
	# входной коридор с севера: пробивает внешнюю стену
	_carve_corridor(Rect2i(125, 146, 6, 8), M_CONCRETE)
	_set_wall_rect(Rect2i(124, 146, 1, 7), S_CONCRETE)
	_set_wall_rect(Rect2i(131, 146, 1, 7), S_CONCRETE)
	_add_prop("bunker_door", tile_center(Vector2i(127, 147)), 1.0)
	# залы и коридоры между ними
	var hall := _build_room(Rect2i(112, 154, 18, 14), S_BUNKER, M_BUNKER, [[0, 4, 0.95]], false)
	_build_room(Rect2i(116, 170, 14, 12), S_TILES, M_BUNKER, [[0, 2, 0.42]], false)
	_build_room(Rect2i(132, 156, 14, 10), S_TILES, M_METAL, [[3, 2, 0.5]], false)
	_build_room(Rect2i(132, 170, 12, 13), S_BUNKER, M_BUNKER, [[3, 3, 0.5]], false)
	_carve_corridor(Rect2i(119, 167, 3, 3), M_BUNKER)
	_carve_corridor(Rect2i(129, 159, 4, 3), M_METAL)
	_carve_corridor(Rect2i(129, 175, 4, 2), M_BUNKER)
	# хабар, техника и трупы внутри комплекса
	for i in 8:
		var lx: int = rng.randi_range(114, 144)
		var ly: int = rng.randi_range(156, 182)
		if _floor[_idx(lx, ly)] == 0:
			continue
		_add_loot(tile_center(Vector2i(lx, ly)), 3)
	for i in 6:
		var cx: int = rng.randi_range(114, 144)
		var cy: int = rng.randi_range(156, 182)
		if _floor[_idx(cx, cy)] == 0:
			continue
		_pending_containers.append({"pos": tile_center(Vector2i(cx, cy)),
			"tier": 3, "kind": "safe" if rng.randf() < 0.5 else "sack"})
	for i in 6:
		var bx: int = rng.randi_range(114, 144)
		var by: int = rng.randi_range(156, 182)
		if _floor[_idx(bx, by)] == 0:
			continue
		_add_prop("crate_metal" if rng.randf() < 0.5 else "pipe_ruin",
			tile_center(Vector2i(bx, by)), rng.randf_range(0.8, 1.1))
	if hall.size.x > 0:
		_boss_spots.append({"pos": tile_center(Vector2i(hall.position.x + 3,
			hall.position.y + 3)), "type": "zombie", "level": 6, "zone": ZONE_BUNKER})


## Помечает прямоугольник как «пол внутри постройки» (пропы туда не ставятся).
func _mark_floor_rect(r: Rect2i) -> void:
	for y in range(maxi(0, r.position.y), mini(H, r.end.y)):
		for x in range(maxi(0, r.position.x), mini(W, r.end.x)):
			_floor[_idx(x, y)] = 1


## Прорубает коридор: снимает стены, кладёт пол нужного материала.
func _carve_corridor(r: Rect2i, mat: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not _in_bounds(x, y):
				continue
			_wall[_idx(x, y)] = 0
			_mat[_idx(x, y)] = mat
			_floor[_idx(x, y)] = 1


# ------------------------------------------------------------------ болото
## Токсичная низина: водоёмы с рваными краями, мёртвые деревья, туман.
func _build_swamp() -> void:
	var rect: Rect2i = ZONE_TILES[ZONE_SWAMP - 1]
	var pools: Array = [
		[Vector2i(rect.position.x + 14, rect.position.y + 12), 9.5, M_WATER_TOX],
		[Vector2i(rect.position.x + 27, rect.position.y + 25), 7.5, M_WATER_TOX],
		[Vector2i(rect.position.x + 8, rect.position.y + 29), 6.0, M_MUD],
		[Vector2i(rect.position.x + 30, rect.position.y + 8), 5.5, M_MUD],
	]
	for p in pools:
		_paint_blob(p[0], float(p[1]), int(p[2]))
	for i in 30:
		var tx: int = rng.randi_range(rect.position.x + 1, rect.end.x - 2)
		var ty: int = rng.randi_range(rect.position.y + 1, rect.end.y - 2)
		if _blocked(tx, ty) or _mat_at(tx, ty) == M_WATER_TOX:
			continue
		_add_prop("tree_dead", tile_center(Vector2i(tx, ty)), rng.randf_range(0.85, 1.25))
	for i in 14:
		var bx: int = rng.randi_range(rect.position.x + 1, rect.end.x - 2)
		var by: int = rng.randi_range(rect.position.y + 1, rect.end.y - 2)
		if _blocked(bx, by) or _mat_at(bx, by) == M_WATER_TOX:
			continue
		if rng.randf() < 0.5:
			_add_prop("bush_dry", tile_center(Vector2i(bx, by)),
				rng.randf_range(0.8, 1.2), false)
		else:
			_add_prop("rock_b", tile_center(Vector2i(bx, by)), rng.randf_range(0.8, 1.2))
	for i in 5:
		var lx: int = rng.randi_range(rect.position.x + 2, rect.end.x - 3)
		var ly: int = rng.randi_range(rect.position.y + 2, rect.end.y - 3)
		if _blocked(lx, ly) or _mat_at(lx, ly) == M_WATER_TOX:
			continue
		_add_loot(tile_center(Vector2i(lx, ly)), rng.randi_range(2, 3))
	for i in 5:
		var sx: int = rng.randi_range(rect.position.x + 3, rect.end.x - 4)
		var sy: int = rng.randi_range(rect.position.y + 3, rect.end.y - 4)
		if _blocked(sx, sy) or _mat_at(sx, sy) == M_WATER_TOX:
			continue
		_pending_containers.append({"pos": tile_center(Vector2i(sx, sy)),
			"tier": 2, "kind": "barrel"})


## Пятно материала с рваным краем (лужа, гарь, выжженная земля).
func _paint_blob(c: Vector2i, r: float, mat: int) -> void:
	var ri: int = int(ceil(r)) + 1
	for y in range(c.y - ri, c.y + ri + 1):
		for x in range(c.x - ri, c.x + ri + 1):
			if not _in_bounds(x, y) or _blocked(x, y):
				continue
			var d: float = Vector2(float(x - c.x), float(y - c.y)).length()
			var edge: float = r * (0.72 + 0.28 * _noise_c.get_noise_2d(float(x * 2), float(y * 2)))
			if d <= edge:
				_mat[_idx(x, y)] = mat


# ------------------------------------------------------- аномальное поле
## Густая россыпь аномалий: гарь, камни, кости, лагерь мутантов и хабар.
func _build_anomaly_field() -> void:
	var rect: Rect2i = ZONE_TILES[ZONE_ANOMALY - 1]
	for i in 7:
		var bx: int = rng.randi_range(rect.position.x + 4, rect.end.x - 5)
		var by: int = rng.randi_range(rect.position.y + 4, rect.end.y - 5)
		var mat: int = M_ASH if rng.randf() < 0.6 else M_CONCRETE
		_paint_blob(Vector2i(bx, by), rng.randf_range(3.5, 6.0), mat)
	for i in 12:
		var rx: int = rng.randi_range(rect.position.x + 2, rect.end.x - 3)
		var ry: int = rng.randi_range(rect.position.y + 2, rect.end.y - 3)
		if _blocked(rx, ry):
			continue
		var rname: String = "rock_a" if rng.randf() < 0.45 else "rock_b"
		_add_prop(rname, tile_center(Vector2i(rx, ry)), rng.randf_range(0.8, 1.3))
	for i in 6:
		var tx: int = rng.randi_range(rect.position.x + 2, rect.end.x - 3)
		var ty: int = rng.randi_range(rect.position.y + 2, rect.end.y - 3)
		if _blocked(tx, ty):
			continue
		_add_prop("tree_dead", tile_center(Vector2i(tx, ty)), rng.randf_range(0.8, 1.15))
	for i in 6:
		var lx: int = rng.randi_range(rect.position.x + 3, rect.end.x - 4)
		var ly: int = rng.randi_range(rect.position.y + 3, rect.end.y - 4)
		if _blocked(lx, ly):
			continue
		_add_loot(tile_center(Vector2i(lx, ly)), 3)
	for i in 5:
		var sx: int = rng.randi_range(rect.position.x + 3, rect.end.x - 4)
		var sy: int = rng.randi_range(rect.position.y + 3, rect.end.y - 4)
		if _blocked(sx, sy):
			continue
		_pending_containers.append({"pos": tile_center(Vector2i(sx, sy)),
			"tier": 3, "kind": "sack"})
	# лагерь мутантов на востоке поля: тут будет кровь и кости
	var camp := Vector2i(rect.end.x - 8, rect.position.y + 10)
	_lairs.append(tile_center(camp))


# ----------------------------------------------------- лес, камни, остовы
## Деревья в лесных пятнах, камни и кусты по всей локации, остовы машин у дорог.
func _scatter_props() -> void:
	# густой лес в «лесной» зоне: там должны быть настоящие рощи, а не кустики
	var frect: Rect2i = ZONE_TILES[ZONE_FOREST - 1]
	for i in 52:
		var fx: int = rng.randi_range(frect.position.x + 1, frect.end.x - 2)
		var fy: int = rng.randi_range(frect.position.y + 1, frect.end.y - 2)
		if not _free_tile(fx, fy) or _inside_taken(fx, fy) or _floor[_idx(fx, fy)] != 0:
			continue
		var fname: String = "tree_pine" if rng.randf() < 0.7 else "tree_dead"
		_add_prop(fname, tile_center(Vector2i(fx, fy)), rng.randf_range(0.8, 1.2))
	# лесные пятна по всей карте, кроме дорог и построек
	var patches: Array = []
	for i in 18:
		patches.append([rng.randi_range(BORDER + 5, W - BORDER - 6),
			rng.randi_range(BORDER + 5, H - BORDER - 6), rng.randf_range(3.2, 6.5)])
	for p in patches:
		var tries: int = int(float(p[2]) * 2.0)
		for i in tries:
			var tx: int = int(float(p[0]) + rng.randf_range(-float(p[2]), float(p[2])))
			var ty: int = int(float(p[1]) + rng.randf_range(-float(p[2]), float(p[2])))
			if not _free_tile(tx, ty) or _inside_taken(tx, ty) or _floor[_idx(tx, ty)] != 0:
				continue
			var zone: int = _zone_at_tile(tx, ty)
			if zone == ZONE_FACTORY or zone == ZONE_BUNKER or zone == ZONE_SWAMP:
				continue
			if _mat_at(tx, ty) in [M_WATER_TOX, M_ASPHALT, M_RAILBED, M_METAL, M_BUNKER]:
				continue
			if rng.randf() < 0.62:
				var tname: String = "tree_pine" if rng.randf() < 0.6 else "tree_dead"
				_add_prop(tname, tile_center(Vector2i(tx, ty)), rng.randf_range(0.75, 1.15))
			else:
				_add_prop("bush_dry", tile_center(Vector2i(tx, ty)),
					rng.randf_range(0.8, 1.3), false)
	# камни и кусты по всей глуши
	for i in 58:
		var rx: int = rng.randi_range(BORDER + 2, W - BORDER - 3)
		var ry: int = rng.randi_range(BORDER + 2, H - BORDER - 3)
		if not _free_tile(rx, ry) or _inside_taken(rx, ry) or _floor[_idx(rx, ry)] != 0:
			continue
		var z_rx: int = _zone_at_tile(rx, ry)
		if z_rx == ZONE_FACTORY or z_rx == ZONE_BUNKER:
			continue
		if _mat_at(rx, ry) in [M_WATER_TOX, M_ASPHALT, M_RAILBED]:
			continue
		var pick: float = rng.randf()
		if pick < 0.4:
			_add_prop("rock_a", tile_center(Vector2i(rx, ry)), rng.randf_range(0.7, 1.2))
		elif pick < 0.75:
			_add_prop("rock_b", tile_center(Vector2i(rx, ry)), rng.randf_range(0.7, 1.2))
		else:
			_add_prop("bush_dry", tile_center(Vector2i(rx, ry)), rng.randf_range(0.8, 1.3), false)
	# остовы техники и бочки вдоль дорог
	var road_tiles: Array = []
	for y in range(0, H, 3):
		for x in range(0, W, 3):
			if _road[_idx(x, y)] != 0 and _mat[_idx(x, y)] == M_ASPHALT:
				road_tiles.append(Vector2i(x, y))
	for i in 26:
		if road_tiles.is_empty():
			break
		var base: Vector2i = road_tiles[rng.randi() % road_tiles.size()]
		var off := Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		var wx: int = base.x + off.x
		var wy: int = base.y + off.y
		if absi(off.x) < 2 and absi(off.y) < 2:
			continue
		if not _free_tile(wx, wy) or _inside_taken(wx, wy):
			continue
		var roll: float = rng.randf()
		var wname: String = "car_wreck" if roll < 0.45 else ("bus_wreck" if roll < 0.6 else "barrel_rust")
		_add_prop(wname, tile_center(Vector2i(wx, wy)), rng.randf_range(0.9, 1.1))
	# брошенные ящики и бочки в глуши
	for i in 12:
		var t := Vector2i(rng.randi_range(BORDER + 2, W - BORDER - 3),
			rng.randi_range(BORDER + 2, H - BORDER - 3))
		if not _free_tile(t.x, t.y) or _inside_taken(t.x, t.y):
			continue
		_pending_containers.append({"pos": tile_center(t),
			"tier": _tier_for(tile_center(t)),
			"kind": "barrel" if rng.randf() < 0.4 else "crate"})
	# столбы вдоль дорог и знаки радиации
	for i in 14:
		if road_tiles.is_empty():
			break
		var base2: Vector2i = road_tiles[rng.randi() % road_tiles.size()]
		var px: int = base2.x + (2 if rng.randf() < 0.5 else -2)
		var py: int = base2.y + rng.randi_range(-2, 2)
		if not _free_tile(px, py) or _inside_taken(px, py):
			continue
		_add_prop("power_pole", tile_center(Vector2i(px, py)), rng.randf_range(0.9, 1.1))
		if rng.randf() < 0.35:
			_add_prop("sign_radiation", tile_center(Vector2i(px + 1, py)), 1.0)


## Внутри ли тайл занятой застройки (дом, цех, бункер).
func _inside_taken(x: int, y: int) -> bool:
	var p := Vector2i(x, y)
	for t in _taken:
		if (t as Rect2i).has_point(p):
			return true
	return false


# ------------------------------------------------ враги, аномалии и лут
## Планирует спавны: боссы, враги по зонам, аномалии и точки лута.
func _plan_spawns() -> void:
	# боссы завода и бункера (заготовки сделаны при постройке зон)
	for b in _boss_spots:
		var bpos: Vector2 = _nearest_walkable(b["pos"])
		enemy_spawns.append({"type": String(b["type"]), "pos": bpos,
			"level": int(b["level"]), "boss": true})
		_lairs.append(bpos)
	# обычные враги: сколько, минимальный уровень зоны, пул типов
	var plan: Dictionary = {
		"kordon": [4, 1, ["dog", "zombie"]],
		"village": [20, 1, ["zombie", "dog", "boar"]],
		"swamp": [15, 2, ["mutant", "boar", "dog"]],
		"factory": [20, 4, ["mutant", "zombie", "boar"]],
		"bunker": [12, 4, ["zombie", "mutant"]],
		"anomaly_field": [15, 3, ["mutant", "boar"]],
		"forest": [12, 2, ["dog", "boar"]],
		"rail": [8, 2, ["dog", "zombie"]],
	}
	var placed: Array = []
	for zid in plan.keys():
		var cfg: Array = plan[zid]
		var rect: Rect2i = ZONE_TILES[ZONE_IDS.find(zid)]
		for i in int(cfg[0]):
			var pos: Vector2 = _random_walkable_in(rect, 90)
			if pos == Vector2.INF or pos.distance_to(spawn_point) < SAFE_RADIUS:
				continue
			if _too_close(pos, placed, 150.0):
				continue
			placed.append(pos)
			var types: Array = cfg[2]
			enemy_spawns.append({"type": String(types[rng.randi() % types.size()]),
				"pos": pos, "level": _level_for(pos, int(cfg[1])), "boss": false})
			if rng.randf() < 0.45:
				_lairs.append(pos)
	# глушь: враги между зонами, уровень — по удалению от кордона
	var pool: Array = ["dog", "boar", "zombie", "mutant"]
	for i in 16:
		var pos2: Vector2 = _random_walkable_map(140)
		if pos2 == Vector2.INF or pos2.distance_to(spawn_point) < SAFE_RADIUS:
			continue
		if _too_close(pos2, placed, 180.0):
			continue
		placed.append(pos2)
		enemy_spawns.append({"type": String(pool[rng.randi() % pool.size()]),
			"pos": pos2, "level": _level_for(pos2, 1), "boss": false})
		if rng.randf() < 0.4:
			_lairs.append(pos2)
	# аномалии: сколько, минимальный и максимальный радиус
	var anom_plan: Dictionary = {
		"anomaly_field": [7, 110.0, 190.0],
		"swamp": [5, 100.0, 165.0],
		"factory": [4, 95.0, 150.0],
		"village": [2, 90.0, 140.0],
		"bunker": [1, 95.0, 130.0],
		"forest": [1, 90.0, 130.0],
	}
	var kinds: Array = ["grav", "elektra", "zharka", "fruit"]
	var anom_pos: Array = []
	for zid in anom_plan.keys():
		var acfg: Array = anom_plan[zid]
		var arect: Rect2i = ZONE_TILES[ZONE_IDS.find(zid)]
		for i in int(acfg[0]):
			var apos: Vector2 = _random_walkable_in(arect, 120)
			if apos == Vector2.INF or _too_close(apos, anom_pos, 260.0):
				continue
			if zid != "bunker" and apos.distance_to(spawn_point) < SAFE_RADIUS:
				continue
			anom_pos.append(apos)
			anomalies.append({"type": String(kinds[rng.randi() % kinds.size()]),
				"pos": apos, "radius": rng.randf_range(float(acfg[1]), float(acfg[2]))})
	for i in 1:
		var apos2: Vector2 = _random_walkable_map(120)
		if apos2 == Vector2.INF or _too_close(apos2, anom_pos, 300.0):
			continue
		anom_pos.append(apos2)
		anomalies.append({"type": String(kinds[rng.randi() % kinds.size()]),
			"pos": apos2, "radius": rng.randf_range(100.0, 160.0)})
	# хабар в глуши: у остовов техники и брошенных стоянок
	for i in 18:
		var pos4: Vector2 = _random_walkable_map(140)
		if pos4 == Vector2.INF:
			continue
		_add_loot(pos4, _tier_for(pos4))


## Уровень врага растёт с удалением от кордона, но не ниже уровня зоны.
func _level_for(pos: Vector2, zone_min: int) -> int:
	return clampi(maxi(zone_min, 1 + int(pos.distance_to(spawn_point) / 4600.0)), 1, 6)


func _too_close(pos: Vector2, list: Array, min_dist: float) -> bool:
	for p in list:
		if pos.distance_to(p) < min_dist:
			return true
	return false


## Точка случайного пригодного тайла внутри прямоугольника (или Vector2.INF).
func _random_walkable_in(rect: Rect2i, tries: int) -> Vector2:
	for i in tries:
		var tx: int = rng.randi_range(rect.position.x, rect.end.x - 1)
		var ty: int = rng.randi_range(rect.position.y, rect.end.y - 1)
		if _spawnable(tx, ty):
			return tile_center(Vector2i(tx, ty))
	return Vector2.INF


func _random_walkable_map(tries: int) -> Vector2:
	for i in tries:
		var tx: int = rng.randi_range(BORDER + 2, W - BORDER - 3)
		var ty: int = rng.randi_range(BORDER + 2, H - BORDER - 3)
		if _spawnable(tx, ty):
			return tile_center(Vector2i(tx, ty))
	return Vector2.INF


## Годится ли тайл под спавн: не стена, не дорога, не вода и не занято пропом.
func _spawnable(x: int, y: int) -> bool:
	if _blocked(x, y) or _road[_idx(x, y)] != 0:
		return false
	if _mat_at(x, y) == M_WATER_TOX:
		return false
	return not _overlaps_solid(tile_center(Vector2i(x, y)), 46.0)


## Добавляет точку лута (tier 1..3) в список для game.gd.
func _add_loot(pos: Vector2, tier: int) -> void:
	loot_spots.append({"pos": _nearest_walkable(pos), "tier": clampi(tier, 1, 3)})


## Уровень лута по удалению от кордона: у старта — 1, в глубине Зоны — 3.
func _tier_for(pos: Vector2) -> int:
	var d: float = pos.distance_to(spawn_point)
	if d < 6000.0:
		return 1
	return 3 if d > 16000.0 else 2


# ------------------------------------------------------------------ декали
## Раскладывает декали: шины и гильзы на дорогах, гарь и масло на заводе,
## мох в болоте, кровь и кости у логов, мох и трава в глуши.
func _scatter_decals() -> void:
	var road_tiles: Array = []
	for y in range(0, H, 2):
		for x in range(0, W, 2):
			if _road[_idx(x, y)] != 0 and _mat[_idx(x, y)] == M_ASPHALT:
				road_tiles.append(Vector2i(x, y))
	var road_marks: Array = [D_TIRE, D_BULLETS, D_CRACK, D_PUDDLE, D_OIL]
	for i in 55:
		if road_tiles.is_empty():
			break
		var t: Vector2i = road_tiles[rng.randi() % road_tiles.size()]
		var pos := tile_center(t) + Vector2(rng.randf_range(-55.0, 55.0), rng.randf_range(-55.0, 55.0))
		_add_decal(int(road_marks[rng.randi() % road_marks.size()]), pos, rng.randf_range(0.7, 1.1))
	# тематические декали каждой зоны
	var zone_decals: Dictionary = {
		"factory": [D_OIL, D_SCORCH, D_CRACK_BIG, D_RUBBLE, D_PUDDLE, D_CRACK],
		"swamp": [D_MOSS, D_PUDDLE_TOX, D_PUDDLE, D_TUFT, D_LEAVES],
		"forest": [D_LEAVES, D_TUFT, D_MOSS, D_PUDDLE],
		"village": [D_RUBBLE, D_CRACK, D_BLOOD_A, D_BONES, D_MOSS],
		"anomaly_field": [D_SCORCH, D_CRACK_BIG, D_BLOOD_B, D_BONES],
		"kordon": [D_TIRE, D_BULLETS, D_CRACK, D_PUDDLE, D_RUBBLE],
		"bunker": [D_RUBBLE, D_CRACK, D_BLOOD_C, D_BONES, D_PUDDLE],
		"rail": [D_CRACK, D_BULLETS, D_RUBBLE, D_OIL],
	}
	var counts: Dictionary = {
		"factory": 70, "swamp": 60, "forest": 45, "village": 55,
		"anomaly_field": 55, "kordon": 30, "bunker": 30, "rail": 30,
	}
	for zid in zone_decals.keys():
		var rect: Rect2i = ZONE_TILES[ZONE_IDS.find(zid)]
		var list: Array = zone_decals[zid]
		for i in int(counts[zid]):
			var tx: int = rng.randi_range(rect.position.x, rect.end.x - 1)
			var ty: int = rng.randi_range(rect.position.y, rect.end.y - 1)
			var dpos := tile_center(Vector2i(tx, ty))
			dpos += Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-60.0, 60.0))
			_add_decal(int(list[rng.randi() % list.size()]), dpos, rng.randf_range(0.8, 1.2))
	# кровь, кости и тряпьё у логова монстров
	var gore: Array = [D_BLOOD_A, D_BLOOD_B, D_BLOOD_C, D_BONES]
	for l in _lairs:
		var lp: Vector2 = l
		for i in rng.randi_range(1, 3):
			var gpos := lp + Vector2(rng.randf_range(-95.0, 95.0), rng.randf_range(-95.0, 95.0))
			_add_decal(int(gore[rng.randi() % gore.size()]), gpos, rng.randf_range(0.8, 1.3))
	# мох, трава и листья по всей карте
	var wild: Array = [D_TUFT, D_LEAVES, D_MOSS, D_PUDDLE]
	for i in 80:
		var wx: int = rng.randi_range(BORDER + 1, W - BORDER - 2)
		var wy: int = rng.randi_range(BORDER + 1, H - BORDER - 2)
		if _mat_at(wx, wy) in [M_ASPHALT, M_RAILBED]:
			continue
		_add_decal(int(wild[rng.randi() % wild.size()]), tile_center(Vector2i(wx, wy)),
			rng.randf_range(0.8, 1.4))


# ------------------------------------------------------ туман и темнота
## Туман над болотом и тёмный пол бункера: полупрозрачные пятна под землёй-нет,
## поверх земли, но ниже игрока и пропов (z_index -4).
func _add_overlays() -> void:
	if overlay_root == null:
		return
	var srect: Rect2i = ZONE_TILES[ZONE_SWAMP - 1]
	for i in 8:
		var cx: int = srect.position.x + rng.randi_range(3, srect.size.x - 4)
		var cy: int = srect.position.y + rng.randi_range(3, srect.size.y - 4)
		_fog_blob(tile_center(Vector2i(cx, cy)), rng.randf_range(230.0, 430.0),
			Color(0.62, 0.72, 0.58, 0.09))
	var orect := Rect2i(108, 152, 40, 34)
	var dark := Polygon2D.new()
	dark.name = "bunker_dark"
	dark.color = Color(0.02, 0.03, 0.04, 0.42)
	dark.polygon = PackedVector2Array([
		Vector2(orect.position) * float(TILE), Vector2(orect.end.x, orect.position.y) * float(TILE),
		Vector2(orect.end) * float(TILE), Vector2(orect.position.x, orect.end.y) * float(TILE),
	])
	overlay_root.add_child(dark)


func _fog_blob(center: Vector2, radius: float, col: Color) -> void:
	var poly := Polygon2D.new()
	poly.color = col
	var pts := PackedVector2Array()
	var steps: int = 20
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		var r: float = radius * (0.8 + 0.2 * _noise_c.get_noise_2d(float(i) * 3.0, center.x * 0.01))
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	poly.polygon = pts
	overlay_root.add_child(poly)


# --------------------------------------------------- объекты: контейнеры, NPC
## Создаёт контейнеры и NPC последними, чтобы они не попали в спавны врагов.
func _place_objects() -> void:
	for c in _pending_containers:
		var pos: Vector2 = _nearest_walkable(c["pos"])
		if _spawn_container(pos, int(c["tier"]), String(c["kind"])):
			_solid.append(Rect2(pos - Vector2(30.0, 30.0), Vector2(60.0, 42.0)))
	for n in _pending_npcs:
		var npos: Vector2 = _nearest_walkable(n["pos"])
		_spawn_npc(String(n["id"]), String(n["name"]), npos)
		_solid.append(Rect2(npos - Vector2(24.0, 24.0), Vector2(48.0, 36.0)))


## Загружает скрипт, если он есть: мир не должен падать из-за чужого файла.
func _script_at(path: String) -> Script:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Script


## Контейнер (scripts/container.gd): setup(tier, kind), группа "containers".
func _spawn_container(pos: Vector2, tier: int, kind: String) -> bool:
	var scr: Script = _script_at("res://scripts/container.gd")
	if scr == null:
		return false
	var node := scr.new() as StaticBody2D
	if node == null:
		return false
	node.name = "container_%d" % container_count
	node.position = pos
	if node.has_method("setup"):
		node.call("setup", tier, kind)
	object_root.add_child(node)
	container_count += 1
	_container_points.append(pos)
	return true


## NPC (scripts/npc.gd): Сидорович и Бармен на кордоне.
func _spawn_npc(id: String, display: String, pos: Vector2) -> void:
	var scr: Script = _script_at("res://scripts/npc.gd")
	if scr == null:
		return
	var node := scr.new() as StaticBody2D
	if node == null:
		return
	node.name = "npc_" + id
	node.position = pos
	if node.has_method("setup"):
		node.call("setup", id, display)
	object_root.add_child(node)
	npc_count += 1


# --------------------------------------------------------- публичный API
## Идентификатор зоны в точке (или "" — глушь между зонами).
func zone_at(pos: Vector2) -> String:
	var t := world_to_tile(pos)
	var z: int = _zone_at_tile(t.x, t.y)
	if z == 0:
		return ""
	return ZONE_IDS[z - 1]


## Проходима ли точка: в границах карты, без стен, пропов и контейнеров.
func is_walkable(pos: Vector2) -> bool:
	if _wall.is_empty():
		return false
	var t := world_to_tile(pos)
	if not _in_bounds(t.x, t.y):
		return false
	if _wall[_idx(t.x, t.y)] != 0:
		return false
	for r in _solid:
		if (r as Rect2).has_point(pos):
			return false
	return true


## Случайная проходимая точка внутри зоны ("" и "any" — по всей карте).
func random_point(zone: String, r: RandomNumberGenerator = null) -> Vector2:
	var gen: RandomNumberGenerator = r if r != null else rng
	var rect: Rect2i
	if zone == "" or zone == "any":
		rect = Rect2i(BORDER + 2, BORDER + 2,
			W - BORDER * 2 - 4, H - BORDER * 2 - 4)
	else:
		var i: int = ZONE_IDS.find(zone)
		if i < 0:
			return _nearest_walkable(spawn_point)
		rect = ZONE_TILES[i]
	for n in 220:
		var t := Vector2i(gen.randi_range(rect.position.x, rect.end.x - 1),
			gen.randi_range(rect.position.y, rect.end.y - 1))
		if _spawnable(t.x, t.y):
			return tile_center(t)
	return _nearest_walkable(spawn_point)


## Ближайшая проходимая точка (спиральный поиск по тайлам).
func _nearest_walkable(pos: Vector2) -> Vector2:
	if is_walkable(pos):
		return pos
	var t := world_to_tile(pos)
	for radius in range(1, 27):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var c := Vector2i(t.x + dx, t.y + dy)
				if is_walkable(tile_center(c)):
					return tile_center(c)
	return tile_center(Vector2i(W / 2, H / 2))


# ----------------------------------------------------- отладочная миникарта
## Цвета материалов земли для миникарты (по именам Assets.GROUND_MATS).
const MAT_COLORS: Dictionary = {
	"asphalt": Color(0.23, 0.23, 0.25), "dirt": Color(0.36, 0.29, 0.2),
	"grass_dry": Color(0.45, 0.47, 0.24), "grass_toxic": Color(0.33, 0.46, 0.22),
	"concrete": Color(0.56, 0.56, 0.56), "gravel": Color(0.47, 0.45, 0.41),
	"mud": Color(0.28, 0.22, 0.15), "metal_floor": Color(0.42, 0.46, 0.5),
	"bunker_tile": Color(0.36, 0.38, 0.41), "water_toxic": Color(0.2, 0.5, 0.3),
	"ash": Color(0.19, 0.18, 0.18), "railbed": Color(0.31, 0.27, 0.23),
}
const ZONE_COLORS: Array = [
	Color(0.2, 0.85, 0.3), Color(0.95, 0.85, 0.2), Color(0.25, 0.8, 0.75),
	Color(0.9, 0.4, 0.2), Color(0.75, 0.5, 0.95), Color(0.95, 0.25, 0.6),
	Color(0.4, 0.8, 0.2), Color(0.85, 0.75, 0.6),
]


## Сколько тайлов занято каждым материалом земли (для тестов и отладки).
func material_histogram() -> Dictionary:
	var mats: PackedStringArray = _assets().GROUND_MATS
	var hist: Dictionary = {}
	for m in mats:
		hist[String(m)] = 0
	for y in H:
		for x in W:
			var name: String = String(mats[_mat[_idx(x, y)]])
			hist[name] = int(hist[name]) + 1
	return hist


## Статистика интерьеров: сколько тайлов пола и сколько из них реально проходимо.
func floor_stats() -> Dictionary:
	var total: int = 0
	var walkable: int = 0
	for y in H:
		for x in W:
			if _floor[_idx(x, y)] == 0:
				continue
			total += 1
			if is_walkable(tile_center(Vector2i(x, y))):
				walkable += 1
	return {"floor_tiles": total, "floor_walkable": walkable}


## Топ-даун картинка мира: материал земли, стены, зоны, спавн, враги, аномалии.
func debug_minimap(px_per_tile: int = 3) -> Image:
	var ppt: int = maxi(1, px_per_tile)
	var img := Image.create_empty(W * ppt, H * ppt, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var mat: int = _mat[_idx(x, y)]
			var mat_name: String = String(_assets().GROUND_MATS[mat])
			var col: Color = MAT_COLORS.get(mat_name, Color(0.5, 0.5, 0.5))
			var w: int = _wall[_idx(x, y)]
			if w != 0:
				col = Color(0.8, 0.87, 0.95) if w - 1 == S_FENCE else Color(0.97, 0.95, 0.9)
			img.fill_rect(Rect2i(x * ppt, y * ppt, ppt, ppt), col)
	# рамки зон
	for i in ZONE_IDS.size():
		_minimap_outline(img, ZONE_TILES[i], ppt, ZONE_COLORS[i % ZONE_COLORS.size()])
	# аномалии: кольцо радиуса действия
	for a in anomalies:
		_minimap_ring(img, a["pos"], float(a["radius"]), ppt, Color(0.85, 0.2, 0.9, 1.0))
	# пропы: деревья, камни, техника — мелкие тёмные точки
	for t in _tree_points:
		_minimap_dot(img, t, ppt, Color(0.0, 0.45, 0.08), 2)
	for p in _prop_points:
		_minimap_dot(img, p, ppt, Color(0.13, 0.14, 0.1), 1)
	# контейнеры
	for c in _container_points:
		_minimap_dot(img, c, ppt, Color(0.55, 0.35, 0.1), 2)
	# точки лута
	for l in loot_spots:
		_minimap_dot(img, l["pos"], ppt, Color(1.0, 0.9, 0.15), 2)
	# враги (боссы — крупнее и с белой каймой)
	for e in enemy_spawns:
		var boss: bool = bool(e["boss"])
		_minimap_dot(img, e["pos"], ppt, Color(0.95, 0.15, 0.1), 4 if boss else 2)
	# NPC и точка спавна игрока
	for n in _pending_npcs:
		_minimap_dot(img, n["pos"], ppt, Color(0.2, 0.6, 1.0), 4)
	_minimap_dot(img, spawn_point, ppt, Color(0.1, 1.0, 0.3), 5)
	return img


func _minimap_dot(img: Image, pos: Vector2, ppt: int, col: Color, size: int) -> void:
	var x: int = int(pos.x / float(TILE) * float(ppt))
	var y: int = int(pos.y / float(TILE) * float(ppt))
	img.fill_rect(Rect2i(x - size / 2, y - size / 2, size, size), col)


func _minimap_outline(img: Image, r: Rect2i, ppt: int, col: Color) -> void:
	var x0: int = r.position.x * ppt
	var y0: int = r.position.y * ppt
	var x1: int = r.end.x * ppt - 1
	var y1: int = r.end.y * ppt - 1
	img.fill_rect(Rect2i(x0, y0, x1 - x0 + 1, 1), col)
	img.fill_rect(Rect2i(x0, y1, x1 - x0 + 1, 1), col)
	img.fill_rect(Rect2i(x0, y0, 1, y1 - y0 + 1), col)
	img.fill_rect(Rect2i(x1, y0, 1, y1 - y0 + 1), col)


func _minimap_ring(img: Image, pos: Vector2, radius_px: float, ppt: int, col: Color) -> void:
	var cx: float = pos.x / float(TILE) * float(ppt)
	var cy: float = pos.y / float(TILE) * float(ppt)
	var r: float = maxf(2.0, radius_px / float(TILE) * float(ppt))
	var steps: int = int(maxf(20.0, r * 8.0))
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		var px: int = int(cx + cos(a) * r)
		var py: int = int(cy + sin(a) * r)
		if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
			img.set_pixel(px, py, col)





## Декаль: тонкий спрайт из атласа декалей, случайный поворот и масштаб.
func _add_decal(idx: int, pos: Vector2, scale_f: float = 1.0) -> void:
	if decal_root == null:
		return
	var spr := Sprite2D.new()
	spr.texture = _assets().decal_tex(idx)
	spr.position = pos
	spr.rotation = rng.randf_range(-0.7, 0.7)
	var s: float = scale_f * rng.randf_range(0.85, 1.5)
	spr.scale = Vector2(s, s)
	spr.modulate = Color(1.0, 1.0, 1.0, rng.randf_range(0.5, 0.92))
	decal_root.add_child(spr)
	decal_count += 1



func _upload_walls() -> void:
	if wall_layer == null or not _wall_ready:
		return
	var cols: int = _assets().WALL_COLS
	for y in H:
		for x in W:
			var w: int = _wall[_idx(x, y)]
			if w == 0:
				continue
			wall_layer.set_cell(Vector2i(x, y), 0,
				Vector2i(_variant_of(x + 7, y + 3, cols), w - 1))

