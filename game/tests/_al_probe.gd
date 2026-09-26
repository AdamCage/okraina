extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== root children ===")
	for c in root.get_children():
		print("  ", c.name, " | ", c.get_class())
	print("GameState node: ", root.get_node_or_null("GameState"))
	print("has_feature web: ", OS.has_feature("web"))
	quit(0)

