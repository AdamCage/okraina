class_name Hud extends CanvasLayer
## HUD сталкера: показатели героя, панель действий, мини-карта, трекер заданий,
## лента сообщений, подсказка цели, вспышки урона и индикатор детектора.
##
## Всё строится кодом (сцен .tscn нет). Каждый элемент интерфейса берётся из
## Assets.ui("имя"), но только через Assets.has_ui() — если файла нет, рисуется
## ColorRect/заглушка, и HUD не падает на неполном наборе ассетов.
## Компоновка — на якорях: 16 px безопасной зоны, ничего не режется ни на 16:9,
## ни на 2:1. Опрос каждый кадр — только мини-карта и пульсация виньетки.

const MARGIN := 16.0          ## «прилипающий» отступ от края экрана
const VITALS_W := 286.0       ## ширина панели показателей
const BAR_H := 26.0
const MINIMAP := 208.0        ## сторона карты
const MINIMAP_INSET := 10.0
const LOG_MAX := 6            ## строк в ленте сообщений
const LOG_LIFE := 5.0         ## сек до исчезновения строки
const LOG_FADE := 1.2         ## сек затухания
const BLIP_LIMIT := 40        ## максимум точек врагов на карте
const LOOT_LIMIT := 24
const TARGET_INTERVAL := 0.1
const DANGER_INTERVAL := 0.2

const KIND_COLORS := {
	"info": Color(0.80, 0.82, 0.84),
	"good": Color(0.58, 0.86, 0.55),
	"bad": Color(0.93, 0.44, 0.38),
	"quest": Color(0.96, 0.83, 0.44),
}

const ENEMY_NAMES := {
	"dog": "Слепой пёс", "mutant": "Кровосос", "zombie": "Зомби",
	"boar": "Кабан", "snork": "Снорк", "pseudodog": "Псевдопёс",
	"controller": "Контролёр", "sniper": "Снайпер",
}

const ANOMALY_COLORS := {
	"grav": Color(0.62, 0.42, 0.92),
	"elektra": Color(0.42, 0.70, 1.00),
	"zharka": Color(1.00, 0.55, 0.20),
	"fruit": Color(0.55, 0.85, 0.35),
}

var game: Node = null
var minimap_visible: bool = true
var damage_numbers: bool = true
var blood_enabled: bool = true

var _root: Control
var _vitals: Control
var _hp_fill: Control
var _stam_fill: Control
var _xp_fill: Control
var _hp_bar_w: float = 0.0
var _meta_label: Label
var _rad_label: Label
var _rad_icon: TextureRect
var _geiger_icon: TextureRect
var _actionbar: Control
var _weapon_icon: TextureRect
var _weapon_label: Label
var _ammo_label: Label
var _reload_label: Label
var _hint_label: Label
var _minimap_frame: Control
var _minimap: Control
var _compass: Control
var _quest_box: VBoxContainer
var _log_box: VBoxContainer
var _target_panel: Control
var _target_name: Label
var _target_fill: Control
var _target_bar_w: float = 0.0
var _flash: Control
var _vignette: Control
var _detector: Control
var _detector_icon: TextureRect
var _detector_label: Label

var _zones: Dictionary = {}
var _size_tiles: Vector2i = Vector2i.ZERO
var _tile: int = 128
var _player_pos: Vector2 = Vector2.ZERO
var _quality: String = "medium"
var _time: float = 0.0
var _prev_hp: float = -1.0
var _flash_t: float = 0.0
var _low_hp: bool = false
var _target_t: float = 0.0
var _danger_t: float = 0.0
var _danger: float = 0.0
var _target: Node = null
var _logs: Array = []


## Внутренний холст мини-карты: CanvasLayer рисовать не умеет,
## поэтому вся отрисовка идёт из Control._draw() через хост.
class MinimapView extends Control:
	var host: Node = null

	func _draw() -> void:
		if host != null and is_instance_valid(host):
			host.call("_draw_minimap", self)


func setup(game_node: Node) -> void:
	game = game_node
	layer = 10
	_build()
	_connect_signals()
	_refresh_all()
	set_process(true)


func _connect_signals() -> void:
	GameState.stats_changed.connect(_refresh_stats)
	GameState.inventory_changed.connect(_refresh_inventory)
	GameState.money_changed.connect(_on_money_changed)
	GameState.leveled_up.connect(_on_leveled_up)
	GameState.log_message.connect(_on_log_message)
	GameState.player_died.connect(_on_player_died)
	Quests.quest_started.connect(_on_quest_changed)
	Quests.quest_updated.connect(_on_quest_changed)
	Quests.quest_completed.connect(_on_quest_changed)


# ------------------------------------------------------------------ построение
func _build() -> void:
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_vitals()
	_build_detector()
	_build_actionbar()
	_build_minimap()
	_build_quest_tracker()
	_build_log()
	_build_target()
	_build_overlays()


## Панель-подложка: NinePatch, если текстура есть; иначе непрозрачная тёмная
## панель StyleBoxFlat (чтобы текст читался поверх мира). Для оверлеев
## (вспышка урона, виньетка) запасной вариант — ColorRect с заливкой.
func _panel(parent: Node, tex_name: String, fallback: Color, overlay: bool = false) -> Control:
	if Assets.has_ui(tex_name):
		var np := NinePatchRect.new()
		np.name = tex_name
		np.texture = Assets.ui(tex_name)
		np.patch_margin_left = 12
		np.patch_margin_right = 12
		np.patch_margin_top = 12
		np.patch_margin_bottom = 12
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(np)
		return np
	if overlay:
		var cr := ColorRect.new()
		cr.name = tex_name
		cr.color = fallback
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(cr)
		return cr
	var p := Panel.new()
	p.name = tex_name
	p.add_theme_stylebox_override("panel", fallback_style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


## Непрозрачная тёмная панель: HUD не должен просвечивать мир.
func fallback_style(alpha: float = 0.97) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.062, 0.070, alpha)
	sb.border_color = Color(0.30, 0.28, 0.24)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	return sb


func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if Assets.font_body != null:
		l.add_theme_font_override("font", Assets.font_body)
	l.modulate = color
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l


func _icon(parent: Node, tex_name: String, size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = tex_name
	tr.texture = Assets.ui(tex_name) if Assets.has_ui(tex_name) else Assets.placeholder()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


## Якоря одной строкой: (left/top/right/bottom offsets + доли якорей).
func _anchored(c: Control, off: Rect2, anchors: Rect2) -> void:
	c.anchor_left = anchors.position.x
	c.anchor_top = anchors.position.y
	c.anchor_right = anchors.size.x
	c.anchor_bottom = anchors.size.y
	c.offset_left = off.position.x
	c.offset_top = off.position.y
	c.offset_right = off.size.x
	c.offset_bottom = off.size.y


# ------------------------------------------------------------ панель героя
func _build_vitals() -> void:
	_vitals = _panel(_root, "panel_vitals", Color(0.07, 0.08, 0.09, 0.72))
	_anchored(_vitals, Rect2(MARGIN, MARGIN, VITALS_W, 118.0), Rect2(0, 0, 0, 0))

	# HP (красная), силы (зелёная), опыт (жёлтая) — узкие «полоски».
	var hp := _make_bar(_vitals, 10.0, "bar_fill_hp", Color(0.78, 0.15, 0.13))
	_hp_fill = hp["fill"]
	_hp_bar_w = hp["width"]
	var st := _make_bar(_vitals, 44.0, "bar_fill_stamina", Color(0.55, 0.72, 0.20))
	_stam_fill = st["fill"]
	var xp := _make_bar(_vitals, 78.0, "bar_fill_xp", Color(0.85, 0.68, 0.18))
	_xp_fill = xp["fill"]
	(_xp_fill.get_parent() as Control).custom_minimum_size = Vector2(0, 8)

	_meta_label = _label(_vitals, "Ур. 1", 20, Color(0.96, 0.86, 0.60))
	_meta_label.position = Vector2(10, 92)

	_geiger_icon = _icon(_vitals, "icon_geiger", Vector2(28, 28))
	_geiger_icon.position = Vector2(VITALS_W - 76, 88)
	_rad_icon = _icon(_vitals, "icon_radiation", Vector2(28, 28))
	_rad_icon.position = Vector2(VITALS_W - 42, 88)
	_rad_label = _label(_vitals, "Радиация: 0 %", 15, Color(0.72, 0.78, 0.66))
	_rad_label.position = Vector2(10, 66)
	_rad_label.size = Vector2(150, 20)


## Полоска: рамка (если есть) + обрезка + заливка. Возвращает заливку и ширину.
func _make_bar(parent: Node, y: float, fill_name: String, color: Color) -> Dictionary:
	var frame := _panel(parent, "bar_frame_" + fill_name.replace("bar_fill_", ""),
		Color(0.16, 0.17, 0.18, 0.85))
	_anchored(frame, Rect2(10, y, VITALS_W - 20, BAR_H), Rect2(0, 0, 0, 0))
	var inner_w: float = VITALS_W - 24.0
	var clip := Control.new()
	clip.name = fill_name + "_clip"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Assets.has_ui(fill_name):
		var tr := TextureRect.new()
		tr.texture = Assets.ui(fill_name)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.size = Vector2(inner_w, BAR_H - 8.0)
		clip.add_child(tr)
	else:
		var cr := ColorRect.new()
		cr.color = color
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cr.size = Vector2(inner_w, BAR_H - 8.0)
		clip.add_child(cr)
	clip.position = Vector2(2, 4)
	clip.size = Vector2(inner_w, BAR_H - 8.0)
	frame.add_child(clip)
	return {"fill": clip, "width": inner_w}


## Индикатор детектора артефактов: ярче, когда рядом аномалия.
func _build_detector() -> void:
	_detector = _panel(_root, "panel_detector", Color(0.07, 0.08, 0.09, 0.60))
	_anchored(_detector, Rect2(MARGIN, 148.0, 132.0, 56.0), Rect2(0, 0, 0, 0))
	_detector_icon = _icon(_detector, "icon_detector", Vector2(40, 40))
	_detector_icon.position = Vector2(6, 8)
	_detector_label = _label(_detector, "Детектор: тихо", 14, Color(0.70, 0.78, 0.72))
	_detector_label.position = Vector2(50, 6)
	_detector_label.size = Vector2(78, 44)
	_detector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detector.visible = false


# ------------------------------------------------------------ панель действий
func _build_actionbar() -> void:
	_actionbar = _panel(_root, "panel_actionbar", Color(0.07, 0.08, 0.09, 0.72))
	# центр по низу: ширина 460, высота 92, отступ 16 от края
	_anchored(_actionbar, Rect2(-230.0, -108.0, 230.0, -MARGIN),
		Rect2(0.5, 1.0, 0.5, 1.0))

	var slot := _panel(_actionbar, "panel_slot", Color(0.13, 0.14, 0.15, 0.9))
	_anchored(slot, Rect2(6, 6, 78, 78), Rect2(0, 0, 0, 0))
	_weapon_icon = _icon(slot, "icon_weapon_empty", Vector2(60, 60))
	_weapon_icon.position = Vector2(9, 9)

	_weapon_label = _label(_actionbar, "Без оружия", 18, Color(0.92, 0.90, 0.84))
	_weapon_label.position = Vector2(92, 8)
	_weapon_label.size = Vector2(220, 22)
	_ammo_label = _label(_actionbar, "— 0/0", 26, Color(0.98, 0.86, 0.55))
	_ammo_label.position = Vector2(92, 30)
	_ammo_label.size = Vector2(220, 32)
	_reload_label = _label(_actionbar, "", 16, Color(0.95, 0.60, 0.35))
	_reload_label.position = Vector2(92, 62)
	_reload_label.size = Vector2(160, 20)
	_hint_label = _label(_actionbar, "", 15, Color(0.70, 0.74, 0.70))
	_hint_label.position = Vector2(250, 62)
	_hint_label.size = Vector2(206, 20)


# ------------------------------------------------------------------ мини-карта
func _build_minimap() -> void:
	_minimap_frame = _panel(_root, "minimap_frame", Color(0.06, 0.07, 0.08, 0.80))
	var w: float = MINIMAP + MINIMAP_INSET * 2.0
	_anchored(_minimap_frame, Rect2(-(w + MARGIN), MARGIN, -MARGIN, w + MARGIN),
		Rect2(1, 0, 1, 0))

	var view := MinimapView.new()
	view.name = "MinimapView"
	view.host = self
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.clip_contents = true
	view.rotation = 0.0
	_anchored(view, Rect2(MINIMAP_INSET, MINIMAP_INSET, MINIMAP_INSET + MINIMAP,
		MINIMAP_INSET + MINIMAP), Rect2(0, 0, 0, 0))
	_minimap_frame.add_child(view)
	_minimap = view

	_compass = _icon(_minimap_frame, "compass", Vector2(52, 52))
	var compass_pos: float = MINIMAP + MINIMAP_INSET - 46.0
	(_compass as Control).position = Vector2(compass_pos, MINIMAP_INSET + 2.0)
	(_compass as Control).pivot_offset = Vector2(26, 26)


func minimap_setup(zones: Dictionary, size_tiles: Vector2i, tile_size: int) -> void:
	_zones = zones if zones != null else {}
	_size_tiles = size_tiles
	_tile = maxi(1, tile_size)
	if _minimap != null:
		_minimap.queue_redraw()


func minimap_set_player(pos: Vector2) -> void:
	_player_pos = pos


# ------------------------------------------------------------------ трекер
func _build_quest_tracker() -> void:
	_quest_box = VBoxContainer.new()
	_quest_box.name = "QuestTracker"
	_quest_box.add_theme_constant_override("separation", 6)
	_quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: float = MARGIN + MINIMAP + MINIMAP_INSET * 2.0 + 10.0
	_anchored(_quest_box, Rect2(-(320.0 + MARGIN), top, -MARGIN, top + 200.0),
		Rect2(1, 0, 1, 0))
	_root.add_child(_quest_box)


func _refresh_quests() -> void:
	if _quest_box == null:
		return
	if not is_instance_valid(_quest_box):
		return
	for c in _quest_box.get_children():
		c.queue_free()
	var lines: Array = Quests.tracker_lines(3)
	if lines.is_empty():
		var empty := _label(_quest_box, "Заданий нет", 15, Color(0.62, 0.64, 0.60))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	for i in lines.size():
		var line: Dictionary = lines[i]
		var head: String = String(line.get("title", ""))
		if i == 0:
			head = "★ " + head
		var title := _label(_quest_box, head, 17,
			Color(0.96, 0.83, 0.44) if i == 0 else Color(0.84, 0.82, 0.74))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var text: String = String(line.get("text", ""))
		var zone: String = String(line.get("zone", ""))
		var body_color := Color(0.80, 0.84, 0.78)
		if text == "Вернуться с докладом":
			body_color = Color(0.58, 0.88, 0.55)
		var body := _label(_quest_box, text, 15, body_color)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if zone != "":
			var z := _label(_quest_box, "Где: " + zone, 13, Color(0.62, 0.66, 0.62))
			z.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


# ------------------------------------------------------- лента сообщений
func _build_log() -> void:
	_log_box = VBoxContainer.new()
	_log_box.name = "LogBox"
	_log_box.add_theme_constant_override("separation", 2)
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(_log_box, Rect2(MARGIN, -MARGIN - 132.0, MARGIN + 420.0, -MARGIN),
		Rect2(0, 1, 0, 1))
	_root.add_child(_log_box)


func _on_log_message(text: String, kind: String) -> void:
	if _log_box == null or not is_instance_valid(_log_box):
		return
	var color: Color = KIND_COLORS.get(kind, KIND_COLORS["info"])
	var l := _label(_log_box, text, 16, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_logs.append({"label": l, "age": 0.0})
	while _logs.size() > LOG_MAX:
		var old: Dictionary = _logs.pop_front()
		var ol: Variant = old.get("label")
		if is_instance_valid(ol):
			(ol as Node).queue_free()


func _update_logs(delta: float) -> void:
	if _logs.is_empty():
		return
	var i: int = _logs.size() - 1
	while i >= 0:
		var line: Dictionary = _logs[i]
		line["age"] = float(line.get("age", 0.0)) + delta
		var l: Variant = line.get("label")
		if not is_instance_valid(l):
			_logs.remove_at(i)
			i -= 1
			continue
		var age: float = float(line["age"])
		if age > LOG_LIFE:
			(l as Node).queue_free()
			_logs.remove_at(i)
		elif age > LOG_LIFE - LOG_FADE:
			(l as CanvasItem).modulate.a = clampf((LOG_LIFE - age) / LOG_FADE, 0.0, 1.0)
		i -= 1


func set_minimap_visible(value: bool) -> void:
	minimap_visible = value
	if _minimap_frame != null and is_instance_valid(_minimap_frame):
		_minimap_frame.visible = value


# --------------------------------------------------- подсказка по цели
func _build_target() -> void:
	_target_panel = _panel(_root, "panel_target", Color(0.07, 0.08, 0.09, 0.78))
	_anchored(_target_panel, Rect2(-150.0, 84.0, 150.0, 146.0), Rect2(0.5, 0, 0.5, 0))
	_target_name = _label(_target_panel, "", 17, Color(0.94, 0.86, 0.72))
	_target_name.position = Vector2(8, 4)
	_target_name.size = Vector2(284, 22)
	var bar := _make_bar(_target_panel, 26.0, "bar_fill_target", Color(0.80, 0.24, 0.18))
	_target_fill = bar["fill"]
	_target_bar_w = bar["width"]
	_target_panel.visible = false


# --------------------------------------------------- оверлеи: урон и виньетка
func _build_overlays() -> void:
	_vignette = _panel(_root, "vignette_low_hp", Color(0.55, 0.02, 0.02, 0.0), true)
	_anchored(_vignette, Rect2(0, 0, 0, 0), Rect2(0, 0, 1, 1))
	(_vignette as CanvasItem).modulate = Color(1, 1, 1, 0.0)

	_flash = _panel(_root, "damage_flash", Color(0.62, 0.04, 0.04, 0.0), true)
	_anchored(_flash, Rect2(0, 0, 0, 0), Rect2(0, 0, 1, 1))
	(_flash as CanvasItem).modulate = Color(1, 1, 1, 0.0)


## Вспышка урона: вызывается самим HUD (по падению hp) или игроком напрямую.
func flash_damage(amount: float = 0.0) -> void:
	_flash_t = clampf(0.55 + amount / 120.0, 0.55, 1.0)
	if _flash != null and is_instance_valid(_flash):
		(_flash as CanvasItem).modulate = Color(1.0, 0.75, 0.75, 0.85)


func set_quality(name: String) -> void:
	_quality = name
	# на «низком» мини-карта рисует меньше точек и без свечения
	if _root != null:
		_root.modulate = Color(1, 1, 1, 1)


func set_damage_numbers(value: bool) -> void:
	damage_numbers = value


func set_blood_enabled(value: bool) -> void:
	blood_enabled = value


# ------------------------------------------------------------------ кадр
func _process(delta: float) -> void:
	_time += delta
	_update_logs(delta)
	_update_flash(delta)
	_update_target(delta)

	if _minimap != null and minimap_visible and visible and is_instance_valid(_minimap):
		_update_player_pos()
		(_minimap as CanvasItem).queue_redraw()
		if _compass != null and is_instance_valid(_compass):
			var dir: Vector2 = _player_aim()
			(_compass as CanvasItem).rotation = dir.angle() + PI * 0.5

	_danger_t -= delta
	if _danger_t <= 0.0:
		_danger_t = DANGER_INTERVAL
		_update_detector()


func _player_node() -> Node2D:
	if game == null or not is_instance_valid(game):
		return null
	var p: Variant = game.get("player")
	if p == null or not is_instance_valid(p):
		return null
	return p as Node2D


func _update_player_pos() -> void:
	var p: Node2D = _player_node()
	if p != null:
		_player_pos = p.global_position


func _player_aim() -> Vector2:
	var p: Variant = _player_node()
	if p == null:
		return Vector2.RIGHT
	if p.has_method("aim_dir_now"):
		var d: Variant = p.call("aim_dir_now")
		if d is Vector2 and (d as Vector2).length() > 0.01:
			return (d as Vector2).normalized()
	return Vector2.RIGHT


func _update_flash(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta * 1.6)
		if _flash != null and is_instance_valid(_flash):
			(_flash as CanvasItem).modulate.a = _flash_t * 0.85
	elif _flash != null and is_instance_valid(_flash) \
			and (_flash as CanvasItem).modulate.a > 0.0:
		(_flash as CanvasItem).modulate.a = 0.0

	# пульс виньетки при низком hp: имитация «сердцебиения»
	var ratio: float = 1.0
	if GameState.hp_max > 0.0:
		ratio = GameState.hp / GameState.hp_max
	var low: bool = ratio < 0.35 and not GameState.is_dead
	var alpha: float = 0.0
	if low:
		var speed: float = 5.4 if ratio < 0.2 else 4.0
		alpha = (0.22 + 0.20 * ratio) * (0.55 + 0.45 * sin(_time * speed))
	_vignette_alpha(alpha)
	if low != _low_hp:
		_low_hp = low


func _vignette_alpha(a: float) -> void:
	if _vignette == null or not is_instance_valid(_vignette):
		return
	var ci := _vignette as CanvasItem
	ci.modulate = Color(1, 1, 1, clampf(a, 0.0, 0.85))


func _update_target(delta: float) -> void:
	_target_t -= delta
	if _target_t > 0.0:
		return
	_target_t = TARGET_INTERVAL
	var t: Node = _pick_target()
	_target = t
	if _target_panel == null or not is_instance_valid(_target_panel):
		return
	if t == null:
		_target_panel.visible = false
		return
	var hp: float = float(t.get("hp")) if t.get("hp") != null else 0.0
	var hp_max: float = float(t.get("hp_max")) if t.get("hp_max") != null else 0.0
	if hp_max <= 0.0:
		hp_max = maxf(1.0, hp)
	_target_panel.visible = true
	_target_name.text = _target_title(t)
	_target_fill.size.x = _target_bar_w * clampf(hp / hp_max, 0.0, 1.0)


func _pick_target() -> Node:
	var p: Variant = _player_node()
	if p == null or not is_inside_tree():
		return null
	var origin: Vector2 = (p as Node2D).global_position
	var aim: Vector2 = _player_aim()
	var mouse_ok: bool = false
	var mouse_pos: Vector2 = Vector2.ZERO
	if not DisplayServer.is_touchscreen_available() and get_viewport() != null:
		var mp: Variant = (p as Node2D).get_global_mouse_position()
		if mp is Vector2:
			mouse_pos = mp
			mouse_ok = mouse_pos.distance_to(origin) > 1.0
	var best: Node = null
	var best_score: float = -1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		if e.has_method("is_alive") and not bool(e.call("is_alive")):
			continue
		var pos: Vector2 = (e as Node2D).global_position
		if mouse_ok and pos.distance_to(mouse_pos) < 56.0:
			var score: float = 200.0 - pos.distance_to(mouse_pos)
			if score > best_score:
				best_score = score
				best = e
	if best != null:
		return best
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		if e.has_method("is_alive") and not bool(e.call("is_alive")):
			continue
		var pos: Vector2 = (e as Node2D).global_position
		var d: float = pos.distance_to(origin)
		if d > 520.0 or d < 1.0:
			continue
		if (pos - origin).normalized().dot(aim) < 0.975:
			continue
		var score: float = 100.0 - d * 0.1
		if score > best_score:
			best_score = score
			best = e
	return best


func _target_title(t: Node) -> String:
	var tid: Variant = t.get("enemy_type")
	var key: String = String(tid) if tid != null else ""
	var name: String = String(ENEMY_NAMES.get(key, key))
	if name == "":
		name = "Неизвестная тварь"
	var lvl: int = 1
	var lv: Variant = t.get("level")
	if lv != null:
		lvl = int(lv)
	var boss: bool = false
	var bs: Variant = t.get("boss")
	if bs != null:
		boss = bool(bs)
	var prefix: String = "Босс: " if boss else ""
	return "%s%s (ур. %d)" % [prefix, name, lvl]


# -------------------------------------------------- детектор аномалий
func _update_detector() -> void:
	if _detector == null or not is_instance_valid(_detector):
		return
	if not GameState.has_detector:
		_detector.visible = false
		_danger = 0.0
		return
	_detector.visible = true
	var pos: Vector2 = _player_pos
	var p: Node2D = _player_node()
	if p != null:
		pos = p.global_position
	var danger: float = 0.0
	if is_inside_tree():
		for a in get_tree().get_nodes_in_group("anomalies"):
			if not is_instance_valid(a):
				continue
			if a.has_method("danger_for"):
				danger = maxf(danger, clampf(float(a.call("danger_for", pos)), 0.0, 1.0))
	_danger = danger
	if _detector_icon != null and is_instance_valid(_detector_icon):
		var warm: Color = Color(1.0, 0.30, 0.22).lerp(Color(0.85, 0.95, 0.65), 1.0 - danger)
		_detector_icon.modulate = Color(warm.r, warm.g, warm.b,
			0.30 + 0.70 * danger + 0.15 * sin(_time * (2.0 + 8.0 * danger)))
		if _detector_icon.pivot_offset == Vector2.ZERO:
			_detector_icon.pivot_offset = Vector2(20, 20)
		var k: float = 1.0 + 0.30 * danger
		_detector_icon.scale = Vector2(k, k)
	if _detector_label != null and is_instance_valid(_detector_label):
		if danger < 0.15:
			_detector_label.text = "Детектор: тихо"
			_detector_label.modulate = Color(0.66, 0.74, 0.68)
		elif danger < 0.45:
			_detector_label.text = "Детектор: фон"
			_detector_label.modulate = Color(0.86, 0.84, 0.58)
		elif danger < 0.75:
			_detector_label.text = "Детектор: аномалия"
			_detector_label.modulate = Color(0.96, 0.68, 0.40)
		else:
			_detector_label.text = "Детектор: опасно!"
			_detector_label.modulate = Color(1.0, 0.42, 0.34)


# ------------------------------------------------------------------ обновления
func _refresh_all() -> void:
	_refresh_stats()
	_refresh_inventory()
	_refresh_quests()


func _refresh_stats() -> void:
	if _hp_fill == null or not is_instance_valid(_hp_fill):
		return
	var hp_max: float = maxf(1.0, GameState.hp_max)
	var hp: float = clampf(GameState.hp, 0.0, hp_max)
	_hp_fill.size.x = _hp_bar_w * (hp / hp_max)
	var stam_max: float = maxf(1.0, GameState.stamina_max)
	_stam_fill.size.x = _hp_bar_w * clampf(GameState.stamina / stam_max, 0.0, 1.0)
	var xp_next: float = maxf(1.0, GameState.xp_next)
	_xp_fill.size.x = _hp_bar_w * clampf(GameState.xp / xp_next, 0.0, 1.0)

	var rad: float = clampf(GameState.radiation / maxf(1.0, GameState.rad_max), 0.0, 1.0)
	_rad_label.text = "Радиация: %d %%" % roundi(rad * 100.0)
	_rad_label.modulate = Color(0.72, 0.78, 0.66).lerp(Color(0.95, 0.45, 0.30), rad)
	if _rad_icon != null and is_instance_valid(_rad_icon):
		_rad_icon.modulate = Color(1, 1, 1, 0.30 + 0.70 * rad)
	if _geiger_icon != null and is_instance_valid(_geiger_icon):
		var base_a: float = 0.9 if GameState.has_geiger else 0.35
		_geiger_icon.modulate = Color(1, 1, 1, clampf(base_a * (0.5 + 0.5 * rad), 0.15, 1.0))

	_meta_label.text = "Ур. %d   ●   %d руб." % [GameState.level, GameState.money]

	# вспышка урона по падению hp (единственный «поллинг» помимо мини-карты)
	if _prev_hp >= 0.0 and hp < _prev_hp - 0.5:
		flash_damage(_prev_hp - hp)
	_prev_hp = hp


func _refresh_inventory() -> void:
	if _weapon_label == null or not is_instance_valid(_weapon_label):
		return
	var name: String = ""
	var wid: String = ""
	var mag: int = 0
	var reserve: int = 0
	var mode: String = "melee"
	var p: Variant = null
	if game != null and is_instance_valid(game):
		p = game.get("player")
	if p != null and is_instance_valid(p):
		if p.has_method("weapon_name"):
			name = String(p.call("weapon_name"))
		if p.has_method("weapon_id"):
			wid = String(p.call("weapon_id"))
		if p.has_method("mag_count"):
			mag = int(p.call("mag_count"))
		if p.has_method("reserve_count"):
			reserve = int(p.call("reserve_count"))
		if p.has_method("weapon_data"):
			var d: Variant = p.call("weapon_data")
			if d is Dictionary:
				mode = String((d as Dictionary).get("mode", "melee"))
	if wid == "":
		wid = String(GameState.equipment.get("weapon", ""))
	if name == "":
		name = ItemDB.display_name(wid) if wid != "" else "Без оружия"
		var wd: Dictionary = ItemDB.get_item(wid)
		mode = String(wd.get("mode", "melee"))
		if mode == "gun":
			reserve = GameState.count_item(_ammo_id_for(String(wd.get("caliber", ""))))
	_weapon_label.text = name
	if mode == "gun":
		_ammo_label.text = "%s %d/%d" % [name, mag, reserve]
	else:
		_ammo_label.text = "%s · ближний бой" % name
	_ammo_label.modulate = Color(0.98, 0.86, 0.55) if (mag > 0 or mode != "gun") \
		else Color(0.92, 0.42, 0.36)
	var icon_name: String = ItemDB.icon(wid) if wid != "" else "icon_weapon_empty"
	if _weapon_icon != null and is_instance_valid(_weapon_icon):
		_weapon_icon.texture = Assets.ui(icon_name) if Assets.has_ui(icon_name) \
			else Assets.placeholder()
	var reload: float = 0.0
	if p != null and is_instance_valid(p) and p.get("_reload_time") != null:
		reload = float(p.get("_reload_time"))
	_reload_label.text = "Перезарядка…" if reload > 0.0 else ""
	var hint: String = ""
	if p != null and is_instance_valid(p) and p.has_method("interact_hint"):
		hint = String(p.call("interact_hint"))
	_hint_label.text = hint


func _ammo_id_for(caliber: String) -> String:
	if caliber == "":
		return ""
	for id in ItemDB.all_ids():
		var d: Dictionary = ItemDB.get_item(id)
		if int(d.get("kind", -1)) == ItemDB.Kind.AMMO \
				and String(d.get("caliber", "")) == caliber:
			return String(id)
	return ""


func _on_money_changed(_amount: int) -> void:
	_refresh_stats()


func _on_leveled_up(new_level: int) -> void:
	_on_log_message("Новый уровень: %d" % new_level, "good")


func _on_player_died() -> void:
	_on_log_message("Сталкер погиб в Зоне", "bad")
	flash_damage(60.0)
	_vignette_alpha(0.5)


func _on_quest_changed(_id: String) -> void:
	_refresh_quests()


# ------------------------------------------------------------- отрисовка карты
## Масштаб и смещение карты внутри холста мини-карты. Отдельная функция нужна,
## чтобы ту же математику проверял headless-тест (в headless _draw не зовётся).
func map_transform(view: Vector2) -> Dictionary:
	var world: Vector2 = Vector2(_size_tiles) * float(_tile)
	if world.x <= 1.0 or world.y <= 1.0 or not world.is_finite() \
			or view.x <= 2.0 or view.y <= 2.0:
		return {"ok": false, "scale": 0.0, "offset": Vector2.ZERO, "world": world}
	var s: float = minf(view.x / world.x, view.y / world.y)
	return {"ok": true, "scale": s, "offset": (view - world * s) * 0.5, "world": world}


## Вызывается из MinimapView._draw(): рисует зоны, метки, стрелку игрока.
func _draw_minimap(c: Control) -> void:
	var view: Vector2 = c.size
	if view.x <= 2.0 or view.y <= 2.0:
		return
	var tr: Dictionary = map_transform(view)
	if not bool(tr.get("ok", false)):
		c.draw_rect(Rect2(Vector2.ZERO, view), Color(0.10, 0.11, 0.12))
		_draw_map_text(c, "нет данных", Vector2(8, 20))
		return
	var s: float = float(tr["scale"])
	var off: Vector2 = tr["offset"]
	var world: Vector2 = tr["world"]
	c.draw_rect(Rect2(Vector2.ZERO, view), Color(0.09, 0.10, 0.10))

	# зоны: цвет по имени, рамка светлее
	for key in _zones.keys():
		var r: Variant = _zones[key]
		if not (r is Rect2):
			continue
		var rect: Rect2 = r
		var rr := Rect2(off + rect.position * s, rect.size * s)
		c.draw_rect(rr, _zone_color(String(key), 0.30), true)
		c.draw_rect(rr, _zone_color(String(key), 0.75), false, 1.0)
	c.draw_rect(Rect2(off, world * s), Color(0.60, 0.62, 0.52, 0.55), false, 1.5)

	var blips: int = BLIP_LIMIT if _quality != "low" else BLIP_LIMIT / 2
	var loot_max: int = LOOT_LIMIT if _quality != "low" else LOOT_LIMIT / 2

	_draw_anomalies(c, off, s)
	_draw_group(c, "loot", off, s, Color(0.95, 0.85, 0.35), 2.4, loot_max, true)
	_draw_group(c, "containers", off, s, Color(0.62, 0.72, 0.88), 2.6, loot_max, false)
	_draw_enemies(c, off, s, blips)
	_draw_player(c, off, s)


func _zone_color(key: String, alpha: float) -> Color:
	match key:
		"kordon":
			return Color(0.42, 0.48, 0.36, alpha)
		"village":
			return Color(0.50, 0.44, 0.34, alpha)
		"factory":
			return Color(0.40, 0.42, 0.46, alpha)
		"bunker":
			return Color(0.30, 0.33, 0.40, alpha)
		"swamp":
			return Color(0.30, 0.42, 0.34, alpha)
		"field":
			return Color(0.48, 0.36, 0.46, alpha)
		_:
			return Color(0.40, 0.40, 0.40, alpha * 0.7)


func _draw_map_text(c: Control, text: String, pos: Vector2) -> void:
	var f: Font = Assets.font_body
	if f == null:
		return
	c.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.86, 0.80))


func _draw_anomalies(c: Control, off: Vector2, s: float) -> void:
	if not is_inside_tree():
		return
	for a in get_tree().get_nodes_in_group("anomalies"):
		if not is_instance_valid(a) or not (a is Node2D):
			continue
		var pos: Vector2 = (a as Node2D).global_position
		var rad: float = 96.0
		var rr: Variant = a.get("radius")
		if rr != null:
			rad = float(rr)
		var tid: String = ""
		var t: Variant = a.get("type_id")
		if t != null:
			tid = String(t)
		var col: Color = ANOMALY_COLORS.get(tid, Color(0.66, 0.44, 0.86))
		var p: Vector2 = off + pos * s
		var pr: float = maxf(2.0, rad * s)
		c.draw_circle(p, pr, Color(col.r, col.g, col.b, 0.22))
		c.draw_arc(p, pr, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.65), 1.2)
		if a.has_method("has_artifact") and bool(a.call("has_artifact")):
			c.draw_circle(p, 2.6, Color(0.98, 0.95, 0.55))


func _draw_group(c: Control, group: String, off: Vector2, s: float, color: Color,
		dot: float, limit: int, skip_opened: bool) -> void:
	if not is_inside_tree() or limit <= 0:
		return
	var drawn: int = 0
	for n in get_tree().get_nodes_in_group(group):
		if drawn >= limit:
			break
		if not is_instance_valid(n) or not (n is Node2D):
			continue
		if skip_opened and n.get("opened") != null and bool(n.get("opened")):
			continue
		var p: Vector2 = off + (n as Node2D).global_position * s
		c.draw_rect(Rect2(p - Vector2(dot, dot), Vector2(dot, dot) * 2.0), color)
		drawn += 1


func _draw_enemies(c: Control, off: Vector2, s: float, limit: int) -> void:
	if not is_inside_tree() or limit <= 0:
		return
	var list: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		if e.has_method("is_alive") and not bool(e.call("is_alive")):
			continue
		var pos: Vector2 = (e as Node2D).global_position
		list.append({"d": pos.distance_squared_to(_player_pos), "p": pos, "n": e})
	list.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	var count: int = mini(limit, list.size())
	for i in count:
		var item: Dictionary = list[i]
		var pos: Vector2 = item["p"]
		var node: Node = item["n"]
		var boss: bool = node.get("boss") != null and bool(node.get("boss"))
		var col: Color = Color(1.0, 0.55, 0.20) if boss else Color(0.95, 0.30, 0.24)
		var p: Vector2 = off + pos * s
		c.draw_circle(p, 4.0 if boss else 3.0, col)


func _draw_player(c: Control, off: Vector2, s: float) -> void:
	var pos: Vector2 = _player_pos
	var p: Node2D = _player_node()
	if p != null:
		pos = p.global_position
	var fwd: Vector2 = _player_aim()
	var right: Vector2 = fwd.orthogonal()
	var c0: Vector2 = off + pos * s
	var pts := PackedVector2Array([
		c0 + fwd * 8.0,
		c0 - fwd * 5.0 + right * 5.0,
		c0 - fwd * 5.0 - right * 5.0,
	])
	c.draw_colored_polygon(pts, Color(0.88, 0.96, 1.0))
	c.draw_arc(c0, 10.0, 0.0, TAU, 20, Color(0.75, 0.85, 0.95, 0.45), 1.0)
	# сектор обзора
	var a0: float = fwd.angle() - 0.5
	var a1: float = fwd.angle() + 0.5
	c.draw_arc(c0, 34.0, a0, a1, 12, Color(0.80, 0.90, 1.0, 0.35), 1.0)


# ------------------------------------------------------------------ отладка
## Короткая сводка для тестов: сколько элементов HUD реально собрано.
func describe() -> Dictionary:
	var counts := {
		"root": _root != null,
		"minimap": _minimap != null,
		"quest_box": _quest_box != null,
		"log_box": _log_box != null,
		"logs": _logs.size(),
		"nodes": count_nodes(self),
		"zones": _zones.size(),
		"size_tiles": _size_tiles,
	}
	return counts


func count_nodes(n: Node) -> int:
	var total: int = 1
	for c in n.get_children():
		total += count_nodes(c)
	return total




