extends SceneTree

const Cards = preload("res://scripts/cards.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.pilot.save_path = "user://cards_flow_ci.json"
	print("CARD FLOW STEP 1 initialized")
	game._new_run()
	game._pick_route(str(game.campaign.available()[0]["id"]))
	if game.screen != "garage":
		_fail("garage initialization")
		return
	var turbo: Dictionary = Cards.CATALOG[0]
	var turbo_better: Dictionary = Cards.CATALOG[1]
	var radiator: Dictionary = Cards.CATALOG[8]
	var tire: Dictionary = Cards.CATALOG[3]
	var suspension: Dictionary = Cards.CATALOG[12]
	for item in [turbo, turbo_better, radiator, tire, suspension]:
		game.inventory.append(item.duplicate(true))
	print("CARD FLOW STEP 2 equipping parts")
	game._equip(turbo)
	game._equip(radiator)
	game._equip(tire)
	game._equip(suspension)
	if Cards.synergies(game.equipped).size() != 2:
		_fail("combos should only use equipped slots")
		return
	var before: float = float(game._stats()["accel"])
	print("CARD FLOW STEP 3 swapped parts")
	game._equip(turbo_better)
	if game.inventory.size() != 5 or str(game.equipped["Turbo"]["id"]) != "turbo_pro" or float(game._stats()["accel"]) <= before:
		_fail("swap should keep old part and increase power")
		return
	print("CARD FLOW STEP 4 unequipping")
	game._unequip("Refrigeracao")
	if Cards.synergies(game.equipped).size() != 1:
		_fail("unequip should remove synergy")
		return
	game._equip(radiator)
	var fake: Dictionary = Cards.CATALOG[2]
	game._equip(fake)
	if str(game.equipped["Turbo"]["id"]) == "turbo_duplo":
		_fail("unowned part equipped")
		return
	print("CARD FLOW STEP 5 opening rewards")
	game._set_screen("reward")
	game.reward_picks_left = 1
	game.cards = [Cards.CATALOG[14].duplicate(true)]
	print("CARD FLOW STEP 6 taking reward")
	game._choose(game.cards[0])
	if game.passives.size() != 1 or game.screen != "map":
		_fail("choosing passive")
		return
	for i in range(2):
		game.passives.append(Cards.CATALOG[14].duplicate(true))
	game._pick_route(str(game.campaign.available()[0]["id"]))
	print("CARD FLOW STEP 7 generating new rewards")
	game._start_reward()
	if game.cards.size() < 3:
		_fail("not enough rewards")
		return
	for option in game.cards:
		if str(option["id"]) == "remap":
			_fail("capped passive presented again")
			return
	game.passives.append(Cards.CATALOG[17].duplicate(true))
	print("CARD FLOW STEP 8 simulating risk")
	var risky = game.sim
	risky.begin(game._stats(), 2, 1234, {"weather":"seca"}, {})
	var no_risk = Cards.calculate({}, [])
	var comparison = game.sim.get_script().new()
	comparison.begin(no_risk, 2, 1234, {"weather":"seca"}, {})
	if risky.error_chance("curve", 0.7, 1.0) >= comparison.error_chance("curve", 0.7, 1.0):
		_fail("risk reduction inactive")
		return
	print("CARD FLOW STEP 9 finishing test")
	game._exit_to_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.pilot.save_path))
	print("PASS: part swapping, inventory, equipped synergies, stacks and race modifiers")
	quit(0)

func _fail(reason: String) -> void:
	printerr("CARD FLOW FAIL: ", reason)
	quit(1)
