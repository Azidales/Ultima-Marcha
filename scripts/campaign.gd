extends RefCounted

const TOTAL_STAGES := 10
const BOSS_STAGES := [5, 10]
const TRACKS := ["Circuito urbano", "Rodovia", "Serra", "Vale", "Costa"]
const CONDITIONS := ["seca", "seca", "seca", "molhada"]
var levels: Array = []
var links: Dictionary = {}
var raced_path: Array[String] = []
var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var bulletins: Array[String] = []

func generate(value: int) -> void:
	seed_value = value
	rng.seed = value
	levels.clear()
	links.clear()
	raced_path.clear()
	bulletins.clear()
	var elite_stages: Array[int] = [rng.randi_range(2, 4), rng.randi_range(6, 7), rng.randi_range(8, 9)]
	for s in range(1, TOTAL_STAGES + 1):
		var count: int = 1 if s == 1 or s in BOSS_STAGES else rng.randi_range(2, 3)
		var elite_column: int = rng.randi_range(0, count - 1) if s in elite_stages else -1
		var level: Array[Dictionary] = []
		for col in range(count):
			var kind := "boss" if s in BOSS_STAGES else "elite" if col == elite_column else "normal"
			level.append({
				"id": "%d_%d" % [s,col],
				"stage": s,
				"column": col,
				"kind": kind,
				"weather": CONDITIONS[rng.randi_range(0, CONDITIONS.size() - 1)],
				"track": TRACKS[rng.randi_range(0, TRACKS.size() - 1)],
				"rival": "Rival %d-%d" % [s,col],
			})
		levels.append(level)
	for i in range(TOTAL_STAGES - 1):
		var sources: Array = levels[i]
		var targets: Array = levels[i + 1]
		for source in sources:
			var options: Array[String] = []
			var safe_choices: Array = []
			for target in targets:
				if str(target["kind"]) != "elite":
					safe_choices.append(target)
			var safe: Dictionary = safe_choices[rng.randi_range(0, safe_choices.size() - 1)]
			options.append(str(safe["id"]))
			for target in targets:
				var id := str(target["id"])
				if id != str(safe["id"]) and rng.randf() < 0.70:
					options.append(id)
			links[str(source["id"])] = options
		# Every node has incoming access, and every previous node has a non-elite exit.
		for target in targets:
			var found := false
			for source in sources:
				if str(target["id"]) in links[str(source["id"])]:
					found = true
					break
			if not found:
				var chosen: Dictionary = sources[rng.randi_range(0, sources.size() - 1)]
				links[str(chosen["id"])].append(str(target["id"]))

func available() -> Array[Dictionary]:
	if raced_path.size() >= TOTAL_STAGES:
		return []
	var next_stage: int = raced_path.size()
	if raced_path.is_empty():
		return [levels[0][0]]
	var result: Array[Dictionary] = []
	for node in levels[next_stage]:
		if str(node["id"]) in links.get(raced_path.back(), []):
			result.append(node)
	return result

func find_node(id: String) -> Dictionary:
	for row in levels:
		for node in row:
			if str(node["id"]) == id:
				return node
	return {}

func record_race(id: String) -> bool:
	for option in available():
		if str(option["id"]) == id:
			raced_path.append(id)
			return true
	return false

func latest_node() -> Dictionary:
	if raced_path.is_empty():
		return {}
	return find_node(raced_path.back())

func reward_count(node: Dictionary) -> int:
	return 2 if str(node.get("kind", "normal")) in ["elite", "boss"] else 1

func reachable_future(from_id: String, minimum_depth: int = 2, maximum_depth: int = 3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var frontier: Array[String] = [from_id]
	for distance in range(1, maximum_depth + 1):
		var upcoming: Array[String] = []
		for id in frontier:
			for next_id in links.get(id, []):
				if next_id not in upcoming:
					upcoming.append(next_id)
		if distance >= minimum_depth:
			for next_id in upcoming:
				result.append(find_node(next_id))
		frontier = upcoming
	return result

func maybe_bulletin() -> String:
	if raced_path.is_empty():
		return ""
	var stage: int = raced_path.size()
	if stage not in [2, 4, 7]:
		return ""
	var future: Array[Dictionary] = reachable_future(raced_path.back(), 2, 3)
	var wet := false
	var mountain := false
	var elite := false
	for node in future:
		if str(node.get("weather", "")) == "molhada":
			wet = true
		if str(node.get("track", "")) == "Serra":
			mountain = true
		if str(node.get("kind", "")) == "elite":
			elite = true
	var options: Array[String] = []
	if wet:
		options.append("RADIO: pilotos relatam chuva em pelo menos uma rota possivel nas proximas etapas.")
	if mountain:
		options.append("RADIO: existe um percurso de serra entre as rotas futuras.")
	if elite:
		options.append("RADIO: um rival de elite foi visto em uma das rotas mais adiante.")
	if options.is_empty():
		return ""
	var info: String = options[rng.randi_range(0, options.size() - 1)]
	bulletins.append(info)
	return info
