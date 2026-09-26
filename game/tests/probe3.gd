extends SceneTree

## API probe #3 — occlusion layers, environment glow, misc — run:
## tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/probe3.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_dump_methods("TileSet", ["add_occlusion_layer", "set_occlusion_layer_light_mask"])
	_dump_methods("TileData", ["set_occluder", "get_occluder"])
	_dump_methods("Environment", ["set_glow_enabled"])
	_dump_methods("Camera2D", ["make_current", "set_zoom"])

	var ts := TileSet.new()
	ts.tile_size = Vector2i(8, 8)
	ts.add_occlusion_layer()
	print("occlusion_layers=", ts.get_occlusion_layers_count())

	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5))
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(8, 8)
	src.create_tile(Vector2i.ZERO)
	ts.add_source(src, 0)
	var td: TileData = src.get_tile_data(Vector2i.ZERO, 0)
	var occ := OccluderPolygon2D.new()
	occ.polygon = PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
	td.set_occluder(0, occ)
	print("occluder_ok=", td.get_occluder(0) != null)

	var env := Environment.new()
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.2
	env.glow_hdr_threshold = 0.85
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	print("env_ok glow=", env.glow_enabled, " contrast=", env.adjustment_contrast)

	# Fonts
	for f in ["res://assets/ui/PT_Sans-Narrow-Web-Regular.ttf", "res://assets/ui/Oswald.ttf"]:
		if ResourceLoader.exists(f):
			var font := load(f) as Font
			print(f, " -> ", font, " cyr=", font.has_char(0x041F) if font else "n/a")
		else:
			print(f, " missing")

	# Image primitives used by tests
	var im2 := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	im2.set_pixel(1, 1, Color(1, 0, 0, 1))
	print("image_ok=", im2.get_pixel(1, 1))
	print("PROBE3_DONE")
	quit(0)


func _dump_methods(cls: String, names: Array) -> void:
	var all: Array = []
	for m in ClassDB.class_get_method_list(cls, true):
		all.append(m["name"])
	var out: Array = []
	for n in names:
		out.append("%s:%s" % [n, "yes" if all.has(n) else "MISSING"])
	print(cls, " => ", out)
