extends Node
## Квестовая цепочка Зоны. Автолоад Quests.
## Цели отслеживаются через notify(kind, target, amount):
##   "kill"    target — id врага (dog/mutant/zombie/boar)
##   "collect" target — id предмета
##   "reach"   target — id локации (kordon/village/factory/bunker)
##   "loot"    target — "" (любой контейнер)
signal quest_started(id: String)
signal quest_updated(id: String)
signal objective_completed(quest_id: String, index: int)
signal quest_completed(id: String)

## Квест: title, giver, intro/outro — тексты, objectives — список целей,
## reward — награда, next — следующий квест цепочки, zone — где искать.
const QUESTS: Dictionary = {
	"q_awake": {
		"title": "Первые шаги", "giver": "Сидорович", "zone": "Кордон",
		"intro": "Ну что, сталкер, выжил? Хорошо. Тогда слушай: Зона пустых не любит. "
			+ "Собери хлам по округе и дойди до заброшенной деревни — там дома, документы и хабар.",
		"outro": "Живой и с хабаром — уже неплохо. Держи мелочь на расходы и не лезь, куда не просят.",
		"objectives": [
			{"kind": "collect", "target": "scrap", "count": 3, "text": "Собрать хлам"},
			{"kind": "reach", "target": "village", "count": 1, "text": "Дойти до заброшенной деревни"},
		],
		"reward": {"money": 400, "xp": 70, "items": [["bandage", 3]]},
		"next": "q_dogs",
	},
	"q_dogs": {
		"title": "Слепые псы", "giver": "Сидорович", "zone": "Свалка",
		"intro": "Слепые псы обнаглели: рвут наших прямо на Свалке. Проредь стаю, "
			+ "и заодно обшарь ящики — там всякое лежит.",
		"outro": "Слышал, как они выли? Теперь тише будут. Патроны не забывай.",
		"objectives": [
			{"kind": "kill", "target": "dog", "count": 4, "text": "Убить слепых псов"},
			{"kind": "loot", "target": "", "count": 2, "text": "Обшарить контейнеры"},
		],
		"reward": {"money": 700, "xp": 150, "items": [["ammo_9x18", 60], ["canned", 2]]},
		"next": "q_artifact",
	},
	"q_artifact": {
		"title": "Первая ходка", "giver": "Сидорович", "zone": "Аномальное поле",
		"intro": "Понимаешь, к чему я? За артефактом надо идти в поле. Детектор возьми — "
			+ "он пищит, когда рядом «Медуза». Только не беги сломя голову, там гравиконцентрат.",
		"outro": "Вот это хабар! Второй раз уже не так страшно, верно?",
		"objectives": [
			{"kind": "collect", "target": "artifact_medusa", "count": 1,
				"text": "Добыть артефакт «Медуза»"},
		],
		"reward": {"money": 1500, "xp": 260, "items": [["detector", 1], ["antidote", 2]]},
		"next": "q_docs",
	},
	"q_docs": {
		"title": "Чужие бумаги", "giver": "Бармен", "zone": "Заброшенная деревня",
		"intro": "В деревне стоят дома, а в домах — документы. Мне нужны любые. "
			+ "Плачу честно, без вопросов.",
		"outro": "Хорошо. Забери комплект — в деревне тебе не поздоровится.",
		"objectives": [
			{"kind": "collect", "target": "docs", "count": 1, "text": "Найти документы"},
		],
		"reward": {"money": 1200, "xp": 300, "items": [["armor_plate", 1], ["medkit", 2]]},
		"next": "q_mutant",
	},
	"q_mutant": {
		"title": "Кровосос", "giver": "Бармен", "zone": "Завод",
		"intro": "На заводе завёлся кровосос. Он слышит тебя раньше, чем ты его. "
			+ "Держи дистанцию и не дай ему подойти вплотную.",
		"outro": "Кровосос — трофей. Теперь тебя будут узнавать в Баре.",
		"objectives": [
			{"kind": "kill", "target": "mutant", "count": 1, "text": "Убить кровососа"},
		],
		"reward": {"money": 2500, "xp": 420, "items": [["ak", 1], ["ammo_545", 90]]},
		"next": "q_zombies",
	},
	"q_zombies": {
		"title": "Долг перед мёртвыми", "giver": "Бармен", "zone": "Руины завода",
		"intro": "Зомбированные сталкеры бродят у цехов. Это ещё люди — но уже нет. "
			+ "Освободи их и забери то, что они не смогли донести.",
		"outro": "Тяжёлый рейс. Ты сделал больше, чем отряд «Долга» за месяц.",
		"objectives": [
			{"kind": "kill", "target": "zombie", "count": 6, "text": "Убить зомбированных"},
			{"kind": "loot", "target": "", "count": 4, "text": "Обшарить контейнеры"},
		],
		"reward": {"money": 2000, "xp": 480, "items": [["helmet", 1], ["ammo_545", 120]]},
		"next": "q_key",
	},
	"q_key": {
		"title": "Ключ от бункера", "giver": "Рация", "zone": "Южный лес",
		"intro": "…приём, приём… слышишь? На юге, в лесополосе, есть схрон. "
			+ "Ключ с биркой ищи у старого лагеря — там давно никого живого.",
		"outro": "Ключ при тебе. Бункер за железной дорогой — там наша цель.",
		"objectives": [
			{"kind": "collect", "target": "key_underground", "count": 1,
				"text": "Найти ключ от бункера"},
		],
		"reward": {"money": 1800, "xp": 400, "items": [["artifact_soul", 1]]},
		"next": "q_bunker",
	},
	"q_bunker": {
		"title": "Последний рейс", "giver": "Рация", "zone": "Бункер",
		"intro": "Это конец похода. В бункере держат то, за чем сюда ходят все. "
			+ "И там же то, что охраняет. Возьми «Гравиконцентрат» и выключи «Плод».",
		"outro": "Ты вынес из Зоны то, что не смогли вынести десятки. Хабар твой — ты его заслужил.",
		"objectives": [
			{"kind": "reach", "target": "bunker", "count": 1, "text": "Войти в бункер"},
			{"kind": "kill", "target": "mutant", "count": 3, "text": "Убить кровососов"},
			{"kind": "collect", "target": "artifact_grav", "count": 1,
				"text": "Добыть «Гравиконцентрат»"},
		],
		"reward": {"money": 9000, "xp": 1500, "items": [["armor_exo", 1], ["medkit", 4]]},
		"next": "",
	},
	"s_boars": {
		"title": "Мясо для Бара", "giver": "Бармен", "zone": "Окраины",
		"intro": "Мутировавшие кабаны дерутся за территорию. Ты их отгонишь — я тебя накормлю.",
		"outro": "Мясо есть, значит Бар живёт ещё одну неделю.",
		"objectives": [{"kind": "kill", "target": "boar", "count": 5, "text": "Убить кабанов"}],
		"reward": {"money": 1200, "xp": 300, "items": [["canned", 4], ["vodka", 2]]},
		"next": "", "side": true,
	},
	"s_meds": {
		"title": "Запас для лазарета", "giver": "Сидорович", "zone": "Везде",
		"intro": "Лазарету нужны бинты и аптечки. Собери — и мы в расчёте.",
		"outro": "Хороший запас. Кто-то сегодня доживёт до утра.",
		"objectives": [
			{"kind": "collect", "target": "bandage", "count": 5, "text": "Собрать бинты"},
			{"kind": "collect", "target": "medkit", "count": 2, "text": "Собрать аптечки"},
		],
		"reward": {"money": 900, "xp": 240, "items": [["antidote", 3]]},
		"next": "", "side": true,
	},
	"s_artifacts": {
		"title": "Коллекционер", "giver": "Бармен", "zone": "Аномалии Зоны",
		"intro": "Ещё три артефакта — и я дам тебе то, за что обычно берут по-крупному.",
		"outro": "Отличная работа. Держи инструменты и рацию.",
		"objectives": [
			{"kind": "collect", "target": "artifact_medusa", "count": 3, "text": "Добыть артефакты"},
		],
		"reward": {"money": 3200, "xp": 700, "items": [["tools", 1], ["radio", 1]]},
		"next": "", "side": true,
	},
}

## Порядок основной цепочки (для подсказок и разблокировки).
const MAIN_CHAIN: PackedStringArray = [
	"q_awake", "q_dogs", "q_artifact", "q_docs",
	"q_mutant", "q_zombies", "q_key", "q_bunker",
]

var state: Dictionary = {}       ## id -> "locked" | "active" | "done"
var progress: Dictionary = {}    ## id -> Array[int]
var active: PackedStringArray = []
var _syncing: bool = false


func _ready() -> void:
	reset()
	GameState.inventory_changed.connect(_on_inventory_changed)


## Любое изменение сумки — повод пересчитать цели «собрать N».
func _on_inventory_changed() -> void:
	if _syncing:
		return
	_syncing = true
	for id in active.duplicate():
		_sync_collect(id)
	_syncing = false



func reset() -> void:
	state.clear()
	progress.clear()
	active.clear()
	for id in QUESTS.keys():
		state[id] = "locked"
		progress[id] = _zeros(id)


func _zeros(id: String) -> Array:
	var arr: Array = []
	for _o in (QUESTS[id] as Dictionary)["objectives"]:
		arr.append(0)
	return arr


func title(id: String) -> String:
	return String((QUESTS.get(id, {}) as Dictionary).get("title", id))


func data(id: String) -> Dictionary:
	return (QUESTS.get(id, {}) as Dictionary)


func is_active(id: String) -> bool:
	return String(state.get(id, "locked")) == "active"


func is_done(id: String) -> bool:
	return String(state.get(id, "locked")) == "done"


func is_known(id: String) -> bool:
	return String(state.get(id, "locked")) != "locked"


func objective_count(id: String, index: int) -> int:
	var arr: Array = progress.get(id, [])
	return int(arr[index]) if index < arr.size() else 0


## Старт задания. false — уже начато/выполнено/нет такого.
func start(id: String) -> bool:
	if not QUESTS.has(id):
		return false
	if String(state.get(id, "locked")) != "locked":
		return false
	state[id] = "active"
	progress[id] = _zeros(id)
	active.append(id)
	quest_started.emit(id)
	GameState.log_message.emit("Новое задание: " + title(id), "quest")
	Sfx.ui("quest_new")
	_sync_collect(id)
	return true


## Сообщить о событии всем активным заданиям.
func notify(kind: String, target: String = "", amount: int = 1) -> void:
	for id in active.duplicate():
		_apply(id, kind, target, amount)


func _apply(id: String, kind: String, target: String, amount: int) -> void:
	var objectives: Array = (QUESTS[id] as Dictionary)["objectives"]
	var changed: bool = false
	for i in objectives.size():
		var o: Dictionary = objectives[i]
		if String(o["kind"]) != kind:
			continue
		if kind != "loot" and String(o["target"]) != target:
			continue
		var want: int = int(o["count"])
		var cur: int = int(progress[id][i])
		if cur >= want:
			continue
		progress[id][i] = mini(want, cur + amount)
		changed = true
		if int(progress[id][i]) >= want:
			objective_completed.emit(id, i)
	if changed:
		quest_updated.emit(id)
		_check_done(id)


## Для целей «собрать N» прогресс = сколько сейчас в сумке (+ надето).
func _sync_collect(id: String) -> void:
	var objectives: Array = (QUESTS[id] as Dictionary)["objectives"]
	for i in objectives.size():
		var o: Dictionary = objectives[i]
		if String(o["kind"]) != "collect":
			continue
		var have: int = GameState.count_total(String(o["target"]))
		progress[id][i] = mini(int(o["count"]), have)
	quest_updated.emit(id)
	_check_done(id)


func _check_done(id: String) -> void:
	if not is_active(id):
		return
	var objectives: Array = (QUESTS[id] as Dictionary)["objectives"]
	for i in objectives.size():
		if int(progress[id][i]) < int(objectives[i]["count"]):
			return
	complete(id)


## Досрочно закрыть задание (награда + следующий квест цепочки).
func complete(id: String) -> void:
	if not QUESTS.has(id) or is_done(id):
		return
	var d: Dictionary = QUESTS[id]
	state[id] = "done"
	active.erase(id)
	_grant(d.get("reward", {}))
	GameState.quests_done += 1
	quest_completed.emit(id)
	GameState.log_message.emit("Задание выполнено: " + title(id), "quest")
	Sfx.ui("quest_done")
	var nxt: String = String(d.get("next", ""))
	if nxt != "":
		start(nxt)


func _grant(reward: Dictionary) -> void:
	var money: int = int(reward.get("money", 0))
	if money > 0:
		GameState.add_money(money)
	var xp: float = float(reward.get("xp", 0))
	if xp > 0.0:
		GameState.add_xp(xp)
	for pair in reward.get("items", []):
		if pair.size() >= 2:
			GameState.add_item(String(pair[0]), int(pair[1]))


## Строки для трекера заданий на HUD.
func tracker_lines(limit: int = 4) -> Array:
	var out: Array = []
	for id in active:
		var objectives: Array = (QUESTS[id] as Dictionary)["objectives"]
		var text: String = ""
		for i in objectives.size():
			if int(progress[id][i]) < int(objectives[i]["count"]):
				text = "%s (%d/%d)" % [String(objectives[i]["text"]),
					int(progress[id][i]), int(objectives[i]["count"])]
				break
		if text == "" and objectives.size() > 0:
			text = "Вернуться с докладом"
		out.append({"id": id, "title": title(id), "text": text,
			"zone": String((QUESTS[id] as Dictionary).get("zone", ""))})
		if out.size() >= limit:
			break
	return out


## Данные для окна журнала.
func journal_entries() -> Array:
	var out: Array = []
	for id in QUESTS.keys():
		var st: String = String(state.get(id, "locked"))
		if st == "locked":
			continue
		var d: Dictionary = QUESTS[id]
		var lines: Array = []
		for i in (d["objectives"] as Array).size():
			var o: Dictionary = d["objectives"][i]
			lines.append({
				"text": String(o["text"]),
				"have": int(progress[id][i]),
				"want": int(o["count"]),
				"done": int(progress[id][i]) >= int(o["count"]),
			})
		out.append({
			"id": id, "title": title(id), "giver": String(d.get("giver", "")),
			"zone": String(d.get("zone", "")), "intro": String(d.get("intro", "")),
			"outro": String(d.get("outro", "")), "state": st, "objectives": lines,
			"side": bool(d.get("side", false)),
		})
	return out


## Текущее основное задание — для диалогов с NPC.
func main_current() -> String:
	for id in MAIN_CHAIN:
		if is_active(id):
			return id
	for id in MAIN_CHAIN:
		if not is_done(id):
			return id
	return ""


## Доступен ли сайд-квест (все основные до этого пройдены).
func side_available(id: String) -> bool:
	return String(state.get(id, "locked")) == "locked"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		pass


# ------------------------------------------------------------------ сохранение
func save_data() -> Dictionary:
	return {"state": state, "progress": progress, "active": Array(active)}


func restore_data(d: Variant) -> void:
	reset()
	if typeof(d) != TYPE_DICTIONARY:
		return
	var dd: Dictionary = d
	var st: Variant = dd.get("state", {})
	if typeof(st) == TYPE_DICTIONARY:
		for id in (st as Dictionary).keys():
			if QUESTS.has(String(id)):
				state[String(id)] = String((st as Dictionary)[id])
	var pr: Variant = dd.get("progress", {})
	if typeof(pr) == TYPE_DICTIONARY:
		for id in (pr as Dictionary).keys():
			if QUESTS.has(String(id)):
				var arr: Variant = (pr as Dictionary)[id]
				if typeof(arr) == TYPE_ARRAY:
					progress[String(id)] = arr
	var ac: Variant = dd.get("active", [])
	active.clear()
	if typeof(ac) == TYPE_ARRAY:
		for id in (ac as Array):
			if QUESTS.has(String(id)) and String(state.get(String(id), "")) == "active":
				active.append(String(id))




