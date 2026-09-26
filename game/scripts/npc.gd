class_name Npc
extends StaticBody2D
## NPC-заказчик (Сидорович, Бармен): выдаёт задания, лечит за деньги,
## скупает хлам и артефакты. Взаимодействие — через interact(player).

const REST_COST := 250
const IDS := {
	"sidorovich": {"name": "Сидорович", "portrait": "dlg_portrait_sidorovich",
		"lines": ["Зона не прощает спешки. Слушай внимательно, спрашивай мало."]},
	"barman": {"name": "Бармен", "portrait": "dlg_portrait_barman",
		"lines": ["В Баре не стреляют. Остальное можно почти всё."]},
}

var npc_id: String = "sidorovich"
var display_name: String = "Сидорович"
var portrait: String = "dlg_portrait_sidorovich"

var _sprite: Sprite2D
var _marker: Sprite2D
var _anim: float = 0.0
var _dialog: DialogUI
var _option_actions: Array = []


func setup(id: String, name: String = "") -> void:
	npc_id = id
	var info: Dictionary = IDS.get(id, {})
	display_name = name if name != "" else String(info.get("name", id))
	portrait = String(info.get("portrait", "dlg_portrait_sidorovich"))
	if is_inside_tree():
		_build()


func _ready() -> void:
	add_to_group("npcs")
	collision_layer = 1 | 32
	collision_mask = 0
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_sprite = Sprite2D.new()
	_sprite.texture = Assets.sheet("stalker_idle", 0)
	_sprite.offset = Vector2(0, -Assets.SHEET_ANCHOR.y + Assets.SHEET_FRAME * 0.5)
	_sprite.modulate = Color(0.85, 0.95, 0.85) if npc_id == "sidorovich" else Color(0.95, 0.88, 0.8)
	add_child(_sprite)
	var shadow := Sprite2D.new()
	shadow.texture = Assets.sprite("soft_shadow")
	shadow.position = Vector2(0, 4)
	add_child(shadow)
	var label := Label.new()
	label.text = display_name
	label.add_theme_font_size_override("font_size", 15)
	if Assets.font_body != null:
		label.add_theme_font_override("font", Assets.font_body)
	label.position = Vector2(-40, -74)
	label.size = Vector2(80, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(1.0, 0.92, 0.7)
	add_child(label)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	shape.position = Vector2(0, -14)
	add_child(shape)
	_marker = Sprite2D.new()
	_marker.texture = Assets.ui("quest_marker")
	_marker.position = Vector2(0, -88)
	_marker.visible = false
	add_child(_marker)
	set_process(true)


func _process(delta: float) -> void:
	_anim += delta
	if _sprite != null:
		var f: int = int(_anim * 4.0) % maxi(1, Assets.sheet_count("stalker_idle"))
		_sprite.texture = Assets.sheet("stalker_idle", f)
	if _marker != null:
		_marker.visible = has_quest_marker()
		_marker.position.y = -88.0 + sin(_anim * 3.0) * 4.0


## Есть ли у NPC незакрытое задание для игрока.
func has_quest_marker() -> bool:
	return _quest_for_npc() != "" or _side_offer() != ""


func _quest_for_npc() -> String:
	var q: String = Quests.main_current()
	if q == "":
		return ""
	if String(Quests.data(q).get("giver", "")) != display_name:
		return ""
	if Quests.is_active(q):
		return q
	if String(Quests.state.get(q, "locked")) == "locked":
		return q
	return ""


func _side_offer() -> String:
	for id in Quests.QUESTS.keys():
		var d: Dictionary = Quests.data(id)
		if not bool(d.get("side", false)):
			continue
		if String(d.get("giver", "")) != display_name:
			continue
		if Quests.side_available(id):
			return id
	return ""


func set_dialog(dialog: DialogUI) -> void:
	_dialog = dialog
	if not _dialog.choice.is_connected(_on_choice):
		_dialog.choice.connect(_on_choice)


func interact_hint() -> String:
	return display_name


## Взаимодействие: открыть диалог заказчика.
func interact(player: Node = null) -> void:
	if _dialog == null or _dialog.is_open():
		return
	var q: String = _quest_for_npc()
	var lines: Array = []
	var options: Array = []
	_option_actions = []
	lines.append_array((IDS.get(npc_id, {}) as Dictionary).get("lines", ["…"]))
	if q != "":
		var d: Dictionary = Quests.data(q)
		if String(Quests.state.get(q, "locked")) == "locked":
			lines.append("%s: %s" % [Quests.title(q), String(d.get("intro", ""))])
			_add_option(options, "Взять задание: " + Quests.title(q), "start_quest", q)
		elif Quests.is_active(q):
			var line: String = "Как продвигается «%s»?" % Quests.title(q)
			for p in Quests.tracker_lines():
				if String(p["id"]) == q:
					line += " " + String(p["text"])
			lines.append(line)
		else:
			lines.append("«%s» — сделано. %s" % [Quests.title(q), String(d.get("outro", ""))])
	if lines.size() <= 1:
		lines.append("Держись подальше от аномалий без детектора.")
	var side: String = _side_offer()
	if side != "":
		lines.append("Есть отдельная работёнка: %s. %s" % [Quests.title(side),
			String(Quests.data(side).get("intro", ""))])
		_add_option(options, "Взять: " + Quests.title(side), "start_quest", side)
	_add_option(options, "Передохнуть у костра (%d ₽)" % REST_COST, "rest", "")
	var scrap: int = GameState.count_item("scrap")
	if scrap > 0:
		_add_option(options, "Продать хлам: %d шт. (%d ₽)" % [scrap, scrap * ItemDB.value("scrap")],
			"sell_scrap", "")
	_add_option(options, "Обменяться новостями", "smalltalk", "")
	_add_option(options, "Уйти", "close", "")
	_dialog.open(display_name, portrait, lines, options)


func _add_option(options: Array, text: String, action: String, value: String) -> void:
	options.append({"text": text})
	_option_actions.append({"action": action, "value": value})


func _on_choice(index: int) -> void:
	if index < 0 or index >= _option_actions.size():
		_dialog.close()
		return
	var act: Dictionary = _option_actions[index]
	match String(act["action"]):
		"start_quest":
			var q: String = String(act["value"])
			if not Quests.start(q):
				Sfx.ui("ui_deny")
				GameState.log_message.emit("Задание недоступно", "bad")
		"rest":
			if GameState.money >= REST_COST:
				GameState.add_money(-REST_COST)
				GameState.heal(GameState.hp_max)
				GameState.stamina = GameState.stamina_max
				GameState.radiation = maxf(0.0, GameState.radiation - 12.0)
				GameState.log_message.emit("Отдохнул у костра, силы вернулись", "good")
				Sfx.play("ui_open", global_position)
			else:
				Sfx.ui("ui_deny")
				GameState.log_message.emit("Не хватает денег", "bad")
		"sell_scrap":
			var n: int = GameState.count_item("scrap")
			if n > 0 and GameState.remove_item("scrap", n):
				GameState.add_money(n * ItemDB.value("scrap"))
				GameState.log_message.emit("Продано: хлам x%d" % n, "good")
				Sfx.ui("pickup_item")
		"smalltalk":
			GameState.log_message.emit(_random_rumour(), "info")
		_:
			pass
	_dialog.close()


func _random_rumour() -> String:
	var rumours := [
		"Говорят, в бункере на юге ещё работает генератор. И что-то живое там ходит.",
		"Слышал вой на Свалке? Это слепые псы. Держись подальше от их троп.",
		"Артефакт «Плод» тёплый, как живой. Не держи его долго в руке.",
		"На заводе кровосос. Хорошему сталкеру он не страшен, но хороших мало.",
		"Если дозиметр защёлкал часто — ты уже облучён и просто не заметил.",
	]
	return rumours[randi() % rumours.size()]

