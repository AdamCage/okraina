class_name DamageText
extends Node2D
## Всплывающие числа: урон, крит, лечение, радиация, опыт.
## Дёшево и безопасно: один Label, движение в _process, самоуничтожение через 0.9 с.
## Число одновременно живых подписей ограничено — старые гасятся первыми.
## Контракт: DamageText.spawn(parent, pos, amount, kind), DamageText.info(parent, pos, text).

## Само-ссылка через путь: глобальный кэш имён классов может быть не обновлён
## (headless-запуск не пересканирует проект), поэтому имя класса внутри файла
## использовать нельзя.
const SCRIPT_PATH := "res://scripts/damage_text.gd"

const MAX_ALIVE := 32
const LIFE := 0.9
const FONT_SIZE := 16
const FONT_SIZE_BIG := 22
const WIDTH := 140.0
const HEIGHT := 26.0

## Цвета по видам сообщения (kind: phys|crit|heal|rad|xp).
const COLORS: Dictionary = {
	"phys": Color(0.96, 0.28, 0.22),
	"crit": Color(1.0, 0.86, 0.25),
	"heal": Color(0.40, 0.92, 0.42),
	"rad": Color(0.78, 0.42, 0.98),
	"xp": Color(0.42, 0.86, 1.0),
	"info": Color(0.85, 0.86, 0.88),
}

var kind: String = "phys"
var life: float = 0.0             ## сколько уже живёт (используется и для «вытеснения»)
var rise: Vector2 = Vector2(0.0, -52.0)
var label: Label


func _ready() -> void:
	add_to_group("damage_text")
	z_index = 90
	set_process(true)


func _process(delta: float) -> void:
	life += delta
	var t: float = clampf(life / LIFE, 0.0, 1.0)
	# подъём с лёгким торможением
	position += rise * delta
	rise.y += 60.0 * delta
	# короткий «щелчок» масштаба в начале жизни
	scale = Vector2.ONE * (1.0 + 0.28 * maxf(0.0, 1.0 - t * 4.0))
	modulate.a = 1.0 if t < 0.55 else clampf(1.0 - (t - 0.55) / 0.45, 0.0, 1.0)
	if life >= LIFE:
		queue_free()


# ------------------------------------------------------------------ создание
## Число урона/лечения. kind: phys|crit|heal|rad|xp.
static func spawn(parent: Node, pos: Vector2, amount: float, kind: String = "phys") -> void:
	_make(parent, pos, _text_for(amount, kind), kind, kind == "crit")


## Текстовое сообщение в стиле «ПРОМАХ» / «БЛОК».
static func info(parent: Node, pos: Vector2, text: String) -> void:
	_make(parent, pos, text, "info", false)


static func _make(parent: Node, pos: Vector2, text: String, kind_id: String, big: bool) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	_trim(parent)
	var dt = _script().new()
	dt.kind = kind_id
	dt.z_as_relative = true
	parent.add_child(dt)
	dt.global_position = pos + Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
	dt.rise = Vector2(randf_range(-14.0, 14.0), randf_range(-56.0, -42.0))
	dt._build(text, Color(COLORS.get(kind_id, COLORS["info"])), big)


static func _script() -> GDScript:
	return load(SCRIPT_PATH) as GDScript


## Гасим самые старые подписи, если их стало слишком много (пул-безопасность).
## Уже поставленные в очередь на удаление не считаем — иначе пул «ползёт» вверх.
static func _trim(parent: Node) -> void:
	var texts: Array = []
	for c in parent.get_children():
		if c.is_in_group("damage_text") and not c.is_queued_for_deletion():
			texts.append(c)
	if texts.size() < MAX_ALIVE:
		return
	texts.sort_custom(func(a: Node, b: Node) -> bool:
		return float(a.get("life")) > float(b.get("life")))
	var free_count: int = mini(texts.size() - MAX_ALIVE + 1, texts.size())
	for i in free_count:
		(texts[i] as Node).queue_free()


func _build(text: String, col: Color, big: bool) -> void:
	label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(WIDTH, HEIGHT)
	label.position = Vector2(-WIDTH * 0.5, -HEIGHT * 0.5 - 16.0)
	var f: Font = Assets.font_body if Assets.font_body != null else ThemeDB.fallback_font
	label.add_theme_font_override("font", f)
	label.add_theme_font_size_override("font_size", FONT_SIZE_BIG if big else FONT_SIZE)
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	add_child(label)


static func _text_for(amount: float, kind: String) -> String:
	var a: float = absf(amount)
	var s: String = str(int(round(a))) if a >= 10.0 else ("%.1f" % a)
	match kind:
		"heal":
			return "+" + s
		"rad":
			return "+" + s + " РАД"
		"xp":
			return "+" + s + " ОП"
		"crit":
			return s + "!"
		_:
			return s
