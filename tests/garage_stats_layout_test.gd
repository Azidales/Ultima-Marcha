extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _find(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var result: Node = _find(child, wanted)
		if result != null:
			return result
	return null

func _check(game, screen_shape: String) -> bool:
	var keys := ["launch", "corner", "straight", "risk"]
	for key in keys:
		var card: Node = _find(game.layer, "Metric_" + key)
		if card == null:
			printerr("FAIL: comparison bar missing ",key," in ",screen_shape)
			return false
		var own: ProgressBar = _find(card, "PlayerBar") as ProgressBar
		var other: ProgressBar = _find(card, "RivalBar") as ProgressBar
		var p_label: Label = _find(card, "PlayerValue") as Label
		var r_label: Label = _find(card, "RivalValue") as Label
		if own == null or other == null or p_label == null or r_label == null:
			printerr("FAIL: opponent/player meter missing in ",key)
			return false
		if own.max_value != other.max_value or own.value < 0.0 or other.value < 0.0:
			printerr("FAIL: unfair visual scale")
			return false
		if p_label.autowrap_mode != TextServer.AUTOWRAP_OFF or r_label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			printerr("FAIL: stat values wrap in ",screen_shape)
			return false
		if not p_label.text.ends_with("%") or not r_label.text.ends_with("%"):
			printerr("FAIL: stat percentages")
			return false
	return true

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.pilot.save_path = "user://stats_layout_ci.json"
	game._new_run()
	game._pick_route(str(game.campaign.available()[0]["id"]))
	for pair in [{"size": Vector2i(540,960),"name":"portrait"},{"size":Vector2i(960,540),"name":"landscape"}]:
		root.size = pair["size"]
		game._draw_ui()
		if not _check(game, str(pair["name"])):
			quit(1)
			return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.pilot.save_path))
	print("PASS: four fair two-car meter pairs with readable values on portrait and landscape")
	quit(0)
