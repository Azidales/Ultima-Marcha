extends RefCounted

# Parts occupy one slot each. Passive effects stack up to three copies.
const MAX_PASSIVE_STACKS := 3
const SLOTS := ["Turbo", "Pneus", "Cambio", "Refrigeracao", "Aerodinamica", "Suspensao"]
const RARITY_LABELS := {"comum": "COMUM", "rara": "RARA", "epica": "EPICA"}
const STATS := ["accel", "grip", "top", "cool", "wet_grip", "risk_reduction"]
const CATALOG := [
	{"id":"turbo_rua","name":"Turbo de Rua","type":"part","rarity":"comum","slot":"Turbo","accel":0.16,"cool":-0.08,"desc":"+16% aceleracao; -8% refrigeracao"},
	{"id":"turbo_pro","name":"Turbo de Competicao","type":"part","rarity":"rara","slot":"Turbo","accel":0.25,"cool":-0.17,"desc":"+25% aceleracao; -17% refrigeracao"},
	{"id":"turbo_duplo","name":"Turbo Duplo","type":"part","rarity":"epica","slot":"Turbo","accel":0.33,"top":0.07,"cool":-0.25,"desc":"+33% aceleracao, +7% final; -25% refrigeracao"},
	{"id":"pneu_esportivo","name":"Pneus Esportivos","type":"part","rarity":"comum","slot":"Pneus","grip":0.15,"desc":"+15% aderencia"},
	{"id":"pneu_slick","name":"Pneus Slick","type":"part","rarity":"rara","slot":"Pneus","grip":0.28,"wet_grip":-0.20,"desc":"+28% aderencia; ruins na chuva"},
	{"id":"pneu_chuva","name":"Pneus de Chuva","type":"part","rarity":"rara","slot":"Pneus","grip":0.09,"wet_grip":0.24,"desc":"+9% aderencia; +24% aderencia adicional na chuva"},
	{"id":"cambio_curto","name":"Cambio Curto","type":"part","rarity":"comum","slot":"Cambio","accel":0.13,"top":-0.04,"desc":"+13% aceleracao; -4% velocidade final"},
	{"id":"cambio_esportivo","name":"Cambio Esportivo","type":"part","rarity":"rara","slot":"Cambio","accel":0.17,"top":0.03,"desc":"+17% aceleracao; +3% final"},
	{"id":"radiador_rua","name":"Radiador Reforcado","type":"part","rarity":"comum","slot":"Refrigeracao","cool":0.23,"desc":"+23% refrigeracao"},
	{"id":"radiador_corrida","name":"Radiador de Corrida","type":"part","rarity":"rara","slot":"Refrigeracao","cool":0.42,"desc":"+42% refrigeracao"},
	{"id":"aero_rua","name":"Aerofolio","type":"part","rarity":"comum","slot":"Aerodinamica","grip":0.08,"top":0.02,"desc":"+8% aderencia; +2% final"},
	{"id":"aero_ativo","name":"Aerodinamica Ativa","type":"part","rarity":"epica","slot":"Aerodinamica","grip":0.19,"top":0.06,"desc":"+19% aderencia; +6% final"},
	{"id":"suspensao_rua","name":"Suspensao Esportiva","type":"part","rarity":"comum","slot":"Suspensao","grip":0.12,"desc":"+12% aderencia"},
	{"id":"suspensao_ativa","name":"Suspensao Adaptativa","type":"part","rarity":"epica","slot":"Suspensao","grip":0.25,"desc":"+25% aderencia"},
	{"id":"remap","name":"Remapeamento","type":"passive","rarity":"comum","accel":0.055,"desc":"+5,5% aceleracao por acumulo (max. 3)"},
	{"id":"curvas","name":"Tecnica de Curvas","type":"passive","rarity":"comum","grip":0.055,"desc":"+5,5% aderencia por acumulo (max. 3)"},
	{"id":"escape","name":"Escapamento Livre","type":"passive","rarity":"comum","top":0.045,"desc":"+4,5% velocidade final por acumulo (max. 3)"},
	{"id":"telemetria","name":"Telemetria","type":"passive","rarity":"rara","risk_reduction":0.07,"desc":"-7% risco relativo de erros por acumulo (max. 3)"},
	{"id":"refrigeracao","name":"Dutos de Resfriamento","type":"passive","rarity":"rara","cool":0.10,"desc":"+10% refrigeracao por acumulo (max. 3)"},
	{"id":"vacuodinamico","name":"Eficiencia Aerodinamica","type":"passive","rarity":"epica","top":0.09,"desc":"+9% velocidade final por acumulo (max. 3)"},
	{"id":"engenharia","name":"Preparacao Fina","type":"passive","rarity":"epica","accel":0.085,"cool":-0.035,"desc":"+8,5% aceleracao; -3,5% refrigeracao por acumulo"}
]

static func stacks(passives: Array, card_id: String) -> int:
	var total := 0
	for item in passives:
		if str(item.get("id", "")) == card_id:
			total += 1
	return total

static func can_take(card: Dictionary, inventory: Array, passives: Array) -> bool:
	var id := str(card.get("id", ""))
	if id.is_empty():
		return false
	if str(card.get("type", "")) == "passive":
		return stacks(passives, id) < MAX_PASSIVE_STACKS
	for owned in inventory:
		if str(owned.get("id", "")) == id:
			return false
	return true

static func _weight(rarity: String, kind: String) -> int:
	if kind == "boss":
		return int({"comum": 22, "rara": 48, "epica": 30}.get(rarity, 0))
	if kind == "elite":
		return int({"comum": 40, "rara": 42, "epica": 18}.get(rarity, 0))
	return int({"comum": 65, "rara": 27, "epica": 8}.get(rarity, 0))

static func draw(rng: RandomNumberGenerator, count: int, kind: String, inventory: Array, passives: Array) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for card in CATALOG:
		if can_take(card, inventory, passives):
			pool.append(card.duplicate(true))
	var drawn: Array[Dictionary] = []
	for unused in range(mini(count, pool.size())):
		var total_weight := 0
		for card in pool:
			total_weight += _weight(str(card["rarity"]), kind)
		if total_weight <= 0:
			break
		var roll: int = rng.randi_range(0, total_weight - 1)
		var index := 0
		for i in range(pool.size()):
			roll -= _weight(str(pool[i]["rarity"]), kind)
			if roll < 0:
				index = i
				break
		drawn.append(pool[index])
		pool.remove_at(index)
	return drawn

static func synergies(equipped: Dictionary) -> Array[String]:
	var active: Array[String] = []
	if equipped.has("Pneus") and equipped.has("Suspensao"):
		active.append("Conjunto de Chassi: +7% aderencia")
	if equipped.has("Turbo") and equipped.has("Refrigeracao"):
		active.append("Turbo Refrigerado: +5% aceleracao")
	if equipped.has("Turbo") and equipped.has("Cambio"):
		active.append("Trem de Forca: +4% aceleracao")
	return active


# Descricao exata do bonus aditivo acumulado das cartas passivas.
static func passive_bonus(card: Dictionary, count: int) -> String:
	if str(card.get("type", "")) != "passive":
		return ""
	if count <= 0:
		return "Nenhum bonus ativo"
	var effects: Array[String] = []
	var labels := {
		"accel": "Aceleracao",
		"grip": "Aderencia",
		"top": "Velocidade final",
		"cool": "Refrigeracao",
		"wet_grip": "Aderencia na chuva",
		"risk_reduction": "Reducao de risco"
	}
	for key in STATS:
		var raw: float = float(card.get(key, 0.0)) * float(count) * 100.0
		if not is_zero_approx(raw):
			effects.append("%s: %+.1f%%" % [str(labels[key]), raw])
	return " | ".join(effects)

static func calculate(equipped: Dictionary, passives: Array) -> Dictionary:
	var result := {"accel":1.0, "grip":1.0, "top":1.0, "cool":1.0, "wet_grip":0.0, "risk_reduction":0.0}
	for part in equipped.values():
		for key in STATS:
			result[key] += float(part.get(key, 0.0))
	for item in passives:
		for key in STATS:
			result[key] += float(item.get(key, 0.0))
	if equipped.has("Pneus") and equipped.has("Suspensao"):
		result["grip"] += 0.07
	if equipped.has("Turbo") and equipped.has("Refrigeracao"):
		result["accel"] += 0.05
	if equipped.has("Turbo") and equipped.has("Cambio"):
		result["accel"] += 0.04
	result["risk_reduction"] = clampf(float(result["risk_reduction"]), 0.0, 0.35)
	result["wet_grip"] = clampf(float(result["wet_grip"]), -0.25, 0.5)
	for key in ["accel", "grip", "top", "cool"]:
		result[key] = clampf(float(result[key]), 0.4, 2.2)
	return result
