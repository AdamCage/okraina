extends Node
## Реестр ассетов: атласы тайлов, спрайт-листы, UI, шрифты, звуки.
## Всё грузится один раз при старте. Если файла нет — создаётся процедурная
## заглушка, чтобы игра не падала на неполном наборе ассетов.

const TEX_DIR := "res://assets/textures"
const SPR_DIR := "res://assets/sprites"
const UI_DIR := "res://assets/ui"
const AUD_DIR := "res://assets/audio"

const TILE := 128              ## сторона тайла в атласах земли/стен
const GROUND_COLS := 3         ## вариантов на материал
const WALL_COLS := 2
const DECAL_COLS := 4
const SHEET_FRAME := 64        ## кадр анимации персонажей/монстров
const SHEET_ANCHOR := Vector2(32.0, 58.0)  ## «ноги» внутри кадра

const GROUND_MATS: PackedStringArray = [
	"asphalt", "dirt", "grass_dry", "grass_toxic", "concrete", "gravel",
	"mud", "metal_floor", "bunker_tile", "water_toxic", "ash", "railbed",
]
const WALL_STYLES: PackedStringArray = [
	"concrete", "brick", "plaster", "metal", "container", "wood",
	"bunker", "tiles", "fence", "rubble",
]
const DECAL_NAMES: PackedStringArray = [
	"crack", "crack_big", "rubble", "moss", "puddle", "puddle_toxic",
	"blood_a", "blood_b", "blood_c", "scorch", "tire", "bones",
	"bullets", "oil", "leaves", "tuft",
]

## Листы анимаций: имя -> число кадров (горизонтальная полоса 64x64 на кадр).
const SHEETS: Dictionary = {
	"stalker_idle": 4, "stalker_walk": 6, "stalker_attack": 4,
	"stalker_hurt": 2, "stalker_dead": 1,
	"dog_idle": 4, "dog_walk": 6, "dog_attack": 4,
	"mutant_idle": 4, "mutant_walk": 6, "mutant_attack": 4,
	"zombie_idle": 4, "zombie_walk": 6, "zombie_attack": 4,
	"boar_idle": 4, "boar_walk": 6, "boar_attack": 4,
	"anomaly_grav": 4, "anomaly_elektra": 4, "anomaly_zharka": 4, "anomaly_fruit": 4,
	"muzzle_flash": 3, "blood_splat": 3, "spark": 4, "smoke_puff": 3, "shockwave": 3,
}

## Односпрайтовые объекты (пропы, декор, оверлеи).
const SPRITE_NAMES: PackedStringArray = [
	"barrel_rust", "barrel_toxic", "crate_wood", "crate_metal", "car_wreck",
	"bus_wreck", "tree_dead", "tree_pine", "bush_dry", "rock_a", "rock_b",
	"tent", "campfire", "power_pole", "grave", "well", "sign_radiation",
	"bunker_door", "fence_panel", "pipe_ruin",
	"light_cone", "soft_shadow",
]

## Звуки (без расширения). Отсутствующие молча игнорируются.
const SOUND_NAMES: PackedStringArray = [
	"shot_pm", "shot_ak", "shot_shotgun", "shot_crossbow", "melee_swing",
	"melee_hit", "hit_flesh", "hit_wall", "explosion",
	"step_gravel_1", "step_gravel_2", "step_gravel_3", "step_grass_1",
	"step_grass_2", "step_metal_1",
	"player_hurt", "player_die", "heartbeat_loop", "breath_loop",
	"pickup_item", "pickup_artefact", "ui_click", "ui_open", "ui_close",
	"ui_deny", "quest_new", "quest_done", "levelup", "notify",
	"geiger_click", "geiger_burst", "detector_ping", "anomaly_hum",
	"anomaly_zap", "anomaly_warp", "artifact_hum", "artifact_taken",
	"dog_growl", "dog_bark", "mutant_roar", "zombie_moan", "boar_snort",
	"creature_die",
	"amb_wind_loop", "amb_zone_loop", "amb_cave_loop", "amb_danger_loop",
	"mus_menu_loop", "mus_raid_loop",
]

var ground: Texture2D
var ground_n: Texture2D
var wall: Texture2D
var wall_n: Texture2D
var decal: Texture2D
var decal_n: Texture2D

var font_title: Font
var font_body: Font
var font_small: Font

var _tex_cache: Dictionary = {}
var _sheets_cache: Dictionary = {}
var _sound_cache: Dictionary = {}
var _missing: Dictionary = {}
var _placeholder: Texture2D
var _generated_cache: Dictionary = {}

func _ready() -> void:
	ground = _load_tex(TEX_DIR + "/ground_atlas.png")
	ground_n = _load_tex(TEX_DIR + "/ground_atlas_n.png")
	wall = _load_tex(TEX_DIR + "/wall_atlas.png")
	wall_n = _load_tex(TEX_DIR + "/wall_atlas_n.png")
	decal = _load_tex(TEX_DIR + "/decal_atlas.png")
	decal_n = _load_tex(TEX_DIR + "/decal_atlas_n.png")
	font_title = _load_font("Oswald.ttf")
	font_body = _load_font("PT_Sans-Narrow-Web-Regular.ttf")
	font_small = font_body

# ------------------------------------------------------------------ тайлы
func _cell(cols: int, idx: int) -> Rect2:
	return Rect2(Vector2(idx % cols, idx / cols) * float(TILE), Vector2(TILE, TILE) * 1.0)

## Тайл земли: mat — индекс в GROUND_MATS, variant — 0..GROUND_COLS-1.
func ground_tex(mat: int, variant: int = 0) -> Texture2D:
	if ground == null:
		return placeholder()
	var v: int = clampi(variant, 0, GROUND_COLS - 1)
	return _atlas(ground, _cell(GROUND_COLS, mat * GROUND_COLS + v))

func ground_normal(mat: int, variant: int = 0) -> Texture2D:
	if ground_n == null:
		return placeholder()
	var v: int = clampi(variant, 0, GROUND_COLS - 1)
	return _atlas(ground_n, _cell(GROUND_COLS, mat * GROUND_COLS + v))

func wall_tex(style: int, variant: int = 0) -> Texture2D:
	if wall == null:
		return placeholder()
	var v: int = clampi(variant, 0, WALL_COLS - 1)
	return _atlas(wall, _cell(WALL_COLS, style * WALL_COLS + v))

func wall_normal(style: int, variant: int = 0) -> Texture2D:
	if wall_n == null:
		return placeholder()
	var v: int = clampi(variant, 0, WALL_COLS - 1)
	return _atlas(wall_n, _cell(WALL_COLS, style * WALL_COLS + v))

func decal_tex(idx: int) -> Texture2D:
	if decal == null:
		return placeholder()
	return _atlas(decal, _cell(DECAL_COLS, idx % DECAL_NAMES.size()))

func decal_normal(idx: int) -> Texture2D:
	if decal_n == null:
		return placeholder()
	return _atlas(decal_n, _cell(DECAL_COLS, idx % DECAL_NAMES.size()))

## Индекс материала по имени (asphalt, dirt, ...).
func ground_index(name: String) -> int:
	var i: int = GROUND_MATS.find(name)
	return i if i >= 0 else 0

func wall_index(name: String) -> int:
	var i: int = WALL_STYLES.find(name)
	return i if i >= 0 else 0

func decal_index(name: String) -> int:
	var i: int = DECAL_NAMES.find(name)
	return i if i >= 0 else 0

func _atlas(src: Texture2D, region: Rect2) -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = src
	at.region = region
	return at

# ------------------------------------------------------------------ спрайты
## Кадр листа анимации: sheet("dog_walk", 2). Если листа нет — заглушка.
func sheet(name: String, frame: int = 0) -> Texture2D:
	var frames: int = int(SHEETS.get(name, 1))
	var tex: Texture2D = _sprite_tex(name)
	if tex == null:
		return placeholder()
	var f: int = clampi(frame, 0, maxi(0, frames - 1))
	return _atlas(tex, Rect2(Vector2(f * SHEET_FRAME, 0.0), Vector2(SHEET_FRAME, SHEET_FRAME)))

func sheet_count(name: String) -> int:
	return int(SHEETS.get(name, 1))

## Односпрайтовый объект (проп, FX-оверлей) в исходном размере.
## Для световых текстур (light_cone, soft_shadow) есть процедурный запас,
## чтобы освещение работало даже без сгенерированных ассетов.
func sprite(name: String) -> Texture2D:
	var tex: Texture2D = _sprite_tex(name)
	if tex == null:
		tex = _generated(name)
	return tex if tex != null else placeholder()


## Процедурные текстуры на случай отсутствия файлов.
func _generated(name: String) -> Texture2D:
	if _generated_cache.has(name):
		return _generated_cache[name]
	var tex: Texture2D = null
	match name:
		"light_cone":
			tex = _make_cone_texture(256)
		"soft_shadow":
			tex = _make_shadow_texture(64)
		"radial_glow":
			tex = _make_radial_texture(128)
		_:
			return null
	_generated_cache[name] = tex
	return tex


func _make_radial_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x - c, y - c).length() / c
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


## Конус фонаря, направленный вверх (rotate в Godot — по часовой стрелке).
func _make_cone_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	var angle := deg_to_rad(34.0)
	for y in size:
		for x in size:
			var rel := Vector2(x - c, y - c)
			var dist: float = rel.length()
			var d: float = rel.normalized().dot(Vector2.UP) if dist > 0.001 else 1.0
			var aa: float = 1.0 if acos(clampf(d, -1.0, 1.0)) <= angle else 0.0
			var fall: float = clampf(1.0 - dist / c, 0.0, 1.0)
			aa *= fall * fall
			img.set_pixel(x, y, Color(1, 1, 1, aa))
	return ImageTexture.create_from_image(img)


func _make_shadow_texture(size: int) -> Texture2D:
	var img := Image.create(size, size / 2, false, Image.FORMAT_RGBA8)
	for y in size / 2:
		for x in size:
			var rel := Vector2((x - size * 0.5) / (size * 0.5), (y - size * 0.25) / (size * 0.25))
			var d: float = rel.length()
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * 0.45))
	return ImageTexture.create_from_image(img)


func has_sprite(name: String) -> bool:
	return _sprite_tex(name) != null

## Иконка/панель UI.
func ui(name: String) -> Texture2D:
	var key: String = "ui:" + name
	if _tex_cache.has(key):
		return _tex_cache[key]
	var tex: Texture2D = _load_tex(UI_DIR + "/" + name + ".png")
	if tex == null:
		tex = placeholder()
	_tex_cache[key] = tex
	return tex

func has_ui(name: String) -> bool:
	return ResourceLoader.exists(UI_DIR + "/" + name + ".png")

func _sprite_tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var tex: Texture2D = _load_tex(SPR_DIR + "/" + name + ".png")
	_tex_cache[name] = tex
	return tex

# ------------------------------------------------------------------ звук
## Поток по имени файла без расширения. Кэшируется, null если нет.
func sound(name: String) -> AudioStream:
	if _sound_cache.has(name):
		return _sound_cache[name]
	var path: String = AUD_DIR + "/" + name + ".wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	_sound_cache[name] = stream
	return stream

func has_sound(name: String) -> bool:
	return ResourceLoader.exists(AUD_DIR + "/" + name + ".wav")

# ------------------------------------------------------------------ шрифты
func _load_font(file_name: String) -> Font:
	var path: String = UI_DIR + "/" + file_name
	if ResourceLoader.exists(path):
		var f: Font = load(path) as Font
		if f != null:
			return f
	return null

## FontVariation заданного размера (в Godot 4 размер задаётся на узле).
func font(name: String, size: int) -> Font:
	var base: Font = font_body
	match name:
		"title":
			base = font_title
		"small":
			base = font_small
	if base == null:
		return null
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = int(size / 12)
	return fv

# ------------------------------------------------------------------ материалы
## CanvasItemMaterial с нормал-маппингом (для 2D-света в Forward+).
func lit_material(light_mode: int = CanvasItemMaterial.LIGHT_MODE_NORMAL) -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = light_mode
	return m

## Заглушка 32x32: шахматка + рамка, чтобы отсутствие файла было заметно,
## но не ломало сцену.
func placeholder() -> Texture2D:
	if _placeholder != null:
		return _placeholder
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.42, 0.36, 0.30))
	for y in 32:
		for x in 32:
			if ((x / 8) + (y / 8)) % 2 == 0:
				img.set_pixel(x, y, Color(0.30, 0.27, 0.24))
	for i in 32:
		img.set_pixel(i, 0, Color(0.85, 0.45, 0.15))
		img.set_pixel(i, 31, Color(0.85, 0.45, 0.15))
		img.set_pixel(0, i, Color(0.85, 0.45, 0.15))
		img.set_pixel(31, i, Color(0.85, 0.45, 0.15))
	_placeholder = ImageTexture.create_from_image(img)
	return _placeholder

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if not _missing.has(path):
		_missing[path] = true
		print_verbose("Assets: нет файла " + path)
	return null

# ------------------------------------------------------------------ сводка
## Список пропов, для которых реально есть спрайт.
func available_props() -> Array:
	var out: Array = []
	for n in SPRITE_NAMES:
		if n == "light_cone" or n == "soft_shadow":
			continue
		if has_sprite(n):
			out.append(n)
	return out

## Размер спрайта пропа в пикселях (для расстановки коллизий).
func sprite_size(name: String) -> Vector2:
	var t: Texture2D = _sprite_tex(name)
	return t.get_size() if t != null else Vector2(32, 32)

## Отчёт о наличии ассетов — используется в тестах и на экране отладки.
func report() -> Dictionary:
	var sheets := {}
	var missing_sheets: Array = []
	for n in SHEETS.keys():
		if has_sprite(n):
			sheets[n] = true
		else:
			missing_sheets.append(n)
	var sounds := 0
	var missing_sounds: Array = []
	for n in SOUND_NAMES:
		if has_sound(n):
			sounds += 1
		else:
			missing_sounds.append(n)
	return {
		"atlases": {
			"ground": ground != null, "wall": wall != null, "decal": decal != null,
			"ground_n": ground_n != null, "wall_n": wall_n != null, "decal_n": decal_n != null,
		},
		"fonts": {"title": font_title != null, "body": font_body != null},
		"sheets_ok": sheets.size(), "sheets_missing": missing_sheets,
		"sounds_ok": sounds, "sounds_missing": missing_sounds,
		"props_ok": available_props().size(),
	}



