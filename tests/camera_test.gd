extends SceneTree

const Framing = preload("res://scripts/camera_framing.gd")

func _initialize() -> void:
	var portrait := Vector2(691, 1536)
	var landscape := Vector2(1536, 691)
	var square := Vector2(720, 720)
	for view_size in [portrait, landscape, square]:
		var width: float = Framing.world_width(view_size)
		var offset: Vector3 = Framing.offset(view_size)
		if width < 27.0 or width > 47.0 or offset.z <= 0.0:
			printerr("FAIL camera framing size: ", view_size, " width=", width)
			quit(1)
			return
	if Framing.world_width(landscape) <= Framing.world_width(portrait):
		printerr("FAIL landscape must reveal more road width")
		quit(1)
		return
	if Framing.focus_distance(10.0, 16.0) != 13.0:
		printerr("FAIL close duel must center both vehicles")
		quit(1)
		return
	if Framing.focus_distance(10.0, 110.0) != 10.0:
		printerr("FAIL distant rival should not pull player out of frame")
		quit(1)
		return
	print("PASS: adaptive race camera (portrait / landscape / duel / distant rival)")
	quit(0)
