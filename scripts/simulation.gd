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
var rng := RandomNumberGenerator.new()
var log: Array[String] = []
var next_error := 65.0
var rival_error := 75.0

func begin(s: Dictionary, level: int, seed_value: int, route: Dictionary = {}) -> void:
	stats = s.duplicate(true)
	event = route.duplicate(true)
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
	log.clear()

func curve(s: float) -> float:
	return clampf((sin(s * 0.027) + sin(s * 0.055 + 0.7) * 0.5 + 0.7) * 0.36, 0.0, 1.0)

func tick(dt: float) -> void:
	if finished:
		return
	time += dt
	var track_factor := 1.20 if str(event.get("track",""))=="Serra" else 1.0
	var pcurve: float = clampf(curve(progress_player) * track_factor,0.0,1.0)
	var rcurve: float = clampf(curve(progress_rival) * track_factor,0.0,1.0)
	var p_grip := float(stats.get("grip",1.0))
	var p_top := float(stats.get("top",1.0))
	var p_acc := float(stats.get("accel",1.0))
	var cool := float(stats.get("cool",1.0))
	var rival_factor := 0.95 + float(stage - 1) * 0.044
	if str(event.get("kind","normal")) == "elite":
		rival_factor += 0.12
	if stage == 5 or stage == 10:
		rival_factor += 0.10
	var wet_factor := 0.82 if str(event.get("weather",""))=="molhada" else 1.0
	var player_limit := lerpf(39.0 * p_top, 18.0 * sqrt(p_grip * wet_factor), pcurve)
	var rival_limit := lerpf(38.0 * rival_factor, 18.0 * sqrt(rival_factor * wet_factor), rcurve)
	var thermal_factor := 0.72 if heat >= 90.0 else 1.0
	speed_player = clampf(speed_player + (6.2 * p_acc * thermal_factor - 0.003 * speed_player * speed_player) * dt, 0.0, player_limit)
	speed_rival = clampf(speed_rival + (5.9 * rival_factor - 0.003 * speed_rival * speed_rival) * dt, 0.0, rival_limit)
	progress_player += speed_player * dt
	progress_rival += speed_rival * dt
	heat = clampf(heat + (speed_player / maxf(player_limit, 1.0)) * 12.0 * dt - cool * 7.5 * dt, 0.0, 100.0)
	if progress_player > next_error:
		next_error += 85.0
		if rng.randf() < (0.05 + 0.08 * pcurve / maxf(p_grip * wet_factor,0.5)):
			var serious := rng.randf() < 0.13
			speed_player *= 0.60 if serious else 0.86
			log.append("Saida de pista" if serious else "Correcao de trajetoria")
	if progress_rival > rival_error:
		rival_error += 95.0
		if rng.randf() < 0.08 + 0.08 * rcurve:
			speed_rival *= 0.65 if rng.randf() < 0.12 else 0.87
	if progress_player >= LENGTH or progress_rival >= LENGTH:
		finished = true
		winner = "player" if progress_player >= LENGTH and progress_player >= progress_rival else "rival"
