extends SceneTree

## Проба: связка «слой касаний <-> игрок» (player.touch) и реальная доставка тапов
## до стика, кнопок касаний и вариантов ответа в диалоге.
##
## Проверяет исправление багов:
##   * player.bind_touch() вызывался только в ветке touch_ui == null, поэтому на
##     телефоне стик и кнопки действий молча не работали (player.touch оставался
##     null, и связь «слой включён» <-> «игрок читает стик» нигде не поддерживалась);
##   * DialogUI._input съедал клик/тап через set_input_as_handled() до GUI-разбора,
##     поэтому варианты ответа не нажимались ни мышью, ни пальцем;
##   * кнопки слоя касаний получали событие дважды (касание + эмуляция мыши из
##     касания), из-за чего один тап по «АПТЕЧКЕ» списывал две аптечки.
##
## Разделы: 0/A/B — связка слоя и игрока, C — стик, D/H — кнопка аптечки (тап и
## клик мышью), E/F — клавиатура и мышь, G — варианты ответа в диалоге.
##
## Полный прогон (нужно настоящее окно с дисплеем):
##   Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/_touch_wire.gd
## В --headless прогоняются только прямые вызовы логики: GUI-выбор в headless мёртв.

const SEED := 555001

var game: Node = null
var player: Node = null
var touch: Node = null
var gs: Node = null          ## GameState: в -s-скрипте автолоад берём по узлу
var fails: int = 0
var windowed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _check(label: String, ok: bool, extra: String = "") -> void:
	if not ok:
		fails += 1
	print("[wire] ", "OK   " if ok else "FAIL ", label, ("  | " + extra) if extra != "" else "")


func _run() -> void:
	windowed = DisplayServer.get_name() != "headless"
	var scene: PackedScene = load("res://scenes/game.tscn")
	game = scene.instantiate()
	root.add_child(game)
	for i in 8:
		await process_frame
	touch = game.get("touch_ui")
	gs = root.get_node_or_null("/root/GameState")
	print("[wire] режим=", DisplayServer.get_name(), " тачскрин=", DisplayServer.is_touchscreen_available(),
		" окно=", root.size, " канва=", root.get_visible_rect().size, " слой=", touch != null,
		" GameState=", gs != null)
	if touch == null or gs == null:
		_check("слой касаний и GameState созданы", false)
		quit(1)
		return
	# Игровой тик (_update_touch_visibility) на десктопе сам выключает слой касаний,
	# поэтому принудительно включённый слой он снимет в первом же кадре — для проверок
	# это мешает, останавливаем _process игры (логика игрока идёт в _physics_process).
	game.set_process(false)

	# --- 0: десктопное поведение по умолчанию (слой выключен)
	touch.call("set_enabled", false)
	game.call("new_game", SEED)
	for i in 20:
		await process_frame
	player = game.get("player")
	_check("0. слой выключен -> player.touch == null",
		player.get("touch") == null, "touch=" + str(player.get("touch")))
	_check("0. на десктопе прицел не переведён в автоприцел",
		player.get("_touch_aim_fallback") == false)

	# --- A: главный баг. Слой включён ДО создания игрока (как на телефоне):
	#     _build_world сам должен связать игрока со слоем.
	touch.call("set_enabled", true)
	game.call("new_game", SEED)
	player = game.get("player")
	_check("A. включённый слой -> player.touch == touch_ui",
		player.get("touch") == touch, "touch=" + str(player.get("touch")))
	_check("A. bind_touch подключил action_pressed к игроку",
		touch.is_connected("action_pressed", Callable(player, "_on_touch_action")))
	_check("A. на телефоне включён автоприцел (_touch_aim_fallback)",
		player.get("_touch_aim_fallback") == true)

	# --- B: связь согласована с включённостью слоя (ручной вызов и тик игры)
	touch.call("set_enabled", false)
	game.call("_sync_touch_binding")
	_check("B. слой выключен -> связи нет", player.get("touch") == null)
	_check("B. слой выключен -> автоприцел сброшен", player.get("_touch_aim_fallback") == false)
	touch.call("set_enabled", true)
	game.call("_sync_touch_binding")
	_check("B. слой включён -> связь есть", player.get("touch") == touch)
	game.call("_update_touch_visibility")
	var bound: bool = player.get("touch") == touch
	var on: bool = bool(touch.call("is_enabled"))
	_check("B. связь согласована с is_enabled()", bound == on,
		"bound=" + str(bound) + " enabled=" + str(on))
	# дальше нужен включённый слой
	touch.call("set_enabled", true)
	game.call("_sync_touch_binding")
	await process_frame
	_check("B. после возврата слоя связь осталась", player.get("touch") == touch)


	# --- C: стик реально двигает игрока (то, что не работало на телефоне)
	var joy: Control = touch.get("_joy_base")
	var center: Vector2 = joy.get_global_rect().get_center()
	var p: Node2D = player
	var before: Vector2 = p.global_position
	if windowed:
		_push_touch(7, center, true)
		await process_frame
		_push_drag(7, center + Vector2(70.0, 0.0))
	else:
		touch.call("_touch_start", 7, center)
		touch.call("_touch_move", 7, center + Vector2(70.0, 0.0))
	for i in 20:
		await process_frame
	var after: Vector2 = p.global_position
	var mv: Vector2 = touch.get("move_vector")
	if windowed:
		_push_touch(7, center + Vector2(70.0, 0.0), false)
	else:
		touch.call("_touch_end", 7)
	_check("C. стик отклонён -> move_vector читается игроком", mv.length() > 0.5,
		"move_vector=" + str(mv))
	_check("C. стик отклонён вправо -> игрок сдвинулся вправо", (after - before).x > 8.0,
		"delta=" + str(after - before))

	# --- D: кнопка «АПТЕЧКА» реально лечит игрока (связь action_pressed работает)
	var heal_btn: Control = null
	for b in touch.get("_buttons"):
		if b != null and String((b as Control).get("action")) == "heal":
			heal_btn = b as Control
	_check("D. кнопка АПТЕЧКА существует и видима", heal_btn != null and heal_btn.visible,
		("rect=" + str(heal_btn.get_global_rect())) if heal_btn != null else "<нет>")
	gs.call("add_item", "medkit", 2, true)
	gs.set("hp", float(gs.get("hp_max")) * 0.4)
	var hp_before: float = float(gs.get("hp"))
	var med_before: int = int(gs.call("count_item", "medkit"))
	if windowed and heal_btn != null:
		var hc: Vector2 = heal_btn.get_global_rect().get_center()
		_send_touch(8, hc, true)
		for i in 2:
			await process_frame
		_send_touch(8, hc, false)
	else:
		touch.call("_on_button_down", "heal")
	for i in 4:
		await process_frame
	var med_after: int = int(gs.call("count_item", "medkit"))
	_check("D. тап по АПТЕЧКЕ расходует аптечку у игрока", med_after < med_before,
		"medkit " + str(med_before) + "->" + str(med_after) +
		" (потрачено " + str(med_before - med_after) + " за один тап)" +
		", hp " + str(hp_before) + "->" + str(gs.get("hp")))
	# Из касания движок сам делает клик мышью (эмуляция включена по умолчанию),
	# поэтому кнопка слоя получала событие дважды и тап списывал две аптечки.
	_check("D. один тап = одна аптечка (эмуляция мыши не дублирует нажатие)",
		med_before - med_after == 1, "потрачено " + str(med_before - med_after))

	# --- H: клик мышью по кнопке слоя касаний (браузер на ПК без тачскрина, узкое
	#     окно: слой включён, а жмёт пользователь мышью). Из мыши движок делает
	#     касание, поэтому проверяем, что эмуляция не дублирует действие.
	gs.call("add_item", "medkit", 3, true)
	gs.set("hp", float(gs.get("hp_max")) * 0.3)
	var h_before: int = int(gs.call("count_item", "medkit"))
	if windowed and heal_btn != null:
		var hc: Vector2 = heal_btn.get_global_rect().get_center()
		_send_mouse(hc, true)
		for i in 2:
			await process_frame
		_send_mouse(hc, false)
	else:
		touch.call("_on_button_down", "heal")
	for i in 4:
		await process_frame
	var h_after: int = int(gs.call("count_item", "medkit"))
	_check("H. один клик мышью по кнопке слоя = одно действие",
		h_before - h_after == 1, "medkit " + str(h_before) + "->" + str(h_after))

	# --- E: клавиатура по-прежнему двигает игрока (слой включён, стик не тронут)
	_key(KEY_D, true)
	for i in 3:
		await process_frame
	var kmove: Vector2 = player.call("_read_move")
	_key(KEY_D, false)
	for i in 2:
		await process_frame
	_check("E. клавиши двигают игрока и при включённом слое касаний", kmove.x > 0.5,
		"keys=" + str(kmove))

	# --- F: при выключенном слое прицел снова по мыши (регрессия десктопа)
	touch.call("set_enabled", false)
	game.call("_sync_touch_binding")
	_check("F. слой выключен -> игрок не читает стик", player.get("touch") == null)
	_check("F. слой выключен -> автоприцел не включён", player.get("_touch_aim_fallback") == false)
	if windowed and not DisplayServer.is_touchscreen_available():
		Input.warp_mouse(Vector2(260.0, 200.0))
		for i in 2:
			await process_frame
		player.call("_update_aim")
		var pc: Vector2 = player.call("center")
		var want: Vector2 = (p.get_global_mouse_position() - pc).normalized()
		var got: Vector2 = player.get("aim_dir")
		_check("F. прицел смотрит на мышь", want.length() < 0.1 or got.distance_to(want) < 0.05,
			"aim=" + str(got) + " мышь=" + str(want))

	# --- G: тап по варианту ответа в диалоге (мобильный случай, с эмуляцией мыши)
	#     Раньше DialogUI._input съедал тап через set_input_as_handled() ещё до
	#     GUI-разбора, поэтому варианты не нажимались ни пальцем, ни мышью.
	var picks: Array = []
	var dialog: Node = game.get("dialog")
	dialog.connect("choice", func(i: int): picks.append(i))
	touch.call("set_enabled", true)
	game.call("_sync_touch_binding")
	var npcs: Array = get_nodes_in_group("npcs")
	_check("G. в мире есть NPC для диалога", npcs.size() > 0, "NPC=" + str(npcs.size()))
	if npcs.size() > 0:
		var npc: Node2D = npcs[0]
		p.global_position = npc.global_position + Vector2(40.0, 0.0)
		for i in 10:
			await process_frame
		_key(KEY_F, true)
		await process_frame
		_key(KEY_F, false)
		for i in 8:
			await process_frame
		_check("G. диалог открылся (F)", dialog.call("is_open"))
		var guard: int = 0
		while dialog.call("is_open") and _option_buttons(dialog).is_empty() and guard < 20:
			_key(KEY_SPACE, true)
			await process_frame
			_key(KEY_SPACE, false)
			for i in 4:
				await process_frame
			guard += 1
		var opts: Array = _option_buttons(dialog)
		_check("G. реплики пролистаны пробелом и показаны варианты ответа", not opts.is_empty(),
			"вариантов=" + str(opts.size()) + " прогонов=" + str(guard))
		if not opts.is_empty():
			var opt: Button = opts[0] as Button
			var oc: Vector2 = opt.get_global_rect().get_center()
			print("[wire] G. тап по варианту «", opt.text, "» в ", oc,
				" windowed=", windowed)
			if windowed:
				_send_touch(9, oc, true)
				for i in 3:
					await process_frame
				_send_touch(9, oc, false)
			else:
				# headless: GUI-выбор мёртв, проверяем только саму ветку диалога
				dialog.call("_on_option", 0)
			for i in 6:
				await process_frame
			_check("G. тап по варианту ответа дошёл до диалога (choice)", not picks.is_empty(),
				"choice=" + str(picks) + " диалог открыт=" + str(dialog.call("is_open")))

	print("[wire] ИТОГ: замечаний ", fails)
	quit(1 if fails > 0 else 0)


func _option_buttons(dialog: Node) -> Array:
	var box: Node = dialog.get("_options_box")
	var out: Array = []
	if box == null:
		return out
	for c in box.get_children():
		if c is Button and (c as Control).visible:
			out.append(c)
	return out


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _push_touch(index: int, canvas_pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = _to_window(canvas_pos)
	ev.pressed = pressed
	root.push_input(ev)


func _push_drag(index: int, canvas_pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = _to_window(canvas_pos)
	root.push_input(ev)


## Настоящий мобильный путь: событие идёт через Input, поэтому с включённой по
## умолчанию эмуляцией мыши из касания (как на телефоне) кнопки тоже получают клик.
func _send_touch(index: int, canvas_pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = _to_window(canvas_pos)
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Клик настоящей мышью (ПК без тачскрина, узкое окно): событие идёт через Input,
## поэтому движок дополнительно эмулирует касание — кнопка слоя не должна сработать дважды.
func _send_mouse(canvas_pos: Vector2, pressed: bool) -> void:
	var win: Vector2 = _to_window(canvas_pos)
	var move := InputEventMouseMotion.new()
	move.position = win
	move.global_position = win
	Input.parse_input_event(move)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = win
	ev.global_position = win
	Input.parse_input_event(ev)


## Координаты канвы -> координаты окна (canvas_items + expand могут отличаться).
func _to_window(canvas_pos: Vector2) -> Vector2:
	var win: Vector2 = Vector2(root.size)
	var canvas: Vector2 = root.get_visible_rect().size
	if canvas.x < 1.0 or canvas.y < 1.0:
		return canvas_pos
	return canvas_pos * (win / canvas)
