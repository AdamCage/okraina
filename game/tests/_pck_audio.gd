## Проба: доступны ли звуки ВНУТРИ собранного пака (web-сборка).
## Запуск по проекту:  godot --headless --path . -s res://tests/_pck_audio.gd
## Запуск по паку:     godot --headless --main-pack build/web/index.pck -s res://tests/_pck_audio.gd
extends SceneTree

const NAMES: Array[String] = [
	"amb_cave_loop", "amb_danger_loop", "amb_wind_loop", "amb_zone_loop",
	"anomaly_hum", "anomaly_warp", "anomaly_zap", "artifact_hum", "artifact_taken",
	"boar_snort", "breath_loop", "creature_die", "detector_ping", "dog_bark",
	"dog_growl", "explosion", "geiger_burst", "geiger_click", "heartbeat_loop",
	"hit_flesh", "hit_wall", "levelup", "melee_hit", "melee_swing",
	"mus_menu_loop", "mus_raid_loop", "mutant_roar", "notify", "pickup_artefact",
	"pickup_item", "player_die", "player_hurt", "quest_done", "quest_new",
	"shot_ak", "shot_crossbow", "shot_pm", "shot_shotgun", "step_grass_1",
	"step_grass_2", "step_gravel_1", "step_gravel_2", "step_gravel_3",
	"step_metal_1", "ui_click", "ui_close", "ui_deny", "ui_open", "zombie_moan",
]


func _initialize() -> void:
	print("[probe] драйвер звука: ", AudioServer.get_driver_name())
	var ok: int = 0
	var miss: Array[String] = []
	for n in NAMES:
		var path: String = "res://assets/audio/" + n + ".wav"
		if not ResourceLoader.exists(path):
			miss.append(n + " (нет ресурса)")
			continue
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			miss.append(n + " (load -> null)")
		else:
			ok += 1
	print("[probe] загружено звуков: ", ok, " из ", NAMES.size())
	for m in miss:
		print("[probe] НЕТ: ", m)
	print("[probe] файлов в res://assets/audio: ", _count("res://assets/audio"))
	print("[probe] файлов в res://.godot/imported: ", _count("res://.godot/imported"))
	var wave: AudioStream = load("res://assets/audio/mus_menu_loop.wav") as AudioStream
	if wave != null:
		print("[probe] mus_menu_loop: длина ", wave.get_length(), " с")
	for n in ["ui_click", "mus_menu_loop", "shot_ak", "amb_zone_loop", "player_die"]:
		_data_report(n)
	quit(0)


func _data_report(name: String) -> void:
	var s := load("res://assets/audio/" + name + ".wav") as AudioStreamWAV
	if s == null:
		print("[probe] ", name, ": load -> null")
		return
	var peak: int = 0
	var step: int = 1 if s.format == AudioStreamWAV.FORMAT_8_BITS else 2
	if s.data.size() > 0:
		var i: int = 0
		while i < mini(s.data.size(), 60000):
			if step == 1:
				peak = maxi(peak, absi(s.data[i] - 128))
			else:
				peak = maxi(peak, absi(s.data.decode_s16(i)))
			i += step
	print("[probe] ", name, ": data=", s.data.size(), " Б, длина=", snappedf(s.get_length(), 0.01),
		" с, формат=", s.format, ", rate=", s.mix_rate, ", пик первых сэмплов=", peak)


func _count(path: String) -> int:
	var dir := DirAccess.open(path)
	return -1 if dir == null else dir.get_files().size()
