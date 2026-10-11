extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game._new_run()
	if game.screen != "map" or game.campaign.available().size() != 1:
		_fail("new run map", game)
		return
	var start: Dictionary = game.campaign.available()[0]
	game._pick_route(str(start["id"]))
	if game.screen != "garage":
		_fail("garage selection", game)
		return
	game._race_start()
	if game.screen != "race" or game.campaign.raced_path.size() != 1:
		_fail("race selection", game)
		return
	game._start_reward()
	if game.cards.size() != 3 or game.reward_picks_left != 1:
		_fail("normal reward", game)
		return
	game._choose(game.cards[0])
	if game.stage != 2 or game.screen != "map":
		_fail("return to map", game)
		return
	var path_before: int = game.campaign.raced_path.size()
	game._pick_route(str(game.campaign.available()[0]["id"]))
	game.selected_route["kind"] = "elite"
	game._start_reward()
	if game.cards.size() != 4 or game.reward_picks_left != 2:
		_fail("elite reward", game)
		return
	var first: Dictionary = game.cards[0]
	game._choose(first)
	if game.reward_picks_left != 1 or game.stage != 2 or game.cards.size() != 3:
		_fail("first of two rewards", game)
		return
	game._choose(game.cards[0])
	if game.stage != 3 or game.screen != "map" or game.campaign.raced_path.size() != path_before:
		_fail("second of two rewards", game)
		return
	print("PASS: map, garage, normal 1-of-3 and elite 2-of-4 rewards")
	quit(0)

func _fail(message: String, game: Node) -> void:
	printerr("FAIL campaign flow: ", message, " stage=",game.stage," screen=",game.screen)
	quit(1)
