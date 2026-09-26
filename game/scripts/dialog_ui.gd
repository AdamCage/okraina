class_name DialogUI
extends CanvasLayer
## Диалоговое окно NPC: портрет, реплики (по тапу/пробелу) и варианты ответа.
## Рассчитано на палец: кнопки высотой 56+ px, панель по низу экрана.

signal choice(index: int)
signal finished

const PANEL_MARGIN := 12.0
const OPTION_HEIGHT := 58.0

var game: Node = null
var _root: Control
var _panel: Control
var _portrait: TextureRect
var _title: Label
var _text: Label
var _options_box: VBoxContainer
var _lines: Array = []
var _options: Array = []
var _line_index: int = 0
var _open: bool = false


func setup(game_node: Node) -> void:
	game = game_node
	layer = 40
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	_panel = _make_panel(Vector2(760, 250))
	_panel.name = "Panel"
	var pv := _panel as Control
	pv.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pv.offset_left = -380
	pv.offset_right = 380
	pv.offset_top = -280
	pv.offset_bottom = -30
	_root.add_child(_panel)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size = Vector2(128, 128)
	_portrait.position = Vector2(16, 16)
	_panel.add_child(_portrait)

	var frame := TextureRect.new()
	frame.texture = Assets.ui("dlg_portrait_frame")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.size = Vector2(144, 144)
	frame.position = Vector2(8, 8)
	_panel.add_child(frame)

	_title = Label.new()
	_title.position = Vector2(168, 14)
	_title.add_theme_font_size_override("font_size", 24)
	if Assets.font_title != null:
		_title.add_theme_font_override("font", Assets.font_title)
	_title.modulate = Color(1.0, 0.86, 0.55)
	_panel.add_child(_title)

	_text = Label.new()
	_text.position = Vector2(168, 50)
	_text.size = Vector2(560, 120)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 18)
	if Assets.font_body != null:
		_text.add_theme_font_override("font", Assets.font_body)
	_text.modulate = Color(0.92, 0.90, 0.84)
	_panel.add_child(_text)

	_options_box = VBoxContainer.new()
	_options_box.position = Vector2(16, 158)
	_options_box.size = Vector2(728, 84)
	_options_box.add_theme_constant_override("separation", 4)
	_panel.add_child(_options_box)


func _make_panel(size: Vector2) -> Control:
	if Assets.has_ui("panel_window"):
		var np := NinePatchRect.new()
		np.texture = Assets.ui("panel_window")
		np.patch_margin_left = 16
		np.patch_margin_right = 16
		np.patch_margin_top = 16
		np.patch_margin_bottom = 16
		np.size = size
		return np
	var cr := ColorRect.new()
	cr.color = Color(0.08, 0.09, 0.10, 0.94)
	cr.size = size
	return cr


func is_open() -> bool:
	return _open


func open(title: String, portrait: String, lines: Array, options: Array) -> void:
	_lines = lines.duplicate()
	_options = options.duplicate()
	_line_index = 0
	_title.text = title
	_portrait.texture = Assets.ui(portrait) if Assets.has_ui(portrait) else Assets.placeholder()
	_open = true
	_root.visible = true
	_show_line()
	set_process_input(true)


func close() -> void:
	_open = false
	_root.visible = false
	finished.emit()
	set_process_input(false)


func _show_line() -> void:
	if _line_index < _lines.size():
		_text.text = String(_lines[_line_index])
		_rebuild_options([])
	else:
		_rebuild_options(_options)


func _rebuild_options(options: Array) -> void:
	for c in _options_box.get_children():
		c.queue_free()
	if options.is_empty():
		var hint := Label.new()
		hint.text = "Далее ▸" if _line_index < _lines.size() - 1 else "Конец"
		hint.add_theme_font_size_override("font_size", 15)
		hint.modulate = Color(0.7, 0.7, 0.65)
		_options_box.add_child(hint)
		return
	for i in options.size():
		var opt: Dictionary = options[i]
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, String(opt.get("text", "…"))]
		btn.custom_minimum_size = Vector2(0, OPTION_HEIGHT)
		btn.add_theme_font_size_override("font_size", 19)
		if Assets.font_body != null:
			btn.add_theme_font_override("font", Assets.font_body)
		if Assets.has_ui("btn_idle"):
			var sb := StyleBoxTexture.new()
			sb.texture = Assets.ui("btn_idle")
			sb.texture_margin_left = 12
			sb.texture_margin_right = 12
			sb.texture_margin_top = 12
			sb.texture_margin_bottom = 12
			btn.add_theme_stylebox_override("normal", sb)
			var sbp: StyleBoxTexture = sb.duplicate()
			if Assets.has_ui("btn_press"):
				sbp.texture = Assets.ui("btn_press")
			btn.add_theme_stylebox_override("pressed", sbp)
		btn.pressed.connect(_on_option.bind(i))
		_options_box.add_child(btn)


func _on_option(index: int) -> void:
	Sfx.ui("ui_click")
	choice.emit(index)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	# Клик/тап: пока идут реплики — листаем диалог как раньше.
	# Когда показаны варианты ответа, событие НЕ перехватываем: варианты — обычные
	# Button, а Node._input выполняется раньше GUI-разбора, поэтому прежний
	# set_input_as_handled() делал варианты недоступными и мышью, и пальцем.
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_tap_or_click()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_tap_or_click()
			return
		_advance_line()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := event as InputEventKey
		if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			if not options_shown():
				_advance_line()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
			var idx: int = int(key.keycode - KEY_1)
			if options_shown() and idx < _options.size():
				_on_option(idx)
			get_viewport().set_input_as_handled()


## Показаны ли варианты ответа (реплики закончились и варианты есть).
func options_shown() -> bool:
	return _line_index >= _lines.size() and not _options.is_empty()


## Листает реплики; после последней показывает варианты ответа.
func _advance_line() -> void:
	if _line_index < _lines.size():
		_line_index += 1
		_show_line()


## Тап по экрану или клик левой кнопкой: листаем реплики, а когда показаны
## варианты — не мешаем нажимать кнопки вариантов.
func _tap_or_click() -> void:
	if options_shown():
		return
	_advance_line()
	get_viewport().set_input_as_handled()
