extends SceneTree
## Headless-тест слоя интерфейса: HUD, сумка, журнал, меню, сенсорное управление.
## Сцена: Node2D-корень + заглушка Game (player/world/apply_quality) + заглушки
## врагов, аномалий и лута. UI-скрипты грузятся во время выполнения (из -s-скрипта
## нельзя обращаться к автолоадам на этапе компиляции).
##
## Запуск: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/t_ui.gd

const PATH_HUD := "res://scripts/hud.gd"
const PATH_INV := "res://scripts/inventory_ui.gd"
const PATH_JRN := "res://scripts/journal_ui.gd"
const PATH_MENU := "res://scripts/menu_ui.gd"
const PATH_TOUCH := "res://scripts/touch_ui.gd"

const MAX_FRAMES := 40
const MARGIN_SAFE := 16.0     ## безопасная зона интерфейса, px

var gs: Node = null
var quests: Node = null
var sfx: Node = null
var test_root: Node2D = null
var stub: Node = null
var stub_player: Node2D = null
var stub_world: Node2D = null
var hud: Node = null
var inv: Node = null
var journal: Node = null
var menu: Node = null
var touch: Node = null
var scripts: Dictionary = {}
var results: Array = []
var finished: bool = false
var frames: int = 0
var _screen_queue: Array = []
var _pending_screen: String = ""


## Заглушка игрока: только тот API, который читает HUD и сенсорный слой.
class StubPlayer extends Node2D:
	var aim_dir: Vector2 = Vector2.RIGHT
	var _mag: int = 8
	var _reload_time: float = 0.0

	func _ready() -> void:
		add_to_group("player")

	func center() -> Vector2:
		return global_position

	func is_alive() -> bool:
		return true

	func aim_dir_now() -> Vector2:
		return aim_dir

	func weapon_id() -> String:
		return "pm"

	func weapon_name() -> String:
		return "ПМ"

	func weapon_data() -> Dictionary:
		return {"mode": "gun", "mag": 8, "caliber": "9x18", "dmg": 18.0}

	func mag_size() -> int:
		return 8

	func mag_count() -> int:
		return _mag

	func reserve_count() -> int:
		return 60

	func interact_hint() -> String:
		return "F — открыть ящик"


class StubEnemy extends Node2D:
	var hp: float = 40.0
	var hp_max: float = 60.0
	var enemy_type: String = "dog"
	var level: int = 1
	var boss: bool = false

	func _ready() -> void:
		add_to_group("enemies")

	func is_alive() -> bool:
		return hp > 0.0

	func center() -> Vector2:
		return global_position


class StubAnomaly extends Node2D:
	var radius: float = 140.0
	var type_id: String = "grav"

	func _ready() -> void:
		add_to_group("anomalies")

	func danger_for(pos: Vector2) -> float:
		var d: float = pos.distance_to(global_position)
		return clampf(1.0 - d / maxf(1.0, radius), 0.0, 1.0)

	func has_artifact() -> bool:
		return true

	func take_artifact() -> String:
		return "artifact_medusa"


class StubLoot extends Node2D:
	func _ready() -> void:
		add_to_group("loot")


class StubContainer extends Node2D:
	var opened: bool = false

	func _ready() -> void:
		add_to_group("containers")


## Заглушка корневой игровой сцены: ровно тот контракт, что нужен UI.
class StubGame extends Node:
	var player: Node2D = null
	var world: Node2D = null
	var hud: Node = null
	var inventory_ui: Node = null
	var journal_ui: Node = null
	var menu_ui: Node = null
	var touch_ui: Node = null
	var quality: String = "medium"
	var paused_calls: int = 0
	var new_game_calls: int = 0
	var menu_calls: int = 0
	var save_calls: int = 0

	func apply_quality(name: String) -> void:
		quality = name

	func new_game(seed_value: int = 0) -> void:
		new_game_calls += 1

	func continue_game() -> void:
		new_game_calls += 1

	func set_paused(value: bool) -> void:
		paused_calls += 1

	func save_run() -> void:
		save_calls += 1

	func to_menu() -> void:
		menu_calls += 1


# ------------------------------------------------------------------ запуск
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	gs = root.get_node_or_null("/root/GameState")
	quests = root.get_node_or_null("/root/Quests")
	sfx = root.get_node_or_null("/root/Sfx")
	if gs == null or quests == null or sfx == null:
		print("НЕ НАЙДЕНЫ АВТОЛОАДЫ: ", gs, " ", quests, " ", sfx)
		quit(1)
		return
	for path in [PATH_HUD, PATH_INV, PATH_JRN, PATH_MENU, PATH_TOUCH]:
		var scr: Variant = load(String(path))
		scripts[String(path)] = scr
		if scr == null:
			print("НЕ ЗАГРУЗИЛСЯ СКРИПТ: ", path)
			quit(1)
			return
	_build_scene()
	print("=== ТЕСТ ИНТЕРФЕЙСА (headless) ===")
	_check("Дерево на старте не на паузе", not _tree_paused(), "")
	_phase_hud()
	_phase_inventory()
	_phase_journal()
	_phase_menu()
	_phase_touch()
	var driver := Driver.new()
	driver.name = "UiDriver"
	driver.host = self
	# тикаем даже когда дерево стоит на паузе (иначе тест зависнет на экране паузы)
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	test_root.add_child(driver)
	# страховка от зависания: таймер игнорирует паузу
	var timer: SceneTreeTimer = create_timer(20.0, true)
	timer.timeout.connect(_on_timeout)


func _on_timeout() -> void:
	_finish("таймаут")



func _build_scene() -> void:
	test_root = Node2D.new()
	test_root.name = "UiTestRoot"
	root.add_child(test_root)

	stub_world = Node2D.new()
	stub_world.name = "World"
	test_root.add_child(stub_world)

	stub_player = StubPlayer.new()
	stub_player.name = "Player"
	test_root.add_child(stub_player)
	stub_player.global_position = Vector2(1600.0, 1600.0)

	for i in 6:
		var e := StubEnemy.new()
		e.name = "Enemy%d" % i
		test_root.add_child(e)
		e.global_position = Vector2(1650.0 + float(i) * 40.0, 1600.0)
		e.enemy_type = ["dog", "mutant", "zombie", "boar", "dog", "snork"][i]
		e.level = 1 + (i % 3)
		e.boss = i == 5
	for i in 3:
		var a := StubAnomaly.new()
		a.name = "Anomaly%d" % i
		test_root.add_child(a)
		a.global_position = Vector2(1700.0 + float(i) * 90.0, 1650.0)
		a.type_id = ["grav", "elektra", "zharka"][i]
	for i in 4:
		var l := StubLoot.new()
		l.name = "Loot%d" % i
		test_root.add_child(l)
		l.global_position = Vector2(1560.0 + float(i) * 30.0, 1620.0)
	for i in 3:
		var c := StubContainer.new()
		c.name = "Container%d" % i
		test_root.add_child(c)
		c.global_position = Vector2(1500.0 + float(i) * 40.0, 1680.0)

	stub = StubGame.new()
	stub.name = "StubGame"
	test_root.add_child(stub)
	stub.set("player", stub_player)
	stub.set("world", stub_world)

	gs.call("reset_run", 20240923)
	gs.set("has_detector", true)
	gs.set("has_geiger", true)


## Создаём UI-узел нужного класса и сразу подключаем его к заглушке игры.
func _make_ui(path: String, node_name: String) -> Node:
	var scr: GDScript = scripts[path]
	var n: Variant = scr.new()
	if n == null or not (n is Node):
		_check("создание " + node_name, false, "script.new() вернул " + str(n))
		return null
	(n as Node).name = node_name
	test_root.add_child(n)
	if (n as Node).has_method("setup"):
		(n as Node).call("setup", stub)
	return n as Node


# ------------------------------------------------------------------ HUD
func _phase_hud() -> void:
	hud = _make_ui(PATH_HUD, "HUD")
	stub.set("hud", hud)
	_check("HUD создан", hud != null, "")
	if hud == null:
		return
	var zones := {
		"kordon": Rect2(0, 0, 1400, 1400),
		"village": Rect2(1400, 0, 1200, 900),
		"factory": Rect2(0, 1400, 1600, 1200),
		"bunker": Rect2(1600, 1400, 600, 600),
	}
	hud.call("minimap_setup", zones, Vector2i(40, 40), 128)
	hud.call("minimap_set_player", stub_player.global_position)
	var d: Dictionary = hud.call("describe")
	_check("HUD: корень и мини-карта", bool(d.get("root", false)) and bool(d.get("minimap", false)),
		str(d.get("nodes", 0)))
	_check("HUD: зоны приняты", int(d.get("zones", 0)) == 4, str(d.get("zones")))
	_check("HUD: узлов больше 30", int(d.get("nodes", 0)) > 30, str(d.get("nodes", 0)))
	_check("HUD: ключевые узлы собраны",
		_find_node(hud, "MinimapView") != null and _find_node(hud, "HudRoot") != null
			and _find_node(hud, "LogBox") != null and _find_node(hud, "QuestTracker") != null
			and _find_node(hud, "panel_vitals") != null
			and _find_node(hud, "panel_actionbar") != null
			and _find_node(hud, "damage_flash") != null
			and _find_node(hud, "vignette_low_hp") != null
			and _find_node(hud, "minimap_frame") != null, "")

	# масштаб карты: 40 тайлов по 128 = 5120 px мира на 208 px холста
	var tr: Dictionary = hud.call("map_transform", Vector2(208, 208))
	var scale: float = float(tr.get("scale", 0.0))
	var offset: Vector2 = tr.get("offset", Vector2.ZERO)
	_check("HUD: масштаб мини-карты", bool(tr.get("ok", false))
		and is_equal_approx(scale, 208.0 / 5120.0), "%.5f" % scale)
	_check("HUD: карта не смещена (квадрат)", offset.length() < 0.01, str(offset))

	gs.emit_signal("log_message", "Первый тест", "info")
	var l1: Dictionary = hud.call("describe")
	_check("HUD: строка лога добавлена", int(l1.get("logs", 0)) == 1, str(l1.get("logs")))
	for i in 8:
		gs.emit_signal("log_message", "Строка %d" % i, "bad")
	var l2: Dictionary = hud.call("describe")
	_check("HUD: лента ограничена 6 строками", int(l2.get("logs", 0)) == 6, str(l2.get("logs")))

	# трекер заданий: запускаем квест и «дёргаем» неудачный сигнал обновления
	quests.call("start", "q_awake")
	quests.emit_signal("quest_updated", "q_awake")
	var tracker: Node = _find_node(hud, "QuestTracker")
	_check("HUD: трекер заданий построен", tracker != null and tracker.get_child_count() >= 2,
		str(tracker.get_child_count()) if tracker != null else "нет узла")

	# опыт/урон: смена hp даёт вспышку урона
	gs.call("apply_damage", 30.0, "phys")
	_check("HUD: вспышка урона сработала", float(hud.get("_flash_t")) > 0.0,
		"%.2f" % float(hud.get("_flash_t")))
	hud.call("set_quality", "low")
	hud.call("set_minimap_visible", false)
	_check("HUD: мини-карту можно скрыть", not bool(hud.get("minimap_visible")), "")
	hud.call("set_minimap_visible", true)
	hud.call("flash_damage", 12.0)


# ------------------------------------------------------------------ СУМКА
func _phase_inventory() -> void:
	inv = _make_ui(PATH_INV, "InventoryUI")
	stub.set("inventory_ui", inv)
	_check("Сумка создана", inv != null, "")
	if inv == null:
		return
	var closed: Dictionary = inv.call("describe")
	_check("Сумка: закрыта сразу после setup", not bool(closed.get("open", true)), "")
	inv.call("toggle")
	var d: Dictionary = inv.call("describe")
	_check("Сумка: toggle открывает", bool(d.get("open", false)), "")
	_check("Сумка: 40 слотов", int(d.get("slots", 0)) == 40, str(d.get("slots")))
	_check("Сумка: 6 ячеек снаряжения", int(d.get("equip", 0)) == 6, str(d.get("equip")))
	_check("Сумка: 5 фильтров", int(d.get("filters", 0)) == 5, str(d.get("filters")))
	_check("Сумка: 3 кнопки действий", int(d.get("actions", 0)) == 3, str(d.get("actions")))

	# выделение первого предмета и надевание
	inv.call("_on_slot_pressed", 0)
	var sel: Dictionary = inv.call("selected_item")
	_check("Сумка: слот выделяется", not sel.is_empty(), str(sel.get("id", "")))
	var first_id: String = String(sel.get("id", ""))
	var before: int = int(gs.call("count_total", first_id))
	inv.call("_on_action_pressed", 0)
	var d2: Dictionary = inv.call("describe")
	_check("Сумка: кнопка «Надеть/Использовать» не падает", true, str(d2.get("selected", "")))
	_check("Сумка: предмет не размножился",
		int(gs.call("count_total", first_id)) <= before + 1,
		"%d -> %d" % [before, int(gs.call("count_total", first_id))])

	# фильтр «Оружие»: пустые слоты становятся недоступными
	inv.call("_on_filter_pressed", "weapon")
	var d3: Dictionary = inv.call("describe")
	_check("Сумка: фильтр применён", String(d3.get("filter", "")) == "weapon",
		String(d3.get("filter", "")))
	var enabled_slots: int = _count_enabled_slots(inv)
	_check("Сумка: фильтр «Оружие» сузил выбор", enabled_slots <= 4, str(enabled_slots))
	inv.call("_on_filter_pressed", "all")

	# квестовый предмет требует подтверждения
	gs.call("add_item", "docs", 1, true)
	inv.call("rebuild")
	var idx: int = _find_inventory_index("docs")
	if idx >= 0:
		inv.call("_on_slot_pressed", idx)
		var count_before: int = int(gs.call("count_item", "docs"))
		inv.call("_on_action_pressed", 2)
		_check("Сумка: выброс квеста ждёт подтверждения",
			int(gs.call("count_item", "docs")) == count_before
				and bool(inv.get("_confirm_drop")), "")
		inv.call("_on_action_pressed", 2)
		_check("Сумка: повторный тап выбрасывает",
			int(gs.call("count_item", "docs")) == count_before - 1,
			str(int(gs.call("count_item", "docs"))))

	# клавиатура и закрытие
	inv.call("_input", _key_event(KEY_E))
	_check("Сумка: E закрывает", not bool((inv.call("describe") as Dictionary).get("open", true)), "")
	inv.call("toggle")
	inv.call("_input", _key_event(KEY_ESCAPE))
	_check("Сумка: Esc закрывает", not bool((inv.call("describe") as Dictionary).get("open", true)), "")
	var weight_text: String = String((inv.get("_weight_label") as Label).text)
	_check("Сумка: счётчик веса на русском", weight_text.contains("Вес"), weight_text)
	var money_text: String = String((inv.get("_money_label") as Label).text)
	_check("Сумка: счётчик денег", money_text.contains("Рубли"), money_text)


# ------------------------------------------------------------------ ЖУРНАЛ
func _phase_journal() -> void:
	journal = _make_ui(PATH_JRN, "JournalUI")
	stub.set("journal_ui", journal)
	_check("Журнал создан", journal != null, "")
	if journal == null:
		return
	quests.call("start", "q_dogs")
	quests.emit_signal("quest_updated", "q_dogs")
	journal.call("toggle")
	var d: Dictionary = journal.call("describe")
	_check("Журнал: toggle открывает", bool(d.get("open", false)), "")
	_check("Журнал: список заданий заполнен", int(d.get("entries", 0)) >= 1
		and int(d.get("rows", 0)) >= 1, "%s / %s" % [d.get("entries"), d.get("rows")])
	_check("Журнал: подробности выбранного квеста",
		String(d.get("title", "")) != "" and String(d.get("title", "")) != "Задание не выбрано",
		String(d.get("title", "")))
	_check("Журнал: строка награды по-русски",
		String(d.get("reward", "")).contains("Награда"), String(d.get("reward", "")))

	journal.call("_on_tab_pressed", "stats")
	var stats: String = String(journal.call("statistics_text"))
	var ds: Dictionary = journal.call("describe")
	_check("Журнал: вкладка статистики", String(ds.get("tab", "")) == "stats", "")
	_check("Журнал: статистика содержит убийства и артефакты",
		stats.contains("Убийств") and stats.contains("Артефактов"), stats.substr(0, 40))
	journal.call("_on_tab_pressed", "quests")

	journal.call("_input", _key_event(KEY_J))
	_check("Журнал: J закрывает",
		not bool((journal.call("describe") as Dictionary).get("open", true)), "")
	journal.call("toggle")
	journal.call("_input", _key_event(KEY_ESCAPE))
	_check("Журнал: Esc закрывает",
		not bool((journal.call("describe") as Dictionary).get("open", true)), "")


# ------------------------------------------------------------------ МЕНЮ
func _phase_menu() -> void:
	menu = _make_ui(PATH_MENU, "MenuUI")
	stub.set("menu_ui", menu)
	_check("Меню создано", menu != null, "")
	if menu == null:
		return
	_check("Меню: process_mode = WHEN_PAUSED",
		(menu as Node).process_mode == Node.PROCESS_MODE_WHEN_PAUSED, "")
	var d0: Dictionary = menu.call("describe")
	_check("Меню: 7 экранов", int(d0.get("screens", 0)) == 7, str(d0.get("screens")))
	_check("Меню: строка версии", String(d0.get("version", "")).contains("версия"),
		String(d0.get("version", "")))
	_check("Меню: после setup ничего не открыто", not bool(d0.get("open", true)), "")

	menu.call("show_screen", "main")
	var d1: Dictionary = menu.call("describe")
	_check("Меню: главный экран открыт", String(d1.get("current", "")) == "main"
		and bool(menu.call("is_any_open")), String(d1.get("current", "")))
	_check("Меню: главное меню не морозит дерево", not _tree_paused(), "")

	menu.call("show_screen", "settings")
	var d2: Dictionary = menu.call("describe")
	_check("Меню: экран настроек", String(d2.get("current", "")) == "settings", "")
	menu.call("_on_quality_pressed", "low")
	_check("Меню: пресет качества прокинут в игру",
		String(stub.get("quality")) == "low"
			and String((menu.call("describe") as Dictionary).get("quality")) == "low",
		String(stub.get("quality")))
	menu.call("_on_quality_pressed", "high")
	_check("Меню: качество «Высокое»", String(stub.get("quality")) == "high", "")

	var slider: HSlider = (menu.get("_vol_sliders") as Dictionary)["vol_master"]
	slider.value = 0.4
	_check("Меню: ползунок громкости пишет в Sfx",
		is_equal_approx(float(sfx.get("vol_master")), 0.4), "%.2f" % float(sfx.get("vol_master")))
	menu.call("_on_toggle_changed", false, "minimap")
	_check("Меню: тумблер мини-карты применяется",
		not bool(hud.get("minimap_visible")), str(hud.get("minimap_visible")))
	menu.call("_on_toggle_changed", true, "minimap")
	menu.call("_on_toggle_changed", false, "damage_numbers")
	_check("Меню: тумблер цифр урона применяется", not bool(hud.get("damage_numbers")), "")
	menu.call("_on_toggle_changed", true, "damage_numbers")

	menu.call("show_screen", "controls")
	_check("Меню: справка по управлению", String(menu.call("current_screen")) == "controls", "")
	menu.call("show_screen", "about")
	_check("Меню: экран «Об игре»", String(menu.call("current_screen")) == "about", "")
	menu.call("show_screen", "stats")
	_check("Меню: сводка рейда", String(menu.call("current_screen")) == "stats", "")

	menu.call("show_screen", "pause")
	_check("Меню: пауза останавливает дерево", _tree_paused(), "")
	_check("Меню: экран паузы открыт", String(menu.call("current_screen")) == "pause", "")
	menu.call("hide_all")
	_check("Меню: hide_all снимает паузу",
		not _tree_paused() and not bool(menu.call("is_any_open")), "")

	menu.call("set_death_reason", "Убит слепым псом")
	menu.call("show_screen", "death")
	var report: String = String(menu.call("raid_report_text"))
	_check("Меню: причина смерти в отчёте", report.contains("Убит слепым псом"),
		report.substr(0, 48))
	_check("Меню: отчёт содержит статистику",
		report.contains("Уровень") and report.contains("Время в рейде"), "")
	menu.call("show_screen", "none")
	_check("Меню: show_screen(\"none\") закрывает всё", not bool(menu.call("is_any_open")), "")
	menu.call("show_screen", "такого-экрана-нет")
	_check("Меню: неизвестный экран не ломает игру", not bool(menu.call("is_any_open")), "")

	menu.call("show_screen", "main")
	menu.call("_on_menu_action", "new")
	_check("Меню: «Новая игра» зовёт game.new_game", int(stub.get("new_game_calls")) >= 1,
		str(stub.get("new_game_calls")))
	menu.call("_on_menu_action", "save")
	_check("Меню: «Сохранить» пишет сохранение", int(stub.get("save_calls")) >= 1,
		str(stub.get("save_calls")))
	menu.call("show_screen", "pause")
	menu.call("_on_menu_action", "to_menu")
	_check("Меню: «Выйти в меню» зовёт game.to_menu",
		int(stub.get("menu_calls")) >= 1 and not _tree_paused(), str(stub.get("menu_calls")))
	menu.call("hide_all")


# ------------------------------------------------------------------ КАСАНИЯ
func _phase_touch() -> void:
	touch = _make_ui(PATH_TOUCH, "TouchUI")
	stub.set("touch_ui", touch)
	_check("Сенсор создан", touch != null, "")
	if touch == null:
		return
	var actions: Array = []
	touch.connect("action_pressed", func(a: String): actions.append(a))
	touch.call("bind_player", stub_player)
	var d0: Dictionary = touch.call("describe")
	_check("Сенсор: 8 круглых кнопок", int(d0.get("buttons", 0)) == 8, str(d0.get("buttons")))
	_check("Сенсор: кнопка огня — самая большая",
		_button_size(touch, "fire") >= 132.0, "%.0f" % _button_size(touch, "fire"))
	_check("Сенсор: все кнопки не меньше 64 px", _min_button_size(touch) >= 64.0,
		"%.0f" % _min_button_size(touch))

	touch.call("set_enabled", true)
	_check("Сенсор: set_enabled(true) включает",
		bool((touch.call("describe") as Dictionary).get("enabled", false)), "")

	# левый стик: касание рождает джойстик, drag задаёт вектор
	touch.call("_input", _touch_event(0, Vector2(240, 420), true))
	touch.call("_input", _touch_drag(0, Vector2(340, 420)))
	var mv: Vector2 = (touch.call("describe") as Dictionary).get("move", Vector2.ZERO)
	_check("Сенсор: стик движения даёт вектор", mv.x > 0.55 and absf(mv.y) < 0.05,
		"%.2f, %.2f" % [mv.x, mv.y])
	touch.call("_input", _touch_drag(0, Vector2(144, 324)))
	var mv2: Vector2 = (touch.call("describe") as Dictionary).get("move", Vector2.ZERO)
	_check("Сенсор: вектор обновляется на drag (по диагонали)", mv2.x < 0.0 and mv2.y < 0.0,
		"%.2f, %.2f" % [mv2.x, mv2.y])
	_check("Сенсор: бег включается при полном отклонении",
		float(mv2.length()) >= 0.82, "%.2f" % mv2.length())
	touch.call("_input", _touch_event(0, Vector2(144, 324), false))
	_check("Сенсор: отпускание обнуляет движение",
		(touch.call("describe") as Dictionary).get("move") == Vector2.ZERO, "")

	# мёртвая зона 12 px
	touch.call("_input", _touch_event(0, Vector2(300, 400), true))
	touch.call("_input", _touch_drag(0, Vector2(307, 400)))
	_check("Сенсор: мёртвая зона 12 px работает",
		(touch.call("describe") as Dictionary).get("move") == Vector2.ZERO, "")
	touch.call("_input", _touch_drag(0, Vector2(360, 400)))
	_check("Сенсор: за мёртвой зоной вектор есть",
		float(((touch.call("describe") as Dictionary).get("move") as Vector2).length()) > 0.05, "")
	touch.call("_input", _touch_event(0, Vector2(360, 400), false))

	# правый стик: тап = одиночный выстрел, удержание = огонь
	touch.call("_input", _touch_event(1, Vector2(1000, 380), true))
	_check("Сенсор: правый стик включает огонь",
		bool((touch.call("describe") as Dictionary).get("attack_held", false)), "")
	touch.call("_input", _touch_drag(1, Vector2(1120, 380)))
	var av: Vector2 = (touch.call("describe") as Dictionary).get("aim", Vector2.ZERO)
	_check("Сенсор: вектор прицела нормализован", av.length() > 0.9 and av.x > 0.9,
		"%.2f" % av.length())
	touch.call("_input", _touch_event(1, Vector2(1120, 380), false))
	var d3: Dictionary = touch.call("describe")
	_check("Сенсор: отпускание стика прекращает огонь",
		not bool(d3.get("attack_held", true))
			and (d3.get("aim") as Vector2) == Vector2.ZERO, "")

	# мультитач: движение и прицел одновременно
	touch.call("_input", _touch_event(0, Vector2(200, 400), true))
	touch.call("_input", _touch_event(1, Vector2(1000, 400), true))
	touch.call("_input", _touch_drag(0, Vector2(260, 340)))
	touch.call("_input", _touch_drag(1, Vector2(1000, 300)))
	var dm: Dictionary = touch.call("describe")
	_check("Сенсор: мультитач — движение и прицел вместе",
		(dm.get("move") as Vector2).length() > 0.2 and (dm.get("aim") as Vector2).y < -0.9
			and bool(dm.get("attack_held", false)), "%s / %s" % [dm.get("move"), dm.get("aim")])
	touch.call("_input", _touch_event(0, Vector2(260, 340), false))
	touch.call("_input", _touch_event(1, Vector2(1000, 300), false))

	# касание по кнопке не должно рождать стик
	var fire_center: Vector2 = _button_center(touch, "fire")
	touch.call("_input", _touch_event(2, fire_center, true))
	_check("Сенсор: тап по кнопке не создаёт стик",
		(touch.call("describe") as Dictionary).get("move") == Vector2.ZERO, str(fire_center))
	touch.call("_input", _touch_event(2, fire_center, false))

	# кнопки: огонь, рывок, аптечка, сумка, журнал, пауза
	touch.call("_on_button_down", "fire")
	_check("Сенсор: кнопка «ОГОНЬ» держит огонь",
		bool((touch.call("describe") as Dictionary).get("attack_held", false)), "")
	touch.call("_on_button_up", "fire")
	touch.call("_on_button_down", "dodge")
	_check("Сенсор: кнопка «РЫВОК» выставляет consume_dodge",
		bool(touch.get("consume_dodge")), "")
	touch.call("_on_button_down", "heal")
	_check("Сенсор: «АПТЕЧКА» уходит в сигнал actions", actions.has("heal"), str(actions))
	touch.call("_on_button_down", "swap")
	_check("Сенсор: «ОРУЖИЕ» уходит в сигнал actions", actions.has("swap"), str(actions))

	inv.call("close")
	touch.call("_on_button_down", "bag")
	_check("Сенсор: «СУМКА» открывает инвентарь", bool(inv.call("is_open")), "")
	touch.call("_on_button_down", "bag")
	_check("Сенсор: повторное нажатие закрывает инвентарь", not bool(inv.call("is_open")), "")
	journal.call("close")
	touch.call("_on_button_down", "journal")
	_check("Сенсор: «ЖУРНАЛ» открывает журнал", bool(journal.call("is_open")), "")
	journal.call("close")
	touch.call("_on_button_down", "pause")
	_check("Сенсор: «ПАУЗА» ставит игру на паузу",
		String(menu.call("current_screen")) == "pause" and _tree_paused(), "")
	menu.call("hide_all")
	_check("Сенсор: после закрытия меню пауза снята", not _tree_paused(), "")

	touch.call("set_enabled", false)
	var d4: Dictionary = touch.call("describe")
	_check("Сенсор: set_enabled(false) сбрасывает ввод",
		not bool(d4.get("enabled", true)) and (d4.get("move") as Vector2) == Vector2.ZERO, "")


# ------------------------------------------------------------------ помощники
func _tree_paused() -> bool:
	var t: SceneTree = root.get_tree()
	return t != null and t.paused


func _key_event(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func _touch_event(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


func _touch_drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	return e


func _find_node(parent: Node, node_name: String) -> Node:
	if parent.name == node_name:
		return parent
	for c in parent.get_children():
		var found: Node = _find_node(c, node_name)
		if found != null:
			return found
	return null


## Первый Control с указанным именем (панели разных окон называются одинаково).
func _panel_node(ui: Node, node_name: String) -> Node:
	var node: Node = _find_node(ui, node_name)
	if node != null and node is Control:
		return node
	return null


func _find_inventory_index(id: String) -> int:
	var items: Array = gs.get("inventory")
	for i in items.size():
		if String((items[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


func _count_enabled_slots(ui: Node) -> int:
	var grid: Node = _find_node(ui, "Grid")
	if grid == null:
		return -1
	var count: int = 0
	for c in grid.get_children():
		if c is Button and not (c as Button).disabled:
			count += 1
	return count


func _find_button(ui: Node, action: String) -> Control:
	var node: Node = _find_node(ui, "Btn_" + action)
	return node as Control


func _button_extent(ui: Node, action: String) -> float:
	var b: Control = _find_button(ui, action)
	if b == null:
		return -1.0
	var s: Vector2 = b.size
	if s.x < 1.0:
		s = b.custom_minimum_size
	return maxf(s.x, s.y)


func _button_size(ui: Node, action: String) -> float:
	return _button_extent(ui, action)


func _button_center(ui: Node, action: String) -> Vector2:
	var b: Control = _find_button(ui, action)
	if b == null:
		return Vector2(1100, 640)
	var extent: float = maxf(_button_extent(ui, action), 84.0)
	# кнопка прижата к правому-нижнему краю: считаем центр от размера вьюпорта
	var view: Vector2 = Vector2(1280, 720)
	if root != null:
		view = Vector2(root.size)
	var offsets: Dictionary = {
		"fire": Rect2(-(16.0 + 132.0), -(16.0 + 132.0), -16.0, -16.0),
	}
	if offsets.has(action):
		var r: Rect2 = offsets[action]
		return Vector2(view.x + r.position.x, view.y + r.position.y) + Vector2(132, 132) * 0.5
	return b.global_position + Vector2(extent, extent) * 0.5


func _min_button_size(ui: Node) -> float:
	var smallest: float = 9999.0
	for b in (ui.get("_buttons") as Array):
		if not is_instance_valid(b):
			continue
		var c := b as Control
		var s: Vector2 = c.size
		if s.x < 1.0:
			s = c.custom_minimum_size
		smallest = minf(smallest, maxf(s.x, s.y))
	if smallest > 9000.0:
		return -1.0
	return smallest


# ------------------------------------------------------------------ кадры
## Несколько кадров с включённым _process: проверяем, что опрос ничего не ломает.
func _tick(frame: int) -> void:
	frames = frame
	if frame == 1:
		# лента сообщений должна затухнуть и очиститься
		if hud != null:
			hud.call("_on_log_message", "Проверка затухания", "info")
	if frame == 3:
		_layout_checks()
	elif _pending_screen != "" and frame > 3:
		# контейнеры пересчитали раскладку в предыдущем кадре — можно мерить
		var screen: String = _pending_screen
		_pending_screen = ""
		_measure_screen(screen)
		if _tree_paused():
			menu.call("hide_all")   # измерение экрана паузы не должно морозить тест
		_next_screen()
	if frame == MAX_FRAMES:
		if menu != null:
			menu.call("hide_all")
		_check("Кадры: _process всех слоёв отработал без ошибок", true, "%d кадров" % frame)
		_finish("кадры отработаны")


# ------------------------------------------------------------------ раскладка
## Геометрия: элементы прижаты к краям с отступом 16 px и не выходят за вьюпорт.
## Проверка идёт по фактическим якорям/прямоугольникам, поэтому одинаково
## работает и на 16:9, и на 2:1 (там вьюпорт шире, а привязка к правому краю).
func _layout_checks() -> void:
	var vp: Rect2 = test_root.get_viewport_rect()
	_check("Раскладка: вьюпорт известен", vp.size.x > 100.0 and vp.size.y > 100.0, str(vp))
	var names: Array = [
		[inv, "InventoryRoot"], [inv, "panel_window"], [inv, "panel_tooltip"],
		[journal, "JournalRoot"], [journal, "panel_window"],
		[menu, "Screen_main"], [menu, "Screen_settings"],
		[hud, "HudRoot"], [hud, "panel_vitals"], [hud, "minimap_frame"],
		[hud, "panel_actionbar"], [hud, "LogBox"], [hud, "QuestTracker"],
		[touch, "TouchRoot"], [touch, "Btn_fire"], [touch, "Btn_pause"],
	]
	var outside: Array = []
	for pair in names:
		var ui: Node = pair[0]
		var node: Node = _find_node(ui, String(pair[1])) if ui != null else null
		if node == null or not (node is Control):
			outside.append(String(pair[1]) + ":нет")
			continue
		var r: Rect2 = (node as Control).get_global_rect()
		if r.position.x < vp.position.x - 0.5 or r.position.y < vp.position.y - 0.5 \
				or r.end.x > vp.end.x + 0.5 or r.end.y > vp.end.y + 0.5:
			outside.append("%s:%s" % [pair[1], r])
	_check("Раскладка: элементы внутри вьюпорта (16:9 и 2:1)", outside.is_empty(),
		", ".join(outside) if not outside.is_empty() else str(vp.size))

	# тач-кнопки прижаты к правому-нижнему краю с отступом 16 px и >= 64 px
	var bad: Array = []
	for b in (touch.get("_buttons") as Array):
		var c := b as Control
		var ext: float = maxf(c.size.x, c.size.y)
		if c.anchor_left < 0.999 or c.anchor_right < 0.999 \
				or c.anchor_top < 0.999 or c.anchor_bottom < 0.999:
			bad.append(String((c as Object).get("action")) + ":якорь")
		elif c.offset_right > -MARGIN_SAFE + 0.01 or c.offset_bottom > -MARGIN_SAFE + 0.01:
			bad.append(String((c as Object).get("action")) + ":отступ")
		elif ext < 64.0:
			bad.append(String((c as Object).get("action")) + ":%.0f px" % ext)
	_check("Раскладка: кнопки касаний — правый-нижний угол, отступ 16 px, >= 64 px",
		bad.is_empty(), ", ".join(bad))

	# HUD: мини-карта у правого верхнего угла, панель героя у левого верхнего
	var mm: Control = _find_node(hud, "minimap_frame") as Control
	_check("Раскладка: мини-карта прижата к правому верхнему углу",
		mm != null and mm.anchor_left > 0.999 and mm.anchor_top < 0.001
			and is_equal_approx(mm.offset_right, -MARGIN_SAFE)
			and is_equal_approx(mm.offset_top, MARGIN_SAFE),
		str(mm.offset_left) if mm != null else "нет узла")
	var vit: Control = _find_node(hud, "panel_vitals") as Control
	_check("Раскладка: панель героя прижата к левому верхнему углу",
		vit != null and vit.anchor_left < 0.001 and vit.anchor_top < 0.001
			and is_equal_approx(vit.offset_left, MARGIN_SAFE)
			and is_equal_approx(vit.offset_top, MARGIN_SAFE),
		str(vit.offset_left) if vit != null else "нет узла")
	var bar: Control = _find_node(hud, "panel_actionbar") as Control
	_check("Раскладка: панель действий по центру низа",
		bar != null and is_equal_approx(bar.anchor_left, 0.5)
			and is_equal_approx(bar.anchor_top, 1.0)
			and is_equal_approx(bar.offset_bottom, -MARGIN_SAFE),
		str(bar.offset_bottom) if bar != null else "нет узла")
	# окна сумки и журнала помещаются в 16:9 (1280x720) целиком
	var inv_win: Control = _find_node(inv, "panel_window") as Control
	var jrn_win: Control = _find_node(journal, "panel_window") as Control
	var tool: Control = _find_node(inv, "panel_tooltip") as Control
	_check("Раскладка: сумка и журнал влезают в 1280x720",
		inv_win != null and inv_win.offset_right <= 1280.0 and inv_win.offset_bottom <= 720.0
			and jrn_win != null and jrn_win.offset_right <= 1280.0
			and jrn_win.offset_bottom <= 720.0, "%.0f x %.0f" % [inv_win.offset_right,
				inv_win.offset_bottom] if inv_win != null else "нет узла")
	_check("Раскладка: панель описания прижата к правому краю",
		tool != null and tool.anchor_left > 0.999 and is_equal_approx(tool.offset_right,
			-MARGIN_SAFE), str(tool.offset_right) if tool != null else "нет узла")

	# запасные панели (assets/ui пуст) должны быть непрозрачными
	var opaque_bad: Array = []
	for pair in [[inv, "panel_window"], [inv, "panel_tooltip"], [journal, "panel_window"],
			[menu, "panel_window"]]:
		var ui: Node = pair[0]
		var node: Node = _panel_node(ui, String(pair[1]))
		if node == null or not (node is Panel):
			opaque_bad.append(String(pair[1]) + ":не Panel")
			continue
		var sb: StyleBox = (node as Panel).get_theme_stylebox("panel")
		if sb == null or not (sb is StyleBoxFlat):
			opaque_bad.append(String(pair[1]) + ":нет стиля")
			continue
		if (sb as StyleBoxFlat).bg_color.a < 0.95:
			opaque_bad.append("%s:альфа %.2f" % [pair[1], (sb as StyleBoxFlat).bg_color.a])
	_check("Раскладка: запасные окна непрозрачные (текст читается поверх мира)",
		opaque_bad.is_empty(), ", ".join(opaque_bad))

	# ничто не должно налезать друг на друга на экранах меню:
	# раскладку каждого экрана меряем в отдельном кадре (контейнеры сортируются
	# отложенно), поэтому экраны идут очередью через _tick.
	_screen_queue = ["main", "settings", "controls", "about", "death", "stats", "pause"]
	_next_screen()


func _next_screen() -> void:
	if _screen_queue.is_empty():
		_pending_screen = ""
		return
	_pending_screen = String(_screen_queue.pop_front())
	menu.call("show_screen", _pending_screen)


## Проверка одного экрана меню: кнопки/ползунки внутри панели и не пересекаются.
func _measure_screen(screen: String) -> void:
	var scr: Node = _find_node(menu, "Screen_" + screen)
	if scr == null:
		_check("Меню (" + screen + "): экран найден", false, "")
		return
	var own_panel: Control = null
	for c in scr.get_children():
		if c is Control and String((c as Control).name).begins_with("panel_"):
			own_panel = c as Control
			break
	var items: Array = []
	_collect_interactive(scr, items)
	var problems: Array = []
	if own_panel != null:
		var pr: Rect2 = own_panel.get_global_rect()
		for it in items:
			var r: Rect2 = (it as Control).get_global_rect()
			if r.position.x < pr.position.x - 1.0 or r.position.y < pr.position.y - 1.0 \
					or r.end.x > pr.end.x + 1.0 or r.end.y > pr.end.y + 1.0:
				problems.append("%s вне панели" % (it as Control).name)
	for i in items.size():
		for j in range(i + 1, items.size()):
			var a: Control = items[i]
			var b: Control = items[j]
			if a.get_global_rect().intersects(b.get_global_rect()):
				problems.append("%s ∩ %s" % [a.name, b.name])
	# строка версии не должна налезать на кнопки
	if screen == "main":
		var version_label := menu.get("_version_label") as Label
		if version_label != null:
			var vr: Rect2 = version_label.get_global_rect()
			for it in items:
				if vr.intersects((it as Control).get_global_rect()):
					problems.append("версия ∩ " + (it as Control).name)
	# каждая кнопка не меньше 64 px по высоте
	for it in items:
		var c := it as Control
		if c is Button and c.get_global_rect().size.y < 63.5:
			problems.append("%s низкая (%.0f px)" % [c.name, c.get_global_rect().size.y])
	if items.is_empty():
		problems.append("нет интерактивных элементов")
	_check("Меню (" + screen + "): %d элементов на месте и не пересекаются" % items.size(),
		problems.is_empty(), ", ".join(problems))


## Интерактивные элементы экрана (кнопки, тумблеры, ползунки) — рекурсивно.
func _collect_interactive(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Button or c is CheckButton or c is HSlider:
			if (c as CanvasItem).visible:
				out.append(c)
		elif c is Control:
			_collect_interactive(c, out)


# ------------------------------------------------------------------ отчёт
func _check(title: String, ok: bool, info: String) -> void:
	results.append({"name": title, "ok": ok, "info": info})
	print("[%s] %s%s" % ["OK  " if ok else "FAIL", title,
		("  (" + info + ")") if info != "" else ""])


func _finish(reason: String) -> void:
	if finished:
		return
	finished = true
	var t: SceneTree = root.get_tree()
	if t != null:
		t.paused = false
	print("")
	print("узлов в дереве: ", t.get_node_count() if t != null else -1)
	if hud != null:
		print("HUD: ", hud.call("describe"))
	if inv != null:
		print("Сумка: ", inv.call("describe"))
	if journal != null:
		print("Журнал: ", journal.call("describe"))
	if menu != null:
		print("Меню: ", menu.call("describe"))
	if touch != null:
		print("Сенсор: ", touch.call("describe"))
	var failed: int = 0
	for r in results:
		if not bool(r["ok"]):
			failed += 1
			print("  ПРОВАЛ: %s%s" % [String(r["name"]),
				("  (" + String(r["info"]) + ")") if String(r["info"]) != "" else ""])
	print("")
	print("=== UI-ТЕСТ (%s): проверок %d, провалов %d ===" % [reason, results.size(), failed])
	quit(0 if failed == 0 else 1)


class Driver extends Node:
	var host: Object = null
	var frames: int = 0

	func _process(_delta: float) -> void:
		frames += 1
		if host != null:
			host.call("_tick", frames)








