extends SceneTree

const Pilot = preload("res://scripts/pilot.gd")
const Cards = preload("res://scripts/cards.gd")

func _initialize() -> void:
	call_deferred("_run")

func _contains(node: Node, text_part: String) -> bool:
	if node is Label and text_part in str(node.text):
		return true
	for child in node.get_children():
		if _contains(child, text_part):
			return true
	return false

func _fail(msg: String) -> void:
	printerr("DESCRIPTION FAIL: ", msg)
	quit(1)

func _run() -> void:
	for id in Pilot.SKILL_LABELS.keys():
		if Pilot.skill_effect(str(id), 0).is_empty() or Pilot.skill_effect(str(id), 3).is_empty():
			_fail("missing skill " + str(id))
			return
	for branch in Pilot.BRANCHES.keys():
		if Pilot.advanced_effect(str(branch)).is_empty():
			_fail("missing advanced " + str(branch))
			return
	var telemetry: Dictionary = Cards.CATALOG[17]
	if str(telemetry["id"]) != "telemetria" or "14.0%" not in Cards.passive_bonus(telemetry, 2) or "21.0%" not in Cards.passive_bonus(telemetry, 3):
		_fail("telemetry bonus calculation")
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.pilot.save_path = "user://stat_descriptions_ci.json"
	game._open_career()
	if not _contains(game.layer, "Diminui em 6%") or not _contains(game.layer, "DUAS proximas trocas"):
		_fail("pilot explanations invisible")
		return
	game._new_run()
	game._pick_route(str(game.campaign.available()[0]["id"]))
	if not _contains(game.layer, "O QUE CADA ATRIBUTO FAZ") or not _contains(game.layer, "REFRIG:"):
		_fail("garage glossary invisible")
		return
	game.passives.append(telemetry.duplicate(true))
	game.passives.append(telemetry.duplicate(true))
	game._set_garage_tab("efeitos")
	if not _contains(game.layer, "ACUMULOS 2/3") or not _contains(game.layer, "14.0%"):
		_fail("accumulated passive description invisible")
		return
	game.cards.clear()
	game.cards.append(telemetry.duplicate(true))
	game.reward_picks_left = 1
	game._set_screen("reward")
	if not _contains(game.layer, "ACUMULOS: 2/3") or not _contains(game.layer, "21.0%"):
		_fail("future stack bonus invisible")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.pilot.save_path))
	print("PASS: pilot explanation, stat glossary, passive stack preview")
	quit(0)
