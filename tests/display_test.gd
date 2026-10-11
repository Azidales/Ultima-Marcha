extends SceneTree

func _initialize() -> void:
	var width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var aspect: String = str(ProjectSettings.get_setting("display/window/stretch/aspect"))
	var orientation: int = int(ProjectSettings.get_setting("display/window/handheld/orientation"))
	if width != height or aspect != "expand" or orientation != 6:
		printerr("FAIL: portrait/landscape layout config. width=", width, " height=", height, " aspect=", aspect, " orientation=", orientation)
		quit(1)
		return
	print("PASS: responsive portrait/landscape layout settings")
	quit(0)
