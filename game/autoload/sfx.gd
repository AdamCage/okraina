extends Node
## Звук: пул позиционных плееров, UI-плеер, эмбиент и музыка с плавными
## переходами, «слой опасности». Автолоад Sfx — API: play/ui/ambient/music.

const POOL_SIZE := 16
const PITCH_VAR := 0.06

var _pool: Array = []
var _ui_player: AudioStreamPlayer
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _amb_use_a: bool = true
var _amb_danger: AudioStreamPlayer
var _mus: AudioStreamPlayer
var _step_counter: int = 0

var vol_master: float = 0.9
var vol_sfx: float = 1.0
var vol_amb: float = 0.75
var vol_mus: float = 0.45
var muted: bool = false
var current_ambient: String = ""
var current_music: String = ""
var danger_level: float = 0.0


func _ready() -> void:
	_create_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer2D.new()
		p.bus = "SFX"
		p.max_distance = 2600.0
		p.attenuation = 0.8
		p.panning_strength = 0.9
		add_child(p)
		_pool.append(p)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "UI"
	add_child(_ui_player)
	for s in 3:
		var amb := AudioStreamPlayer.new()
		amb.bus = "Ambient"
		amb.volume_db = -80.0
		add_child(amb)
		if s == 0:
			_amb_a = amb
		elif s == 1:
			_amb_b = amb
		else:
			_amb_danger = amb
	_mus = AudioStreamPlayer.new()
	_mus.bus = "Music"
	add_child(_mus)
	_apply_volumes()


func _create_buses() -> void:
	var layout: int = AudioServer.bus_count
	var wanted := {"SFX": "Master", "UI": "Master", "Ambient": "Master", "Music": "Master"}
	for bus_name in wanted.keys():
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, String(wanted[bus_name]))
			AudioServer.set_bus_volume_db(idx, 0.0)
		if layout > 1:
			pass


func _apply_volumes() -> void:
	AudioServer.set_bus_mute(0, muted)
	_set_bus("SFX", vol_sfx)
	_set_bus("UI", vol_sfx)
	_set_bus("Ambient", vol_amb)
	_set_bus("Music", vol_mus)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, vol_master)))


func _set_bus(bus_name: String, v: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.001, v)))


# ------------------------------------------------------------------ эффекты
## Позиционный звук. pos == Vector2.INF — играть без панорамы (на игроке).
func play(name: String, pos: Variant = Vector2.INF, volume_db: float = 0.0,
		pitch: float = 1.0) -> void:
	var stream: AudioStream = Assets.sound(name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = clampf(pitch * randf_range(1.0 - PITCH_VAR, 1.0 + PITCH_VAR), 0.5, 2.0)
			p.volume_db = volume_db
			if typeof(pos) == TYPE_VECTOR2 and (pos as Vector2).is_finite():
				p.global_position = pos
			else:
				p.global_position = Vector2.ZERO
			p.play()
			return


## Звук интерфейса (без позиционирования, короткий).
func ui(name: String, pitch: float = 1.0) -> void:
	var stream: AudioStream = Assets.sound(name)
	if stream == null or _ui_player == null:
		return
	_ui_player.stream = stream
	_ui_player.pitch_scale = pitch
	_ui_player.play()


## Шаг игрока: чередуем варианты, чтобы не было «пулемёта».
func step(surface: String = "gravel") -> void:
	_step_counter += 1
	var names: PackedStringArray = PackedStringArray()
	match surface:
		"metal": names = PackedStringArray(["step_metal_1", "step_metal_1"])
		"grass": names = PackedStringArray(["step_grass_1", "step_grass_2"])
		_: names = PackedStringArray(["step_gravel_1", "step_gravel_2", "step_gravel_3"])
	var n: String = names[_step_counter % names.size()]
	play(n, Vector2.INF, -8.0, randf_range(0.92, 1.08))


# ------------------------------------------------------------------ эмбиент
## Плавно переключить фоновый эмбиент (имя без расширения).
func ambient(name: String, fade: float = 2.0) -> void:
	if current_ambient == name:
		return
	var stream: AudioStream = Assets.sound(name)
	current_ambient = name
	var target: AudioStreamPlayer = _amb_b if _amb_use_a else _amb_a
	var old: AudioStreamPlayer = _amb_a if _amb_use_a else _amb_b
	_amb_use_a = not _amb_use_a
	if stream != null:
		target.stream = stream
		target.volume_db = -80.0
		target.play()
		var tw := create_tween()
		tw.tween_property(target, "volume_db", -8.0, fade)
	if old.playing:
		var tw2 := create_tween()
		tw2.tween_property(old, "volume_db", -80.0, fade)
		tw2.tween_callback(old.stop)


func ambient_stop(fade: float = 2.0) -> void:
	current_ambient = ""
	for a in [_amb_a, _amb_b]:
		if a.playing:
			var tw := create_tween()
			tw.tween_property(a, "volume_db", -80.0, fade)
			tw.tween_callback(a.stop)


## 0..1 — «тревожный» слой (рядом враги/аномалия).
func set_danger(value: float, fade: float = 1.0) -> void:
	danger_level = clampf(value, 0.0, 1.0)
	var want: float = linear_to_db(maxf(0.001, danger_level)) if danger_level > 0.02 else -80.0
	if danger_level > 0.02 and not _amb_danger.playing:
		var stream: AudioStream = Assets.sound("amb_danger_loop")
		if stream != null:
			_amb_danger.stream = stream
			_amb_danger.volume_db = -80.0
			_amb_danger.play()
	if _amb_danger.playing:
		var tw := create_tween()
		tw.tween_property(_amb_danger, "volume_db", want, fade)


func music(name: String, fade: float = 3.0) -> void:
	if current_music == name:
		return
	current_music = name
	var stream: AudioStream = Assets.sound(name)
	if stream == null:
		return
	_mus.stream = stream
	if _mus.playing:
		var tw := create_tween()
		tw.tween_property(_mus, "volume_db", -80.0, fade * 0.5)
		tw.tween_callback(_mus.play)
		tw.tween_property(_mus, "volume_db", -6.0, fade * 0.5)
	else:
		_mus.volume_db = -80.0
		_mus.play()
		var tw2 := create_tween()
		tw2.tween_property(_mus, "volume_db", -6.0, fade)


func stop_all() -> void:
	for p in _pool:
		p.stop()
	if _ui_player != null:
		_ui_player.stop()
	ambient_stop(0.4)
	if _mus.playing:
		_mus.stop()
	current_music = ""

