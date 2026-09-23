class_name FloorPreset
extends Resource

@export var id: String = ""
@export var zone: String = ""
@export var title: String = ""
@export var bg: Color = Color(0.16, 0.17, 0.19)
@export var player_spawn: Vector2 = Vector2(160, 360)
@export var exit_pos: Vector2 = Vector2(1120, 120)
@export var obstacles: Array[Rect2] = []
@export var spawn_points: PackedVector2Array = PackedVector2Array()
@export var spawn_kinds: PackedStringArray = PackedStringArray()
