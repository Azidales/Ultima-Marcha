extends SceneTree

const Race = preload("res://scripts/simulation.gd")

func _fail(message: String) -> void:
	printerr("RACE DUEL FAIL: ", message)
	quit(1)

func _initialize() -> void:
	var overtakes := 0
	var interventions := 0
	for seed_value in range(1, 22):
		for enhanced in [false, true]:
			var sim = Race.new()
			var car: Dictionary = {"accel":1.55,"top":1.35,"grip":1.2,"cool":1.1} if enhanced else {"accel":1.0,"top":1.0,"grip":1.0,"cool":1.0}
			var driving: Dictionary = {"style":"agressivo"} if enhanced else {"style":"equilibrado"}
			sim.begin(car, 1 if enhanced else 5, seed_value, {"track":"Rodovia","weather":"seca"}, driving)
			var steps := 0
			while not sim.finished and steps < 10800:
				sim.tick(Race.STEP)
				steps += 1
				if sim.progress_player < -0.0001 or sim.progress_rival < -0.0001:
					_fail("negative progress")
					return
				if absf(sim.progress_player - sim.progress_rival) < Race.MIN_FRONT_GAP - 0.01 and absf(sim.player_lateral - sim.rival_lateral) < Race.MIN_SIDE_GAP - 0.01:
					_fail("collision or ghost overlap at seed %d tick %d" % [seed_value,steps])
					return
				if absf(sim.player_lateral) > 4.0 or absf(sim.rival_lateral) > 4.0:
					_fail("car left roadway")
					return
			if not sim.finished or sim.winner.is_empty():
				_fail("race did not complete")
				return
			if sim.player_passes + sim.rival_passes != sim.clean_passes:
				_fail("invalid overtake accounting")
				return
			overtakes += sim.clean_passes
			interventions += sim.safety_brakes
	if overtakes == 0:
		_fail("cars never exchanged places despite stronger player configurations")
		return
	# Deliberately force a tight follow situation and verify the no-contact guard.
	var blocked = Race.new()
	blocked.begin({"accel":1.8,"top":1.5,"grip":1.0,"cool":1.0}, 1, 123)
	blocked.progress_player = 99.0
	blocked.progress_rival = 103.0
	blocked.player_lateral = Race.BASE_LANE
	blocked.rival_lateral = Race.BASE_LANE
	blocked.speed_player = 33.0
	blocked.speed_rival = 9.0
	blocked.tick(Race.STEP)
	if absf(blocked.progress_player - blocked.progress_rival) < Race.MIN_FRONT_GAP - 0.01 and absf(blocked.player_lateral - blocked.rival_lateral) < Race.MIN_SIDE_GAP - 0.01:
		_fail("no-contact brake failed")
		return
	if blocked.safety_brakes == 0:
		_fail("no intervention on collision course")
		return
	print("PASS: seeded 1v1 races, ",overtakes," overtakes, ",interventions," safe braking ticks, zero overlaps")
	quit(0)
