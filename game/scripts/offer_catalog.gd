extends RefCounted

## Floor finds for one run. Numbers are the E2 contract.


static func all() -> Array[Dictionary]:
	return [
		{"id": "brick", "title": "Кирпич в рукаве", "detail": "+12 к удару", "damage": 12},
		{"id": "sweater", "title": "Второй свитер", "detail": "+25 к максимуму HP", "max_hp": 25, "heal": 25},
		{"id": "short_swing", "title": "Короткий замах", "detail": "удар чаще", "attack_cd_mult": 0.8},
		{"id": "another_brick", "title": "Ещё кирпич", "detail": "+8 к удару", "damage": 8},
		{"id": "tap_water", "title": "Вода из-под крана", "detail": "+20 к максимуму HP", "max_hp": 20, "fill": true},
		{"id": "slippers", "title": "Домашние тапки", "detail": "быстрее шаг", "speed_mult": 1.25},
		{"id": "habit", "title": "Привычка уходить", "detail": "шаг чаще", "dodge_cd": -0.20},
		{"id": "long_stride", "title": "Широкий шаг", "detail": "длиннее уход", "dodge_speed": 140.0},
		{"id": "hurry", "title": "Опаздываю", "detail": "ещё быстрее", "speed_mult": 1.15},
		{"id": "shoulder", "title": "Плечо уже ушло", "detail": "шаг чуть чаще", "dodge_cd": -0.15},
	]


static func get_by_id(id: String) -> Dictionary:
	for entry in all():
		if str(entry["id"]) == id:
			return entry
	return {}
