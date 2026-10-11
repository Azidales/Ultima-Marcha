extends SceneTree

const Race = preload("res://scripts/simulation.gd")

func _initialize() -> void:
	var first := _race(1901)
	var again := _race(1901)
	if first != again or float(first["time"]) <= 0.0 or float(first["time"]) >= 180.0:
		printerr("FAILED: deterministic race")
		quit(1)
		return
	print("PASS: deterministic race ", first)
	quit(0)

func _race(seed_value: int) -> Dictionary:
	var sim = Race.new()
	sim.begin({"accel":1.0,"grip":1.0,"top":1.0,"cool":1.0}, 1, seed_value)
	var count := 0
	while not sim.finished and count < 10800:
		sim.tick(Race.STEP)
		count += 1
	return {"winner":sim.winner,"time":sim.time,"events":sim.log}
