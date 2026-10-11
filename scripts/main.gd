extends Node3D

const Race = preload("res://scripts/simulation.gd")
const COLORS = {"bg":Color("111927"),"panel":Color("19283b"),"accent":Color("52dfd0"),"white":Color("f5f7fb"),"dim":Color("b1c3d3")}
const CARDS = [
	{"name":"Turbo de Rua","slot":"Turbo","type":"part","accel":0.19,"cool":-0.10,"desc":"+19% aceleracao; aumenta o calor"},
	{"name":"Pneus Slick","slot":"Pneus","type":"part","grip":0.28,"desc":"+28% aderencia"},
	{"name":"Cambio Curto","slot":"Cambio","type":"part","accel":0.17,"top":-0.06,"desc":"+17% aceleracao; -6% final"},
	{"name":"Radiador Pro","slot":"Refrigeracao","type":"part","cool":0.40,"desc":"+40% refrigeracao"},
	{"name":"Aerofolio","slot":"Aerodinamica","type":"part","grip":0.13,"top":0.03,"desc":"+13% aderencia; +3% final"},
	{"name":"Mapa Agressivo","type":"passive","accel":0.08,"desc":"+8% aceleracao permanente"},
	{"name":"Tecnica de Curvas","type":"passive","grip":0.08,"desc":"+8% aderencia permanente"},
	{"name":"Escapamento Livre","type":"passive","top":0.07,"desc":"+7% velocidade maxima"}
]
var sim = Race.new()
var stage := 1
var screen := "menu"
var equipped: Dictionary = {}
var inventory: Array[Dictionary] = []
var passives: Array[Dictionary] = []
var cards: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var replay := 1
var accumulator := 0.0
var camera: Camera3D
var player: Node3D
var rival: Node3D
var layer: CanvasLayer
var progress_text: Label
var speed_text: Label
var heat_text: Label
var won := false

func _ready() -> void:
	rng.randomize()
	_make_track()
	get_viewport().size_changed.connect(_draw_ui)
	_draw_ui()

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _block(parent: Node3D, dimensions: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	item.mesh = shape
	item.material_override = _mat(color)
	item.position = pos
	parent.add_child(item)
	return item

func _road_x(s: float) -> float:
	return sin(s * 0.015) * 5.0 + sin(s * 0.033) * 2.0

func _at(s: float, lateral: float = 0.0) -> Vector3:
	return Vector3(_road_x(s) + lateral, 0.0, -s)

func _make_track() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8cb4c0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8e2e1")
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,25,-10)
	sun.light_energy = 1.4
	add_child(sun)
	_block(self, Vector3(150,0.2,1150),Vector3(0,-0.3,-280),Color("356a51"))
	for i in range(110):
		var s := float(i)*5.0
		var center := _at(s)
		var road := _block(self, Vector3(12,0.08,5.1),center,Color("3b4048"))
		road.rotation.y = atan2(_road_x(s+1)-_road_x(s-1),-2.0)
		if i%3==0:
			_block(self,Vector3(0.18,0.02,2.5),center+Vector3.UP*0.08,Color("d6dde3"))
		if i%6==0:
			for side in [-1.0,1.0]:
				var tree := _at(s,side*17)
				_block(self,Vector3(0.8,2.9,0.8),tree+Vector3.UP*1.4,Color("71533d"))
				_block(self,Vector3(4.0,4.4,4.0),tree+Vector3.UP*4.6,Color("24724e"))
	player = _make_car(Color("248ce7"))
	rival = _make_car(Color("df524b"))
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	camera.position = Vector3(27,36,45)
	camera.look_at(_at(15), Vector3.UP)

func _make_car(color: Color) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	_block(root,Vector3(2.25,0.65,4.0),Vector3(0,0.65,0),color)
	_block(root,Vector3(1.85,0.65,2.0),Vector3(0,1.22,0.15),color.darkened(0.2))
	_block(root,Vector3(1.6,0.10,1.4),Vector3(0,1.57,0.0),Color("92c7df"))
	for x in [-1.2,1.2]:
		for z in [-1.3,1.25]:
			_block(root,Vector3(0.46,0.65,0.78),Vector3(x,0.45,z),Color("14191f"))
	return root

func _process(delta: float) -> void:
	if screen=="race" and not sim.finished:
		accumulator += minf(delta,0.1)*float(replay)
		var steps := 0
		while accumulator >= Race.STEP and steps < 45:
			sim.tick(Race.STEP)
			accumulator -= Race.STEP
			steps += 1
		if sim.finished:
			won = sim.winner=="player"
			_set_screen("result")
	var a: float = sim.progress_player if screen=="race" else 18.0
	var b: float = sim.progress_rival if screen=="race" else 28.0
	player.position = _at(a,-1.8)+Vector3.UP*0.2
	rival.position = _at(b,1.8)+Vector3.UP*0.2
	var focus: float = (a+b)*0.5
	var target := _at(focus)+Vector3(28,40,48)
	camera.global_position = camera.global_position.lerp(target,minf(1.0,delta*3.0))
	camera.look_at(_at(focus+13.0), Vector3.UP)
	camera.size = 32.0 if get_viewport().size.x < get_viewport().size.y else 38.0
	if screen=="race" and progress_text!=null:
		progress_text.text = "CORRIDA %d/10  •  %d%%" % [stage,roundi(100.0*minf(1.0,sim.progress_player/Race.LENGTH))]
		speed_text.text = "%d km/h" % roundi(sim.speed_player*3.6)
		heat_text.text = "CALOR: %d%%  |  Rival: %.0f m" % [roundi(sim.heat),sim.progress_rival-sim.progress_player]

func _stats() -> Dictionary:
	var result := {"accel":1.0,"grip":1.0,"top":1.0,"cool":1.0}
	for item in equipped.values():
		for key in result.keys():
			result[key] += float(item.get(key,0.0))
	for item in passives:
		for key in result.keys():
			result[key] += float(item.get(key,0.0))
	return result

func _new_run() -> void:
	stage = 1
	equipped.clear()
	inventory.clear()
	passives.clear()
	_set_screen("garage")

func _race_start() -> void:
	accumulator = 0.0
	replay = 1
	sim.begin(_stats(),stage,rng.randi())
	_set_screen("race")

func _skip() -> void:
	while not sim.finished:
		sim.tick(Race.STEP)
	won = sim.winner=="player"
	_set_screen("result")

func _choose(card: Dictionary) -> void:
	if str(card.get("type"))=="part":
		inventory.append(card.duplicate(true))
		equipped[str(card["slot"])] = card.duplicate(true)
	else:
		passives.append(card.duplicate(true))
	stage += 1
	_set_screen("garage")

func _equip(card: Dictionary) -> void:
	equipped[str(card["slot"])] = card
	_draw_ui()

func _set_screen(name: String) -> void:
	screen = name
	if screen=="reward":
		cards.clear()
		var pool := CARDS.duplicate(true)
		pool.shuffle()
		for i in range(3):
			cards.append(pool[i])
	_draw_ui()

func _label(s: String, size: int=21, color: Color=Color.WHITE) -> Label:
	var l := Label.new()
	l.text=s
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(s: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text=s
	b.custom_minimum_size=Vector2(185,58)
	b.add_theme_font_size_override("font_size",20)
	b.pressed.connect(fn)
	return b

func _draw_ui() -> void:
	progress_text=null
	speed_text=null
	heat_text=null
	if layer!=null:
		layer.queue_free()
	layer=CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	layer.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation",12)
	margin.add_child(outer)
	if screen=="race":
		progress_text=_label("CORRIDA",25,COLORS["accent"])
		speed_text=_label("0 km/h",24)
		heat_text=_label("Calor 0%",20)
		outer.add_child(progress_text)
		var spacer := Control.new()
		spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
		outer.add_child(spacer)
		outer.add_child(speed_text)
		outer.add_child(heat_text)
		var buttons := HBoxContainer.new()
		outer.add_child(buttons)
		buttons.add_child(_button("Velocidade "+str(replay)+"x",func(): replay=2 if replay==1 else 4 if replay==2 else 1))
		buttons.add_child(_button("Pular",_skip))
		return
	var back := ColorRect.new()
	back.color=Color(0.04,0.07,0.13,0.87)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(back)
	margin.move_child(back,0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",15)
	scroll.add_child(body)
	if screen=="menu":
		body.add_child(_label("ULTIMA MARCHA",42,COLORS["accent"]))
		body.add_child(_label("ROGUELIKE DE CORRIDAS AUTOMATICAS",19))
		body.add_child(_label("Monte seu carro, enfrente rivais e escolha cartas a cada vitoria. Gire o aparelho quando quiser.",20))
		body.add_child(_button("INICIAR TENTATIVA",_new_run))
	elif screen=="garage":
		body.add_child(_label("GARAGEM • CORRIDA %d DE 10" % stage,31,COLORS["accent"]))
		body.add_child(_label("Hatch 1.6 | inventario livre",20))
		var s := _stats()
		body.add_child(_label("ACEL: %d%%  ADERENCIA: %d%%\nFINAL: %d%%  REFRIG: %d%%" % [roundi(float(s["accel"])*100.0),roundi(float(s["grip"])*100.0),roundi(float(s["top"])*100.0),roundi(float(s["cool"])*100.0)]))
		body.add_child(_label("PECAS EQUIPADAS",23,COLORS["accent"]))
		for slot in equipped.keys():
			body.add_child(_label(str(slot)+": "+str(equipped[slot]["name"]),19))
		body.add_child(_label("INVENTARIO",23,COLORS["accent"]))
		for part in inventory:
			var item := part.duplicate(true)
			body.add_child(_button("EQUIPAR: "+str(item["name"]),func(): _equip(item)))
		body.add_child(_label("HABILIDADES: %d" % passives.size(),20))
		body.add_child(_button("LARGAR!",_race_start))
	elif screen=="result":
		body.add_child(_label("VITORIA!" if won else "DERROTA",42,COLORS["accent"]))
		body.add_child(_label("Corrida %d • Tempo %.1f s" % [stage,sim.time]))
		for e in sim.log:
			body.add_child(_label(e,16))
		if won and stage<10:
			body.add_child(_button("ESCOLHER CARTA",func(): _set_screen("reward")))
		else:
			body.add_child(_button("NOVA TENTATIVA",_new_run))
		body.add_child(_button("MENU",func(): _set_screen("menu")))
	elif screen=="reward":
		body.add_child(_label("ESCOLHA UMA CARTA",32,COLORS["accent"]))
		for card in cards:
			var item := card.duplicate(true)
			body.add_child(_label(str(item["name"])+" — "+str(item["desc"]),20))
			body.add_child(_button("ESCOLHER "+str(item["name"]),func(): _choose(item)))
