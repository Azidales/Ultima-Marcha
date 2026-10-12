extends SceneTree

func _fail(message: String) -> void:
	printerr("TOUCH UI FAIL: ",message)
	quit(1)

func _check(game, label: String) -> bool:
	var shell: Node = game.layer.get_node_or_null("SafeArea/UILayout")
	if shell == null:
		_fail("no shell " + label)
		return false
	var bar: HBoxContainer = shell.get_node_or_null("ActionBar") as HBoxContainer
	var scroll: ScrollContainer = shell.get_node_or_null("ContentScroll") as ScrollContainer
	if bar == null or scroll == null:
		_fail("missing action controls " + label)
		return false
	if bar.get_index() >= scroll.get_index():
		_fail("action bar too far below content " + label)
		return false
	for item in bar.get_children():
		if item is Button:
			if item.custom_minimum_size.y < 60.0 or item.get_theme_font_size("font_size") < 21:
				_fail("button too small in " + label)
				return false
	return true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.pilot.save_path = "user://touch_test_ci.json"
	for shape in [Vector2i(540, 960), Vector2i(960, 540)]:
		root.size = shape
		game._set_screen("menu")
		if not _check(game, "menu"):
			return
		game._open_career()
		if not _check(game, "career"):
			return
		game._set_screen("menu")
		game._new_run()
		if not _check(game, "map"):
			return
		game._pick_route(str(game.campaign.available()[0]["id"]))
		if not _check(game, "garage"):
			return
		for name in ["conservador", "equilibrado", "agressivo"]:
			game._set_pilot_style(name)
			if game.pilot_style != name or not _check(game, "style"):
				return
		game._race_start()
		var shell: Node = game.layer.get_node_or_null("SafeArea/UILayout")
		var buttons: Node = shell.get_node_or_null("RaceActions")
		if buttons == null or buttons.get_index() > 3:
			_fail("race buttons not close to telemetry")
			return
		if game.speed_button == null or game.speed_button.custom_minimum_size.y < 60.0:
			_fail("race tap target too small")
			return
		game._exit_to_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.pilot.save_path))
	print("PASS: top-positioned large action buttons on portrait and landscape screens")
	quit(0)
