extends SceneTree

const Pilot = preload("res://scripts/pilot.gd")
const Race = preload("res://scripts/simulation.gd")

func _initialize() -> void:
	var savefile := "user://pilot_ci_test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(savefile))
	var p = Pilot.new()
	p.save_path = savefile
	for i in range(8):
		p.grant_result(true, "normal")
	if p.experience != 400 or p.level() != 3 or p.total_points() != 2:
		_fail("XP and points")
		return
	if not p.upgrade("curvas") or not p.upgrade("curvas") or p.upgrade("curvas"):
		_fail("basic skill cap")
		return
	if not p.start_run() or p.upgrade("marchas") or p.respec() or p.unlock("controle"):
		_fail("tree should lock during a run")
		return
	p.end_run()
	if not p.respec() or p.spent() != 0:
		_fail("free redistribution")
		return
	for i in range(40):
		p.grant_result(true, "normal")
	if p.total_points() != 12:
		_fail("max points")
		return
	for id in ["curvas", "correcao"]:
		for i in range(2):
			if not p.upgrade(id):
				_fail("invest basics")
				return
	if not p.unlock("controle") or p.unlock("controle"):
		_fail("advanced unlock")
		return
	if p.spent() != 6 or p.available_points() != 6:
		_fail("advanced point costs")
		return
	var second = Pilot.new()
	second.save_path = savefile
	second.load_save()
	if second.experience != p.experience or second.skills != p.skills or second.advanced != p.advanced:
		_fail("persistent save/load")
		return
	var rookie := Race.new()
	rookie.begin({"accel":1.0,"grip":1.0,"top":1.0,"cool":1.0},1,12,{},Pilot.new().snapshot("equilibrado"))
	var veteran := Race.new()
	veteran.begin({"accel":1.0,"grip":1.0,"top":1.0,"cool":1.0},1,12,{},second.snapshot("equilibrado"))
	if veteran.error_chance("curve", 0.8, 1.0) >= rookie.error_chance("curve", 0.8, 1.0):
		_fail("pilot improvements do not reduce risk")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(savefile))
	print("PASS: permanent XP, saved tree, locked runs, free respec, advanced skills and race risk")
	quit(0)

func _fail(msg: String) -> void:
	printerr("PILOT TEST FAIL: ", msg)
	quit(1)
