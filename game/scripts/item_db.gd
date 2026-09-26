class_name ItemDB
extends RefCounted
## Статическая база предметов Зоны. Никаких .tres — только словари, чтобы
## правки были текстовыми и не ломали бинарные ресурсы.

enum Kind { WEAPON, AMMO, ARMOR, HELMET, MED, FOOD, ARTIFACT, MISC, QUEST }

## Поля предмета:
##   name/desc — русские строки, icon — имя спрайта в assets/ui без ".png",
##   kind, weight, value (руб.), stack (макс. в слоте).
## Оружие: dmg, rate (выстр/с), spread (рад), gun_range (px), mag, caliber,
##          auto (bool), sfx, speed (px/с), mode ("melee"/"gun").
## Броня:  armor (%), hp_bonus, radiation (защита от радиации).
## Аптечки/еда: heal, stamina, rad_heal.
## Артефакты: эффект + radiation (фон).
const ITEMS: Dictionary = {
	"knife": {
		"name": "Нож охотничий", "kind": Kind.WEAPON, "icon": "icon_knife",
		"desc": "Потёртая сталь. Тихо, быстро, почти бесплатно.",
		"weight": 0.6, "value": 120, "stack": 1,
		"mode": "melee", "dmg": 24.0, "rate": 2.2, "reach": 62.0, "sfx": "melee_swing",
	},
	"pm": {
		"name": "ПМ", "kind": Kind.WEAPON, "icon": "icon_pm",
		"desc": "Старый добрый пистолет Макарова. Надёжен, пока есть патроны.",
		"weight": 1.2, "value": 900, "stack": 1,
		"mode": "gun", "dmg": 18.0, "rate": 4.0, "spread": 0.05, "gun_range": 520.0,
		"mag": 8, "caliber": "9x18", "auto": false, "sfx": "shot_pm", "speed": 1400.0,
	},
	"ak": {
		"name": "АК-74", "kind": Kind.WEAPON, "icon": "icon_ak",
		"desc": "Автомат. Бьёт далеко и зло, но кушает патрон за патроном.",
		"weight": 3.8, "value": 4200, "stack": 1,
		"mode": "gun", "dmg": 22.0, "rate": 9.0, "spread": 0.075, "gun_range": 720.0,
		"mag": 30, "caliber": "5.45", "auto": true, "sfx": "shot_ak", "speed": 1700.0,
	},
	"shotgun": {
		"name": "Обрез", "kind": Kind.WEAPON, "icon": "icon_shotgun",
		"desc": "Два ствола, четыре метра и много шума. В упор — в клочья.",
		"weight": 3.0, "value": 3100, "stack": 1,
		"mode": "gun", "dmg": 56.0, "rate": 1.1, "spread": 0.18, "gun_range": 300.0,
		"mag": 2, "caliber": "12ga", "auto": false, "sfx": "shot_shotgun", "speed": 1200.0,
		"pellets": 5,
	},
	"crossbow": {
		"name": "Арбалет", "kind": Kind.WEAPON, "icon": "icon_crossbow",
		"desc": "Бесконечные болты, мертвая тишина. Медленно, зато никто не придёт на звук.",
		"weight": 2.4, "value": 2600, "stack": 1,
		"mode": "gun", "dmg": 38.0, "rate": 0.9, "spread": 0.02, "gun_range": 640.0,
		"mag": 1, "caliber": "bolt", "auto": false, "sfx": "shot_crossbow", "speed": 900.0,
		"recoverable": true,
	},
	"ammo_9x18": {
		"name": "Патроны 9x18", "kind": Kind.AMMO, "icon": "icon_ammo_9x18",
		"desc": "Коробка пистолетных патронов.", "weight": 0.02, "value": 12,
		"stack": 240, "caliber": "9x18", "count": 30,
	},
	"ammo_545": {
		"name": "Патроны 5.45", "kind": Kind.AMMO, "icon": "icon_ammo_545",
		"desc": "Автоматные патроны в обойме.", "weight": 0.03, "value": 22,
		"stack": 300, "caliber": "5.45", "count": 30,
	},
	"ammo_12ga": {
		"name": "Патроны 12х70", "kind": Kind.AMMO, "icon": "icon_ammo_12ga",
		"desc": "Картечь. Дорогая, но убедительная.", "weight": 0.06, "value": 45,
		"stack": 120, "caliber": "12ga", "count": 12,
	},
	"bolts": {
		"name": "Болты", "kind": Kind.AMMO, "icon": "icon_bolt",
		"desc": "Короткие арбалетные болты с оперением.", "weight": 0.04, "value": 30,
		"stack": 90, "caliber": "bolt", "count": 10,
	},

	# ---------------------------------------------------------- броня
	"armor_leather": {
		"name": "Куртка сталкера", "kind": Kind.ARMOR, "icon": "icon_armor_leather",
		"desc": "Кожанка с бронепластинами. Держит когти, но не пулю.",
		"weight": 4.0, "value": 1500, "stack": 1,
		"armor": 8.0, "hp_bonus": 10.0, "radiation": 0.0, "speed": 1.0,
	},
	"armor_plate": {
		"name": "Комбинезон «Заря»", "kind": Kind.ARMOR, "icon": "icon_armor_plate",
		"desc": "Тяжёлый комбинезон с керамикой. Тяжёлый, зато живой.",
		"weight": 9.0, "value": 6400, "stack": 1,
		"armor": 22.0, "hp_bonus": 30.0, "radiation": 12.0, "speed": 0.94,
	},
	"armor_exo": {
		"name": "Экзоскелет «Буревестник»", "kind": Kind.ARMOR, "icon": "icon_armor_exo",
		"desc": "Гидравлика, броня, радость. Требует снабжения и ремонта.",
		"weight": 18.0, "value": 18000, "stack": 1,
		"armor": 38.0, "hp_bonus": 60.0, "radiation": 25.0, "speed": 1.05,
	},
	"helmet": {
		"name": "Шлем «Сфера»", "kind": Kind.HELMET, "icon": "icon_helmet",
		"desc": "Противогаз с бронёй. Фильтры давно не новые.",
		"weight": 2.2, "value": 2200, "stack": 1,
		"armor": 6.0, "hp_bonus": 0.0, "radiation": 18.0,
	},

	# ---------------------------------------------------------- медицина и еда
	"medkit": {
		"name": "Аптечка", "kind": Kind.MED, "icon": "icon_medkit",
		"desc": "Армейская аптечка: жгут, промедол, бинты. Ставит на ноги.",
		"weight": 1.0, "value": 800, "stack": 8, "heal": 60.0, "stamina": 10.0,
	},
	"bandage": {
		"name": "Бинт", "kind": Kind.MED, "icon": "icon_bandage",
		"desc": "Останавливает кровь. Всё, что он умеет.",
		"weight": 0.2, "value": 120, "stack": 16, "heal": 22.0,
	},
	"antidote": {
		"name": "Антирад", "kind": Kind.MED, "icon": "icon_antidote",
		"desc": "Порошок от радиации. Горький, как сама Зона.",
		"weight": 0.3, "value": 500, "stack": 10, "rad_heal": 45.0,
	},
	"vodka": {
		"name": "Водка", "kind": Kind.FOOD, "icon": "icon_vodka",
		"desc": "Народное средство от облучения и плохих мыслей.",
		"weight": 0.5, "value": 200, "stack": 10, "heal": 6.0, "rad_heal": 18.0,
	},
	"canned": {
		"name": "Тушёнка", "kind": Kind.FOOD, "icon": "icon_canned",
		"desc": "Банка неизвестного года выпуска. Съедобно.",
		"weight": 0.4, "value": 150, "stack": 12, "heal": 14.0, "stamina": 20.0,
	},
	"bread": {
		"name": "Хлеб", "kind": Kind.FOOD, "icon": "icon_bread",
		"desc": "Чёрствый, но свой.", "weight": 0.3, "value": 60, "stack": 12,
		"heal": 8.0, "stamina": 12.0,
	},
	"energy_drink": {
		"name": "Энергетик", "kind": Kind.FOOD, "icon": "icon_energy_drink",
		"desc": "Газировка с кофеином. Силы вернутся мгновенно.",
		"weight": 0.4, "value": 260, "stack": 8, "stamina": 60.0,
	},

	# ---------------------------------------------------------- гаджеты
	"flashlight": {
		"name": "Фонарь", "kind": Kind.MISC, "icon": "icon_flashlight",
		"desc": "Тактический фонарь. Свет — жизнь и метка для всех сразу.",
		"weight": 0.5, "value": 700, "stack": 1, "equip": "light",
	},
	"detector": {
		"name": "Детектор «Отклик»", "kind": Kind.MISC, "icon": "icon_detector",
		"desc": "Пищит на артефакты. Чем ближе — тем злее.",
		"weight": 1.1, "value": 5200, "stack": 1, "equip": "detector",
	},
	"binocular": {
		"name": "Бинокль", "kind": Kind.MISC, "icon": "icon_binocular",
		"desc": "Разглядеть горизонт и не подходить ближе, чем нужно.",
		"weight": 0.9, "value": 1800, "stack": 1, "equip": "zoom",
	},
	"radio": {
		"name": "Рация", "kind": Kind.MISC, "icon": "icon_radio",
		"desc": "Хрипит на всех частотах Зоны.", "weight": 1.0, "value": 1400, "stack": 1,
	},
	"geiger": {
		"name": "Дозиметр", "kind": Kind.MISC, "icon": "icon_geiger",
		"desc": "Щёлкает. Когда щёлкает часто — беги.", "weight": 0.4,
		"value": 900, "stack": 1, "equip": "geiger",
	},
	"scrap": {
		"name": "Хлам", "kind": Kind.MISC, "icon": "icon_scrap",
		"desc": "Ржавые железяки. Бармен такое берёт.", "weight": 0.5,
		"value": 40, "stack": 50,
	},
	"tools": {
		"name": "Инструменты", "kind": Kind.MISC, "icon": "icon_tools",
		"desc": "Ключи, отвёртки, проволока. Иногда спасают.",
		"weight": 1.5, "value": 600, "stack": 1,
	},
	"docs": {
		"name": "Документы", "kind": Kind.QUEST, "icon": "icon_docs",
		"desc": "Помятые бумаги с печатями. Кто-то за них заплатит.",
		"weight": 0.1, "value": 0, "stack": 10, "quest": true,
	},
	"key_underground": {
		"name": "Ключ от бункера", "kind": Kind.QUEST, "icon": "icon_key",
		"desc": "Тяжёлый ключ с биркой. Пахнет мазутом.",
		"weight": 0.2, "value": 0, "stack": 1, "quest": true,
	},

	# ---------------------------------------------------------- артефакты
	"artifact_medusa": {
		"name": "«Медуза»", "kind": Kind.ARTIFACT, "icon": "icon_artifact_medusa",
		"desc": "Холодный синий комок. Гасит радиацию вокруг тела.",
		"weight": 1.0, "value": 9000, "stack": 4, "rad_resist": 40.0,
	},
	"artifact_flower": {
		"name": "«Цветок»", "kind": Kind.ARTIFACT, "icon": "icon_artifact_flower",
		"desc": "Тёплый, почти живой. Зарубцовывает раны на глазах.",
		"weight": 1.0, "value": 8500, "stack": 4, "regen": 1.2, "radiation": 3.0,
	},
	"artifact_soul": {
		"name": "«Душа»", "kind": Kind.ARTIFACT, "icon": "icon_artifact_soul",
		"desc": "Тускло мерцает. Поднимает силы и скорость.",
		"weight": 1.0, "value": 7000, "stack": 4, "stamina_regen": 4.0,
		"speed": 1.06, "radiation": 4.0,
	},
	"artifact_moonlight": {
		"name": "«Ночная звезда»", "kind": Kind.ARTIFACT, "icon": "icon_artifact_moonlight",
		"desc": "Светится жёлтым. Режет тьму и немного лечит.",
		"weight": 1.0, "value": 11000, "stack": 4, "light": 1.0, "regen": 0.4,
		"radiation": 5.0,
	},
	"artifact_fruit": {
		"name": "«Плод»", "kind": Kind.ARTIFACT, "icon": "icon_artifact_fruit",
		"desc": "Оранжевый, тяжёлый, тёплый. Прибавляет здоровья.",
		"weight": 1.0, "value": 9800, "stack": 4, "hp_bonus": 25.0, "radiation": 6.0,
	},
	"artifact_grav": {
		"name": "«Гравиконцентрат»", "kind": Kind.ARTIFACT, "icon": "icon_artifact_grav",
		"desc": "Почти невесомый, но тянет к земле с чужой силой.",
		"weight": 1.0, "value": 14000, "stack": 4, "armor": 10.0, "radiation": 8.0,
	},
}

## ---------------------------------------------------------------- утилиты
static func has(id: String) -> bool:
	return ITEMS.has(id)

## Копия описания предмета (нельзя случайно испортить базу).
static func get_item(id: String) -> Dictionary:
	if not ITEMS.has(id):
		return {}
	var d: Dictionary = (ITEMS[id] as Dictionary).duplicate(true)
	d["id"] = id
	return d

static func all_ids() -> Array:
	return ITEMS.keys()

static func icon(id: String) -> String:
	return String((ITEMS.get(id, {}) as Dictionary).get("icon", "icon_scrap"))

static func kind_of(id: String) -> int:
	return int((ITEMS.get(id, {}) as Dictionary).get("kind", Kind.MISC))

static func kind_name(kind: int) -> String:
	match kind:
		Kind.WEAPON: return "Оружие"
		Kind.AMMO: return "Патроны"
		Kind.ARMOR: return "Броня"
		Kind.HELMET: return "Шлем"
		Kind.MED: return "Медицина"
		Kind.FOOD: return "Провизия"
		Kind.ARTIFACT: return "Артефакт"
		Kind.QUEST: return "Квест"
		_: return "Прочее"

static func display_name(id: String) -> String:
	return String((ITEMS.get(id, {}) as Dictionary).get("name", id))

static func max_stack(id: String) -> int:
	return int((ITEMS.get(id, {}) as Dictionary).get("stack", 1))

static func weight(id: String) -> float:
	return float((ITEMS.get(id, {}) as Dictionary).get("weight", 0.0))

static func value(id: String) -> int:
	return int((ITEMS.get(id, {}) as Dictionary).get("value", 0))

static func is_equipable(id: String) -> bool:
	var k: int = kind_of(id)
	return k == Kind.WEAPON or k == Kind.ARMOR or k == Kind.HELMET

## Список расходуемых (можно «применить»).
static func is_usable(id: String) -> bool:
	var k: int = kind_of(id)
	return k == Kind.MED or k == Kind.FOOD or k == Kind.ARTIFACT


