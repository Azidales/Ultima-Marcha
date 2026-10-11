extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene._new_run()
	scene._pick_route(str(scene.campaign.available()[0]["id"]))
	scene._race_start()
	var button = scene.speed_button
	if not is_instance_valid(button):
		printerr("FAIL: speed button was not created")
		quit(1)
		return
	var expected := ["Velocidade 1x", "Velocidade 2x", "Velocidade 3x", "Velocidade 4x", "Velocidade 1x"]
	for i in range(expected.size()):
		if button.text != expected[i] or scene.replay != int(i % 4 + 1):
			printerr("FAIL: unexpected playback speed label at step ", i, ": ", button.text)
			quit(1)
			return
		if i < expected.size() - 1:
			button.pressed.emit()
	if scene.sim.finished:
		printerr("FAIL: switching speed ended the race")
		quit(1)
		return
	print("PASS: playback speed button updates 1x > 2x > 3x > 4x > 1x")
	quit(0)
