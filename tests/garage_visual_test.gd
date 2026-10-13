extends SceneTree
const Confrontation = preload("res://scripts/confrontation.gd")
const Cards = preload("res://scripts/cards.gd")

func _fail(s: String) -> void:
	printerr("GARAGE VISUAL FAIL: ", s)
	quit(1)

func _find(node: Node, desired: String) -> Node:
	if node.name == desired:
		return node
	for n in node.get_children():
		var result: Node = _find(n, desired)
		if result != null:
			return result
	return null

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.pilot.save_path = "user://garage_visual_ci.json"
	game._new_run()
	game._pick_route(str(game.campaign.available()[0]["id"]))
	for key in ["launch","corner","straight","risk"]:
		if _find(game.layer, "Metric_"+key) == null:
			_fail("missing first comparison for "+key)
			return
	var old_stats: Dictionary = game._stats()
	var part: Dictionary = Cards.CATALOG[0].duplicate(true)
	game.inventory.append(part)
	game._set_garage_tab("pecas")
	game._preview_part(part)
	if game.part_preview.is_empty() or game.equipped.has("Turbo"):
		_fail("preview equipped something without confirmation")
		return
	if _find(game.layer, "Metric_launch") == null:
		_fail("preview missing comparison bars")
		return
	var future_stats: Dictionary = Confrontation.preview_stats(game.equipped, game.passives, part)
	if float(future_stats["accel"]) <= float(old_stats["accel"]):
		_fail("preview did not improve acceleration")
		return
	game._equip_preview()
	if not game.part_preview.is_empty() or str(game.equipped.get("Turbo", {}).get("id", "")) != "turbo_rua":
		_fail("equipment not committed")
		return
	if not is_equal_approx(float(game._stats()["accel"]), float(future_stats["accel"])):
		_fail("preview and actual stats disagree")
		return
	if game.inventory.size() != 1:
		_fail("free swap deleted inventory")
		return
	game._set_garage_tab("resumo")
	if _find(game.layer, "Metric_launch") == null:
		_fail("bars missing after upgrade")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.pilot.save_path))
	print("PASS: visual comparisons, preview without purchase, confirm swap and recomputed bars")
	quit(0)
