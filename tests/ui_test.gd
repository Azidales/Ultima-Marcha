extends SceneTree

func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	printerr("UI TEST FAIL: ", message)
	quit(1)

func _find_buttons(node: Node, text_fragment: String) -> int:
	var total := 0
	if node is Button and text_fragment in str(node.text):
		total += 1
	for child in node.get_children():
		total += _find_buttons(child, text_fragment)
	return total

func _check_structure(game, section: String) -> bool:
	var root_layout: Node = game.layer.get_node_or_null("SafeArea/UILayout")
	if root_layout == null:
		_fail("missing responsive shell at " + section)
		return false
	var scroll: Node = root_layout.get_node_or_null("ContentScroll")
	var footer: Node = root_layout.get_node_or_null("ActionBar")
	if scroll == null or footer == null:
		_fail("missing fixed footer or scroll container at " + section)
		return false
	if root_layout.get_child_count() < 4:
		_fail("screen structure missing parts at " + section)
		return false
	return true

func _verify() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.pilot.save_path = "user://ui_ci_pilot.json"
	if not _check_structure(game, "menu") or _find_buttons(game.layer, "JOGAR") != 1:
		return
	game._open_career()
	if not _check_structure(game, "career") or _find_buttons(game.layer, "REDISTRIBUIR") != 1:
		return
	game._set_screen("menu")
	game._new_run()
	if not _check_structure(game, "map"):
		return
	var route: Dictionary = game.campaign.available()[0]
	game._pick_route(str(route["id"]))
	if not _check_structure(game, "garage"):
		return
	if game.layer.get_node_or_null("SafeArea/UILayout/TabBar") == null:
		_fail("garage tabs not found")
		return
	if _find_buttons(game.layer, "LARGAR!") != 1:
		_fail("fixed start button missing")
		return
	for tab in ["pecas", "efeitos", "resumo"]:
		game._set_garage_tab(tab)
		if game.garage_tab != tab or not _check_structure(game, tab):
			_fail("garage tab navigation " + tab)
			return
		if _find_buttons(game.layer, "LARGAR!") != 1:
			_fail("start action lost in " + tab)
			return
	game._set_garage_tab("resumo")
	game._set_pilot_style("agressivo")
	if game.pilot_style != "agressivo":
		_fail("pilot style not selectable")
		return
	game._race_start()
	if game.screen != "race" or not is_instance_valid(game.speed_button):
		_fail("race controls changed")
		return
	game._start_reward()
	if game.screen != "reward" or not _check_structure(game, "reward") or _find_buttons(game.layer, "ESCOLHER ESTA CARTA") != 3:
		_fail("card buttons not easy to reach")
		return
	game._choose(game.cards[0])
	if game.screen != "map":
		_fail("reward navigation failed")
		return
	game._exit_to_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.pilot.save_path))
	print("PASS: compact mobile UI, fixed actions, tabs, readable card choices and menu navigation")
	quit(0)
