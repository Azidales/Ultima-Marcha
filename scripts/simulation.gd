extends RefCounted

const STEP := 1.0 / 60.0
const LENGTH := 540.0
var progress_player := 0.0
var progress_rival := 0.0
var speed_player := 0.0
var speed_rival := 0.0
var heat := 0.0
var time := 0.0
var finished := false
var winner := ""
var stage := 1
var event: Dictionary = {}
var stats: Dictionary = {}
var driver: Dictionary = {}
var rng := RandomNumberGenerator.new()
var log: Array[String] = []
var next_error := 65.0
var rival_error := 75.0
var next_shift := 50.0
var shifted := 0
var clean_curves := 0
var mastery_ready := false
var perfect_shifts := 0
var launch_checked := false
var sprint_announced := false

func begin(s: Dictionary, level: int, seed_value: int, route: Dictionary = {}, pilot: Dictionary = {}) -> void:
	stats = s.duplicate(true)
	event = route.duplicate(true)
	driver = pilot.duplicate(true)
	stage = level
	rng.seed = seed_value
	progress_player = 0.0
	progress_rival = 0.0
	speed_player = 0.0
	speed_rival = 0.0
	heat = 0.0
	time = 0.0
	finished = false
	winner = ""
	next_error = 65.0
	rival_error = 75.0
	next_shift = 50.0
	shifted = 0
	clean_curves = 0
	mastery_ready = false
	perfect_shifts = 0
	launch_checked = false
	sprint_announced = false
	log.clear()

func curve(s: float) -> float:
	return clampf((sin(s * 0.027) + sin(s * 0.055 + 0.7) * 0.5 + 0.7) * 0.36, 0.0, 1.0)

func pilot_skill(id: String) -> int:
	var skillset: Dictionary = driver.get("skills", {})
	return int(skillset.get(id, 0))

func advanced_active(branch: String) -> bool:
	var unlocked: Dictionary = driver.get("advanced", {})
	return bool(unlocked.get(branch, false))

func style() -> String:
	var selected := str(driver.get("style", "equilibrado"))
	return selected if selected in ["conservador", "equilibrado", "agressivo"] else "equilibrado"

func _style_risk_factor() -> float:
	if style() == "conservador":
		return 0.67
	if style() == "agressivo":
		return 1.52
	return 1.0

func _under_pressure() -> bool:
	var gap: float = progress_rival - progress_player
	return advanced_active("concentracao") and progress_player >= LENGTH * 0.80 and gap > 0.0 and gap < 30.0

func error_chance(kind: String, turn: float, effective_grip: float) -> float:
	var chance: float = 0.0
	if kind == "curve":
		chance = (0.05 + 0.08 * turn / maxf(effective_grip, 0.5))
		chance *= 1.0 - 0.06 * float(pilot_skill("curvas"))
	elif kind == "launch":
		chance = 0.12 * (1.0 - 0.08 * float(pilot_skill("largada")))
	elif kind == "shift":
		chance = 0.14 * (1.0 - 0.08 * float(pilot_skill("marchas")))
	else:
		return 0.0
	chance *= _style_risk_factor()
	chance *= 1.0 - 0.045 * float(pilot_skill("foco"))
	chance *= 1.0 - clampf(float(stats.get("risk_reduction", 0.0)),0.0,0.35)
	if _under_pressure():
		chance *= 1.22
	return clampf(chance, 0.01, 0.45)

func driving_margin() -> float:
	var margin := 0.94 if style() == "conservador" else 1.0 if style() == "agressivo" else 0.975
	if heat > 93.0:
		margin = minf(margin, 0.94)
	if _under_pressure():
		margin += 0.018
		if not sprint_announced:
			log.append("Sob Pressao: ataque final")
			sprint_announced = true
	if mastery_ready:
		margin += 0.015
	return minf(1.0, margin)

func tick(dt: float) -> void:
	if finished:
		return
	time += dt
	var track_factor := 1.20 if str(event.get("track", "")) == "Serra" else 1.0
	var pcurve: float = clampf(curve(progress_player) * track_factor, 0.0, 1.0)
	var rcurve: float = clampf(curve(progress_rival) * track_factor, 0.0, 1.0)
	var p_grip: float = float(stats.get("grip", 1.0))
	var p_top: float = float(stats.get("top", 1.0))
	var p_acc: float = float(stats.get("accel", 1.0))
	var cool: float = float(stats.get("cool", 1.0))
	var rival_factor: float = 0.95 + float(stage - 1) * 0.044
	if str(event.get("kind", "normal")) == "elite":
		rival_factor += 0.12
	if stage == 5 or stage == 10:
		rival_factor += 0.10
	# Wet-weather tires change the available grip, not the motor's raw power.
	var wet_factor: float = clampf(0.82 + float(stats.get("wet_grip", 0.0)), 0.5, 1.15) if str(event.get("weather", "")) == "molhada" else 1.0
	var player_limit: float = lerpf(39.0 * p_top, 18.0 * sqrt(p_grip * wet_factor), pcurve)
	var rival_limit: float = lerpf(38.0 * rival_factor, 18.0 * sqrt(rival_factor * wet_factor), rcurve)
	var thermal_factor := 0.72 if heat >= 90.0 else 1.0
	var momentum_bonus := 1.0
	# Better pilot technique minimizes avoidable acceleration loss; never raises the speed cap.
	speed_player = clampf(speed_player + (6.2 * p_acc * thermal_factor * momentum_bonus - 0.003 * speed_player * speed_player) * dt, 0.0, player_limit * driving_margin())
	speed_rival = clampf(speed_rival + (5.9 * rival_factor - 0.003 * speed_rival * speed_rival) * dt, 0.0, rival_limit * 0.985)
	progress_player += speed_player * dt
	progress_rival += speed_rival * dt
	heat = clampf(heat + (speed_player / maxf(player_limit, 1.0)) * 12.0 * dt - cool * 7.5 * dt, 0.0, 100.0)
	if not launch_checked and time >= 0.75:
		launch_checked = true
		if rng.randf() < error_chance("launch", 0.0, p_grip * wet_factor):
			speed_player *= 0.83
			log.append("Largada com patinagem")
		elif advanced_active("tecnica"):
			perfect_shifts = 2
			log.append("Largada Perfeita ativada")
	if progress_player >= next_shift:
		next_shift += 95.0
		shifted += 1
		if perfect_shifts > 0:
			perfect_shifts -= 1
			log.append("Troca perfeita automatica")
		elif rng.randf() < error_chance("shift", 0.0, p_grip):
			speed_player *= 0.87 + 0.02 * float(pilot_skill("marchas"))
			log.append("Troca de marcha imperfeita")
	if progress_player > next_error:
		next_error += 85.0
		var clean: bool = rng.randf() >= error_chance("curve", pcurve, p_grip * wet_factor)
		if clean:
			clean_curves += 1
			if mastery_ready:
				log.append("Tracado Perfeito executado")
				mastery_ready = false
			elif advanced_active("controle") and clean_curves >= 2:
				mastery_ready = true
				clean_curves = 0
				log.append("Mestre das Curvas preparado")
		else:
			clean_curves = 0
			mastery_ready = false
			var serious: bool = rng.randf() < 0.13
			var correction: float = 0.025 * float(pilot_skill("correcao")) + 0.02 * float(pilot_skill("recuperacao"))
			speed_player *= minf(0.92, (0.60 if serious else 0.86) + correction)
			log.append("Saida de pista" if serious else "Correcao de trajetoria")
	if progress_rival > rival_error:
		rival_error += 95.0
		if rng.randf() < 0.08 + 0.08 * rcurve:
			speed_rival *= 0.65 if rng.randf() < 0.12 else 0.87
	if progress_player >= LENGTH or progress_rival >= LENGTH:
		finished = true
		winner = "player" if progress_player >= LENGTH and progress_player >= progress_rival else "rival"
