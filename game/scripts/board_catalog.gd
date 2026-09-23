class_name BoardCatalog
extends RefCounted

const TROLL_BODY := "не ходи в подъезд. после щитовой налево, там типа выход"
const HR_BODY := "раздел есть. тредов пока нет."
const QUIET_BODY := "пока тихо. кто спустится — напишите этаж"


static func threads_for(last_result: String, last_floors: int, last_kills: int) -> Array[Dictionary]:
	var truth_claim := _truth_claim(last_result, last_floors, last_kills)
	var lie_claim := _lie_claim(last_result, last_floors, last_kills)
	return [
		_thread("pod_truth", "/pod/", "кто вышел", _body_for(truth_claim), true, truth_claim),
		_thread("pod_lie", "/pod/", "он лёг", _body_for(lie_claim), true, lie_claim),
		_thread("pod_troll", "/pod/", "не ходи", TROLL_BODY, true, _none_claim()),
		_thread("hr_note", "/hr/", "раздел пуст", HR_BODY, false, _none_claim()),
	]


static func modifier_for(lead_id: String) -> Dictionary:
	match lead_id:
		"pod_truth":
			return {"damage": 6, "speed_mult": 1.0, "attack_cd_mult": 1.0, "label": "Сверился"}
		"pod_lie":
			return {"damage": 0, "speed_mult": 0.85, "attack_cd_mult": 1.0, "label": "Поверил"}
		"pod_troll":
			return {"damage": 0, "speed_mult": 1.0, "attack_cd_mult": 0.85, "label": "Пошёл всё равно"}
		_:
			return {"damage": 0, "speed_mult": 1.0, "attack_cd_mult": 1.0, "label": ""}


static func _thread(id: String, board: String, title: String, body: String, can_check: bool, claim: Dictionary) -> Dictionary:
	return {
		"id": id,
		"board": board,
		"title": title,
		"body": body,
		"can_check": can_check,
		"claims_result": str(claim["result"]),
		"claims_floors": int(claim["floors"]),
		"claims_kills": int(claim["kills"]),
	}


static func _none_claim() -> Dictionary:
	return {"result": "", "floors": -1, "kills": -1}


static func _truth_claim(last_result: String, last_floors: int, last_kills: int) -> Dictionary:
	if last_result != "extract" and last_result != "death":
		return _none_claim()
	return {"result": last_result, "floors": last_floors, "kills": last_kills}


static func _lie_claim(last_result: String, last_floors: int, last_kills: int) -> Dictionary:
	if last_result != "extract" and last_result != "death":
		var floors := 10 if last_floors == 9 else 9
		var kills := 33 if last_kills == 30 else 30
		return {"result": "extract", "floors": floors, "kills": kills}
	var opposite := "death" if last_result == "extract" else "extract"
	return {"result": opposite, "floors": last_floors + 1, "kills": last_kills + 3}


static func _body_for(claim: Dictionary) -> String:
	if str(claim["result"]) == "":
		return QUIET_BODY
	if str(claim["result"]) == "extract":
		return "вышел с %d. убито %d" % [int(claim["floors"]), int(claim["kills"])]
	return "лёг на %d. контактов %d" % [int(claim["floors"]), int(claim["kills"])]
