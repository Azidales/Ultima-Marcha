extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.pilot.save_path = "user://integration_pilot_ci.json"
	game.pilot.experience = 0
	game.pilot.respec()
	game._open_career()
	if game.screen != "career":
		_fail("career menu")
		return
	game._new_run()
	if not game.pilot.running or game.screen != "map":
		_fail("run starts with locked pilot")
		return
	game._pick_route(str(game.campaign.available()[0]["id"]))
	game._set_pilot_style("conservador")
	if game.pilot_style != "conservador":
		_fail("style is configurable before race")
		return
	game._race_start()
	if game.sim.style() != "conservador" or not game.pilot.running:
		_fail("race must use pilot style and remain locked")
		return
	game.sim.finished = true
	game.sim.winner = "player"
	game._finish_race()
	var experience_before: int = game.pilot.experience
	if experience_before != 50 or game.earned_xp != 50 or game.screen != "result":
		_fail("XP result")
		return
	game._finish_race()
	if game.pilot.experience != experience_before:
		_fail("XP awarded multiple times")
		return
	if not game.pilot.running or game.pilot.respec():
		_fail("XP can grow during run but training cannot")
		return
	game._exit_to_menu()
	if game.pilot.running or game.screen != "menu" or not game.pilot.respec():
		_fail("respec should unlock after run")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.pilot.save_path))
	print("PASS: career screen, style selection, XP exactly once, lock/unlock and persistent profile")
	quit(0)

func _fail(message: String) -> void:
	printerr("FAIL pilot flow: ", message)
	quit(1)
