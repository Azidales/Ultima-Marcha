extends Node3D

const Race = preload("res://scripts/simulation.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Cards = preload("res://scripts/cards.gd")
const Pilot = preload("res://scripts/pilot.gd")
const Framing = preload("res://scripts/camera_framing.gd")
const COLORS = {"bg":Color("111927"),"panel":Color("19283b"),"accent":Color("52dfd0"),"white":Color("f5f7fb"),"dim":Color("b1c3d3")}
var sim = Race.new()
var campaign = Campaign.new()
var pilot = Pilot.new()
var pilot_style := "equilibrado"
var race_result_recorded := false
var earned_xp := 0
var stage := 1
var selected_route: Dictionary = {}
var active_bulletin := ""
var reward_picks_left := 0
var screen := "menu"
var equipped: Dictionary = {}
var inventory: Array[Dictionary] = []
var passives: Array[Dictionary] = []
var cards: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var replay := 1
var speed_button: Button
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
	pilot.load_save()
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
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.current = true
	add_child(camera)
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var initial_focus: Vector3 = _at(23.0)
	camera.size = Framing.world_width(view_size)
	camera.position = initial_focus + Framing.offset(view_size)
	camera.look_at(initial_focus, Vector3.UP)

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
			_finish_race()
	var a: float = sim.progress_player if screen=="race" else 18.0
	var b: float = sim.progress_rival if screen=="race" else 28.0
	player.position = _at(a,-1.8)+Vector3.UP*0.2
	rival.position = _at(b,1.8)+Vector3.UP*0.2
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var focus_distance: float = Framing.focus_distance(a, b)
	var focus_point: Vector3 = _at(focus_distance + Framing.look_ahead(view_size))
	var target_position: Vector3 = focus_point + Framing.offset(view_size)
	camera.global_position = camera.global_position.lerp(target_position, minf(1.0, delta * 3.0))
	camera.look_at(focus_point, Vector3.UP)
	camera.size = lerpf(camera.size, Framing.world_width(view_size), minf(1.0, delta * 5.0))
	if screen=="race" and progress_text!=null:
		progress_text.text = "CORRIDA %d/10  •  %d%%" % [stage,roundi(100.0*minf(1.0,sim.progress_player/Race.LENGTH))]
		speed_text.text = "%d km/h" % roundi(sim.speed_player*3.6)
		heat_text.text = "CALOR: %d%%  |  Rival: %.0f m" % [roundi(sim.heat),sim.progress_rival-sim.progress_player]

func _stats() -> Dictionary:
	return Cards.calculate(equipped, passives)

func _new_run() -> void:
	if pilot.running:
		return
	pilot.start_run()
	stage = 1
	equipped.clear()
	inventory.clear()
	passives.clear()
	selected_route.clear()
	active_bulletin = ""
	campaign.generate(rng.randi())
	_set_screen("map")

func _pick_route(id: String) -> void:
	for option in campaign.available():
		if str(option["id"]) == id:
			selected_route = option.duplicate(true)
			_set_screen("garage")
			return

func _after_victory() -> void:
	active_bulletin = campaign.maybe_bulletin()
	if not active_bulletin.is_empty():
		_set_screen("bulletin")
	else:
		_start_reward()

func _start_reward() -> void:
	reward_picks_left = campaign.reward_count(selected_route)
	var offer_count: int = 4 if reward_picks_left == 2 else 3
	cards = Cards.draw(rng, offer_count, str(selected_route.get("kind","normal")), inventory, passives)
	_set_screen("reward")

func _race_start() -> void:
	if selected_route.is_empty():
		_set_screen("map")
		return
	if not campaign.record_race(str(selected_route["id"])):
		_set_screen("map")
		return
	accumulator = 0.0
	replay = 1
	race_result_recorded = false
	earned_xp = 0
	sim.begin(_stats(),stage,rng.randi(),selected_route,pilot.snapshot(pilot_style))
	_set_screen("race")

func _cycle_speed() -> void:
	replay = replay + 1 if replay < 4 else 1
	if is_instance_valid(speed_button):
		speed_button.text = "Velocidade %dx" % replay

func _skip() -> void:
	while not sim.finished:
		sim.tick(Race.STEP)
	_finish_race()

func _finish_race() -> void:
	if race_result_recorded or not sim.finished:
		return
	race_result_recorded = true
	won = sim.winner == "player"
	earned_xp = pilot.grant_result(won, str(selected_route.get("kind", "normal")), won and stage == 10)
	if not won or stage == 10:
		pilot.end_run()
	_set_screen("result")

func _exit_to_menu() -> void:
	# Leaving a run is a forfeit; earned experience is kept.
	pilot.end_run()
	_set_screen("menu")

func _open_career() -> void:
	if not pilot.running:
		_set_screen("career")

func _train_skill(id: String) -> void:
	if screen == "career" and pilot.upgrade(id):
		_draw_ui()

func _train_advanced(branch: String) -> void:
	if screen == "career" and pilot.unlock(branch):
		_draw_ui()

func _reset_pilot_tree() -> void:
	if screen == "career" and pilot.respec():
		_draw_ui()

func _set_pilot_style(value: String) -> void:
	if screen == "garage" and value in ["conservador", "equilibrado", "agressivo"]:
		pilot_style = value
		_draw_ui()

func _choose(card: Dictionary) -> void:
	if screen != "reward" or reward_picks_left <= 0 or card not in cards:
		return
	if not Cards.can_take(card, inventory, passives):
		return
	if str(card.get("type"))=="part":
		var owned: Dictionary = card.duplicate(true)
		inventory.append(owned)
		equipped[str(owned["slot"])] = owned
	else:
		passives.append(card.duplicate(true))
	cards.erase(card)
	reward_picks_left -= 1
	if reward_picks_left == 0:
		stage += 1
		selected_route.clear()
		_set_screen("map")
	else:
		_draw_ui()

func _unequip(slot: String) -> void:
	equipped.erase(slot)
	_draw_ui()

func _equip(card: Dictionary) -> void:
	if screen != "garage" or str(card.get("type","")) != "part":
		return
	var owned := false
	for part in inventory:
		if str(part.get("id", "")) == str(card.get("id", "")):
			owned = true
			break
	if not owned or str(card.get("slot","")) not in Cards.SLOTS:
		return
	equipped[str(card["slot"])] = card
	_draw_ui()

func _set_screen(name: String) -> void:
	screen = name
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
	speed_button=null
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
		speed_button = _button("Velocidade %dx" % replay, _cycle_speed)
		buttons.add_child(speed_button)
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
		body.add_child(_label("Monte seu carro, escolha caminhos, enfrente elites e ganhe cartas. Gire o aparelho quando quiser.",20))
		body.add_child(_label("PILOTO NIVEL %d | XP %d | PONTOS %d LIVRES" % [pilot.level(),pilot.experience,pilot.available_points()],20,COLORS["accent"]))
		body.add_child(_button("CARREIRA DO PILOTO",_open_career))
		body.add_child(_button("INICIAR TENTATIVA",_new_run))
	elif screen=="career":
		body.add_child(_label("CARREIRA DO PILOTO",33,COLORS["accent"]))
		body.add_child(_label("NIVEL %d   |   XP TOTAL %d" % [pilot.level(),pilot.experience],22))
		body.add_child(_label("PONTOS LIVRES %d / %d" % [pilot.available_points(),pilot.total_points()],20))
		body.add_child(_label("Um ponto a cada 200 XP, ate 12. Reinicie a distribuicao sem custo entre tentativas.",18,COLORS["dim"]))
		for branch in Pilot.BRANCHES.keys():
			var b_name: String = str(branch)
			body.add_child(_label(b_name.to_upper(),23,COLORS["accent"]))
			for skill in Pilot.BRANCHES[branch]:
				var id: String = str(skill)
				body.add_child(_label("%s  -  %d/3" % [str(Pilot.SKILL_LABELS[id]),int(pilot.skills[id])],18))
				var improve := _button("TREINAR (+1 PONTO)",func(): _train_skill(id))
				improve.disabled = pilot.available_points() == 0 or int(pilot.skills[id]) >= 3
				body.add_child(improve)
			body.add_child(_label("%s  -  %s" % [str(Pilot.ADVANCED_LABELS[b_name]),"ATIVA" if bool(pilot.advanced[b_name]) else "BLOQUEADA"],18))
			var advanced_button := _button("TECNICA AVANCADA (2 PONTOS)",func(): _train_advanced(b_name))
			advanced_button.disabled = pilot.available_points() < 2 or pilot.branch_basics(b_name) < 4 or bool(pilot.advanced[b_name])
			body.add_child(advanced_button)
		body.add_child(_button("REDISTRIBUIR TODOS OS PONTOS",_reset_pilot_tree))
		body.add_child(_button("VOLTAR AO MENU",func(): _set_screen("menu")))
	elif screen=="map":
		body.add_child(_label("MAPA DA TEMPORADA",34,COLORS["accent"]))
		body.add_child(_label("ETAPA %d/10 • CHEFES NA 5 E NA 10" % stage,19))
		if campaign.raced_path.size() > 0:
			body.add_child(_label("CAMINHO PERCORRIDO:",20,COLORS["accent"]))
			for id in campaign.raced_path:
				var past: Dictionary = campaign.find_node(id)
				body.add_child(_label("%d: %s / %s" % [int(past["stage"]),str(past["track"]),str(past["kind"]).to_upper()],17))
		body.add_child(_label("PROXIMAS ROTAS DESCOBERTAS",23,COLORS["accent"]))
		for option in campaign.available():
			var route: Dictionary = option.duplicate(true)
			var kind: String = str(route["kind"])
			var label_name: String = "CHEFE" if kind=="boss" else "ELITE" if kind=="elite" else "NORMAL"
			var reward: int = campaign.reward_count(route)
			if int(route["stage"])==10:
				reward=0
			body.add_child(_label("%s - %s - %s - %s" % [label_name,str(route["track"]),str(route["weather"]),str(route["rival"])],18))
			body.add_child(_button("ESCOLHER ROTA • %d CARTA(S)" % reward,func(): _pick_route(str(route["id"]))))
		body.add_child(_label("NEBLINA: as proximas etapas permanecem desconhecidas.",17,COLORS["dim"]))
		if not campaign.bulletins.is_empty():
			body.add_child(_label("HISTORICO DO RADIO",22,COLORS["accent"]))
			for bulletin in campaign.bulletins:
				body.add_child(_label(str(bulletin),17))
	elif screen=="garage":
		body.add_child(_label("GARAGEM • CORRIDA %d DE 10" % stage,31,COLORS["accent"]))
		body.add_child(_label("Hatch 1.6 | inventario livre",20))
		body.add_child(_label("%s • %s • %s" % [str(selected_route.get("kind","normal")).to_upper(),str(selected_route.get("track","")),str(selected_route.get("weather",""))],18,COLORS["accent"]))
		body.add_child(_button("MUDAR CAMINHO",func(): _set_screen("map")))
		body.add_child(_label("ESTILO DE PILOTAGEM: %s" % pilot_style.to_upper(),18,COLORS["accent"]))
		for style_name in ["conservador", "equilibrado", "agressivo"]:
			var chosen: String = str(style_name)
			body.add_child(_button(("ATIVO: " if pilot_style == chosen else "USAR: ") + chosen.to_upper(),func(): _set_pilot_style(chosen)))
		body.add_child(_label("A arvore de habilidades fica bloqueada durante a tentativa.",16,COLORS["dim"]))
		var s := _stats()
		body.add_child(_label("ACEL: %d%%  ADERENCIA: %d%%\nFINAL: %d%%  REFRIG: %d%%" % [roundi(float(s["accel"])*100.0),roundi(float(s["grip"])*100.0),roundi(float(s["top"])*100.0),roundi(float(s["cool"])*100.0)]))
		body.add_child(_label("COMBINACOES ATIVAS",22,COLORS["accent"]))
		var combos: Array[String] = Cards.synergies(equipped)
		if combos.is_empty():
			body.add_child(_label("Nenhuma combinacao ativa. Combine pneus + suspensao, turbo + refrigeracao ou turbo + cambio.",17,COLORS["dim"]))
		else:
			for combo in combos:
				body.add_child(_label(combo,17,COLORS["accent"]))
		if str(selected_route.get("weather", "seca")) == "molhada":
			body.add_child(_label("ADERENCIA EXTRA NA CHUVA: %+d%%" % roundi(float(s["wet_grip"])*100.0),18))
		body.add_child(_label("REDUCAO DE RISCO: %d%%" % roundi(float(s["risk_reduction"])*100.0),18))
		body.add_child(_label("PECAS EQUIPADAS (%d/%d)" % [equipped.size(),Cards.SLOTS.size()],23,COLORS["accent"]))
		for slot in equipped.keys():
			var current_slot: String = str(slot)
			body.add_child(_label(str(slot)+": "+str(equipped[slot]["name"])+" ["+str(equipped[slot]["rarity"]).to_upper()+"]",19))
			body.add_child(_button("RETIRAR "+current_slot,func(): _unequip(current_slot)))
		body.add_child(_label("INVENTARIO DE PECAS (%d)" % inventory.size(),23,COLORS["accent"]))
		for part in inventory:
			var item: Dictionary = part.duplicate(true)
			var is_equipped: bool = equipped.has(str(item["slot"])) and str(equipped[str(item["slot"])]["id"]) == str(item["id"])
			var equip_button := _button(("EQUIPADO: " if is_equipped else "EQUIPAR: ") + str(item["name"])+" ["+str(item["rarity"]).to_upper()+"]",func(): _equip(item))
			equip_button.disabled = is_equipped
			body.add_child(equip_button)
		body.add_child(_label("EFEITOS ACUMULADOS (%d CARTAS)" % passives.size(),23,COLORS["accent"]))
		for passive_card in Cards.CATALOG:
			if str(passive_card["type"]) != "passive":
				continue
			var amount: int = Cards.stacks(passives, str(passive_card["id"]))
			if amount > 0:
				body.add_child(_label("%s [%s] %d/%d" % [str(passive_card["name"]),str(passive_card["rarity"]).to_upper(),amount,Cards.MAX_PASSIVE_STACKS],18))
		body.add_child(_button("LARGAR!",_race_start))
	elif screen=="result":
		body.add_child(_label("VITORIA!" if won else "DERROTA",42,COLORS["accent"]))
		body.add_child(_label("Corrida %d • Tempo %.1f s" % [stage,sim.time]))
		body.add_child(_label("+%d XP | TOTAL: %d XP | PILOTO NIVEL %d" % [earned_xp,pilot.experience,pilot.level()],21,COLORS["accent"]))
		for e in sim.log:
			body.add_child(_label(e,16))
		if won and stage < 10:
			body.add_child(_button("CONTINUAR PARA RECOMPENSAS",_after_victory))
		else:
			if won:
				body.add_child(_label("CAMPEONATO CONCLUIDO!",29,COLORS["accent"]))
			body.add_child(_button("NOVA TENTATIVA",_new_run))
		body.add_child(_button("MENU / ENCERRAR TENTATIVA",_exit_to_menu))
	elif screen=="bulletin":
		body.add_child(_label("RADIO DA ESTRADA",31,COLORS["accent"]))
		body.add_child(_label(active_bulletin,23))
		body.add_child(_label("Os caminhos continuam ocultos ate voce avancar.",18,COLORS["dim"]))
		body.add_child(_button("VER RECOMPENSAS",_start_reward))
	elif screen=="reward":
		body.add_child(_label("ESCOLHA %d CARTA(S)" % reward_picks_left,32,COLORS["accent"]))
		body.add_child(_label("%d opcoes disponiveis • novas cartas apenas apos vitorias" % cards.size(),17,COLORS["dim"]))
		for card in cards:
			var item: Dictionary = card.duplicate(true)
			var category: String = str(item.get("slot","EFEITO ACUMULAVEL"))
			var amount: int = Cards.stacks(passives,str(item["id"]))
			var amount_label: String = " • %d/%d" % [amount,Cards.MAX_PASSIVE_STACKS] if str(item["type"]) == "passive" else ""
			body.add_child(_label("[%s] %s" % [str(item["rarity"]).to_upper(),str(item["name"])],23,COLORS["accent"]))
			body.add_child(_label("%s%s | %s" % [category,amount_label,str(item["desc"])],18))
			body.add_child(_button("ESCOLHER "+str(item["name"]),func(): _choose(item)))
