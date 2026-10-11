extends RefCounted

const POINT_XP := 200
const MAX_POINTS := 12
const MAX_SKILL_LEVEL := 3
const BRANCHES := {
	"controle": ["curvas", "correcao"],
	"tecnica": ["largada", "marchas"],
	"concentracao": ["foco", "recuperacao"]
}
const SKILL_LABELS := {
	"curvas": "Tracado preciso",
	"correcao": "Maos firmes",
	"largada": "Reflexos de largada",
	"marchas": "Troca perfeita",
	"foco": "Sangue frio",
	"recuperacao": "Recuperacao rapida"
}
const ADVANCED_LABELS := {
	"controle": "Mestre das Curvas",
	"tecnica": "Largada Perfeita",
	"concentracao": "Sob Pressao"
}

var experience: int = 0
var skills: Dictionary = {}
var advanced: Dictionary = {}
var running: bool = false
var save_path := "user://piloto_v1.json"

func _init() -> void:
	_reset_tree()

func _reset_tree() -> void:
	skills = {}
	advanced = {}
	for key in SKILL_LABELS.keys():
		skills[key] = 0
	for key in BRANCHES.keys():
		advanced[key] = false

func level() -> int:
	return mini(MAX_POINTS, experience / POINT_XP) + 1

func total_points() -> int:
	return mini(MAX_POINTS, experience / POINT_XP)

func spent() -> int:
	var used := 0
	for val in skills.values():
		used += int(val)
	for val in advanced.values():
		if bool(val):
			used += 2
	return used

func available_points() -> int:
	return maxi(0, total_points() - spent())

func branch_basics(branch: String) -> int:
	var sum := 0
	for key in BRANCHES.get(branch, []):
		sum += int(skills.get(key, 0))
	return sum

func upgrade(id: String) -> bool:
	if running or not skills.has(id) or available_points() < 1:
		return false
	if int(skills[id]) >= MAX_SKILL_LEVEL:
		return false
	skills[id] = int(skills[id]) + 1
	save()
	return true

func unlock(branch: String) -> bool:
	if running or not advanced.has(branch) or bool(advanced[branch]):
		return false
	if branch_basics(branch) < 4 or available_points() < 2:
		return false
	advanced[branch] = true
	save()
	return true

func respec() -> bool:
	if running:
		return false
	_reset_tree()
	save()
	return true

func start_run() -> bool:
	if running:
		return false
	running = true
	return true

func end_run() -> void:
	running = false

func grant_result(won: bool, race_kind: String, final_race: bool = false) -> int:
	var gained := 20
	if won:
		gained += 30
		if race_kind == "elite":
			gained += 20
		if race_kind == "boss":
			gained += 50
		if final_race:
			gained += 100
	experience += gained
	save()
	return gained

func snapshot(style: String) -> Dictionary:
	return {"skills": skills.duplicate(true), "advanced": advanced.duplicate(true), "style": style}

func save() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"version": 1,
		"experience": experience,
		"skills": skills,
		"advanced": advanced
	}))
	file.close()
	return true

func load_save() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
		return
	experience = maxi(0, int(parsed.get("experience", 0)))
	_reset_tree()
	var saved_skills: Dictionary = parsed.get("skills", {})
	var saved_advanced: Dictionary = parsed.get("advanced", {})
	for key in SKILL_LABELS.keys():
		skills[key] = mini(MAX_SKILL_LEVEL, maxi(0, int(saved_skills.get(key, 0))))
	for key in BRANCHES.keys():
		advanced[key] = bool(saved_advanced.get(key, false))
	# Invalid or obsolete save data must never grant more points than earned.
	var valid := spent() <= total_points()
	for branch in BRANCHES.keys():
		if bool(advanced[branch]) and branch_basics(branch) < 4:
			valid = false
	if not valid:
		_reset_tree()
