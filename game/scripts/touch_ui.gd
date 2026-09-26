class_name TouchUI extends CanvasLayer
## Сенсорное управление для телефона и браузера: виртуальный стик движения
## (появляется там, где коснулся палец), второй стик прицела/огня справа и
## круглые кнопки действий вдоль правого края.
##
## Мультитач: каждый палец отслеживается по index (InputEventScreenTouch/Drag),
## Input.is_action_pressed не используется. Клавиатура и мышь продолжают
## работать одновременно. Слой виден только на тачскрине/в вебе либо после
## ручного включения set_enabled(true) (клавиша T).

signal action_pressed(action: String)

const MARGIN := 16.0            ## безопасная зона от края
const DEAD_ZONE := 12.0         ## мёртвая зона стика, px
const MOVE_RADIUS := 96.0
const AIM_RADIUS := 104.0
const KNOB := 56.0
const FIRE_SIZE := 132.0        ## самая большая кнопка — огонь
const BTN := 84.0
const SPRINT_AT := 0.82         ## отклонение стика, с которого включается бег
const DODGE_WINDOW := 0.12      ## окно, в котором игрок забирает consume_dodge

## Состояние, которое читает игрок (Player._read_move/_update_aim/_handle_attack).
var move_vector: Vector2 = Vector2.ZERO
var aim_vector: Vector2 = Vector2.ZERO
var attack_held: bool = false
var sprint_held: bool = false
var consume_dodge: bool = false

var game: Node = null
var enabled: bool = false
var player: Node = null

var _root: Control
var _buttons: Array = []
var _move_index: int = -1
var _aim_index: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _aim_origin: Vector2 = Vector2.ZERO
var _joy_base: Control
var _joy_knob: Control
var _aim_base: Control
var _aim_knob: Control
var _dodge_t: float = 0.0
var _stick_view_script: GDScript = null


## Круглая кнопка: текстура Assets.ui("touch_*") либо процедурный круг.
class TouchButton extends Control:
	var host: Node = null
	var action: String = ""
	var tex_name: String = ""
	var caption: String = ""
	var down: bool = false
	var hold: bool = false          ## true — держать (огонь), false — тап

	## Гашение дубликатов: касание и сгенерированный движком из него клик мышью
	## приходят парой. Считаем, что второе событие пары — эхо первого, если у него
	## другой источник (палец/мышь) и он пришёл почти сразу.
	const ECHO_MS := 250
	var _press_from_touch: bool = false
	var _press_ms: int = -10000
	var _release_from_touch: bool = false
	var _release_ms: int = -10000

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var s: Vector2 = size
		var center: Vector2 = s * 0.5
		var r: float = minf(s.x, s.y) * 0.5
		var tex: Texture2D = null
		if tex_name != "" and Assets.has_ui(tex_name):
			tex = Assets.ui(tex_name)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, s), false)
		else:
			var fill: Color = Color(0.30, 0.33, 0.31, 0.80) if down \
				else Color(0.075, 0.082, 0.090, 0.62)
			draw_circle(center, r, fill)
			draw_arc(center, r - 2.0, 0.0, TAU, 40, Color(0.80, 0.78, 0.62, 0.80), 2.5)
		if hold:
			var ring: Color = Color(0.95, 0.45, 0.32, 0.85) if down \
				else Color(0.72, 0.70, 0.58, 0.55)
			draw_arc(center, r - 6.0, 0.0, TAU, 40, ring, 2.0)
		var f: Font = Assets.font_body
		if f != null and caption != "":
			var fs: int = 17 if r < 50.0 else 20
			var w: float = f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(center.x - w * 0.5, center.y + fs * 0.36), caption,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.96, 0.95, 0.88))

	func _gui_input(event: InputEvent) -> void:
		var pressed: bool = false
		var released: bool = false
		var from_touch: bool = false
		var pos: Vector2 = Vector2.ZERO
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			# Различать «мышь / эмуляция из касания» по device нельзя: платформы
			# проставляют его по-разному, и часть нажатий (в том числе клики мышью)
			# отбрасывалась молча. Пару «касание + клик» гасим ниже — по источнику
			# события и времени.
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			pressed = mb.pressed
			released = not mb.pressed
			pos = mb.position
		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			pressed = st.pressed
			released = not st.pressed
			from_touch = true
			pos = st.position
		else:
			return
		if pressed:
			if _is_echo(true, from_touch):
				accept_event()
				return
			down = true
			queue_redraw()
			if host != null:
				host.call("_on_button_down", action)
			accept_event()
		elif released:
			if _is_echo(false, from_touch):
				accept_event()
				return
			down = false
			queue_redraw()
			if host != null:
				host.call("_on_button_up", action)
			accept_event()


	## true, если это второе событие пары «касание + эмулированный клик»: источник
	## другой, а время почти то же — обрабатывать его нельзя, иначе один тап
	## выполнит действие дважды (это и списывало две аптечки).
	func _is_echo(is_press: bool, from_touch: bool) -> bool:
		var now: int = Time.get_ticks_msec()
		var last_from_touch: bool = _press_from_touch if is_press else _release_from_touch
		var last_ms: int = _press_ms if is_press else _release_ms
		if now - last_ms <= ECHO_MS and from_touch != last_from_touch:
			return true
		if is_press:
			_press_from_touch = from_touch
			_press_ms = now
		else:
			_release_from_touch = from_touch
			_release_ms = now
		return false


## Палец-стик: круглая подложка и «шляпка».
class StickView extends Control:
	var knob: bool = false

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		if knob:
			draw_circle(center, r, Color(0.86, 0.84, 0.72, 0.42))
			draw_arc(center, r - 1.5, 0.0, TAU, 32, Color(0.96, 0.94, 0.80, 0.65), 2.0)
		else:
			draw_circle(center, r, Color(0.10, 0.12, 0.12, 0.28))
			draw_arc(center, r - 2.0, 0.0, TAU, 48, Color(0.80, 0.78, 0.64, 0.55), 2.5)
			draw_arc(center, r * 0.62, 0.0, TAU, 32, Color(0.80, 0.78, 0.64, 0.25), 1.0)


# ------------------------------------------------------------------ построение
func setup(game_node: Node) -> void:
	game = game_node
	layer = 40
	_build()
	var auto_enable: bool = DisplayServer.is_touchscreen_available() or OS.has_feature("web")
	set_enabled(auto_enable)
	set_process(true)


func _build() -> void:
	_root = Control.new()
	_root.name = "TouchRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	_joy_base = _make_stick(false)
	_joy_knob = _make_stick(true)
	_aim_base = _make_stick(false)
	_aim_knob = _make_stick(true)
	_joy_base.visible = false
	_joy_knob.visible = false
	_aim_base.visible = false
	_aim_knob.visible = false
	_place_stick(_joy_base, _move_origin, MOVE_RADIUS)
	_place_stick(_joy_knob, _move_origin, KNOB)
	_place_stick(_aim_base, _aim_origin, AIM_RADIUS)
	_place_stick(_aim_knob, _aim_origin, KNOB)

	# Огонь — самая большая кнопка, правый нижний угол.
	_add_button("fire", "touch_fire", "ОГОНЬ", FIRE_SIZE, true,
		Rect2(-(MARGIN + FIRE_SIZE), -(MARGIN + FIRE_SIZE), -MARGIN, -MARGIN))
	# Кнопки вокруг: справа-снизу, вне зоны большого пальца.
	var col1: float = MARGIN + FIRE_SIZE + 10.0
	var col2: float = col1 + BTN + 8.0
	_add_button("use", "touch_use", "ДЕЙСТВИЕ", BTN, false,
		Rect2(-(col1 + BTN), -(MARGIN + BTN), -col1, -MARGIN))
	_add_button("heal", "touch_heal", "АПТЕЧКА", BTN, false,
		Rect2(-(col1 + BTN), -(MARGIN + BTN * 2.0 + 8.0), -col1, -(MARGIN + BTN + 8.0)))
	_add_button("swap", "touch_swap", "ОРУЖИЕ", BTN, false,
		Rect2(-(col2 + BTN), -(MARGIN + BTN), -col2, -MARGIN))
	_add_button("dodge", "touch_dodge", "РЫВОК", BTN, false,
		Rect2(-(col2 + BTN), -(MARGIN + BTN * 2.0 + 8.0), -col2, -(MARGIN + BTN + 8.0)))
	_add_button("bag", "touch_bag", "СУМКА", BTN, false,
		Rect2(-(col2 + BTN), -(MARGIN + BTN * 3.0 + 16.0), -col2, -(MARGIN + BTN * 2.0 + 16.0)))
	_add_button("journal", "touch_journal", "ЖУРНАЛ", BTN, false,
		Rect2(-(col1 + BTN), -(MARGIN + BTN * 3.0 + 16.0), -col1, -(MARGIN + BTN * 2.0 + 16.0)))
	_add_button("pause", "touch_pause", "ПАУЗА", BTN, false,
		Rect2(-(col1 + BTN), -(MARGIN + BTN * 4.0 + 24.0), -col1, -(MARGIN + BTN * 3.0 + 24.0)))


func _make_stick(knob: bool) -> Control:
	var tex_name: String = "joy_knob" if knob else "joy_base"
	var c: Control
	if Assets.has_ui(tex_name):
		var tr := TextureRect.new()
		tr.texture = Assets.ui(tex_name)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		c = tr
	else:
		var v := StickView.new()
		v.knob = knob
		c = v
	c.name = tex_name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(c)
	return c


func _add_button(action: String, tex_name: String, caption: String, size_px: float,
		hold: bool, anchors: Rect2) -> TouchButton:
	var b := TouchButton.new()
	b.name = "Btn_" + action
	b.host = self
	b.action = action
	b.tex_name = tex_name
	b.caption = caption
	b.hold = hold
	b.anchor_left = anchors.position.x if anchors.position.x >= 0.0 else 1.0
	b.anchor_right = anchors.size.x if anchors.size.x >= 0.0 else 1.0
	b.anchor_top = anchors.position.y if anchors.position.y >= 0.0 else 1.0
	b.anchor_bottom = anchors.size.y if anchors.size.y >= 0.0 else 1.0
	b.offset_left = anchors.position.x
	b.offset_right = anchors.size.x
	b.offset_top = anchors.position.y
	b.offset_bottom = anchors.size.y
	b.custom_minimum_size = Vector2(size_px, size_px)
	_root.add_child(b)
	_buttons.append(b)
	return b


func _place_stick(c: Control, center: Vector2, size_px: float) -> void:
	c.position = center - Vector2(size_px, size_px) * 0.5
	c.size = Vector2(size_px, size_px)


# ------------------------------------------------------------------ включение
func set_enabled(value: bool) -> void:
	enabled = value
	if _root != null and is_instance_valid(_root):
		_root.visible = value
	if not value:
		_reset_input_state()


func is_enabled() -> bool:
	return enabled


func bind_player(p: Node) -> void:
	player = p


func _reset_input_state() -> void:
	_move_index = -1
	_aim_index = -1
	move_vector = Vector2.ZERO
	aim_vector = Vector2.ZERO
	attack_held = false
	sprint_held = false
	consume_dodge = false
	_dodge_t = 0.0
	for c in [_joy_base, _joy_knob, _aim_base, _aim_knob]:
		if c != null and is_instance_valid(c):
			(c as CanvasItem).visible = false


# ------------------------------------------------------------------ ввод
func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_start(t.index, t.position)
		else:
			_touch_end(t.index)
		return
	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touch_move(d.index, d.position)
		return


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var key := event as InputEventKey
	if key.echo:
		return
	if key.keycode == KEY_T:
		set_enabled(not enabled)
		GameState.log_message.emit("Сенсорные кнопки: " + ("включены" if enabled else "выключены"),
			"info")
		if get_viewport() != null:
			get_viewport().set_input_as_handled()


func _view_size() -> Vector2:
	if _root != null and is_instance_valid(_root) and _root.size.x > 1.0:
		return _root.size
	return Vector2(1280, 720)


func _point_on_button(pos: Vector2) -> bool:
	for b in _buttons:
		if not is_instance_valid(b):
			continue
		var c := b as Control
		if not c.visible:
			continue
		if Rect2(c.global_position, c.size).has_point(pos):
			return true
	return false


func _touch_start(index: int, pos: Vector2) -> void:
	if _point_on_button(pos):
		return
	var half: float = _view_size().x * 0.5
	if pos.x < half:
		if _move_index == -1:
			_move_index = index
			_move_origin = pos
			move_vector = Vector2.ZERO
			sprint_held = false
			_show_stick(true, pos)
		return
	if _aim_index == -1:
		_aim_index = index
		_aim_origin = pos
		aim_vector = Vector2.ZERO
		attack_held = true
		_show_stick_aim(pos)


func _touch_move(index: int, pos: Vector2) -> void:
	if index == _move_index:
		_update_move(pos)
	elif index == _aim_index:
		_update_aim(pos)


func _touch_end(index: int) -> void:
	if index == _move_index:
		_move_index = -1
		move_vector = Vector2.ZERO
		sprint_held = false
		_hide_stick(true)
	elif index == _aim_index:
		_aim_index = -1
		aim_vector = Vector2.ZERO
		attack_held = _fire_button_down()
		_hide_stick(false)


func _show_stick(move: bool, pos: Vector2) -> void:
	var base := _joy_base if move else _aim_base
	var knob := _joy_knob if move else _aim_knob
	var radius: float = MOVE_RADIUS if move else AIM_RADIUS
	if base != null and is_instance_valid(base):
		_place_stick(base, pos, radius * 2.0)
		base.visible = true
	if knob != null and is_instance_valid(knob):
		_place_stick(knob, pos, KNOB)
		knob.visible = true


func _show_stick_aim(pos: Vector2) -> void:
	_show_stick(false, pos)


func _hide_stick(move: bool) -> void:
	var base := _joy_base if move else _aim_base
	var knob := _joy_knob if move else _aim_knob
	for c in [base, knob]:
		if c != null and is_instance_valid(c):
			(c as CanvasItem).visible = false


func _update_move(pos: Vector2) -> void:
	var delta: Vector2 = pos - _move_origin
	var dist: float = delta.length()
	var radius: float = MOVE_RADIUS
	if dist < DEAD_ZONE:
		move_vector = Vector2.ZERO
		sprint_held = false
	else:
		var f: float = clampf((dist - DEAD_ZONE) / (radius - DEAD_ZONE), 0.0, 1.0)
		move_vector = delta.normalized() * f
		sprint_held = f >= SPRINT_AT
	var knob_pos: Vector2 = _move_origin + delta.limit_length(radius)
	var knob := _joy_knob
	if knob != null and is_instance_valid(knob):
		_place_stick(knob, knob_pos, KNOB)


func _update_aim(pos: Vector2) -> void:
	var delta: Vector2 = pos - _aim_origin
	var dist: float = delta.length()
	if dist < DEAD_ZONE:
		aim_vector = Vector2.ZERO
	else:
		aim_vector = delta.normalized()
	var knob_pos: Vector2 = _aim_origin + delta.limit_length(AIM_RADIUS)
	var knob := _aim_knob
	if knob != null and is_instance_valid(knob):
		_place_stick(knob, knob_pos, KNOB)
	if knob != null and is_instance_valid(knob):
		(knob as CanvasItem).visible = true


# ------------------------------------------------------------------ кнопки
func _on_button_down(action: String) -> void:
	if not enabled:
		return
	Sfx.ui("ui_click", 1.0)
	match action:
		"fire":
			attack_held = true
		"dodge":
			consume_dodge = true
			_dodge_t = DODGE_WINDOW
		"_":
			pass
	if action != "fire":
		_emit_action(action)


func _on_button_up(action: String) -> void:
	if action == "fire":
		attack_held = _aim_index != -1


## Единая точка действий: сигнал для игрока + прямое управление окнами.
func _emit_action(action: String) -> void:
	action_pressed.emit(action)
	match action:
		"bag":
			_toggle_window("inventory_ui")
		"journal":
			_toggle_window("journal_ui")
		"pause":
			_pause_game()
		"_":
			pass


func _toggle_window(field: String) -> void:
	if game == null or not is_instance_valid(game):
		return
	var ui: Variant = game.get(field)
	if ui != null and is_instance_valid(ui) and (ui as Node).has_method("toggle"):
		ui.call("toggle")


func _pause_game() -> void:
	if game == null or not is_instance_valid(game):
		return
	if game.has_method("set_paused"):
		game.call("set_paused", true)
	var menu: Variant = game.get("menu_ui")
	if menu != null and is_instance_valid(menu) and (menu as Node).has_method("show_screen"):
		menu.call("show_screen", "pause")


func _fire_button_down() -> bool:
	for b in _buttons:
		if is_instance_valid(b) and String((b as TouchButton).action) == "fire":
			return (b as TouchButton).down
	return false


func _process(delta: float) -> void:
	if _dodge_t > 0.0:
		_dodge_t -= delta
		if _dodge_t <= 0.0:
			consume_dodge = false


# ------------------------------------------------------------------ отладка
func describe() -> Dictionary:
	var captions: Array = []
	for b in _buttons:
		if is_instance_valid(b):
			captions.append(String((b as TouchButton).action))
	return {
		"enabled": enabled,
		"visible": _root != null and _root.visible,
		"buttons": _buttons.size(),
		"actions": captions,
		"move": move_vector,
		"aim": aim_vector,
		"attack_held": attack_held,
		"sprint_held": sprint_held,
		"dodge": consume_dodge,
		"nodes": count_nodes(self),
	}


func count_nodes(n: Node) -> int:
	var total: int = 1
	for c in n.get_children():
		total += count_nodes(c)
	return total



