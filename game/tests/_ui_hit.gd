extends SceneTree

## Кто перехватывает клик в точке кнопки меню. Сравнение старой и новой сборок.
## Запуск: godot --headless --path . -s res://tests/_ui_hit.gd
##         godot --headless --main-pack old.pck -s <абс.путь>/_ui_hit.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/game.tscn")
	var game: Node = scene.instantiate()
	root.add_child(game)
	for i in 6:
		await process_frame

	var box: Node = _find_by_name(root, "MainButtons")
	if box == null or box.get_child_count() == 0:
		print("[hit] кнопок нет")
		quit(1)
		return
	var btn: Control = box.get_child(0) as Control
	var pt: Vector2 = btn.get_global_rect().get_center()
	print("[hit] точка клика: ", pt, " | tree.paused=", paused)
	print("[hit] кнопка: ", btn.get_path(), " filter=", btn.mouse_filter,
		" can_process=", btn.can_process(), " process_mode=", btn.process_mode)

	var layers: Array = []
	_collect_layers(root, layers)
	layers.sort_custom(func(a, b): return int(a["layer"]) > int(b["layer"]))
	for l in layers:
		print("[hit] CanvasLayer layer=", l["layer"], " name=", l["name"],
			" visible=", l["visible"], " process_mode=", l["mode"],
			" root_filter=", l["filter"])

	print("[hit] кто в точке (сверху вниз по слою/z):")
	var hits: Array = []
	_collect(root, null, pt, hits)
	hits.sort_custom(func(a, b): return int(a["order"]) > int(b["order"]))
	var shown: int = 0
	for h in hits:
		if not bool(h["visible"]):
			continue
		print("[hit]   order=", h["order"], " filter=", h["filter"], " can_process=", h["can"],
			" rect=", h["rect"], " ", h["path"])
		shown += 1
		if shown >= 12:
			break
	quit(0)


func _collect_layers(n: Node, out: Array) -> void:
	if n is CanvasLayer:
		var cl := n as CanvasLayer
		var rf: Variant = null
		for c in cl.get_children():
			if c is Control:
				rf = (c as Control).mouse_filter
				break
		out.append({"layer": cl.layer, "name": String(cl.name), "visible": cl.visible,
			"mode": cl.process_mode, "filter": rf})
	for c in n.get_children():
		_collect_layers(c, out)


func _collect(n: Node, layer: CanvasLayer, pt: Vector2, out: Array) -> void:
	var cur: CanvasLayer = layer
	if n is CanvasLayer:
		cur = n as CanvasLayer
	if n is Control and n != root:
		var c := n as Control
		var r: Rect2 = c.get_global_rect()
		if r.has_point(pt):
			var order: int = (int(cur.layer) * 1000 if cur != null else 0) + c.z_index
			var idx: int = 0
			if c.get_parent() != null:
				idx = c.get_index()
			out.append({"order": order * 100 + idx, "filter": c.mouse_filter,
				"can": c.can_process(), "rect": r, "path": String(c.get_path()),
				"visible": c.visible})
	for c in n.get_children():
		_collect(c, cur, pt, out)


func _find_by_name(n: Node, wanted: String) -> Node:
	if n.name == wanted:
		return n
	for c in n.get_children():
		var r: Node = _find_by_name(c, wanted)
		if r != null:
			return r
	return null
