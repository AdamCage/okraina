class_name InventoryUI extends CanvasLayer
## Сумка сталкера: 40 слотов, колонка снаряжения (оружие/броня/шлем + 3 ячейки
## артефактов), панель описания предмета со сравнением с надетым оружием,
## счётчик веса и денег, фильтры и три больших кнопки действий.
##
## Рассчитано на палец: слоты 64x64, кнопки 64 px высотой, «тап = действие»,
## подтверждение только для выброса квестовых предметов. Клавиатура работает
## параллельно: E — открыть/закрыть, Esc — закрыть.

const CELL := 64.0            ## сторона слота (минимум 64 px под палец)
const GAP := 6.0
const COLS := 8
const ROWS := 5
const MAX_SLOTS := 40
const BTN_H := 64.0
const CONFIRM_TIME := 4.0

const FILTERS: Array = [
	{"id": "all", "label": "Всё"},
	{"id": "weapon", "label": "Оружие"},
	{"id": "armor", "label": "Броня"},
	{"id": "med", "label": "Медицина"},
	{"id": "artifact", "label": "Артефакты"},
]

const ARMOR_COLOR := Color(0.62, 0.76, 0.95)
const COLOR_KIND := Color(0.62, 0.76, 0.95)
const GOOD_COLOR := Color(0.58, 0.88, 0.55)
const BAD_COLOR := Color(0.94, 0.46, 0.40)

var game: Node = null

var _root: Control
var _dim: Control
var _window: Control
var _title: Label
var _grid: GridContainer
var _equip_box: Control
var _equip_buttons: Dictionary = {}
var _tooltip: Control
var _tt_name: Label
var _tt_kind: Label
var _tt_stats: Label
var _tt_desc: Label
var _weight_label: Label
var _penalty_label: Label
var _money_label: Label
var _filter_buttons: Array = []
var _act_buttons: Array = []
var _hint: Label
var _sel_index: int = -1
var _sel_equip: String = ""
var _filter: String = "all"
var _open: bool = false
var _confirm_drop: bool = false
var _confirm_t: float = 0.0


func setup(game_node: Node) -> void:
	game = game_node
	layer = 20
	_build()
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.stats_changed.connect(_on_stats_changed)
	GameState.money_changed.connect(_on_money_changed)
	set_process(true)
	set_process_input(true)


# ------------------------------------------------------------------ построение
## Панель-подложка: NinePatch, если текстура есть; иначе непрозрачная тёмная
## панель StyleBoxFlat — иначе на телефоне окна просвечивают и текст не читается.
func _panel(parent: Node, tex_name: String, fallback: Color) -> Control:
	if Assets.has_ui(tex_name):
		var np := NinePatchRect.new()
		np.name = tex_name
		np.texture = Assets.ui(tex_name)
		np.patch_margin_left = 14
		np.patch_margin_right = 14
		np.patch_margin_top = 14
		np.patch_margin_bottom = 14
		parent.add_child(np)
		return np
	var p := Panel.new()
	p.name = tex_name
	p.add_theme_stylebox_override("panel", panel_style())
	parent.add_child(p)
	return p


## Непрозрачный тёмный стиль панели (fallback, когда assets/ui ещё пуст).
func panel_style(alpha: float = 0.97) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.062, 0.070, alpha)
	sb.border_color = Color(0.30, 0.28, 0.24)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	return sb


## Стиль слота/кнопки: та же непрозрачная основа, выделение — светлая рамка.
func slot_style(selected: bool = false, bg: float = 0.97) -> StyleBoxFlat:
	var sb := panel_style(bg)
	sb.bg_color = Color(0.075, 0.082, 0.090, bg) if not selected \
		else Color(0.14, 0.13, 0.10, bg)
	sb.border_color = Color(0.96, 0.82, 0.42) if selected else Color(0.30, 0.28, 0.24)
	if selected:
		sb.set_border_width_all(3)
	sb.set_content_margin_all(6)
	return sb


func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if Assets.font_body != null:
		l.add_theme_font_override("font", Assets.font_body)
	l.modulate = color
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Кнопка с текстурой btn_idle/btn_press, если она есть; иначе стандартная.
func _button(parent: Node, text: String, size: Vector2, font_size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.size = size
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", font_size)
	if Assets.font_body != null:
		b.add_theme_font_override("font", Assets.font_body)
	if Assets.has_ui("btn_idle"):
		var sb := StyleBoxTexture.new()
		sb.texture = Assets.ui("btn_idle")
		sb.texture_margin_left = 14
		sb.texture_margin_right = 14
		sb.texture_margin_top = 14
		sb.texture_margin_bottom = 14
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override("normal", sb)
		var hovered: StyleBoxTexture = sb.duplicate()
		b.add_theme_stylebox_override("hover", hovered)
		if Assets.has_ui("btn_press"):
			var sbp: StyleBoxTexture = sb.duplicate()
			sbp.texture = Assets.ui("btn_press")
			sbp.texture_margin_left = 14
			sbp.texture_margin_right = 14
			sbp.texture_margin_top = 14
			sbp.texture_margin_bottom = 14
			b.add_theme_stylebox_override("pressed", sbp)
			b.add_theme_stylebox_override("focus", sbp)
	else:
		var flat := panel_style(0.97)
		flat.set_content_margin_all(10)
		b.add_theme_stylebox_override("normal", flat)
		b.add_theme_stylebox_override("hover", flat)
		var pressed: StyleBoxFlat = panel_style(0.97)
		pressed.bg_color = Color(0.16, 0.17, 0.17, 0.97)
		pressed.set_content_margin_all(10)
		b.add_theme_stylebox_override("pressed", pressed)
		b.add_theme_stylebox_override("focus", pressed)
	b.add_theme_color_override("font_color", Color(0.92, 0.90, 0.84))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.52, 0.52, 0.50))
	parent.add_child(b)
	return b


func _anchored(c: Control, off: Rect2, anchors: Rect2) -> void:
	c.anchor_left = anchors.position.x
	c.anchor_top = anchors.position.y
	c.anchor_right = anchors.size.x
	c.anchor_bottom = anchors.size.y
	c.offset_left = off.position.x
	c.offset_top = off.position.y
	c.offset_right = off.size.x
	c.offset_bottom = off.size.y


func _build() -> void:
	_root = Control.new()
	_root.name = "InventoryRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.03, 0.55)
	_anchored(_dim, Rect2(0, 0, 0, 0), Rect2(0, 0, 1, 1))
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	_window = _panel(_root, "panel_window", Color(0.08, 0.09, 0.10, 0.96))
	_anchored(_window, Rect2(16, 16, 856, 704), Rect2(0, 0, 0, 0))

	_title = _label(_window, "Сумка", 28, Color(0.96, 0.86, 0.55))
	if Assets.font_title != null:
		_title.add_theme_font_override("font", Assets.font_title)
	_title.position = Vector2(18, 6)
	_title.size = Vector2(300, 34)

	var close_btn := _button(_window, "Закрыть  (Esc)", Vector2(180, 40), 17)
	close_btn.position = Vector2(636, 8)
	close_btn.pressed.connect(close)

	_build_filters()
	_build_grid()
	_build_equipment()
	_build_bottom()
	_build_tooltip()


func _build_filters() -> void:
	var x: float = 260.0
	var w: float = 106.0
	for f in FILTERS:
		var b := _button(_window, String(f["label"]), Vector2(w, 60.0), 19)
		b.position = Vector2(x, 48.0)
		b.set_meta("filter_id", String(f["id"]))
		b.pressed.connect(_on_filter_pressed.bind(String(f["id"])))
		_filter_buttons.append(b)
		x += w + GAP


func _build_grid() -> void:
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_grid.position = Vector2(260, 116)
	_grid.size = Vector2(COLS * CELL + (COLS - 1) * GAP, ROWS * CELL + (ROWS - 1) * GAP)
	_window.add_child(_grid)
	for i in MAX_SLOTS:
		var b := _slot_button(_grid, i)
		_grid.add_child(b)


## Слот сумки: кнопка 64x64 с иконкой и счётчиком.
func _slot_button(parent: Node, index: int, equip_key: String = "") -> Button:
	var b := Button.new()
	b.name = "Slot%d" % index
	b.custom_minimum_size = Vector2(CELL, CELL)
	b.size = Vector2(CELL, CELL)
	b.set_meta("slot_index", index)
	if Assets.has_ui("panel_slot"):
		var sb := _slot_style("panel_slot")
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		var sel := _slot_style("panel_slot_sel")
		b.add_theme_stylebox_override("pressed", sel)
		b.add_theme_stylebox_override("focus", sel)
	else:
		var flat := slot_style(false, 0.97)
		b.add_theme_stylebox_override("normal", flat)
		b.add_theme_stylebox_override("hover", flat)
		var sel := slot_style(true, 0.97)
		b.add_theme_stylebox_override("pressed", sel)
		b.add_theme_stylebox_override("focus", sel)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(CELL - 10.0, CELL - 10.0)
	icon.position = Vector2(5, 5)
	b.add_child(icon)
	var count := _label(b, "", 15, Color(0.98, 0.94, 0.80))
	count.name = "Count"
	count.position = Vector2(2, CELL - 22.0)
	count.size = Vector2(CELL - 6.0, 20)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if equip_key == "":
		b.pressed.connect(_on_slot_pressed.bind(index))
	else:
		b.pressed.connect(_on_equip_pressed.bind(equip_key))
	return b


func _build_equipment() -> void:
	_equip_box = Control.new()
	_equip_box.name = "Equipment"
	_equip_box.position = Vector2(20, 112)
	_equip_box.size = Vector2(226, 400)
	_window.add_child(_equip_box)

	var head := _label(_equip_box, "Снаряжение", 20, Color(0.94, 0.84, 0.56))
	head.position = Vector2(0, 0)
	head.size = Vector2(220, 26)

	var rows: Array = [
		{"key": "weapon", "label": "Оружие", "y": 34.0},
		{"key": "armor", "label": "Броня", "y": 104.0},
		{"key": "helmet", "label": "Шлем", "y": 174.0},
	]
	for r in rows:
		var slot := _equip_slot(String(r["key"]), String(r["label"]), float(r["y"]))
		_equip_buttons[String(r["key"])] = slot

	var art_head := _label(_equip_box, "Артефакты", 20, Color(0.94, 0.84, 0.56))
	art_head.position = Vector2(0, 244)
	art_head.size = Vector2(220, 26)
	for i in 3:
		var key: String = "artifact_%d" % (i + 1)
		var b := _equip_slot(key, "—", 0.0, true)
		b.position = Vector2(float(i) * (CELL + 10.0), 274.0)


func _equip_slot(key: String, label_text: String, y: float, label_below: bool = false) -> Button:
	var b := _slot_button(_equip_box, -1, key)
	b.name = "Equip_" + key
	b.position = Vector2(0, y)
	b.set_meta("equip_key", key)
	_equip_box.add_child(b)
	_equip_buttons[key] = b
	(b.get_node("Count") as Label).text = ""
	# подпись — ребёнок кнопки, чтобы её не пришлось искать отдельно
	var nm := _label(b, label_text, 14 if label_below else 17, Color(0.86, 0.86, 0.80))
	nm.name = "Name"
	if label_below:
		nm.position = Vector2(0, CELL + 2.0)
		nm.size = Vector2(CELL + 8.0, 40)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		nm.position = Vector2(CELL + 12.0, 20.0)
		nm.size = Vector2(150, 24)
	return b


func _build_bottom() -> void:
	_weight_label = _label(_window, "Вес: 0 / 60 кг", 20, Color(0.90, 0.90, 0.84))
	_weight_label.position = Vector2(260, 466)
	_weight_label.size = Vector2(300, 26)
	_money_label = _label(_window, "Рубли: 0", 20, Color(0.96, 0.86, 0.55))
	_money_label.position = Vector2(560, 466)
	_money_label.size = Vector2(250, 26)
	_penalty_label = _label(_window, "", 16, BAD_COLOR)
	_penalty_label.position = Vector2(260, 494)
	_penalty_label.size = Vector2(554, 22)
	_penalty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var labels: Array = ["Надеть", "Использовать", "Выбросить"]
	for i in labels.size():
		var b := _button(_window, String(labels[i]), Vector2(180, BTN_H), 21)
		b.position = Vector2(260.0 + float(i) * 190.0, 524.0)
		b.set_meta("action_id", i)
		b.pressed.connect(_on_action_pressed.bind(i))
		_act_buttons.append(b)

	_hint = _label(_window, "Выберите предмет в сумке или в снаряжении",
		16, Color(0.72, 0.74, 0.70))
	_hint.position = Vector2(260, 596)
	_hint.size = Vector2(554, 24)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_tooltip() -> void:
	_tooltip = _panel(_root, "panel_tooltip", Color(0.07, 0.08, 0.09, 0.96))
	_anchored(_tooltip, Rect2(-408, 16, -16, 704), Rect2(1, 0, 1, 0))
	_tt_name = _label(_tooltip, "Предмет не выбран", 24, Color(0.96, 0.90, 0.70))
	if Assets.font_title != null:
		_tt_name.add_theme_font_override("font", Assets.font_title)
	_tt_name.position = Vector2(14, 12)
	_tt_name.size = Vector2(360, 60)
	_tt_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tt_kind = _label(_tooltip, "", 17, COLOR_KIND)
	_tt_kind.position = Vector2(14, 76)
	_tt_kind.size = Vector2(360, 24)
	_tt_stats = _label(_tooltip, "", 17, Color(0.88, 0.90, 0.84))
	_tt_stats.position = Vector2(14, 104)
	_tt_stats.size = Vector2(360, 300)
	_tt_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tt_desc = _label(_tooltip, "", 16, Color(0.76, 0.78, 0.74))
	_tt_desc.position = Vector2(14, 410)
	_tt_desc.size = Vector2(360, 200)
	_tt_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Стиль слота из текстуры (panel_slot / panel_slot_sel).
func _slot_style(tex_name: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = Assets.ui(tex_name)
	sb.texture_margin_left = 10
	sb.texture_margin_right = 10
	sb.texture_margin_top = 10
	sb.texture_margin_bottom = 10
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


# ------------------------------------------------------------------ состояние
func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	_open = true
	_confirm_drop = false
	_root.visible = true
	Sfx.ui("ui_open")
	if _sel_index < 0 and _sel_equip == "":
		_sel_index = 0 if not GameState.inventory.is_empty() else -1
	rebuild()


func close() -> void:
	if not _open:
		return
	_open = false
	_confirm_drop = false
	_root.visible = false
	Sfx.ui("ui_close")


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var key := event as InputEventKey
	if key.echo:
		return
	match key.keycode:
		KEY_ESCAPE, KEY_E, KEY_I:
			close()
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
		KEY_F:
			_on_action_pressed(2)
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			_on_action_pressed(0)
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
		_:
			pass


func _process(delta: float) -> void:
	if not _confirm_drop:
		return
	_confirm_t -= delta
	if _confirm_t <= 0.0:
		_confirm_drop = false
		_update_actions()


func _on_inventory_changed() -> void:
	if not _open:
		return
	if _sel_index >= GameState.inventory.size():
		_sel_index = GameState.inventory.size() - 1
	rebuild()


func _on_stats_changed() -> void:
	if _open:
		_update_weight()
		_update_actions()


func _on_money_changed(_amount: int) -> void:
	if _open:
		_update_weight()


# ------------------------------------------------------------------ сборка вида
func rebuild() -> void:
	_rebuild_slots()
	_rebuild_equipment()
	_update_weight()
	_update_tooltip()
	_update_filters()
	_update_actions()


func _rebuild_slots() -> void:
	var items: Array = GameState.inventory
	for i in MAX_SLOTS:
		var btn: Button = _grid.get_child(i)
		if i < items.size():
			var slot: Dictionary = items[i]
			var id: String = String(slot.get("id", ""))
			var count: int = int(slot.get("count", 1))
			if not _passes_filter(id):
				_blank_slot(btn, i)
				continue
			_fill_slot(btn, id, count)
			btn.set_meta("slot_index", i)
		else:
			_blank_slot(btn, i)


func _passes_filter(id: String) -> bool:
	if _filter == "all" or id == "":
		return true
	var kind: int = ItemDB.kind_of(id)
	match _filter:
		"weapon":
			return kind == ItemDB.Kind.WEAPON
		"armor":
			return kind == ItemDB.Kind.ARMOR or kind == ItemDB.Kind.HELMET
		"med":
			return kind == ItemDB.Kind.MED or kind == ItemDB.Kind.FOOD
		"artifact":
			return kind == ItemDB.Kind.ARTIFACT
	return true


func _fill_slot(btn: Button, id: String, count: int) -> void:
	var icon := btn.get_node("Icon") as TextureRect
	var icon_name: String = ItemDB.icon(id)
	icon.texture = Assets.ui(icon_name) if Assets.has_ui(icon_name) else Assets.placeholder()
	icon.visible = true
	var lbl := btn.get_node("Count") as Label
	lbl.text = ("%d" % count) if count > 1 else ""
	btn.disabled = false
	btn.set_meta("item_id", id)


func _blank_slot(btn: Button, index: int) -> void:
	var icon := btn.get_node("Icon") as TextureRect
	icon.texture = null
	icon.visible = false
	(btn.get_node("Count") as Label).text = ""
	btn.disabled = true
	btn.set_meta("item_id", "")
	btn.set_meta("slot_index", -1)
	if index >= 0:
		btn.name = "Slot%d" % index


func _rebuild_equipment() -> void:
	for key in _equip_buttons.keys():
		var btn: Button = _equip_buttons[key]
		var id: String = String(GameState.equipment.get(String(key), ""))
		var icon := btn.get_node("Icon") as TextureRect
		var nm := btn.get_node("Name") as Label
		if id == "":
			icon.texture = null
			icon.visible = false
			nm.text = "Пусто"
			nm.modulate = Color(0.58, 0.58, 0.56)
		else:
			var icon_name: String = ItemDB.icon(id)
			icon.texture = Assets.ui(icon_name) if Assets.has_ui(icon_name) \
				else Assets.placeholder()
			icon.visible = true
			nm.text = ItemDB.display_name(id)
			nm.modulate = ARMOR_COLOR if String(key) != "weapon" \
				else Color(0.96, 0.88, 0.60)
		btn.set_meta("item_id", id)


func _update_filters() -> void:
	for b in _filter_buttons:
		var b_id: String = String((b as Button).get_meta("filter_id", "all"))
		(b as Button).modulate = Color(1, 1, 1) if b_id == _filter \
			else Color(0.74, 0.74, 0.70)


func _update_weight() -> void:
	var w: float = GameState.total_weight()
	var mx: float = maxf(1.0, GameState.max_weight())
	_weight_label.text = "Вес: %.1f / %.1f кг" % [w, mx]
	var over: bool = w > mx
	_weight_label.modulate = BAD_COLOR if over else Color(0.90, 0.90, 0.84)
	_money_label.text = "Рубли: %d" % GameState.money
	if over:
		var pen: float = clampf((w / mx - 1.0) * 100.0, 5.0, 50.0)
		_penalty_label.text = "Перегрузка: скорость передвижения снижена на %d %% (выбросьте лишнее)" % roundi(pen)
	else:
		_penalty_label.text = ""


# ------------------------------------------------------------------ выбор
func _on_slot_pressed(index: int) -> void:
	_sel_index = index
	_sel_equip = ""
	_confirm_drop = false
	Sfx.ui("ui_click")
	_update_tooltip()
	_update_actions()
	_populate_selection()
	_highlight_selected()


func _on_equip_pressed(key: String) -> void:
	_sel_equip = key
	_sel_index = -1
	_confirm_drop = false
	Sfx.ui("ui_click")
	_update_tooltip()
	_update_actions()
	_populate_selection()
	_highlight_selected()


func _on_filter_pressed(filter_id: String) -> void:
	_filter = filter_id
	Sfx.ui("ui_click")
	rebuild()


func _highlight_selected() -> void:
	for i in _grid.get_child_count():
		var btn: Button = _grid.get_child(i)
		var idx: int = int(btn.get_meta("slot_index", -1))
		var on: bool = idx == _sel_index and _sel_index >= 0
		btn.modulate = Color(1.0, 0.96, 0.72) if on else Color(1, 1, 1)
	for key in _equip_buttons.keys():
		var btn: Button = _equip_buttons[key]
		btn.modulate = Color(1.0, 0.96, 0.72) if String(key) == _sel_equip \
			else Color(1, 1, 1)


## Слот выделенного предмета: {"id", "count", "equipped", "slot"}.
func selected_item() -> Dictionary:
	if _sel_equip != "":
		var eq_id: String = String(GameState.equipment.get(_sel_equip, ""))
		if eq_id == "":
			return {}
		return {"id": eq_id, "count": 1, "equipped": true, "slot": _sel_equip}
	if _sel_index >= 0 and _sel_index < GameState.inventory.size():
		var slot: Dictionary = GameState.inventory[_sel_index]
		return {"id": String(slot.get("id", "")), "count": int(slot.get("count", 1)),
			"equipped": false, "slot": ""}
	return {}


func _populate_selection() -> void:
	var sel := selected_item()
	if sel.is_empty():
		_hint.text = "Предмет не выбран — ткните в слот сумки"
	else:
		_hint.text = ItemDB.display_name(String(sel["id"])) + " · " \
			+ ItemDB.kind_name(ItemDB.kind_of(String(sel["id"])))


func _update_tooltip() -> void:
	var sel := selected_item()
	if sel.is_empty():
		_tt_name.text = "Предмет не выбран"
		_tt_kind.text = "Ткните в слот сумки или снаряжения"
		_tt_stats.text = ""
		_tt_desc.text = ""
		return
	var id: String = String(sel["id"])
	var count: int = int(sel["count"])
	var d: Dictionary = ItemDB.get_item(id)
	var kind: int = ItemDB.kind_of(id)
	_tt_name.text = ItemDB.display_name(id)
	var equipped: bool = bool(sel.get("equipped", false))
	_tt_kind.text = ("надето · " if equipped else "") + ItemDB.kind_name(kind)
	_tt_kind.modulate = GOOD_COLOR if equipped else COLOR_KIND
	_tt_stats.text = _stat_lines(id, d, kind, count, ItemDB.weight(id) * float(count))
	_tt_desc.text = String(d.get("desc", ""))


func _stat_lines(id: String, d: Dictionary, kind: int, count: int, weight: float) -> String:
	var lines: Array = []
	lines.append("Вес: %.2f кг" % weight)
	lines.append("Цена: %d руб. за штуку" % ItemDB.value(id))
	if count > 1:
		lines.append("В стопке: %d шт." % count)
	lines.append("")
	match kind:
		ItemDB.Kind.WEAPON:
			lines.append("Урон: %.0f" % float(d.get("dmg", 0.0)))
			lines.append("Скорострельность: %.1f/с" % float(d.get("rate", 1.0)))
			if String(d.get("mode", "melee")) == "gun":
				lines.append("Дальность: %.0f" % float(d.get("gun_range", 0.0)))
				lines.append("Магазин: %d патр." % int(d.get("mag", 0)))
				lines.append("Калибр: %s" % String(d.get("caliber", "—")))
				lines.append("Разброс: %.3f" % float(d.get("spread", 0.0)))
				var auto_mode: bool = bool(d.get("auto", false))
				lines.append("Режим: " + ("автоматический" if auto_mode else "одиночный"))
			else:
				lines.append("Ближний бой, выпад: %.0f" % float(d.get("reach", 0.0)))
			lines.append("")
			lines.append(_weapon_compare(id))
		ItemDB.Kind.ARMOR, ItemDB.Kind.HELMET:
			lines.append("Броня: %.0f %%" % float(d.get("armor", 0.0)))
			lines.append("Бонус здоровья: %+.0f" % float(d.get("hp_bonus", 0.0)))
			lines.append("Защита от радиации: %.0f %%" % float(d.get("radiation", 0.0)))
			var sp: float = float(d.get("speed", 1.0))
			if not is_equal_approx(sp, 1.0):
				lines.append("Скорость: %+.0f %%" % ((sp - 1.0) * 100.0))
		ItemDB.Kind.MED, ItemDB.Kind.FOOD:
			if float(d.get("heal", 0.0)) > 0.0:
				lines.append("Лечит: %.0f" % float(d.get("heal", 0.0)))
			if float(d.get("stamina", 0.0)) > 0.0:
				lines.append("Возвращает силы: %.0f" % float(d.get("stamina", 0.0)))
			if float(d.get("rad_heal", 0.0)) > 0.0:
				lines.append("Снимает радиацию: %.0f" % float(d.get("rad_heal", 0.0)))
		ItemDB.Kind.ARTIFACT:
			if float(d.get("regen", 0.0)) > 0.0:
				lines.append("Восстановление: %.1f hp/с" % float(d.get("regen", 0.0)))
			if float(d.get("rad_resist", 0.0)) > 0.0:
				lines.append("Защита от радиации: %.0f %%" % float(d.get("rad_resist", 0.0)))
			if float(d.get("radiation", 0.0)) > 0.0:
				lines.append("Фон радиации: +%.0f" % float(d.get("radiation", 0.0)))
			if float(d.get("stamina_regen", 0.0)) > 0.0:
				lines.append("Силы: +%.1f/с" % float(d.get("stamina_regen", 0.0)))
			if float(d.get("light", 0.0)) > 0.0:
				lines.append("Светится в темноте")
			if float(d.get("armor", 0.0)) > 0.0:
				lines.append("Броня: %.0f %%" % float(d.get("armor", 0.0)))
			if float(d.get("hp_bonus", 0.0)) > 0.0:
				lines.append("Бонус здоровья: %+.0f" % float(d.get("hp_bonus", 0.0)))
		ItemDB.Kind.AMMO:
			lines.append("Калибр: %s" % String(d.get("caliber", "—")))
		ItemDB.Kind.QUEST:
			lines.append("Квестовый предмет — выброс только с подтверждением")
		_:
			lines.append("Материал для обмена")
	return "\n".join(lines)


## Сравнение с надетым оружием: «Урон: 18 → 22 (+4)».
func _weapon_compare(id: String) -> String:
	var eq: String = String(GameState.equipment.get("weapon", ""))
	if eq == id:
		return "Сравнение: это оружие уже в руках"
	if eq == "":
		return "Сравнение: оружия нет, сравнить не с чем"
	var a: float = float(ItemDB.get_item(eq).get("dmg", 0.0))
	var b: float = float(ItemDB.get_item(id).get("dmg", 0.0))
	var delta: float = b - a
	var sign_txt: String = "+" if delta >= 0.0 else ""
	return "Урон: %.0f → %.0f (%s%.0f) против «%s»" % [a, b, sign_txt, delta,
		ItemDB.display_name(eq)]


# ------------------------------------------------------------------ действия
func _update_actions() -> void:
	var sel := selected_item()
	var equip_btn: Button = _act_buttons[0]
	var use_btn: Button = _act_buttons[1]
	var drop_btn: Button = _act_buttons[2]
	if sel.is_empty():
		equip_btn.disabled = true
		use_btn.disabled = true
		drop_btn.disabled = true
		equip_btn.text = "Надеть"
		use_btn.text = "Использовать"
		drop_btn.text = "Выбросить"
		return
	var id: String = String(sel["id"])
	var equipped: bool = bool(sel.get("equipped", false))
	var is_artifact: bool = ItemDB.kind_of(id) == ItemDB.Kind.ARTIFACT
	equip_btn.disabled = not (ItemDB.is_equipable(id) or is_artifact)
	use_btn.disabled = not (ItemDB.is_usable(id) or is_artifact)
	drop_btn.disabled = false
	equip_btn.text = "Снять" if equipped else "Надеть"
	use_btn.text = "Использовать"
	drop_btn.text = "Точно выбросить?" if _confirm_drop else "Выбросить"


func _on_action_pressed(action: int) -> void:
	var sel := selected_item()
	if sel.is_empty():
		Sfx.ui("ui_deny")
		return
	var id: String = String(sel["id"])
	match action:
		0:
			_do_equip(sel)
		1:
			_do_use(id)
		2:
			_do_drop(sel, id)
	rebuild()


func _do_equip(sel: Dictionary) -> void:
	if bool(sel.get("equipped", false)):
		if GameState.unequip(String(sel["slot"])):
			Sfx.ui("ui_click")
			_sel_equip = ""
			_sel_index = GameState.inventory.size() - 1
		else:
			Sfx.ui("ui_deny")
		return
	if GameState.equip(String(sel["id"])):
		Sfx.ui("ui_click")
		if _sel_index >= GameState.inventory.size():
			_sel_index = GameState.inventory.size() - 1
	else:
		Sfx.ui("ui_deny")


func _do_use(id: String) -> void:
	if GameState.use_item(id):
		Sfx.ui("ui_click")
	else:
		Sfx.ui("ui_deny")


func _do_drop(sel: Dictionary, id: String) -> void:
	var quest_item: bool = ItemDB.kind_of(id) == ItemDB.Kind.QUEST \
		or bool(ItemDB.get_item(id).get("quest", false))
	if quest_item and not _confirm_drop:
		_confirm_drop = true
		_confirm_t = CONFIRM_TIME
		_update_actions()
		_hint.text = "Квестовый предмет: нажмите «Точно выбросить?» ещё раз"
		Sfx.ui("ui_deny")
		return
	_confirm_drop = false
	if bool(sel.get("equipped", false)):
		GameState.unequip(String(sel["slot"]))
	if GameState.remove_item(id, 1):
		_spawn_drop(id)
		Sfx.ui("ui_click")
	else:
		Sfx.ui("ui_deny")


## Выбросить предмет в мир: Loot грузим динамически, чтобы UI работал и без него.
func _spawn_drop(id: String) -> void:
	var p: Variant = null
	if game != null and is_instance_valid(game):
		p = game.get("player")
	if p == null or not is_instance_valid(p) or not (p is Node2D):
		return
	var parent: Node = (p as Node).get_parent()
	if parent == null:
		return
	var scr: Variant = load("res://scripts/loot.gd")
	if scr == null:
		return
	var tmp: Variant = (scr as GDScript).new()
	var pos: Vector2 = (p as Node2D).global_position + Vector2(0.0, 28.0)
	if tmp != null and tmp.has_method("spawn_drop"):
		tmp.call("spawn_drop", parent, pos, id, 1)
	if tmp is Node and is_instance_valid(tmp):
		(tmp as Node).free()


# ------------------------------------------------------------------ отладка
func describe() -> Dictionary:
	var sel := selected_item()
	return {
		"open": _open,
		"slots": _grid.get_child_count() if _grid != null else 0,
		"equip": _equip_buttons.size(),
		"filters": _filter_buttons.size(),
		"actions": _act_buttons.size(),
		"items": GameState.inventory.size(),
		"selected": String(sel.get("id", "")),
		"filter": _filter,
		"nodes": count_nodes(self),
	}


func count_nodes(n: Node) -> int:
	var total: int = 1
	for c in n.get_children():
		total += count_nodes(c)
	return total


