extends SceneTree

const Cards = preload("res://scripts/cards.gd")

func _initialize() -> void:
	var all_ids: Dictionary = {}
	for card in Cards.CATALOG:
		var id := str(card["id"])
		if all_ids.has(id) or not card.has("rarity") or not card.has("desc"):
			_fail("duplicate or malformed card: " + id)
			return
		all_ids[id] = true
	var rng1 := RandomNumberGenerator.new()
	var rng2 := RandomNumberGenerator.new()
	rng1.seed = 2026
	rng2.seed = 2026
	var first: Array[Dictionary] = Cards.draw(rng1, 4, "elite", [], [])
	var second: Array[Dictionary] = Cards.draw(rng2, 4, "elite", [], [])
	if first != second or first.size() != 4:
		_fail("seeded rewards")
		return
	var seen: Dictionary = {}
	for card in first:
		if seen.has(card["id"]):
			_fail("duplicate offer")
			return
		seen[card["id"]] = true
	var turbo: Dictionary = Cards.CATALOG[0]
	var radiator: Dictionary = Cards.CATALOG[8]
	var tires: Dictionary = Cards.CATALOG[3]
	var suspension: Dictionary = Cards.CATALOG[12]
	var gear: Dictionary = Cards.CATALOG[6]
	var equipped := {"Turbo": turbo,"Refrigeracao": radiator,"Pneus": tires,"Suspensao": suspension,"Cambio": gear}
	var stats: Dictionary = Cards.calculate(equipped, [])
	var combo_names := Cards.synergies(equipped)
	if combo_names.size() != 3 or not is_equal_approx(float(stats["accel"]), 1.38) or not is_equal_approx(float(stats["grip"]), 1.34):
		_fail("synergies not applied")
		return
	var remap: Dictionary = Cards.CATALOG[14]
	var passives: Array = [remap,remap,remap]
	if not is_equal_approx(float(Cards.calculate({}, passives)["accel"]), 1.165):
		_fail("stacking is not additive")
		return
	if Cards.can_take(remap, [], passives):
		_fail("passive overcap")
		return
	var filtered = Cards.draw(rng1, 4, "normal", [], passives)
	for card in filtered:
		if str(card["id"]) == "remap":
			_fail("capped passive offered again")
			return
	if Cards.can_take(turbo, [turbo], []):
		_fail("already owned part should not be drawn")
		return
	var nothing: Dictionary = Cards.calculate({}, [])
	if not is_equal_approx(float(nothing["accel"]),1.0) or not Cards.synergies({}).is_empty():
		_fail("baseline car")
		return
	print("PASS: weighted seeded offers, unique cards, capped stacks, slot synergies and car stats")
	quit(0)

func _fail(reason: String) -> void:
	printerr("CARD TEST FAIL: ",reason)
	quit(1)
