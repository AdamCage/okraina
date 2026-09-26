extends SceneTree

## API probe for Godot 4.7 — run:
## tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/probe.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("version=", Engine.get_version_info())
	var classes := [
		"TileMapLayer", "TileSet", "TileSetAtlasSource", "AStarGrid2D", "PointLight2D",
		"DirectionalLight2D", "LightOccluder2D", "CanvasModulate", "WorldEnvironment",
		"GPUParticles2D", "CPUParticles2D", "CanvasTexture", "AtlasTexture", "ImageTexture",
		"NoiseTexture2D", "FastNoiseLite", "AudioStreamWAV", "AudioStreamPlayer",
		"AudioStreamPlayer2D", "NinePatchRect", "RichTextLabel", "TextureProgressBar",
		"PointLight2D", "NavigationRegion2D", "NavigationAgent2D", "Line2D", "Polygon2D",
		"Curve2D", "Path2D", "PackedScene", "ResourceLoader", "Gradient", "GradientTexture2D",
		"BoxContainer", "GridContainer", "ItemList", "MenuButton", "Window", "SubViewport",
		"AnimationPlayer", "Tween", "ShaderMaterial", "CanvasItemMaterial",
	]
	var missing: Array = []
	for c in classes:
		if not ClassDB.class_exists(c):
			missing.append(c)
	print("missing_classes=", missing)

	var f: Font = ThemeDB.fallback_font
	print("font_cyrillic=", f.has_char(0x041F), " cyr_yo=", f.has_char(0x0451), " font=", f)

	for s in [
		"rendering/viewport/hdr_2d",
		"rendering/anti_aliasing/quality/msaa_2d",
		"rendering/environment/defaults/default_clear_color",
		"rendering/textures/canvas_textures/default_texture_filter",
		"physics/2d/default_gravity",
		"display/window/stretch/mode",
	]:
		print("setting ", s, " exists=", ProjectSettings.has_setting(s), " value=", ProjectSettings.get_setting(s))

	# --- TileSet / TileMapLayer programmatic API ---
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.3, 0.2))
	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	src.create_tile(Vector2i(0, 0))
	var td: TileData = src.get_tile_data(Vector2i(0, 0), 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	]))
	ts.add_source(src, 0)
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	layer.set_cell(Vector2i(1, 1), 0, Vector2i(0, 0))
	root.add_child(layer)
	print("tilemap_ok=", layer.get_cell_source_id(Vector2i(1, 1)))

	# --- AStarGrid2D ---
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, 8, 8)
	astar.cell_size = Vector2(16, 16)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	astar.set_point_solid(Vector2i(3, 3), true)
	var path: PackedVector2Array = astar.get_point_path(Vector2i(0, 0), Vector2i(7, 7))
	print("astar_ok=", path.size())

	# --- normal map as CanvasTexture ---
	var normal_png := "res://assets/textures/_probe_normal.png"
	if FileAccess.file_exists(normal_png):
		var ntex: Texture2D = load(normal_png)
		print("probe normal loaded=", ntex, " size=", ntex.get_size())
		var ct := CanvasTexture.new()
		ct.texture = tex
		ct.normal_texture = ntex
		var spr := Sprite2D.new()
		spr.texture = ct
		root.add_child(spr)
		print("canvas_texture_ok=", spr.texture)
	else:
		print("probe normal png missing")

	# --- Light2D + shadows ---
	var light := PointLight2D.new()
	light.texture = tex
	light.shadow_enabled = true
	light.energy = 1.2
	root.add_child(light)
	print("light_ok=", light.shadow_enabled, " blend=", light.blend_mode)

	print("PROBE_DONE")
	quit(0)
