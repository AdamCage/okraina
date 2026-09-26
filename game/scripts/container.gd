class_name LootContainer
extends StaticBody2D
## Обыскиваемый контейнер (ящик, бочка, труп, сейф). Блокирует движение,
## но доступен для взаимодействия (слой world 1 + interact 32).
## Имя LootContainer — чтобы не конфликтовать с нативным классом Container.

const PROPS_BY_KIND := {
	"crate": ["crate_wood", "crate_metal"],
	"barrel": ["barrel_rust", "barrel_toxic"],
	"sack": ["crate_wood"],
	"safe": ["crate_metal"],
}

## Таблицы дропа: [id, count_min, count_max, chance]
const TABLES := {
	1: [
		["scrap", 1, 3, 0.55], ["bandage", 1, 2, 0.45], ["ammo_9x18", 8, 20, 0.5],
		["bread", 1, 1, 0.3], ["canned", 1, 1, 0.25], ["bolts", 3, 6, 0.2],
	],
	2: [
		["ammo_9x18", 10, 30, 0.55], ["ammo_545", 10, 30, 0.4], ["bandage", 2, 4, 0.4],
		["medkit", 1, 1, 0.3], ["vodka", 1, 2, 0.3], ["scrap", 2, 5, 0.4],
		["docs", 1, 1, 0.35], ["armor_leather", 1, 1, 0.08], ["tools", 1, 1, 0.12],
	],
	3: [
		["ammo_545", 20, 60, 0.6], ["ammo_12ga", 6, 16, 0.4], ["medkit", 1, 2, 0.45],
		["antidote", 1, 2, 0.3], ["armor_plate", 1, 1, 0.12], ["helmet", 1, 1, 0.12],
		["detector", 1, 1, 0.08], ["key_underground", 1, 1, 0.25],
		["artifact_flower", 1, 1, 0.1], ["scrap", 3, 8, 0.5],
	],
}

var tier: int = 1
var kind: String = "crate"
var opened: bool = false
var guaranteed: Array = []


func setup(container_tier: int, container_kind: String = "crate") -> void:
	tier = clampi(container_tier, 1, 3)
	kind = container_kind
	if is_inside_tree():
		_build_visual()


func _ready() -> void:
	add_to_group("containers")
	collision_layer = 1 | 32
	collision_mask = 0
	_build_visual()



func _build_visual() -> void:
	for c in get_children():
		c.queue_free()
	var names: Array = PROPS_BY_KIND.get(kind, ["crate_wood"])
	var pick: String = String(names[randi() % names.size()])
	if not Assets.has_sprite(pick):
		pick = "crate_wood"
	var tex: Texture2D = Assets.sprite(pick)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.name = "Visual"
	add_child(sprite)
	if not Assets.has_sprite(pick):
		var fallback := ColorRect.new()
		fallback.color = Color(0.45, 0.33, 0.22)
		fallback.size = Vector2(40, 34)
		fallback.position = Vector2(-20, -30)
		add_child(fallback)
	var size: Vector2 = tex.get_size() if Assets.has_sprite(pick) else Vector2(40, 34)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(maxf(22.0, size.x * 0.75), maxf(16.0, size.y * 0.42))
	shape.shape = box
	shape.position = Vector2(0, -box.size.y * 0.4)
	add_child(shape)
	var area := Area2D.new()          # зона наведения/подсказки
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	var asize := CollisionShape2D.new()
	var acircle := CircleShape2D.new()
	acircle.radius = 46.0
	asize.shape = acircle
	area.add_child(asize)
	add_child(area)


## Открыть контейнер: высыпает лут рядом. false — уже пусто.
func open(player: Node = null) -> bool:
	if opened:
		if player != null:
			Sfx.ui("ui_deny")
		return false
	opened = true
	var drops: Array = []
	for row in guaranteed:
		drops.append([String(row), 1])
	for row in TABLES.get(tier, []):
		var chance: float = float(row[3])
		if randf() <= chance:
			var cmin: int = int(row[1])
			var cmax: int = int(row[2])
			var cnt: int = randi_range(cmin, cmax)
			if ItemDB.kind_of(String(row[0])) == ItemDB.Kind.ARTIFACT and cnt > 1:
				cnt = 1
			drops.append([String(row[0]), cnt])
	if drops.is_empty():
		drops.append(["scrap", 1])
	for d in drops:
		Loot.spawn_drop(get_parent(), global_position + Vector2(0, 6), String(d[0]), int(d[1]))
	Sfx.play("ui_open", global_position)
	GameState.containers_looted += 1
	Quests.notify("loot", "", 1)
	var vis := get_node_or_null("Visual") as Sprite2D
	if vis != null:
		vis.modulate = Color(0.62, 0.58, 0.52)
	return true


## Гарантированный предмет (квестовый ключ, документы и т.п.).
func add_guaranteed(id: String) -> void:
	if id != "" and not guaranteed.has(id):
		guaranteed.append(id)


func interact_hint() -> String:
	return "Пусто" if opened else "Обыскать"
