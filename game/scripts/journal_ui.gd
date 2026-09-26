class_name JournalUI extends CanvasLayer
## Журнал сталкера: две вкладки — «Задания» (список слева, подробности справа)
## и «Статистика» (убийства по типам, артефакты, контейнеры, время рейда).
##
## Активные задания идут первыми, выполненные — серым, побочные помечены
## «(побочное)». Кнопки списка 64 px высотой, работает и палец, и клавиатура
## (J — открыть/закрыть, Esc — закрыть).

const PANEL_W := 840.0
const PANEL_H := 688.0
const LIST_W := 300.0
const ROW_H := 64.0
const TAB_H := 56.0

const ENEMY_NAMES := {
	"dog": "Слепые псы", "mutant": "Кровосос", "zombie": "Зомбированные",
	"boar": "Кабаны", "snork": "Снорки", "pseudodog": "Псевдопсы",
	"controller": "Контролёры",
}

var game: Node = null

var _root: Control
var _window: Control
var _tabs: Array = []
var _quest_page: Control
var _stats_page: Control
var _list_box: VBoxContainer
var _scroll: ScrollContainer
var _d_title: Label
var _d_meta: Label
var _d_intro: Label
var _d_obj: Label
var _d_reward: Label
var _d_outro: Label
var _stats_label: Label
var _hint: Label
var _entries: Array = []
var _selected: String = ""
var _tab: String = "quests"
var _open: bool = false


func setup(game_node: Node) -> void:
	game = game_node
	layer = 22
	_build()
	GameState.stats_changed.connect(_on_stats_changed)
	Quests.quest_started.connect(_on_quest_signal)
	Quests.quest_updated.connect(_on_quest_signal)
	Quests.quest_completed.connect(_on_quest_signal)
	set_process(true)
	set_process_input(true)


# ------------------------------------------------------------------ построение
## Панель-подложка: NinePatch, если текстура есть; иначе непрозрачный тёмный
## StyleBoxFlat, чтобы текст журнала читался поверх мира.
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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, size: Vector2, font_size: int = 20) -> Button:
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
		sb.texture_margin_left = 14
		sb.texture_margin_right = 14
		sb.texture_margin_top = 14
		sb.texture_margin_bottom = 14
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		var press: StyleBoxTexture = sb.duplicate()
		if Assets.has_ui("panel_slot_sel"):
			press.texture = Assets.ui("panel_slot_sel")
			press.texture_margin_left = 10
			press.texture_margin_right = 10
			press.texture_margin_top = 10
			press.texture_margin_bottom = 10
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
	b.add_theme_color_override("font_color", Color(0.92, 0.90, 0.84))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
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
	_root.name = "JournalRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.55)
	_anchored(dim, Rect2(0, 0, 0, 0), Rect2(0, 0, 1, 1))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_window = _panel(_root, "panel_window", Color(0.08, 0.09, 0.10, 0.96))
	_anchored(_window, Rect2(16, 16, 16 + PANEL_W, 16 + PANEL_H), Rect2(0, 0, 0, 0))

	var title := _label(_window, "Журнал", 28, Color(0.96, 0.86, 0.55))
	if Assets.font_title != null:
		title.add_theme_font_override("font", Assets.font_title)
	title.position = Vector2(20, 6)
	title.size = Vector2(220, 36)

	var close_btn := _button(_window, "Закрыть  (Esc)", Vector2(180, 40), 17)
	close_btn.position = Vector2(636, 8)
	close_btn.pressed.connect(close)

	_build_tabs()
	_build_quest_page()
	_build_stats_page()


func _build_tabs() -> void:
	var defs: Array = [{"id": "quests", "label": "Задания"}, {"id": "stats", "label": "Статистика"}]
	var x: float = 20.0
	for d in defs:
		var b := _button(_window, String(d["label"]), Vector2(220, TAB_H), 21)
		b.position = Vector2(x, 62)
		b.pressed.connect(_on_tab_pressed.bind(String(d["id"])))
		b.set_meta("tab_id", String(d["id"]))
		_tabs.append(b)
		x += 230.0


func _build_quest_page() -> void:
	_quest_page = Control.new()
	_quest_page.name = "QuestPage"
	_anchored(_quest_page, Rect2(16, 130, 16 + PANEL_W - 32, 16 + PANEL_H - 16),
		Rect2(0, 0, 0, 0))
	_quest_page.mouse_filter = Control.MOUSE_FILTER_PASS
	_window.add_child(_quest_page)

	_scroll = ScrollContainer.new()
	_scroll.name = "QuestScroll"
	_scroll.position = Vector2(6, 6)
	_scroll.size = Vector2(LIST_W, PANEL_H - 190.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_quest_page.add_child(_scroll)

	_list_box = VBoxContainer.new()
	_list_box.name = "QuestList"
	_list_box.add_theme_constant_override("separation", 4)
	_list_box.custom_minimum_size = Vector2(LIST_W - 12.0, 0)
	_scroll.add_child(_list_box)

	var sep := ColorRect.new()
	sep.color = Color(0.32, 0.31, 0.28, 0.8)
	sep.position = Vector2(LIST_W + 14.0, 6)
	sep.size = Vector2(2, PANEL_H - 190.0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_page.add_child(sep)

	var dx: float = LIST_W + 30.0
	var dw: float = PANEL_W - 32.0 - dx - 6.0
	_d_title = _label(_quest_page, "Задание не выбрано", 24, Color(0.96, 0.90, 0.70))
	_d_title.position = Vector2(dx, 4)
	_d_title.size = Vector2(dw, 34)
	_d_meta = _label(_quest_page, "", 17, Color(0.70, 0.74, 0.72))
	_d_meta.position = Vector2(dx, 40)
	_d_meta.size = Vector2(dw, 24)
	_d_intro = _label(_quest_page, "", 17, Color(0.88, 0.88, 0.82))
	_d_intro.position = Vector2(dx, 70)
	_d_intro.size = Vector2(dw, 120)
	_d_obj = _label(_quest_page, "", 18, Color(0.90, 0.90, 0.84))
	_d_obj.position = Vector2(dx, 196)
	_d_obj.size = Vector2(dw, 170)
	_d_reward = _label(_quest_page, "", 17, Color(0.96, 0.84, 0.50))
	_d_reward.position = Vector2(dx, 372)
	_d_reward.size = Vector2(dw, 110)
	_d_outro = _label(_quest_page, "", 16, Color(0.74, 0.78, 0.74))
	_d_outro.position = Vector2(dx, 486)
	_d_outro.size = Vector2(dw, 100)


func _build_stats_page() -> void:
	_stats_page = Control.new()
	_stats_page.name = "StatsPage"
	_anchored(_stats_page, Rect2(30, 136, 30 + PANEL_W - 60, 16 + PANEL_H - 16),
		Rect2(0, 0, 0, 0))
	_stats_page.mouse_filter = Control.MOUSE_FILTER_PASS
	_stats_page.visible = false
	_window.add_child(_stats_page)
	_stats_label = _label(_stats_page, "", 19, Color(0.90, 0.90, 0.84))
	_stats_label.position = Vector2(0, 0)
	_stats_label.size = Vector2(PANEL_W - 60, PANEL_H - 170)
	_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP


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
	_root.visible = true
	Sfx.ui("ui_open")
	refresh()


func close() -> void:
	if not _open:
		return
	_open = false
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
		KEY_ESCAPE, KEY_J:
			close()
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
		KEY_TAB:
			_on_tab_pressed("quests" if _tab == "stats" else "stats")
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
		_:
			pass


func _on_tab_pressed(tab_id: String) -> void:
	_tab = tab_id
	Sfx.ui("ui_click")
	_quest_page.visible = tab_id == "quests"
	_stats_page.visible = tab_id == "stats"
	for b in _tabs:
		var b_id: String = String((b as Button).get_meta("tab_id", ""))
		(b as Button).modulate = Color(1, 1, 1) if b_id == _tab else Color(0.70, 0.70, 0.66)
	if tab_id == "stats":
		_update_stats()


func _on_quest_signal(_id: String) -> void:
	if _open:
		refresh()


func _on_stats_changed() -> void:
	if _open and _tab == "stats":
		_update_stats()


# ------------------------------------------------------------------ данные
func refresh() -> void:
	_entries = _sorted_entries()
	_rebuild_list()
	if _tab == "stats":
		_update_stats()
	else:
		_show_details(_selected)


## Активные вперёд, затем выполненные; побочные помечаются.
func _sorted_entries() -> Array:
	var entries: Array = Quests.journal_entries()
	var active: Array = []
	var done: Array = []
	for e in entries:
		var d: Dictionary = e
		if String(d.get("state", "")) == "done":
			done.append(d)
		else:
			active.append(d)
	active.sort_custom(func(a, b): return String(a.get("title", "")) < String(b.get("title", "")))
	done.sort_custom(func(a, b): return String(a.get("title", "")) < String(b.get("title", "")))
	var out: Array = []
	out.append_array(active)
	out.append_array(done)
	return out


func _rebuild_list() -> void:
	if _list_box == null or not is_instance_valid(_list_box):
		return
	for c in _list_box.get_children():
		c.queue_free()
	if _entries.is_empty():
		var empty := _label(_list_box, "Заданий пока нет. Поговорите с Сидоровичем.", 16,
			Color(0.66, 0.68, 0.64))
		empty.custom_minimum_size = Vector2(LIST_W - 16.0, 60)
		return
	for e in _entries:
		var d: Dictionary = e
		var id: String = String(d.get("id", ""))
		var state: String = String(d.get("state", "active"))
		var prefix: String = "★ " if state == "active" else "✓ "
		var side: String = "  (побочное)" if bool(d.get("side", false)) else ""
		var b := _button(_list_box, prefix + String(d.get("title", "")) + side,
			Vector2(LIST_W - 16.0, ROW_H), 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_color_override("font_color",
			Color(0.96, 0.86, 0.55) if state == "active" else Color(0.66, 0.72, 0.66))
		b.pressed.connect(_on_quest_pressed.bind(id))
		b.set_meta("quest_id", id)
		if id == _selected:
			b.modulate = Color(1.0, 0.97, 0.78)


func _on_quest_pressed(id: String) -> void:
	_selected = id
	Sfx.ui("ui_click")
	_show_details(id)
	for c in _list_box.get_children():
		if c is Button and c.has_meta("quest_id"):
			var on: bool = String(c.get_meta("quest_id")) == id
			(c as Button).modulate = Color(1.0, 0.97, 0.78) if on else Color(1, 1, 1)


func _entry_by_id(id: String) -> Dictionary:
	for e in _entries:
		if String((e as Dictionary).get("id", "")) == id:
			return e
	return {}


func _show_details(id: String) -> void:
	if id == "":
		if not _entries.is_empty():
			id = String((_entries[0] as Dictionary).get("id", ""))
			_selected = id
	if id == "":
		_d_title.text = "Задание не выбрано"
		_d_meta.text = ""
		_d_intro.text = ""
		_d_obj.text = ""
		_d_reward.text = ""
		_d_outro.text = ""
		return
	var d: Dictionary = _entry_by_id(id)
	if d.is_empty():
		return
	var state: String = String(d.get("state", "active"))
	_d_title.text = String(d.get("title", ""))
	_d_meta.text = "Заказчик: %s   ·   Место: %s   ·   %s" % [
		String(d.get("giver", "—")), String(d.get("zone", "—")),
		"выполнено" if state == "done" else "активное"]
	_d_meta.modulate = Color(0.62, 0.86, 0.62) if state == "done" \
		else Color(0.76, 0.80, 0.74)
	_d_intro.text = String(d.get("intro", ""))
	var obj_lines: Array = ["Цели:"]
	for o in (d.get("objectives", []) as Array):
		var od: Dictionary = o
		var mark: String = "[+]" if bool(od.get("done", false)) else "[ ]"
		obj_lines.append("%s %s — %d/%d" % [mark, String(od.get("text", "")),
			int(od.get("have", 0)), int(od.get("want", 0))])
	_d_obj.text = "\n".join(obj_lines)
	_d_reward.text = _reward_text(id, state)
	_d_outro.text = ("После сдачи: " + String(d.get("outro", ""))) if state == "done" \
		else String(d.get("outro", ""))


## Награда из данных квеста: деньги, опыт, предметы.
func _reward_text(id: String, state: String) -> String:
	var d: Dictionary = _quest_data(id)
	var reward: Dictionary = d.get("reward", {})
	if reward.is_empty():
		return ""
	var parts: Array = []
	if int(reward.get("money", 0)) > 0:
		parts.append("%d руб." % int(reward.get("money", 0)))
	if float(reward.get("xp", 0.0)) > 0.0:
		parts.append("%.0f опыта" % float(reward.get("xp", 0.0)))
	for pair in reward.get("items", []):
		if pair.size() >= 2:
			parts.append("%s x%d" % [ItemDB.display_name(String(pair[0])), int(pair[1])])
	if parts.is_empty():
		return ""
	var head: String = "Награда получена:" if state == "done" else "Награда:"
	return head + " " + ", ".join(parts)


## Константа QUESTS живёт в скрипте автолоада — достаём её через карту констант.
func _quest_data(id: String) -> Dictionary:
	var scr: Variant = Quests.get_script()
	if scr == null:
		return {}
	var map: Dictionary = (scr as GDScript).get_script_constant_map()
	var all: Variant = map.get("QUESTS", {})
	if all is Dictionary and (all as Dictionary).has(id):
		return (all as Dictionary)[id]
	return {}


# ------------------------------------------------------------------ статистика
func _update_stats() -> void:
	if _stats_label == null or not is_instance_valid(_stats_label):
		return
	_stats_label.text = statistics_text()


func statistics_text() -> String:
	var lines: Array = []
	lines.append("Рейд в Зоне")
	lines.append("Уровень: %d   ·   Опыт: %.0f / %.0f" % [
		GameState.level, GameState.xp, maxf(1.0, GameState.xp_next)])
	lines.append("Убийств всего: %d" % GameState.kills)
	var types: Dictionary = GameState.kills_by_type
	if types.is_empty():
		lines.append("   (пока никого не пришлось)")
	else:
		var keys: Array = types.keys()
		keys.sort()
		for k in keys:
			var key: String = String(k)
			lines.append("   %s: %d" % [String(ENEMY_NAMES.get(key, key)), int(types[k])])
	lines.append("Артефактов найдено: %d" % GameState.artifacts_found)
	lines.append("Контейнеров вскрыто: %d" % GameState.containers_looted)
	lines.append("Заданий выполнено: %d" % GameState.quests_done)
	lines.append("Пройдено: %.0f м" % GameState.distance_walked)
	lines.append("Время в рейде: %s" % _time_text(GameState.play_time))
	lines.append("Денег: %d руб." % GameState.money)
	lines.append("Семя мира: %d" % GameState.world_seed)
	lines.append("")
	lines.append("Снаряжение: оружие «%s», броня «%s», шлем «%s»" % [
		_equip_name("weapon"), _equip_name("armor"), _equip_name("helmet")])
	lines.append("Артефакты: «%s», «%s», «%s»" % [
		_equip_name("artifact_1"), _equip_name("artifact_2"), _equip_name("artifact_3")])
	return "\n".join(lines)


func _equip_name(slot: String) -> String:
	var id: String = String(GameState.equipment.get(slot, ""))
	return ItemDB.display_name(id) if id != "" else "нет"


func _time_text(seconds: float) -> String:
	var total: int = int(maxf(0.0, seconds))
	var h: int = total / 3600
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	if h > 0:
		return "%d ч %02d мин" % [h, m]
	return "%d мин %02d с" % [m, s]


# ------------------------------------------------------------------ отладка
func describe() -> Dictionary:
	return {
		"open": _open,
		"tab": _tab,
		"entries": _entries.size(),
		"rows": _list_box.get_child_count() if _list_box != null else 0,
		"selected": _selected,
		"title": _d_title.text if _d_title != null else "",
		"reward": _d_reward.text if _d_reward != null else "",
		"nodes": count_nodes(self),
	}


func count_nodes(n: Node) -> int:
	var total: int = 1
	for c in n.get_children():
		total += count_nodes(c)
	return total





