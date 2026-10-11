extends SceneTree
const Map = preload("res://scripts/campaign.gd")

func _initialize() -> void:
	for seed_value in range(1, 61):
		var map = Map.new()
		map.generate(seed_value)
		var same = Map.new()
		same.generate(seed_value)
		if str(map.levels) != str(same.levels) or str(map.links) != str(same.links):
			_fail("map is not deterministic")
			return
		if map.levels.size() != 10 or map.levels[4].size() != 1 or map.levels[9].size() != 1:
			_fail("boss layout")
			return
		var elite_count := 0
		for row in map.levels:
			for node in row:
				if node["kind"] == "elite":
					elite_count += 1
		if elite_count != 3:
			_fail("must have three elite opportunities")
			return
		for index in range(9):
			for node in map.levels[index]:
				var exits: Array = map.links.get(str(node["id"]), [])
				if exits.is_empty():
					_fail("dead end")
					return
				var safe := false
				for id in exits:
					if map.find_node(str(id))["kind"] != "elite":
						safe = true
				if not safe:
					_fail("elite became mandatory")
					return
		for stage in range(1, 11):
			var choices = map.available()
			if choices.is_empty():
				_fail("no reachable choices")
				return
			var picked: Dictionary = choices[0]
			if not map.record_race(str(picked["id"])):
				_fail("valid route was rejected")
				return
			if stage == 5 or stage == 10:
				if picked["kind"] != "boss":
					_fail("wrong boss placement")
					return
			if stage < 10:
				map.maybe_bulletin()
		if map.available().size() != 0:
			_fail("run continues past final")
			return
		for msg in map.bulletins:
			if msg.is_empty():
				_fail("empty bulletin")
				return
	print("PASS: 60 reproducible maps, 10 stages, mandatory bosses, safe exits, no dead ends")
	quit(0)

func _fail(message: String) -> void:
	printerr("FAIL campaign: ", message)
	quit(1)
