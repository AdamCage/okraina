extends Node

## Runtime state for the vertical slice. No disk save (S4).

const SCENE_APARTMENT := "res://scenes/apartment_hub.tscn"
const SCENE_ENTRANCE := "res://scenes/entrance.tscn"
const SCENE_RUN := "res://scenes/run_floor.tscn"
const SCENE_RESULT := "res://scenes/result_screen.tscn"

var player_hp: int = 100
var player_max_hp: int = 100
var kills: int = 0
var extracted_once: bool = false
var kitchen_door_unlocked: bool = false
var last_result: String = "" # "death" | "extract"
var zh_ek_notice: String = "В связи с повторным появлением лестничных площадок между 14-м и 15-м этажами просьба не оставлять там велосипеды."


func reset_run() -> void:
	player_hp = player_max_hp
	kills = 0


func go_apartment() -> void:
	reset_run()
	get_tree().call_deferred("change_scene_to_file", SCENE_APARTMENT)


func go_entrance() -> void:
	get_tree().call_deferred("change_scene_to_file", SCENE_ENTRANCE)


func go_run() -> void:
	reset_run()
	get_tree().call_deferred("change_scene_to_file", SCENE_RUN)


func finish_death() -> void:
	last_result = "death"
	get_tree().call_deferred("change_scene_to_file", SCENE_RESULT)


func finish_extract() -> void:
	last_result = "extract"
	extracted_once = true
	kitchen_door_unlocked = true
	get_tree().call_deferred("change_scene_to_file", SCENE_RESULT)
