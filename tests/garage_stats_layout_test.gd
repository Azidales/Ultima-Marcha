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
	var scroll: ScrollContainer = game.layer.get_node_or_null("SafeArea/UILayout/ContentScroll") as ScrollContainer
	if scroll == null or scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER:
		printerr("FAIL: intrusive visible scrollbar on ",screen_shape)
		return false
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
		var badge: Label = _find(card, "Status") as Label
		if badge == null or badge.autowrap_mode != TextServer.AUTOWRAP_OFF:
			printerr("FAIL: advantage badge wraps vertically: ",key)
			return false
		if badge.custom_minimum_size.x < 130.0 or badge.text.contains("\n"):
			printerr("FAIL: advantage badge has insufficient horizontal space: ",key)
			return false
		var measured_height: float = (card as Control).get_combined_minimum_size().y
		if measured_height > 135.0:
			printerr("FAIL: huge metric card ",key,": ",measured_height)
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
	print("PASS: four compact no-wrap metric cards, no visible scrollbar and fair meter scales")
	quit(0)
