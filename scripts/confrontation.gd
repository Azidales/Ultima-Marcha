extends RefCounted

const Race = preload("res://scripts/simulation.gd")
const Cards = preload("res://scripts/cards.gd")

# This screen deliberately does not claim an estimated chance to win.
# It only compares quantities derived from the SAME equations used by tick().
static func rival_factor(stage: int, route: Dictionary) -> float:
	var factor: float = 0.95 + float(stage - 1) * 0.044
	if str(route.get("kind", "normal")) == "elite":
		factor += 0.12
	if stage == 5 or stage == 10:
		factor += 0.10
	return factor

static func weather_multiplier(route: Dictionary, stat: Dictionary) -> float:
	if str(route.get("weather", "seca")) != "molhada":
		return 1.0
	return clampf(0.82 + float(stat.get("wet_grip", 0.0)), 0.5, 1.15)

static func preview_stats(equipped: Dictionary, passives: Array, part: Dictionary) -> Dictionary:
	var future: Dictionary = equipped.duplicate(true)
	if str(part.get("type", "")) == "part":
		future[str(part.get("slot", ""))] = part.duplicate(true)
	return Cards.calculate(future, passives)

static func comparison(stats: Dictionary, stage: int, route: Dictionary, pilot: Dictionary) -> Array[Dictionary]:
	var factor: float = rival_factor(stage, route)
	var wet_player: float = weather_multiplier(route, stats)
	var wet_rival: float = 0.82 if str(route.get("weather", "seca")) == "molhada" else 1.0
	var turn: float = clampf(0.5 * (1.20 if str(route.get("track", "")) == "Serra" else 1.0), 0.0, 1.0)
	var driver = Race.new()
	driver.begin(stats, stage, 1, route, pilot)
	var risk_player: float = driver.error_chance("curve", turn, float(stats.get("grip", 1.0)) * wet_player) * 100.0
	var risk_rival: float = (0.08 + 0.08 * turn) * 100.0
	return [
		{"key": "launch", "title": "SAIDA", "player": float(stats.get("accel", 1.0)) * 100.0, "rival": 100.0 * 5.9 * factor / 6.2, "lower_better": false, "hint": "Resposta de aceleracao"},
		{"key": "corner", "title": "CURVA", "player": sqrt(float(stats.get("grip", 1.0)) * wet_player) * 100.0, "rival": sqrt(factor * wet_rival) * 100.0, "lower_better": false, "hint": "Velocidade permitida nas curvas"},
		{"key": "straight", "title": "RETA", "player": float(stats.get("top", 1.0)) * 100.0, "rival": 100.0 * 38.0 * factor / 39.0, "lower_better": false, "hint": "Velocidade maxima"},
		{"key": "risk", "title": "DERRAPAGEM", "player": risk_player, "rival": risk_rival, "lower_better": true, "hint": "Chance de erro por verificacao de curva • menor e melhor"}
	]

static func advantage(metric: Dictionary) -> int:
	var difference: float = float(metric.get("player", 0.0)) - float(metric.get("rival", 0.0))
	if bool(metric.get("lower_better", false)):
		difference = -difference
	# Close contests count as ties, not misleading wins.
	if absf(difference) < 1.5:
		return 0
	return 1 if difference > 0.0 else -1

static func summary(rows: Array[Dictionary]) -> String:
	var strongest := ""
	var score := -INF
	var weakest := ""
	var low_score := INF
	for metric in rows:
		var delta: float = float(metric["player"]) - float(metric["rival"])
		if bool(metric["lower_better"]):
			delta = -delta
		if delta > score:
			score = delta
			strongest = str(metric["title"])
		if delta < low_score:
			low_score = delta
			weakest = str(metric["title"])
	if weakest == strongest or absf(score - low_score) < 1.5:
		return "DISPUTA EQUILIBRADA: os indicadores estao proximos."
	return "PONTO FORTE: %s  •  ATENCAO: %s" % [strongest, weakest]

static func preview_delta(current: Array[Dictionary], future: Array[Dictionary]) -> String:
	var values: Array[String] = []
	for i in range(mini(current.size(), future.size())):
		var before: float = float(current[i].get("player", 0.0))
		var after: float = float(future[i].get("player", 0.0))
		var difference: float = after - before
		if absf(difference) >= 0.05:
			values.append("%s %+.1f" % [str(current[i].get("title", "?")), difference])
	if values.is_empty():
		return "Sem mudanca mensuravel nesta pista"
	return "  •  ".join(PackedStringArray(values))
