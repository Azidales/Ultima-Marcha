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
var garage_tab := "resumo"
var map_history_visible := false
var result_log_visible := false
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
	garage_tab = "resumo"
	map_history_visible = false
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
	result_log_visible = false
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
	b.text = s
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(fn)
	return b

func _set_garage_tab(tab: String) -> void:
	if screen == "garage" and tab in ["resumo", "pecas", "efeitos"]:
		garage_tab = tab
		_draw_ui()

func _toggle_history() -> void:
	map_history_visible = not map_history_visible
	_draw_ui()

func _toggle_result_log() -> void:
	result_log_visible = not result_log_visible
	_draw_ui()

func _ui_title() -> String:
	match screen:
		"menu": return "ULTIMA MARCHA"
		"career": return "CARREIRA DO PILOTO"
		"map": return "MAPA • ETAPA %d/10" % stage
		"garage": return "GARAGEM • ETAPA %d/10" % stage
		"race": return "CORRIDA %d/10" % stage
		"result": return "RESULTADO"
		"bulletin": return "RADIO DA ESTRADA"
		"reward": return "RECOMPENSA • %d RESTANTE(S)" % reward_picks_left
	return "ULTIMA MARCHA"

func _section(parent: VBoxContainer, heading: String, description: String = "") -> VBoxContainer:
	var pane := PanelContainer.new()
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.19, 0.27, 0.97)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	pane.add_theme_stylebox_override("panel", style)
	parent.add_child(pane)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 7)
	pane.add_child(contents)
	if not heading.is_empty():
		contents.add_child(_label(heading, 21, COLORS["accent"]))
	if not description.is_empty():
		contents.add_child(_label(description, 17, COLORS["dim"]))
	return contents

func _action(footer: HBoxContainer, title: String, callback: Callable, primary: bool = false) -> Button:
	var button := _button(title, callback)
	if primary:
		button.add_theme_color_override("font_color", Color("121e29"))
		var style := StyleBoxFlat.new()
		style.bg_color = COLORS["accent"]
		style.set_corner_radius_all(9)
		style.set_content_margin_all(9)
		button.add_theme_stylebox_override("normal", style)
		var hover: StyleBoxFlat = style.duplicate() as StyleBoxFlat
		hover.bg_color = Color("8bf5e9")
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", style)
	footer.add_child(button)
	return button

func _rarity_color(rarity: String) -> Color:
	if rarity == "epica":
		return Color("e5a1ff")
	if rarity == "rara":
		return Color("83baff")
	return Color("dfebf3")

func _build_race_ui(shell: VBoxContainer) -> void:
	var hud := _label(_ui_title(), 24, COLORS["accent"])
	progress_text = hud
	shell.add_child(hud)
	speed_text = _label("0 km/h", 23)
	heat_text = _label("Calor 0%", 18)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(spacer)
	shell.add_child(speed_text)
	shell.add_child(heat_text)
	var controls := HBoxContainer.new()
	controls.name = "RaceActions"
	controls.add_theme_constant_override("separation", 9)
	shell.add_child(controls)
	speed_button = _button("Velocidade %dx" % replay, _cycle_speed)
	controls.add_child(speed_button)
	_action(controls, "PULAR", _skip)

func _draw_ui() -> void:
	speed_button = null
	progress_text = null
	speed_text = null
	heat_text = null
	if layer != null:
		layer.queue_free()
	layer = CanvasLayer.new()
	add_child(layer)
	var base := MarginContainer.new()
	base.name = "SafeArea"
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	var portrait: bool = get_viewport().get_visible_rect().size.y > get_viewport().get_visible_rect().size.x
	var safe_margin := 12 if portrait else 16
	for edge in ["left", "right", "top", "bottom"]:
		base.add_theme_constant_override("margin_" + edge, safe_margin)
	layer.add_child(base)
	var shell := VBoxContainer.new()
	shell.name = "UILayout"
	shell.add_theme_constant_override("separation", 9)
	base.add_child(shell)
	if screen == "race":
		_build_race_ui(shell)
		return
	var background := ColorRect.new()
	background.color = Color(0.045, 0.07, 0.11, 0.97)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.add_child(background)
	base.move_child(background, 0)
	var heading := _label(_ui_title(), 26, COLORS["accent"])
	shell.add_child(heading)
	var hr := HSeparator.new()
	shell.add_child(hr)
	if screen == "garage":
		_build_garage_tabs(shell)
	var scroll := ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "ScreenBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	var footer := HBoxContainer.new()
	footer.name = "ActionBar"
	footer.add_theme_constant_override("separation", 9)
	shell.add_child(footer)
	match screen:
		"menu":
			_ui_menu(body, footer)
		"career":
			_ui_career(body, footer)
		"map":
			_ui_map(body, footer)
		"garage":
			_ui_garage(body, footer)
		"result":
			_ui_result(body, footer)
		"bulletin":
			_ui_bulletin(body, footer)
		"reward":
			_ui_rewards(body, footer)

func _ui_menu(body: VBoxContainer, footer: HBoxContainer) -> void:
	var panel := _section(body, "ROGUELIKE DE CORRIDAS AUTOMATICAS")
	panel.add_child(_label("Monte seu carro, escolha sua rota e enfrente ate dez adversarios.", 20))
	panel.add_child(_label("PILOTO NIVEL %d  •  %d XP  •  %d PONTO(S)" % [pilot.level(), pilot.experience, pilot.available_points()], 18, COLORS["accent"]))
	_action(footer, "PILOTO", _open_career)
	_action(footer, "JOGAR", _new_run, true)

func _ui_career(body: VBoxContainer, footer: HBoxContainer) -> void:
	var status := _section(body, "NIVEL %d • %d XP" % [pilot.level(), pilot.experience])
	status.add_child(_label("%d PONTO(S) LIVRE(S) DE %d" % [pilot.available_points(), pilot.total_points()], 19))
	status.add_child(_label("1 ponto a cada 200 XP; limite 12. Mudancas somente entre tentativas.", 17, COLORS["dim"]))
	for branch in Pilot.BRANCHES.keys():
		var branch_id: String = str(branch)
		var content := _section(body, branch_id.to_upper(), str(Pilot.ADVANCED_LABELS[branch_id]))
		for entry in Pilot.BRANCHES[branch_id]:
			var skill_id: String = str(entry)
			content.add_child(_label("%s  %d/3" % [str(Pilot.SKILL_LABELS[skill_id]), int(pilot.skills[skill_id])], 18))
			content.add_child(_label(Pilot.skill_effect(skill_id, int(pilot.skills[skill_id])), 16, COLORS["dim"]))
			var train := _button("TREINAR (+1)", func(): _train_skill(skill_id))
			train.disabled = pilot.available_points() <= 0 or int(pilot.skills[skill_id]) >= 3
			content.add_child(train)
		content.add_child(_label("Avancada: %s" % ("DESBLOQUEADA" if bool(pilot.advanced[branch_id]) else "BLOQUEADA"), 18))
		content.add_child(_label(Pilot.advanced_effect(branch_id), 16, COLORS["dim"]))
		content.add_child(_label("Requer 4 pontos basicos nesta especialidade e 2 pontos livres.", 16, COLORS["dim"]))
		var unlock := _button("DESBLOQUEAR (2 PONTOS)", func(): _train_advanced(branch_id))
		unlock.disabled = pilot.available_points() < 2 or pilot.branch_basics(branch_id) < 4 or bool(pilot.advanced[branch_id])
		content.add_child(unlock)
	_action(footer, "VOLTAR", func(): _set_screen("menu"))
	_action(footer, "REDISTRIBUIR", _reset_pilot_tree)

func _ui_map(body: VBoxContainer, footer: HBoxContainer) -> void:
	var info := _section(body, "ETAPA %d / 10" % stage, "Chefes obrigatorios: 5 e 10 • caminhos futuros ocultos")
	info.add_child(_label("Selecione uma rota. Voce ainda podera ajustar o carro antes da largada.", 17))
	for node in campaign.available():
		var route: Dictionary = node.duplicate(true)
		var kind: String = str(route["kind"])
		var kind_label := "CHEFE" if kind == "boss" else "ELITE" if kind == "elite" else "NORMAL"
		var reward_count: int = 0 if stage == 10 else campaign.reward_count(route)
		var option := _section(body, "%s  •  %s" % [kind_label, str(route["track"])], "%s  |  %s  |  %d CARTA(S)" % [str(route["weather"]), str(route["rival"]), reward_count])
		option.add_child(_button("PREPARAR PARA ESTA ROTA", func(): _pick_route(str(route["id"]))))
	if not campaign.bulletins.is_empty():
		var bulletins := _section(body, "ULTIMO BOLETIM")
		bulletins.add_child(_label(str(campaign.bulletins.back()), 17))
	if map_history_visible and not campaign.raced_path.is_empty():
		var history := _section(body, "ETAPAS REALIZADAS")
		for previous_id in campaign.raced_path:
			var visited: Dictionary = campaign.find_node(previous_id)
			history.add_child(_label("%d. %s • %s" % [int(visited["stage"]), str(visited["track"]), str(visited["kind"]).to_upper()], 17))
	if campaign.raced_path.is_empty():
		_action(footer, "INICIO", _exit_to_menu)
	else:
		_action(footer, "HISTORICO" if not map_history_visible else "OCULTAR", _toggle_history)
	_action(footer, "AJUDA: MAPA", func(): _show_help("map"))

func _build_garage_tabs(shell: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	tabs.name = "TabBar"
	tabs.add_theme_constant_override("separation", 6)
	shell.add_child(tabs)
	for tab in ["resumo", "pecas", "efeitos"]:
		var value: String = str(tab)
		var b := _button(("• " if garage_tab == value else "") + value.to_upper(), func(): _set_garage_tab(value))
		b.custom_minimum_size.y = 42
		b.disabled = garage_tab == value
		tabs.add_child(b)

func _ui_garage(body: VBoxContainer, footer: HBoxContainer) -> void:
	if garage_tab == "pecas":
		_ui_garage_parts(body)
	elif garage_tab == "efeitos":
		_ui_garage_effects(body)
	else:
		_ui_garage_summary(body)
	_action(footer, "ROTAS", func(): _set_screen("map"))
	_action(footer, "LARGAR!", _race_start, true)

func _ui_garage_summary(body: VBoxContainer) -> void:
	var overview := _section(body, "HATCH 1.6 • %s" % str(selected_route.get("kind", "normal")).to_upper(), "%s  •  %s" % [str(selected_route.get("track", "")), str(selected_route.get("weather", ""))])
	var s: Dictionary = _stats()
	# A full-width vertical list prevents GridContainer's squeezed columns
	# from wrapping stat labels one letter per line on Android portrait screens.
	var stats_list := VBoxContainer.new()
	stats_list.name = "CarStats"
	stats_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_list.add_theme_constant_override("separation", 4)
	overview.add_child(stats_list)
	for pair in [["ACEL", "accel"], ["ADERENCIA", "grip"], ["FINAL", "top"], ["REFRIG", "cool"]]:
		var stat_name: String = str(pair[0])
		var key: String = str(pair[1])
		var stat_label := _label("%s: %d%%" % [stat_name, roundi(float(s[key]) * 100.0)], 18)
		stat_label.name = "Stat_" + key
		stat_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_label.custom_minimum_size = Vector2(150, 26)
		stats_list.add_child(stat_label)
	overview.add_child(_label("PECAS %d/%d • CARTAS PASSIVAS %d" % [equipped.size(), Cards.SLOTS.size(), passives.size()], 17, COLORS["dim"]))
	var explain := _section(body, "O QUE CADA ATRIBUTO FAZ")
	explain.add_child(_label("ACEL: rapidez para ganhar velocidade nas retas e saidas de curva.", 16, COLORS["dim"]))
	explain.add_child(_label("ADERENCIA: permite maior velocidade nas curvas e reduz o risco de erro.", 16, COLORS["dim"]))
	explain.add_child(_label("FINAL: limita a velocidade maxima nas retas.", 16, COLORS["dim"]))
	explain.add_child(_label("REFRIG: retira calor do motor; superaquecimento reduz a aceleracao.", 16, COLORS["dim"]))
	explain.add_child(_label("CHUVA: altera a aderencia em piso molhado, mas nao no seco.", 16, COLORS["dim"]))
	explain.add_child(_label("RISCO: percentual de reducao relativa da chance de erros do piloto.", 16, COLORS["dim"]))
	var styles := _section(body, "ESTILO DE PILOTAGEM", "Pode ser alterado antes de cada corrida.")
	var choices := HBoxContainer.new()
	styles.add_child(choices)
	for name in ["conservador", "equilibrado", "agressivo"]:
		var value: String = str(name)
		var b := _button(("✓ " if pilot_style == value else "") + value.substr(0, 4).to_upper(), func(): _set_pilot_style(value))
		b.custom_minimum_size.y = 42
		choices.add_child(b)
	var combos: Array[String] = Cards.synergies(equipped)
	var features := _section(body, "COMBINACOES • %d" % combos.size())
	if combos.is_empty():
		features.add_child(_label("Equipe Turbo + Radiador, Turbo + Cambio ou Pneus + Suspensao.", 17, COLORS["dim"]))
	else:
		for item in combos:
			features.add_child(_label(item, 18))
	if str(selected_route.get("weather", "")) == "molhada":
		features.add_child(_label("ADERENCIA NA CHUVA: %+d%%" % roundi(float(s["wet_grip"]) * 100.0), 17))
	features.add_child(_label("REDUCAO DE RISCO: %d%%" % roundi(float(s["risk_reduction"]) * 100.0), 17))

func _ui_garage_parts(body: VBoxContainer) -> void:
	var summary := _section(body, "TROCA LIVRE", "Retirar uma peca nao a descarta. Apenas uma peca por espaco.")
	summary.add_child(_label("%d PECAS NO INVENTARIO" % inventory.size(), 18))
	for slot in Cards.SLOTS:
		var equip_id: String = str(slot)
		var selected: Dictionary = equipped.get(equip_id, {})
		var pane := _section(body, equip_id.to_upper(), "Equipado: %s" % str(selected.get("name", "NENHUM")))
		if not selected.is_empty():
			pane.add_child(_button("RETIRAR", func(): _unequip(equip_id)))
		var any_owned := false
		for card in inventory:
			if str(card.get("slot", "")) != equip_id:
				continue
			any_owned = true
			var part: Dictionary = card.duplicate(true)
			var is_current := str(selected.get("id", "")) == str(part.get("id", ""))
			var choose := _button(("EQUIPADA: " if is_current else "EQUIPAR: ") + str(part["name"]), func(): _equip(part))
			choose.disabled = is_current
			pane.add_child(choose)
		if not any_owned:
			pane.add_child(_label("Sem pecas no inventario", 17, COLORS["dim"]))

func _ui_garage_effects(body: VBoxContainer) -> void:
	var combinations := _section(body, "COMBINACOES ATIVAS")
	var combos: Array[String] = Cards.synergies(equipped)
	if combos.is_empty():
		combinations.add_child(_label("Nenhuma combinacao equipada.", 18))
	else:
		for combo in combos:
			combinations.add_child(_label(combo, 18, COLORS["accent"]))
	var passives_section := _section(body, "CARTAS PASSIVAS", "Acumulo = quantidade da MESMA carta adquirida. Maximo de 3 por habilidade.")
	var count := 0
	for data in Cards.CATALOG:
		if str(data.get("type", "")) != "passive":
			continue
		var copies: int = Cards.stacks(passives, str(data["id"]))
		if copies > 0:
			count += 1
			passives_section.add_child(_label("%s • ACUMULOS %d/%d" % [str(data["name"]), copies, Cards.MAX_PASSIVE_STACKS], 18, _rarity_color(str(data["rarity"]))))
			passives_section.add_child(_label("BONUS TOTAL: " + Cards.passive_bonus(data, copies), 16, COLORS["accent"]))
			passives_section.add_child(_label(str(data["desc"]), 16, COLORS["dim"]))
	if count == 0:
		passives_section.add_child(_label("Nenhum efeito acumulavel adquirido.", 18, COLORS["dim"]))

func _ui_result(body: VBoxContainer, footer: HBoxContainer) -> void:
	var summary := _section(body, "VITORIA!" if won else "DERROTA", "Etapa %d • %.1f s" % [stage, sim.time])
	summary.add_child(_label("+%d XP  •  PILOTO NIVEL %d" % [earned_xp, pilot.level()], 20, COLORS["accent"]))
	summary.add_child(_label("Ocorrencias registradas: %d" % sim.log.size(), 17))
	if result_log_visible and not sim.log.is_empty():
		var log_section := _section(body, "REGISTRO DA CORRIDA")
		for line in sim.log:
			log_section.add_child(_label(str(line), 17))
	if not sim.log.is_empty():
		var button := _button("VER EVENTOS" if not result_log_visible else "OCULTAR EVENTOS", _toggle_result_log)
		body.add_child(button)
	_action(footer, "MENU", _exit_to_menu)
	if won and stage < 10:
		_action(footer, "RECOMPENSAS", _after_victory, true)
	else:
		if won:
			body.add_child(_label("CAMPEONATO CONCLUIDO!", 22, COLORS["accent"]))
		_action(footer, "RECOMECAR", _new_run, true)

func _ui_bulletin(body: VBoxContainer, footer: HBoxContainer) -> void:
	var radio := _section(body, "INFORMACAO DAS PROXIMAS ROTAS")
	radio.add_child(_label(active_bulletin, 21))
	radio.add_child(_label("O boletim descreve uma rota possivel, nao necessariamente a sua escolha.", 17, COLORS["dim"]))
	_action(footer, "VER CARTAS", _start_reward, true)

func _ui_rewards(body: VBoxContainer, footer: HBoxContainer) -> void:
	var header := _section(body, "%d ESCOLHA(S) RESTANTE(S)" % reward_picks_left, "Escolha uma carta por vez. As outras opcoes continuam disponiveis.")
	for offered in cards:
		var card: Dictionary = offered.duplicate(true)
		var rarity: String = str(card.get("rarity", "comum"))
		var passive: bool = str(card.get("type", "")) == "passive"
		var caption: String = "EFEITO SEM ESPACO" if passive else "PECA • %s" % str(card.get("slot", ""))
		var info := _section(body, str(card.get("name", "")), caption)
		info.add_child(_label(str(card.get("desc", "")), 18))
		info.add_child(_label(rarity.to_upper(), 17, _rarity_color(rarity)))
		if passive:
			var accumulated: int = Cards.stacks(passives, str(card.get("id", "")))
			info.add_child(_label("ACUMULOS: %d/%d (a mesma carta pode ser escolhida mais de uma vez)" % [accumulated, Cards.MAX_PASSIVE_STACKS], 16, COLORS["dim"]))
			info.add_child(_label("SE ESCOLHER: " + Cards.passive_bonus(card, accumulated + 1), 16, COLORS["accent"]))
		var take := _button("ESCOLHER ESTA CARTA", func(): _choose(card))
		info.add_child(take)
	if cards.is_empty():
		header.add_child(_label("Nenhuma carta elegivel encontrada.", 18, COLORS["dim"]))

func _show_help(topic: String) -> void:
	if topic == "map":
		OS.alert("As rotas disponiveis estao visiveis. Caminhos adiante ficam ocultos ate concluir a etapa. Elites sao opcionais; chefes estao nas etapas 5 e 10.", "Como funciona o mapa")
