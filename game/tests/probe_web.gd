extends SceneTree

## Разведка API/настроек для веб- и мобильного таргета (Godot 4.7).
## Запуск: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/probe_web.gd

func _init() -> void:
	print("=== VERSION ===")
	print(Engine.get_version_info())
	print("display server: ", DisplayServer.get_name())
	print("OS: ", OS.get_name(), " | features: ", OS.get_name(), " ", Engine.get_architecture_name())

	print("=== SETTINGS ===")
	var keys := [
		"rendering/renderer/rendering_method",
		"rendering/renderer/rendering_method.mobile",
		"rendering/renderer/rendering_method.web",
		"display/window/handheld/orientation",
		"display/window/size/mode",
		"display/window/size/resizable",
		"display/window/size/viewport_width",
		"display/window/size/viewport_height",
		"display/window/stretch/mode",
		"display/window/stretch/aspect",
		"display/window/stretch/scale",
		"display/window/vsync/vsync_mode",
		"rendering/textures/vram_compression/import_etc2_astc",
		"rendering/anti_aliasing/quality/msaa_2d",
		"rendering/viewport/hdr_2d",
		"rendering/2d/snap/snap_2d_transforms_to_pixel",
		"input_devices/pointing/emulate_mouse_from_touch",
		"input_devices/pointing/emulate_touch_from_mouse",
		"application/run/max_fps",
		"application/boot_splash/show_image",
		"rendering/environment/defaults/default_clear_color",
		"audio/driver/enable_input",
		"physics/common/physics_ticks_per_second",
	]
	for k in keys:
		var has_it: bool = ProjectSettings.has_setting(k)
		var val: Variant = ProjectSettings.get_setting(k, "<нет>") if has_it else "<нет>"
		print("  ", k, " | has=", has_it, " | val=", val)

	print("=== API ===")
	print("TileMapLayer: ", ClassDB.class_exists("TileMapLayer"))
	print("TileSetAtlasSource: ", ClassDB.class_exists("TileSetAtlasSource"))
	print("CanvasModulate: ", ClassDB.class_exists("CanvasModulate"))
	print("PointLight2D: ", ClassDB.class_exists("PointLight2D"))
	print("DirectionalLight2D: ", ClassDB.class_exists("DirectionalLight2D"))
	print("TextureRect: ", ClassDB.class_exists("TextureRect"))
	print("Camera2D: ", ClassDB.class_exists("Camera2D"))
	print("AtlasTexture: ", ClassDB.class_exists("AtlasTexture"))
	print("ResourceLoader.load atlas: ", load("res://assets/textures/ground_atlas.png") != null)
	var t: Texture2D = load("res://assets/textures/ground_atlas.png")
	if t != null:
		print("  ground_atlas size: ", t.get_size())
	var n: Texture2D = load("res://assets/textures/ground_atlas_n.png")
	if n != null:
		print("  ground_atlas_n size: ", n.get_size())

	print("=== WEB RUNTIME CAPS ===")
	print("has_feature('web'): ", OS.has_feature("web"), " | 'mobile': ", OS.has_feature("mobile"))
	print("rendering method now: ", RenderingServer.get_current_rendering_method())
	print("touchscreen: ", DisplayServer.is_touchscreen_available())
	print("DisplayServer.screen_get_size: ", DisplayServer.screen_get_size())
	print("get_display_safe_area: ", DisplayServer.get_display_safe_area())

	print("=== EXPORT TEMPLATES ===")
	print("template dir setting: ", ProjectSettings.get_setting("application/config/export_templates_dir", "<auto>"))
	print("EditorExportPlatformWeb: ", ClassDB.class_exists("EditorExportPlatformWeb"))
	print("=== DONE ===")
	quit()
