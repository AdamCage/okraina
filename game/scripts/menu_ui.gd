class_name MenuUI extends CanvasLayer
## Меню: главный экран (логотип, кнопки, версия), пауза, настройки качества и
## звука, экран смерти со статистикой рейда, сводка рейда, справка об управлении
## и «Об игре». Панель работает и когда дерево остановлено, и когда идёт рейд
## (главное меню, экран смерти): process_mode = PROCESS_MODE_ALWAYS, поэтому
## остановка мира делается отдельно — через get_tree().paused.
##
## Видимость держит сама панель: show_screen() включает CanvasLayer, hide_all()
## гасит его. game.gd::_hide_menus() на старте рейда вызывает hide_all()
## и дополнительно ставит menu_ui.visible = false.
##
## Все кнопки не ниже 64 px, взаимодействие — тап (одиночное нажатие) и клавиши.

const PANEL_W := 560.0
const PANEL_H := 560.0
const BTN_H := 64.0
const VERSION_FALLBACK := "0.1.3"

## Настройки живут статически: сцена перезагружается при возрождении,
## а выбор игрока должен сохраниться.
static var settings: Dictionary = {
	"quality": "medium",
	"vol_master": 0.9,
	"vol_sfx": 1.0,
	"vol_amb": 0.75,
	"vol_mus": 0.45,
	"minimap": true,
	"damage_numbers": true,
	"blood": true,
}

const QUALITY_OPTIONS: Array = [
	{"id": "low", "label": "Низкое"},
	{"id": "medium", "label": "Среднее"},
	{"id": "high", "label": "Высокое"},
]

const VOLUME_OPTIONS: Array = [
	{"key": "vol_master", "label": "Общая громкость"},
	{"key": "vol_sfx", "label": "Эффекты"},
	{"key": "vol_amb", "label": "Эмбиент"},
	{"key": "vol_mus", "label": "Музыка"},
]

const TOGGLE_OPTIONS: Array = [
	{"key": "minimap", "label": "Мини-карта"},
	{"key": "damage_numbers", "label": "Цифры урона"},
	{"key": "blood", "label": "Кровь"},
]

const KEYS_HELP: Array = [
	"W A S D — движение, Shift — бег, Space — рывок",
	"Ctrl — атака, R — перезарядка, Q — смена оружия",
	"F — действие и подбор, H — аптечка, L — фонарь",
	"I или E — сумка, J — журнал, Esc — пауза",
	"M — карта, F11 — полный экран, T — вкл/выкл сенсорные кнопки",
]

const TOUCH_HELP: Array = [
	"Левая половина экрана — виртуальный стик: касание рождает джойстик",
	"Правая половина — стик прицела: тап = одиночный выстрел, удержание = огонь",
	"Круглые кнопки справа: огонь, действие, рывок, сумка, журнал, пауза, аптечка, смена оружия",
	"Кнопки не меньше 64 px, ничего не висит под пальцем",
]

var game: Node = null

var _root: Control
var _screens: Dictionary = {}
var _current: String = ""
var _prev: String = ""
var _pause_context: bool = false
var _death_reason: String = ""
var _last_bad: String = ""
var _quality_buttons: Dictionary = {}
var _vol_sliders: Dictionary = {}
var _toggle_buttons: Dictionary = {}
var _continue_btn: Button
var _death_stats: Label
var _version_label: Label
var _fullscreen_btn: Button
var _web_note: Label
var _stats_label: Label


func setup(game_node: Node) -> void:
	game = game_node
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GameState.log_message.connect(_on_log_message)
	GameState.player_died.connect(_on_player_died)
	apply_settings()
	refresh()
	hide_all()


# ------------------------------------------------------------------ помощники
## Панель-подложка: NinePatch, если текстура есть; иначе непрозрачный тёмный
## StyleBoxFlat — на телефоне окна не должны просвечивать мир.
func _panel(parent: Node, tex_name: String, fallback: Color) -> Control:
	if Assets.has_ui(tex_name):
		var np := NinePatchRect.new()
		np.name = tex_name
		np.texture = Assets.ui(tex_name)
		np.patch_margin_left = 16
		np.patch_margin_right = 16
		np.patch_margin_top = 16
		np.patch_margin_bottom = 16
		parent.add_child(np)
		return np
	var p := Panel.new()
	p.name = tex_name
	p.add_theme_stylebox_override("panel", panel_style())
	parent.add_child(p)
	return p


## Непрозрачный тёмный стиль панели (fallback).
func panel_style(alpha: float = 0.97) -> StyleBoxFlat:
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
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, size: Vector2, font_size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.size = size
	b.add_theme_font_size_override("font_size", font_size)
	if Assets.font_body != null:
		b.add_theme_font_override("font", Assets.font_body)
	if Assets.has_ui("btn_idle"):
		var sb := StyleBoxTexture.new()
		sb.texture = Assets.ui("btn_idle")
		sb.texture_margin_left = 16
		sb.texture_margin_right = 16
		sb.texture_margin_top = 16
		sb.texture_margin_bottom = 16
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		var press: StyleBoxTexture = sb.duplicate()
		if Assets.has_ui("btn_press"):
			press.texture = Assets.ui("btn_press")
			press.texture_margin_left = 16
			press.texture_margin_right = 16
			press.texture_margin_top = 16
			press.texture_margin_bottom = 16
		b.add_theme_stylebox_override("pressed", press)
		b.add_theme_stylebox_override("focus", press)
	else:
		var flat := panel_style(0.97)
		flat.set_content_margin_all(10)
		b.add_theme_stylebox_override("normal", flat)
		b.add_theme_stylebox_override("hover", flat)
		var pressed: StyleBoxFlat = panel_style(0.97)
		pressed.bg_color = Color(0.16, 0.17, 0.17, 0.97)
		pressed.border_color = Color(0.96, 0.82, 0.42)
		pressed.set_content_margin_all(10)
		b.add_theme_stylebox_override("pressed", pressed)
		b.add_theme_stylebox_override("focus", pressed)
	b.add_theme_color_override("font_color", Color(0.93, 0.91, 0.85))
	b.add_theme_color_override("font_disabled_color", Color(0.52, 0.52, 0.50))
	parent.add_child(b)
	return b


func _check(parent: Node, text: String, pressed: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = pressed
	c.add_theme_font_size_override("font_size", 20)
	if Assets.font_body != null:
		c.add_theme_font_override("font", Assets.font_body)
	c.add_theme_color_override("font_color", Color(0.92, 0.90, 0.84))
	c.custom_minimum_size = Vector2(0, BTN_H)
	parent.add_child(c)
	return c


func _anchored(c: Control, off: Rect2, anchors: Rect2) -> void:
	c.anchor_left = anchors.position.x
	c.anchor_top = anchors.position.y
	c.anchor_right = anchors.size.x
	c.anchor_bottom = anchors.size.y
	c.offset_left = off.position.x
	c.offset_top = off.position.y
	c.offset_right = off.size.x
	c.offset_bottom = off.size.y


## Экарн-обёртка: затемнение + центральная панель.
func _new_screen(name: String, w: float, h: float) -> Control:
	var scr := Control.new()
	scr.name = "Screen_" + name
	_anchored(scr, Rect2(0, 0, 0, 0), Rect2(0, 0, 1, 1))
	scr.mouse_filter = Control.MOUSE_FILTER_STOP
	scr.visible = false
	_root.add_child(scr)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.78)
	_anchored(dim, Rect2(0, 0, 0, 0), Rect2(0, 0, 1, 1))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	scr.add_child(dim)
	var panel := _panel(scr, "panel_window", Color(0.08, 0.09, 0.10, 0.97))
	_anchored(panel, Rect2(-w * 0.5, -h * 0.5, w * 0.5, h * 0.5), Rect2(0.5, 0.5, 0.5, 0.5))
	scr.set_meta("panel", panel)
	_screens[name] = scr
	return panel


# ------------------------------------------------------------------ построение
func _build() -> void:
	_root = Control.new()
	_root.name = "MenuRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	_build_main()
	_build_pause()
	_build_settings()
	_build_controls()
	_build_about()
	_build_death()
	_build_stats()


func _build_main() -> void:
	var panel := _new_screen("main", 620.0, 660.0)
	var logo: Control = null
	if Assets.has_ui("logo"):
		var tr := TextureRect.new()
		tr.texture = Assets.ui("logo")
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(60, 18)
		tr.size = Vector2(500, 150)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tr)
		logo = tr
	var title := _label(panel, "ЗОНА: ПИКНИК НА ОБОЧИНЕ", 32, Color(0.96, 0.84, 0.48))
	if Assets.font_title != null:
		title.add_theme_font_override("font", Assets.font_title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 174 if logo != null else 24)
	title.size = Vector2(580, 42)

	# кнопки — в VBoxContainer: высота панели подстраивается под содержимое
	var box := VBoxContainer.new()
	box.name = "MainButtons"
	box.add_theme_constant_override("separation", 10)
	box.position = Vector2(100, 232)
	box.size = Vector2(420, 360)
	panel.add_child(box)

	var labels: Array = ["Новая игра", "Продолжить", "Настройки", "Управление", "Об игре"]
	var actions: Array = ["new", "continue", "settings", "controls", "about"]
	for i in labels.size():
		var b := _button(box, String(labels[i]), Vector2(420, BTN_H), 24)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.set_meta("action", String(actions[i]))
		b.pressed.connect(_on_menu_action.bind(String(actions[i])))
		if String(actions[i]) == "continue":
			_continue_btn = b

	_version_label = _label(panel, "", 16, Color(0.62, 0.64, 0.60))
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version_label.position = Vector2(20, 606)
	_version_label.size = Vector2(580, 22)


func _build_pause() -> void:
	var panel := _new_screen("pause", 520.0, 460.0)
	var title := _label(panel, "Пауза", 30, Color(0.96, 0.86, 0.55))
	if Assets.font_title != null:
		title.add_theme_font_override("font", Assets.font_title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 18)
	title.size = Vector2(480, 40)

	var box := VBoxContainer.new()
	box.name = "PauseButtons"
	box.add_theme_constant_override("separation", 14)
	box.position = Vector2(60, 84)
	box.size = Vector2(400, 298)
	panel.add_child(box)

	var labels: Array = ["Продолжить", "Сохранить", "Настройки", "Выйти в меню"]
	var actions: Array = ["resume", "save", "settings", "to_menu"]
	for i in labels.size():
		var b := _button(box, String(labels[i]), Vector2(400, BTN_H), 24)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_menu_action.bind(String(actions[i])))

	var hint := _label(panel, "Зона не ждёт: игра остановлена, пока открыто меню", 16,
		Color(0.64, 0.66, 0.62))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(20, 398)
	hint.size = Vector2(480, 44)


func _build_settings() -> void:
	var panel := _new_screen("settings", 700.0, 700.0)
	var title := _label(panel, "Настройки", 30, Color(0.96, 0.86, 0.55))
	if Assets.font_title != null:
		title.add_theme_font_override("font", Assets.font_title)
	title.position = Vector2(24, 12)
	title.size = Vector2(400, 40)

	var head1 := _label(panel, "Качество графики", 20, Color(0.86, 0.86, 0.78))
	head1.position = Vector2(24, 58)
	head1.size = Vector2(300, 26)
	var x: float = 24.0
	for q in QUALITY_OPTIONS:
		var b := _button(panel, String(q["label"]), Vector2(206, BTN_H), 22)
		b.position = Vector2(x, 90)
		b.set_meta("quality_id", String(q["id"]))
		b.pressed.connect(_on_quality_pressed.bind(String(q["id"])))
		_quality_buttons[String(q["id"])] = b
		x += 216.0

	var head2 := _label(panel, "Звук", 20, Color(0.86, 0.86, 0.78))
	head2.position = Vector2(24, 162)
	head2.size = Vector2(200, 26)
	var y: float = 192.0
	for v in VOLUME_OPTIONS:
		var l := _label(panel, String(v["label"]) + ": 100 %", 18, Color(0.88, 0.88, 0.82))
		l.position = Vector2(24, y + 8.0)
		l.size = Vector2(240, 28)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(settings.get(String(v["key"]), 0.8))
		s.position = Vector2(276, y)
		s.size = Vector2(390, 44)
		s.custom_minimum_size = Vector2(390, 44)
		s.set_meta("label", l)
		s.value_changed.connect(_on_volume_changed.bind(String(v["key"]), l))
		panel.add_child(s)
		_vol_sliders[String(v["key"])] = s
		y += 46.0

	var head3 := _label(panel, "Отображение", 20, Color(0.86, 0.86, 0.78))
	head3.position = Vector2(24, 382)
	head3.size = Vector2(240, 26)
	# тумблеры — в VBox: 3 x 64 px + зазоры, ровно 200 px по высоте
	var tbox := VBoxContainer.new()
	tbox.name = "DisplayToggles"
	tbox.add_theme_constant_override("separation", 4)
	tbox.position = Vector2(24, 410)
	tbox.size = Vector2(286, 200)
	panel.add_child(tbox)
	for t in TOGGLE_OPTIONS:
		var c := _check(tbox, String(t["label"]), bool(settings.get(String(t["key"]), true)))
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c.toggled.connect(_on_toggle_changed.bind(String(t["key"])))
		_toggle_buttons[String(t["key"])] = c

	_fullscreen_btn = _check(panel, "Полный экран", false)
	_fullscreen_btn.position = Vector2(340, 410)
	_fullscreen_btn.size = Vector2(330, BTN_H)
	_fullscreen_btn.toggled.connect(_on_fullscreen_toggled)
	if OS.has_feature("web"):
		_fullscreen_btn.disabled = true
	var is_web: bool = OS.has_feature("web")
	_web_note = _label(panel, "В браузере полноэкранный режим включает сама страница "
		+ "(кнопка на панели телефона) — игра лишь подстраивается под размер окна.",
		15, Color(0.66, 0.68, 0.64))
	_web_note.position = Vector2(340, 480)
	_web_note.size = Vector2(330, 112)
	_web_note.visible = is_web

	var back := _button(panel, "Назад", Vector2(240, BTN_H), 23)
	back.position = Vector2(230, 620)
	back.pressed.connect(_on_back)


func _build_controls() -> void:
	var panel := _new_screen("controls", 760.0, 660.0)
	var title := _label(panel, "Управление", 30, Color(0.96, 0.86, 0.55))
	if Assets.font_title != null:
		title.add_theme_font_override("font", Assets.font_title)
	title.position = Vector2(24, 12)
	title.size = Vector2(400, 40)

	var khead := _label(panel, "Клавиатура и мышь", 22, Color(0.88, 0.88, 0.80))
	khead.position = Vector2(24, 60)
	khead.size = Vector2(360, 28)
	var y: float = 94.0
	for line in KEYS_HELP:
		var l := _label(panel, "· " + String(line), 18, Color(0.86, 0.88, 0.84))
		l.position = Vector2(24, y)
		l.size = Vector2(700, 30)
		y += 30.0

	var thead := _label(panel, "Сенсорное управление (телефон, браузер)", 22,
		Color(0.88, 0.88, 0.80))
	thead.position = Vector2(24, 262)
	thead.size = Vector2(700, 28)
	var ty: float = 298.0
	for line in TOUCH_HELP:
		var l2 := _label(panel, "· " + String(line), 18, Color(0.86, 0.88, 0.84))
		l2.position = Vector2(24, ty)
		l2.size = Vector2(700, 44)
		ty += 42.0

	var hint := _label(panel, "Сенсорные кнопки включаются автоматически на телефоне; "
		+ "на компьютере их можно включить клавишей T.", 16, Color(0.70, 0.72, 0.68))
	hint.position = Vector2(24, 486)
	hint.size = Vector2(700, 44)

	var back := _button(panel, "Назад", Vector2(240, BTN_H), 23)
	back.position = Vector2(260, 546)
	back.pressed.connect(_on_back)


func _build_about() -> void:
	var panel := _new_screen("about", 700.0, 560.0)
	var title := _label(panel, "Об игре", 30, Color(0.96, 0.86, 0.55))
	if Assets.font_title != null:
		title.add_theme_font_override("font", Assets.font_title)
	title.position = Vector2(24, 12)
	title.size = Vector2(400, 40)

	var text := _label(panel, "\"ЗОНА: Пикник на обочине\" — rogue-like ARPG в духе Diablo "
		+ "по мотивам повести братьев Стругацких.\n\n"
		+ "Вы — сталкер, который идёт в Зону за хабаром: артефакты, документы, "
		+ "патроны и своя шкура. Каждый заход генерируется заново: другой мир, другие "
		+ "аномалии, другие твари.\n\n"
		+ "Следите за здоровьем, силами и радиацией. Таскайте с собой только нужное: "
		+ "перегрузка замедляет. Артефакты греют, лечат и светят — но фонят.\n\n"
		+ "Интерфейс рассчитан на палец: тап = действие, все кнопки не меньше 64 px.",
		19, Color(0.90, 0.90, 0.84))
	text.position = Vector2(24, 62)
	text.size = Vector2(652, 340)

	var ver := _label(panel, version_string(), 16, Color(0.66, 0.68, 0.64))
	ver.position = Vector2(24, 412)
	ver.size = Vector2(400, 24)

	var back := _button(panel, "Назад", Vector2(240, BTN_H), 23)
	back.position = Vector2(230, 452)
	back.pressed.connect(_on_back)


func _build_death() -> void:
	var panel := _new_screen("death", 720.0, 620.0)
	var title := _label(panel, "ВЫ ПОГИБЛИ", 38, Color(0.92, 0.34, 0.30))
	if Assets.font_title != null:
		title.add_theme_font_override("font", Assets.font_title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 20)
	title.size = Vector2(680, 50)

	var reason := _label(panel, "Причина: Зона забрала сталкера", 20, Color(0.88, 0.84, 0.78))
	reason.name = "Reason"
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.position = Vector2(20, 76)
	reason.size = Vector2(680, 30)

	_death_stats = _label(panel, "", 19, Color(0.86, 0.88, 0.84))
	_death_stats.position = Vector2(40, 120)
	_death_stats.size = Vector2(640, 340)

	var respawn := _button(panel, "Возродиться", Vector2(300, BTN_H), 24)
	respawn.position = Vector2(40, 500)
	respawn.pressed.connect(_on_respawn)

	var to_menu := _button(panel, "В меню", Vector2(300, BTN_H), 24)
	to_menu.position = Vector2(380, 500)
	to_menu.pressed.connect(_on_menu_action.bind("to_menu"))


func _build_stats() -> void:
	var panel := _new_screen("stats", 720.0, 620.0)
	var title := _label(panel, "Итоги рейда", 30, Color(0.96, 0.86, 0.55))
	if Assets.font_title != null:
		title.add_theme_font_override("font", Assets.font_title)
	title.position = Vector2(24, 12)
	title.size = Vector2(400, 40)
	_stats_label = _label(panel, "", 19, Color(0.88, 0.90, 0.86))
	_stats_label.position = Vector2(40, 70)
	_stats_label.size = Vector2(640, 420)
	var back := _button(panel, "Назад", Vector2(240, BTN_H), 23)
	back.position = Vector2(240, 526)
	back.pressed.connect(_on_back)


# ------------------------------------------------------------------ экраны
func show_screen(name: String) -> void:
	if name == "" or name == "none":
		hide_all()
		return
	if not _screens.has(name):
		# push_warning в headless-прогоне роняет процесс — пишем в ленту сообщений
		print_verbose("MenuUI: неизвестный экран " + name)
		GameState.log_message.emit("Меню: неизвестный экран %s" % name, "info")
		return
	if name == "pause":
		_pause_context = true
	elif name == "main":
		_pause_context = false   # главное меню — не пауза, дерево не морозим
	elif _current != "" and _current != name:
		_prev = _current
	# экраны модальные: показываем только один, иначе панели накладываются
	for key in _screens.keys():
		_screens[key].visible = String(key) == name
	_current = name
	visible = true   # game.gd::_hide_menus() гасит CanvasLayer на старте рейда
	_root.visible = true
	refresh()
	_apply_pause_state()
	if name == "settings":
		_sync_settings_widgets()


func hide_all() -> void:
	for key in _screens.keys():
		_screens[key].visible = false
	_current = ""
	_prev = ""
	visible = false
	_root.visible = false
	_apply_pause_state()


func is_any_open() -> bool:
	return _current != ""


func current_screen() -> String:
	return _current


## Пауза: дерево останавливается только в контексте паузы; главное меню живёт
## поверх заставки и не морозит сцену (иначе встанет генерация мира и таймеры).
func _apply_pause_state() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.paused = _pause_context and _current != ""


func _on_back() -> void:
	_prev = ""
	show_screen("pause" if _pause_context else "main")


func _paused_ctx() -> bool:
	return _pause_context



# ------------------------------------------------------------------ действия
func _on_menu_action(action: String) -> void:
	match action:
		"new":
			_to_game()
			if game != null and is_instance_valid(game) and game.has_method("new_game"):
				game.call("new_game", 0)
		"continue":
			_to_game()
			if game != null and is_instance_valid(game) and game.has_method("continue_game"):
				game.call("continue_game")
		"settings":
			show_screen("settings")
		"controls":
			show_screen("controls")
		"about":
			show_screen("about")
		"pause":
			show_screen("pause")
		"stats":
			show_screen("stats")
		"resume":
			hide_all()
		"save":
			_save_now()
		"to_menu":
			_to_menu()
		_:
			pass


## Закрываем меню и снимаем паузу — начинается рейд.
func _to_game() -> void:
	_pause_context = false
	hide_all()
	if game != null and is_instance_valid(game) and game.has_method("set_paused"):
		game.call("set_paused", false)


func _to_menu() -> void:
	_pause_context = false
	hide_all()
	if game != null and is_instance_valid(game) and game.has_method("to_menu"):
		game.call("to_menu")
	show_screen("main")


func _save_now() -> void:
	if game != null and is_instance_valid(game) and game.has_method("save_run"):
		game.call("save_run")
	else:
		GameState.save_game()


# ------------------------------------------------------------------ настройки
func _on_quality_pressed(quality_id: String) -> void:
	settings["quality"] = quality_id
	Sfx.ui("ui_click")
	if game != null and is_instance_valid(game) and game.has_method("apply_quality"):
		game.call("apply_quality", quality_id)
	_sync_settings_widgets()


func _on_volume_changed(value: float, key: String, label: Label) -> void:
	settings[key] = value
	if is_instance_valid(label):
		label.text = "%s: %d %%" % [_volume_label(key), roundi(value * 100.0)]
	_apply_volumes()


func _volume_label(key: String) -> String:
	for v in VOLUME_OPTIONS:
		if String(v["key"]) == key:
			return String(v["label"])
	return key


func _apply_volumes() -> void:
	Sfx.vol_master = float(settings.get("vol_master", 0.9))
	Sfx.vol_sfx = float(settings.get("vol_sfx", 1.0))
	Sfx.vol_amb = float(settings.get("vol_amb", 0.75))
	Sfx.vol_mus = float(settings.get("vol_mus", 0.45))
	if Sfx.has_method("_apply_volumes"):
		Sfx.call("_apply_volumes")


func _on_toggle_changed(value: bool, key: String) -> void:
	settings[key] = value
	Sfx.ui("ui_click")
	apply_settings()


func _on_fullscreen_toggled(value: bool) -> void:
	if OS.has_feature("web"):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value
		else DisplayServer.WINDOW_MODE_WINDOWED)


## Применяем настройки к игре: качество, громкость, слой HUD.
func apply_settings() -> void:
	_apply_volumes()
	if game != null and is_instance_valid(game) and game.has_method("apply_quality"):
		game.call("apply_quality", String(settings.get("quality", "medium")))
	var hud: Variant = null
	if game != null and is_instance_valid(game):
		hud = game.get("hud")
	if hud != null and is_instance_valid(hud):
		if (hud as Node).has_method("set_minimap_visible"):
			hud.call("set_minimap_visible", bool(settings.get("minimap", true)))
		if (hud as Node).has_method("set_damage_numbers"):
			hud.call("set_damage_numbers", bool(settings.get("damage_numbers", true)))
		if (hud as Node).has_method("set_blood_enabled"):
			hud.call("set_blood_enabled", bool(settings.get("blood", true)))


## Синхронизируем виджеты настроек с сохранёнными значениями.
func _sync_settings_widgets() -> void:
	var q: String = String(settings.get("quality", "medium"))
	for key in _quality_buttons.keys():
		var b: Button = _quality_buttons[key]
		b.modulate = Color(1.0, 0.96, 0.72) if String(key) == q else Color(0.78, 0.78, 0.74)
	for key in _vol_sliders.keys():
		var s: HSlider = _vol_sliders[key]
		var want: float = float(settings.get(String(key), 0.8))
		if not is_equal_approx(s.value, want):
			s.value = want
		var l: Variant = s.get_meta("label")
		if is_instance_valid(l):
			(l as Label).text = "%s: %d %%" % [_volume_label(String(key)), roundi(want * 100.0)]
	for key in _toggle_buttons.keys():
		var c: CheckButton = _toggle_buttons[key]
		var on: bool = bool(settings.get(String(key), true))
		if c.button_pressed != on:
			c.button_pressed = on
	if _fullscreen_btn != null and is_instance_valid(_fullscreen_btn):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if _fullscreen_btn.button_pressed != full:
			_fullscreen_btn.button_pressed = full


# ------------------------------------------------------------------ смерть
func _on_log_message(text: String, kind: String) -> void:
	if kind == "bad":
		_last_bad = text


func _on_player_died() -> void:
	_pause_context = false
	if _death_reason == "":
		_death_reason = _last_bad
	show_screen("death")


## Причина смерти — можно задать извне (игрок передаёт вид урона).
func set_death_reason(text: String) -> void:
	_death_reason = text


func death_reason_text() -> String:
	if _death_reason != "":
		return _death_reason
	if _last_bad != "":
		return _last_bad
	return "Зона забрала сталкера"


func _on_respawn() -> void:
	Sfx.ui("ui_click")
	GameState.is_dead = false
	GameState.reset_run(0)
	_death_reason = ""
	_pause_context = false
	hide_all()
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false
		tree.reload_current_scene()


func raid_report_text() -> String:
	var lines: Array = []
	lines.append("Причина смерти: %s" % death_reason_text())
	lines.append("")
	lines.append("Уровень: %d   ·   Опыт: %.0f" % [GameState.level, GameState.xp])
	lines.append("Убийств: %d" % GameState.kills)
	var types: Dictionary = GameState.kills_by_type
	if not types.is_empty():
		var keys: Array = types.keys()
		keys.sort()
		var parts: Array = []
		for k in keys:
			parts.append("%s — %d" % [String(k), int(types[k])])
		lines.append("   (%s)" % ", ".join(parts))
	lines.append("Артефактов: %d   ·   Контейнеров: %d" % [
		GameState.artifacts_found, GameState.containers_looted])
	lines.append("Заданий выполнено: %d" % GameState.quests_done)
	lines.append("Пройдено: %.0f м" % GameState.distance_walked)
	lines.append("Время в рейде: %s" % _time_text(GameState.play_time))
	lines.append("В сумке: %.1f / %.1f кг, %d руб." % [
		GameState.total_weight(), maxf(1.0, GameState.max_weight()), GameState.money])
	lines.append("")
	lines.append("Рейд окончен. Зона всё запомнила — попробуйте снова.")
	return "\n".join(lines)


func _time_text(seconds: float) -> String:
	var total: int = int(maxf(0.0, seconds))
	var h: int = total / 3600
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	if h > 0:
		return "%d ч %02d мин" % [h, m]
	return "%d мин %02d с" % [m, s]


func version_string() -> String:
	var v: Variant = ProjectSettings.get_setting("application/config/version", "")
	var text: String = String(v) if v != null else ""
	if text == "":
		text = VERSION_FALLBACK
	return "версия " + text + " · Godot 4.7 · сборка для телефона и браузера"


# ------------------------------------------------------------------ обновление
func refresh() -> void:
	if _version_label != null and is_instance_valid(_version_label):
		_version_label.text = version_string()
	if _continue_btn != null and is_instance_valid(_continue_btn):
		_continue_btn.disabled = not GameState.has_save()
	if _death_stats != null and is_instance_valid(_death_stats):
		_death_stats.text = raid_report_text()
	var reason: Variant = null
	if _screens.has("death"):
		var panel: Variant = (_screens["death"] as Control).get_meta("panel")
		if panel is Node and is_instance_valid(panel):
			reason = (panel as Node).get_node_or_null("Reason")
	if reason != null and reason is Label:
		(reason as Label).text = "Причина: " + death_reason_text()
	if _stats_label != null and is_instance_valid(_stats_label):
		_stats_label.text = raid_report_text()


func _input(event: InputEvent) -> void:
	if not is_any_open():
		return
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var key := event as InputEventKey
	if key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			if _current == "pause":
				hide_all()
			else:
				_on_back()
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
		_:
			pass


# ------------------------------------------------------------------ отладка
func describe() -> Dictionary:
	var visible_screens: Array = []
	for key in _screens.keys():
		if (_screens[key] as Control).visible:
			visible_screens.append(String(key))
	return {
		"current": _current,
		"open": is_any_open(),
		"pause_context": _pause_context,
		"screens": _screens.size(),
		"visible": visible_screens,
		"quality": String(settings.get("quality", "medium")),
		"vol_master": float(settings.get("vol_master", 0.9)),
		"death_reason": death_reason_text(),
		"version": version_string(),
		"nodes": count_nodes(self),
	}


func count_nodes(n: Node) -> int:
	var total: int = 1
	for c in n.get_children():
		total += count_nodes(c)
	return total








