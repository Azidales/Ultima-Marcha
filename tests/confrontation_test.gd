extends SceneTree

const Compare = preload("res://scripts/confrontation.gd")
const Cards = preload("res://scripts/cards.gd")
const Race = preload("res://scripts/simulation.gd")

func _fail(s: String) -> void:
	printerr("COMPARISON FAIL: ", s)
	quit(1)

func _initialize() -> void:
	var base: Dictionary = Cards.calculate({}, [])
	for route in [
		{"stage": 1,"kind": "normal","weather":"seca","track":"Rodovia"},
		{"stage": 4,"kind": "elite","weather":"molhada","track":"Serra"},
		{"stage": 5,"kind": "boss","weather":"seca","track":"Circuito urbano"},
		{"stage": 10,"kind": "boss","weather":"molhada","track":"Serra"}
	]:
		var stage: int = int(route["stage"])
		var rows: Array[Dictionary] = Compare.comparison(base,stage,route,{"style":"equilibrado"})
		if rows.size() != 4:
			_fail("four indicators")
			return
		var seed_sim = Race.new()
		seed_sim.begin(base,stage,37,route,{"style":"equilibrado"})
		var factor: float = 0.95 + float(stage-1)*0.044 + (0.12 if str(route["kind"])=="elite" else 0.0) + (0.10 if stage in [5,10] else 0.0)
		var wet: float = 0.82 if route["weather"]=="molhada" else 1.0
		var track: float = 1.20 if route["track"]=="Serra" else 1.0
		var curve: float = 0.5 * track
		if not is_equal_approx(float(rows[0]["rival"]),5.9*factor/6.2*100.0):
			_fail("opponent acceleration mismatches actual sim")
			return
		if not is_equal_approx(float(rows[1]["rival"]),sqrt(factor*wet)*100.0):
			_fail("opponent corner speed mismatches actual sim")
			return
		if not is_equal_approx(float(rows[2]["rival"]),38.0*factor/39.0*100.0):
			_fail("opponent straight speed mismatches actual sim")
			return
		if not is_equal_approx(float(rows[3]["player"]),seed_sim.error_chance("curve",curve,wet)*100.0):
			_fail("risk differs from simulation")
			return
		if Compare.advantage({"player":9.0,"rival":15.0,"lower_better":true}) != 1:
			_fail("lower risk must be better")
			return
	var tires: Dictionary = Cards.CATALOG[5]
	var changed: Dictionary = Compare.preview_stats({}, [], tires)
	var wet_row: Array[Dictionary] = Compare.comparison(changed,4,{"kind":"normal","weather":"molhada","track":"Serra"},{"style":"equilibrado"})
	var dry_row: Array[Dictionary] = Compare.comparison(changed,4,{"kind":"normal","weather":"seca","track":"Serra"},{"style":"equilibrado"})
	if float(wet_row[1]["player"]) <= float(dry_row[1]["player"])*0.95:
		_fail("wet tires preview")
		return
	var turbo: Dictionary = Cards.CATALOG[0]
	var after: Dictionary = Compare.preview_stats({},[],turbo)
	if not is_equal_approx(float(after["accel"]),1.16):
		_fail("preview does not reflect equipped new part")
		return
	print("PASS: physically grounded rival comparisons, wet tires, skill risk, preview and invert lower-risk advantage")
	quit(0)
