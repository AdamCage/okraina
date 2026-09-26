class_name Loot
extends Area2D
## Предмет на земле. Подбирается сенсором игрока (слой loot = 16) или по F.
## Слои: collision_layer = 16 (loot), mask = 0 — сам ничего не ищет.

const ICON_SIZE := 34.0
const LIFETIME := 600.0     ## сек до исчезновения (чтобы мир не засорялся)

var item_id: String = ""
var item_count: int = 1
var pickup_hint: String = ""
var _sprite: Sprite2D
var _label: Label
var _age: float = 0.0
var _bob: float = 0.0


## Единственный способ создать дроп — статическая фабрика.
static func spawn_drop(parent: Node, pos: Vector2, id: String, count: int = 1) -> Loot:
	if parent == null or id == "" or count <= 0:
		return null
	var l := Loot.new()
	l.item_id = id
	l.item_count = count
	parent.add_child(l)
	l.global_position = pos + Vector2(randf_range(-12.0, 12.0), randf_range(-10.0, 10.0))
	return l


func _ready() -> void:
	add_to_group("loot")
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = Assets.ui(ItemDB.icon(item_id))
	_sprite.scale = Vector2.ONE * (ICON_SIZE / maxf(1.0, _sprite.texture.get_width()))
	add_child(_sprite)
	if item_count > 1:
		_label = Label.new()
		_label.text = "x%d" % item_count
		_label.add_theme_font_size_override("font_size", 13)
		_label.position = Vector2(8, 10)
		_label.modulate = Color(1.0, 0.95, 0.75)
		add_child(_label)
	pickup_hint = ItemDB.display_name(item_id)
	# лёгкое свечение для заметности в темноте
	if ItemDB.kind_of(item_id) == ItemDB.Kind.ARTIFACT:
		var light := PointLight2D.new()
		light.texture = _radial_texture()
		light.color = Color(0.55, 0.85, 1.0)
		light.energy = 0.9
		light.texture_scale = 0.34
		add_child(light)
	set_process(true)


func _process(delta: float) -> void:
	_age += delta
	_bob += delta
	if _sprite != null:
		_sprite.position.y = sin(_bob * 2.2) * 2.2
	if _age > LIFETIME:
		queue_free()


## Подобрать. false — нет места в сумке.
func pick_up(player: Node = null) -> bool:
	if not GameState.add_item(item_id, item_count, true):
		if player != null:
			GameState.log_message.emit("Сумка переполнена", "bad")
			Sfx.ui("ui_deny")
		return false
	if ItemDB.kind_of(item_id) == ItemDB.Kind.ARTIFACT:
		Sfx.play("pickup_artefact", global_position)
		GameState.artifacts_found += 1
	else:
		Sfx.play("pickup_item", global_position)
	queue_free()
	return true


func _radial_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d: float = Vector2(x - 32, y - 32).length() / 32.0
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
