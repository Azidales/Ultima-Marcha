extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _find_by_name(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found: Node = _find_by_name(child, wanted)
		if found != null:
			return found
	return null

func _check(game, orientation: String) -> bool:
	var stats: Node = _find_by_name(game.layer, "CarStats")
	if stats == null or not stats is VBoxContainer or stats.get_child_count() != 4:
		printerr("FAIL: car stats list missing in " + orientation)
		return false
	var keys := ["accel", "grip", "top", "cool"]
	for key in keys:
		var label: Label = stats.get_node_or_null("Stat_" + key) as Label
		if label == null:
			printerr("FAIL: missing horizontal stat label " + key)
			return false
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF or label.custom_minimum_size.x < 140.0:
			printerr("FAIL: stat could wrap vertically on " + orientation + ": " + key)
			return false
		if not label.text.ends_with("%") or label.text.contains("\n"):
			printerr("FAIL: malformed value " + label.text)
			return false
	return true

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.pilot.save_path = "user://stats_layout_ci.json"
	game._new_run()
	game._pick_route(str(game.campaign.available()[0]["id"]))
	# The same layout must remain valid in both orientations.
	for shape in [{"size":Vector2i(540, 960), "name":"portrait"},{"size":Vector2i(960, 540), "name":"landscape"}]:
		root.size = shape["size"]
		game._draw_ui()
		if not _check(game, str(shape["name"])):
			quit(1)
			return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.pilot.save_path))
	print("PASS: full-width, no-wrap car stat rows in portrait and landscape")
	quit(0)
