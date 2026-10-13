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


# Descricoes exibidas na carreira devem refletir os fatores usados em simulation.gd.
static func skill_effect(id: String, rank: int) -> String:
	var n: int = clampi(rank, 0, MAX_SKILL_LEVEL)
	match id:
		"curvas":
			return "Diminui em 6%% por nivel o risco relativo de erro nas curvas. Atual: -%d%%." % (6 * n)
		"correcao":
			return "Apos erro em curva, preserva mais velocidade (+2,5 pontos percentuais por nivel). Atual: +%.1f p.p." % (2.5 * float(n))
		"largada":
			return "Reduz em 8%% por nivel o risco relativo de patinar na largada. Atual: -%d%%." % (8 * n)
		"marchas":
			return "Reduz em 8%% por nivel o risco relativo de troca ruim e preserva +2 pontos de velocidade. Atual: -%d%% risco." % (8 * n)
		"foco":
			return "Diminui o risco relativo de TODOS os erros em 4,5%% por nivel. Atual: -%.1f%%." % (4.5 * float(n))
		"recuperacao":
			return "Apos erros em curva, preserva mais velocidade (+2 pontos percentuais por nivel). Atual: +%d p.p." % (2 * n)
	return ""

static func advanced_effect(branch: String) -> String:
	match branch:
		"controle":
			return "Apos duas curvas limpas, prepara tracado especial: ate +1,5 p.p. no aproveitamento da velocidade ate a proxima curva."
		"tecnica":
			return "Se nao patinar na largada, as DUAS proximas trocas de marcha ficam livres de erros."
		"concentracao":
			return "Nos ultimos 20% da corrida, quando estiver ate 30 m atras do rival, aproveita +1,8 p.p. da velocidade permitida, mas aumenta o risco de erro em 22%."
	return ""

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
