extends SceneTree

## API probe #2 — run:
## tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/probe2.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_dump_methods("TileSet", ["add_physics_layer", "set_physics_layer_collision_layer", "get_physics_layers_count"])
	_dump_props("CanvasTexture")
	_dump_methods("TileData", ["add_collision_polygon", "set_collision_polygon_points", "set_collision_polygon_one_way"])
	_dump_props("PointLight2D")
	_dump_methods("AudioStreamWAV", ["set_data", "save_to_wav"])
	_dump_methods("Image", ["load_from_file", "create_empty", "save_png"])

	# Physics layer with default signature
	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5))
	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(8, 8)
	ts.add_physics_layer()
	print("physics_layers_count=", ts.get_physics_layers_count())
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(8, 8)
	src.create_tile(Vector2i.ZERO)
	ts.add_source(src, 0)
	var td: TileData = src.get_tile_data(Vector2i.ZERO, 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)
	]))
	print("collision_polygon_size=", td.get_collision_polygon_points(0, 0).size())

	# CanvasTexture — find the real property name
	var ct := CanvasTexture.new()
	var names: Array = []
	for p in ct.get_property_list():
		names.append(p["name"])
	print("canvas_texture_props=", names)
	ct.set("diffuse_texture", tex)
	print("diffuse_texture=", ct.get("diffuse_texture"))
	ct.set("normal_texture", tex)
	print("normal_texture_set_ok=", ct.get("normal_texture"))

	# Light2D sanity, no crash
	var light := PointLight2D.new()
	light.texture = tex
	light.shadow_enabled = true
	light.blend_mode = Light2D.BLEND_MODE_ADD
	root.add_child(light)
	print("light ok")

	print("PROBE2_DONE")
	quit(0)


func _dump_methods(cls: String, names: Array) -> void:
	var have: Array = []
	var all: Array = []
	for m in ClassDB.class_get_method_list(cls, true):
		all.append(m["name"])
	for n in names:
		if all.has(n):
			var info := ""
			for m in ClassDB.class_get_method_list(cls, true):
				if m["name"] == n:
					var args: Array = []
					for a in m["args"]:
						args.append("%s:%s" % [a["name"], type_string(a["type"])])
					info = "%s(%s) -> %s" % [n, ", ".join(args), type_string(m["return"]["type"])]
			have.append(info)
		else:
			have.append("%s: MISSING" % n)
	print(cls, " => ", have)


func _dump_props(cls: String) -> void:
	var props: Array = []
	for p in ClassDB.class_get_property_list(cls, true):
		if int(p["usage"]) & PROPERTY_USAGE_EDITOR:
			props.append(p["name"])
	print(cls, " props => ", props)
