class_name NoticeCatalog
extends RefCounted

const EXTRACT: Array[String] = ["bikes", "elevator", "pot"]
const DEATH: Array[String] = ["boxes", "bulb", "seal"]


static func pick(last_result: String, last_floors: int, last_kills: int) -> Dictionary:
	var pool: Array[String] = []
	if last_result == "extract":
		pool = EXTRACT
	elif last_result == "death":
		pool = DEATH
	if pool.is_empty():
		return {"id": "", "text": "", "damage": 0, "speed_mult": 1.0}
	var id := pool[(last_floors + last_kills) % 3]
	var effect := effect_for(id)
	return {
		"id": id,
		"text": text_for(id, last_floors, last_kills),
		"damage": int(effect["damage"]),
		"speed_mult": float(effect["speed_mult"]),
	}


static func effect_for(notice_id: String) -> Dictionary:
	match notice_id:
		"bikes", "elevator", "boxes":
			return {"damage": 0, "speed_mult": 0.9}
		"pot", "bulb", "seal":
			return {"damage": 8, "speed_mult": 1.0}
		_:
			return {"damage": 0, "speed_mult": 1.0}


static func text_for(notice_id: String, last_floors: int, last_kills: int) -> String:
	match notice_id:
		"bikes":
			return "УК: с этажа %d вынесли велосипед. На следующий заход не перегружайте себя. Контактов: %d" % [last_floors, last_kills]
		"elevator":
			return "УК: лифт с этажа %d снова не доезжает. Ходить пешком. Зафиксировано: %d" % [last_floors, last_kills]
		"pot":
			return "УК: по акту с этажа %d на время без воды выдана кастрюля. Контактов: %d" % [last_floors, last_kills]
		"boxes":
			return "Акт: потеря связи на этаже %d. Коробки на площадке делают ношу тяжелее. Контактов: %d" % [last_floors, last_kills]
		"bulb":
			return "Акт: на этаже %d погасли лампы. Жильцу оставлен запасной фонарь. Контактов: %d" % [last_floors, last_kills]
		"seal":
			return "Акт: пломба на этаже %d сорвана. До ремонта можно взять монтировку. Контактов: %d" % [last_floors, last_kills]
		_:
			return ""
