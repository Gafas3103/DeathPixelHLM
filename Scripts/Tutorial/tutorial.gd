extends Node2D

## Tutorial interactivo (Scenes/Levels/Tutorial.tscn): 6 salas y 12 pasos. Una tarjeta arriba explica cada
## paso y avanza cuando lo haces bien. Eres invulnerable; N salta un paso.

const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const ZoneScript := preload("res://Scripts/Tutorial/tutorial_zone.gd")
const EnemyScene := preload("res://Scenes/Enemy.tscn")
const KeyScene := preload("res://Scenes/Items/KeyItem.tscn")
const DoorScene := preload("res://Scenes/Items/Door.tscn")
const PickupScene := preload("res://Scenes/Items/Pickup.tscn")

const RIFLE := 0
const SHOTGUN := 1
const KNIFE := 2

## título, texto y teclas de cada paso; {K:accion} se reemplaza por la tecla configurada
const STEPS: Array[Dictionary] = [
	{
		"title": "MUÉVETE Y APUNTA",
		"body": "Camina con {K:move_up} {K:move_left} {K:move_down} {K:move_right} y apunta con el MOUSE: tu personaje siempre mira hacia la mirilla. Llega a la zona verde marcada.",
		"keys": ["{K:move_up}", "{K:move_left}", "{K:move_down}", "{K:move_right}", "MOUSE"],
	},
	{
		"title": "RIFLE · UN CLIC = UN DISPARO",
		"body": "Tienes el RIFLE (tecla 1). Un clic suelto dispara UNA sola vez. Derriba el muñeco marcado con clics sueltos.",
		"keys": ["CLIC IZQ.", "1"],
	},
	{
		"title": "RIFLE · RÁFAGA",
		"body": "Si MANTIENES presionado el clic, el rifle dispara en ráfaga automática. Derriba los 3 muñecos.",
		"keys": ["MANTENER CLIC IZQ."],
	},
	{
		"title": "RECARGAR",
		"body": "Te quedan pocas balas en el cargador (número grande, abajo a la derecha; la reserva va al lado). Presiona {K:reload} para recargar. En dificultad DIFÍCIL la recarga es siempre manual.",
		"keys": ["{K:reload}"],
	},
	{
		"title": "ESCOPETA",
		"body": "Presiona 2 para sacar la ESCOPETA: lanza 8 perdigones, es potente de cerca, lenta y MUY ruidosa (los enemigos la oyen de lejos). Derriba los 3 muñecos con ella.",
		"keys": ["2", "CLIC IZQ."],
	},
	{
		"title": "CUCHILLO",
		"body": "Presiona 3 para el CUCHILLO (o {K:melee} / CLIC DERECHO desde cualquier arma). No gasta balas y casi no hace ruido. Acércate al muñeco y golpéalo.",
		"keys": ["3", "{K:melee}", "CLIC DER."],
	},
	{
		"title": "SIGILO",
		"body": "Los enemigos NO te detectan al instante: sobre su cabeza aparece un anillo que se llena, luego «?» (sospecha) y por último «!» (te detectó). Mira también la barra SIGILO arriba a la derecha. Mantén {K:sneak} para caminar despacio: tardan MUCHO más en verte. Usa las paredes como cobertura y cruza la sala hasta la zona verde sin que te detecten.",
		"keys": ["{K:sneak} (MANTENER)"],
	},
	{
		"title": "PUNTO CIEGO",
		"body": "Un enemigo solo ve delante de él. Rodéalo sin que te vea, colócate DETRÁS y usa el cuchillo: muerte instantánea y SILENCIOSA con puntos dobles. Elimina al guardia por la espalda.",
		"keys": ["{K:sneak} (MANTENER)", "{K:melee}"],
	},
	{
		"title": "COMBO Y FLOW",
		"body": "Cada baja sube tu COMBO (multiplica los puntos). Con combo 3 entras en FLOW, con 6 en FRENESÍ y con 10 en BERSERK: más daño, más velocidad y más cadencia. ¡Derriba a los muñecos rápido!",
		"keys": ["CLIC IZQ.", "1 / 2 / 3"],
	},
	{
		"title": "BOTIQUINES Y MUNICIÓN",
		"body": "Los enemigos sueltan botiquines, munición, cartuchos y corazones al morir; pasa sobre ellos para recogerlos. Te bajamos la vida a propósito: recoge el botiquín (cruz roja).",
		"keys": ["PASA POR ENCIMA"],
	},
	{
		"title": "LLAVE Y PUERTA",
		"body": "En cada nivel, el ÚLTIMO enemigo suelta la llave. Recógela y presiona {K:action} junto a la puerta roja para abrirla.",
		"keys": ["{K:action}"],
	},
	{
		"title": "SALIDA",
		"body": "Cruza la puerta y entra a la zona de salida: en los niveles, así se completa la misión. ¡Último paso!",
		"keys": [],
	},
]

const NEEDED_WEAPON_HINT := {
	0: "USA EL RIFLE (TECLA 1)",
	1: "USA LA ESCOPETA (TECLA 2)",
	2: "USA EL CUCHILLO (TECLA 3 / F)",
}


## anillo de puntería bajo cada muñeco
class TargetRing extends Node2D:
	var _t: float = 0.0

	func _init() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 1.0 + 0.06 * sin(_t * 5.0)
		draw_arc(Vector2.ZERO, 15.0 * pulse, 0.0, TAU, 28, Color("#EF3E4A", 0.9), 2.0)
		draw_arc(Vector2.ZERO, 9.0 * pulse, 0.0, TAU, 24, Color("#E9E5D8", 0.7), 1.5)
		draw_circle(Vector2.ZERO, 2.0, Color("#EF3E4A"))


var step: int = -1

var _card: PanelContainer
var _step_label: Label
var _title_label: Label
var _body_label: Label
var _keys_box: HBoxContainer
var _segments: Array[ColorRect] = []
var _advance_timer: Timer
var _hint_label: Label

var _zone: Area2D = null
var _dummies: Array[Node2D] = []
var _guard: Node2D = null
var _door: Node2D = null
var _advancing: bool = false
var _done: bool = false
var _reload_seen: bool = false
var _door_opened: bool = false
var _hint_tween: Tween = null


func _ready() -> void:
	add_to_group("tutorial")
	_advance_timer = Timer.new()
	_advance_timer.one_shot = true
	_advance_timer.wait_time = 1.1
	_advance_timer.timeout.connect(_advance)
	add_child(_advance_timer)

	_build_ui()
	Global.enemy_killed.connect(_on_enemy_killed)
	Global.door_opened.connect(func() -> void: _door_opened = true)
	# el nivel reinicia Global en su _ready, así que empezamos después
	call_deferred("_begin")


func _begin() -> void:
	Global.invuln_time = 1.0e6
	Global.grace_time = 2.0
	Global.refill_weapons()

	_door = DoorScene.instantiate() as Node2D
	_door.position = Vector2(1112, 96)
	_door.set("size", Vector2(16, 32))
	get_parent().add_child(_door)

	_go_to_step(0)


# pasos

func _go_to_step(index: int) -> void:
	_cleanup_step()
	step = index
	if step >= STEPS.size():
		_finish()
		return
	Global.refill_weapons()
	_update_card()
	_setup_step()


func _cleanup_step() -> void:
	if _zone != null and is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	_reload_seen = false
	for d in get_tree().get_nodes_in_group("tutorial_target"):
		if d != _guard and d.has_method("is_alive") and d.is_alive() == false:
			d.remove_from_group("tutorial_target")


func _setup_step() -> void:
	match step:
		0:
			_make_zone(Vector2(184, 88), Vector2(24, 72), "AQUÍ")
		1:
			Global.switch_weapon(RIFLE)
			_spawn_dummy(Vector2(360, 88))
		2:
			_spawn_dummy(Vector2(344, 40))
			_spawn_dummy(Vector2(376, 88))
			_spawn_dummy(Vector2(344, 136))
		3:
			Global.switch_weapon(RIFLE)
			Global.ammo = 5
			Global.ammo_changed.emit(Global.ammo)
		4:
			_spawn_dummy(Vector2(536, 88))
			_spawn_dummy(Vector2(584, 56))
			_spawn_dummy(Vector2(584, 136))
		5:
			_spawn_dummy(Vector2(600, 88))
		6:
			Global.grace_time = 0.0
			_spawn_guard(Vector2(776, 88))
			_make_zone(Vector2(872, 88), Vector2(28, 80), "CRUZA SIN QUE TE VEAN")
		7:
			if _guard == null or not is_instance_valid(_guard) or not _guard.is_alive():
				_spawn_guard(Vector2(776, 88))
		8:
			for pos in [Vector2(968, 40), Vector2(968, 88), Vector2(968, 136), Vector2(1032, 40), Vector2(1032, 88), Vector2(1032, 136)]:
				_spawn_dummy(pos)
		9:
			Global.health = 35.0
			Global.health_changed.emit(Global.health)
			_spawn_pickup(1, 60, Vector2(1064, 56))
			_spawn_pickup(0, 20, Vector2(1064, 88))
			_spawn_pickup(3, 6, Vector2(1064, 120))
		10:
			var key := KeyScene.instantiate() as Node2D
			key.position = Vector2(1000, 88)
			get_parent().add_child(key)
		11:
			_make_zone(Vector2(1192, 96), Vector2(48, 64), "SALIDA")


func _process(_delta: float) -> void:
	if _done or _advancing:
		return
	match step:
		1, 2, 4, 5:
			if _alive_dummies() == 0 and not _dummies.is_empty():
				_complete_step()
		3:
			if Global.reloading:
				_reload_seen = true
			if _reload_seen and Global.current_weapon == RIFLE and Global.ammo > 5:
				_complete_step()
		8:
			if Global.flow_tier() >= 1:
				_complete_step()
		9:
			if Global.health > 60.0:
				_complete_step()
		10:
			if Global.has_key and _door_opened:
				_complete_step()


func _on_zone_reached() -> void:
	if _done or _advancing:
		return
	match step:
		0, 11:
			_complete_step()
		6:
			# solo cuenta si el guardia no te detectó
			if _guard != null and is_instance_valid(_guard) and _guard.is_alive() and _guard.awareness >= 1.0:
				_hint("TE DETECTARON. ALÉJATE, ESPERA A QUE SE CALME Y USA SHIFT")
				_zone.rearm()
			else:
				_complete_step()


func _on_enemy_killed(pos: Vector2) -> void:
	if _done:
		return
	match step:
		1, 2, 4, 5:
			var needed := {1: RIFLE, 2: RIFLE, 4: SHOTGUN, 5: KNIFE}[step] as int
			if Global.last_kill_weapon != needed:
				_hint(String(NEEDED_WEAPON_HINT[needed]))
				call_deferred("_spawn_dummy", pos)
		6:
			# aparece otro guardia
			if _guard != null and is_instance_valid(_guard) and not _guard.is_alive():
				_hint("NO LO ELIMINES AÚN: CRUZA SIN QUE TE VEA")
				call_deferred("_spawn_guard", Vector2(776, 88))
		7:
			if _guard != null and is_instance_valid(_guard) and not _guard.is_alive():
				if Global.last_kill_silent:
					_complete_step()
				else:
					_hint("HICISTE RUIDO. RODÉALO Y GOLPÉALO POR LA ESPALDA, SIN SER DETECTADO")
					call_deferred("_spawn_guard", Vector2(776, 88))


func skip_step() -> void:
	if _done:
		return
	_advance_timer.stop()
	_advancing = false
	_go_to_step(step + 1)


func _complete_step() -> void:
	if _advancing or _done:
		return
	_advancing = true
	Global.show_message("¡BIEN! PASO COMPLETADO")
	for i in range(_segments.size()):
		if i == step:
			_segments[i].color = UIStyle.BAR_FILL
	_advance_timer.start()


func _advance() -> void:
	_advancing = false
	_go_to_step(step + 1)


func _finish() -> void:
	_done = true
	GameManager.mark_tutorial_done()
	_card.visible = false
	Global.show_message("¡TUTORIAL COMPLETADO!")
	_show_end_panel()


# objetos

func _make_zone(pos: Vector2, zone_size: Vector2, caption: String) -> void:
	_zone = ZoneScript.new()
	_zone.position = pos
	_zone.set("size", zone_size)
	_zone.set("caption", caption)
	_zone.reached.connect(_on_zone_reached)
	get_parent().add_child(_zone)


func _spawn_dummy(pos: Vector2, hp: float = 44.0) -> Node2D:
	var e := EnemyScene.instantiate() as Node2D
	e.set("behavior", 3)
	e.set("max_health", hp)
	e.set("can_flee", false)
	e.position = pos
	e.rotation = PI
	e.add_child(TargetRing.new())
	get_parent().add_child(e)
	e.add_to_group("tutorial_target")
	e.set_meta("caption", "MUÑECO")
	_dummies.append(e)
	return e


func _spawn_guard(pos: Vector2) -> void:
	var g := EnemyScene.instantiate() as Node2D
	g.set("behavior", 1)
	g.set("patrol_distance", 70.0)
	g.set("patrol_wait", 1.2)
	g.set("can_flee", false)
	g.position = pos
	get_parent().add_child(g)
	g.add_to_group("tutorial_target")
	g.set_meta("caption", "GUARDIA")
	_guard = g


func _spawn_pickup(kind: int, amount: int, pos: Vector2) -> void:
	var p := PickupScene.instantiate() as Node2D
	p.set("kind", kind)
	p.set("amount", amount)
	p.position = pos
	get_parent().add_child(p)


func _alive_dummies() -> int:
	var n := 0
	for d in _dummies:
		if is_instance_valid(d) and d.is_alive():
			n += 1
	return n


# interfaz

func _key_text(text: String) -> String:
	var out := text
	var re := RegEx.new()
	re.compile("\\{K:([a-z_]+)\\}")
	for m in re.search_all(text):
		out = out.replace(m.get_string(0), Settings.key_name(m.get_string(1)))
	return out


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	layer.add_child(root)

	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.BG, 0.94), UIStyle.OBJECTIVE, 2, 8, 20, 14))
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.offset_left = -320.0
	_card.offset_right = 320.0
	_card.offset_top = 62.0
	_card.offset_bottom = 62.0
	root.add_child(_card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	_step_label = UIStyle.label("TUTORIAL", 14, UIStyle.TEXT_DIM, true)
	_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_step_label)
	header.add_child(UIStyle.label("[N] SALTAR PASO", 13, UIStyle.TEXT_DIM))

	_title_label = UIStyle.label("", 26, UIStyle.OBJECTIVE, true)
	box.add_child(_title_label)

	_body_label = UIStyle.label("", 17, UIStyle.TEXT)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(580, 0)
	box.add_child(_body_label)

	_keys_box = HBoxContainer.new()
	_keys_box.add_theme_constant_override("separation", 8)
	_keys_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_keys_box)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	for i in range(STEPS.size()):
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(44, 6)
		seg.color = UIStyle.BAR_EMPTY
		bar.add_child(seg)
		_segments.append(seg)

	# aviso corto bajo la tarjeta
	_hint_label = UIStyle.label("", 20, UIStyle.LIFE, true)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hint_label.add_theme_constant_override("outline_size", 6)
	_hint_label.anchor_left = 0.5
	_hint_label.anchor_right = 0.5
	_hint_label.offset_left = -400.0
	_hint_label.offset_right = 400.0
	_hint_label.offset_top = 0.0
	_hint_label.modulate.a = 0.0
	_hint_label.name = "HintLabel"
	root.add_child(_hint_label)


func _update_card() -> void:
	var data: Dictionary = STEPS[step]
	_step_label.text = "TUTORIAL · PASO %d DE %d" % [step + 1, STEPS.size()]
	_title_label.text = String(data["title"])
	_body_label.text = _key_text(String(data["body"]))

	for c in _keys_box.get_children():
		_keys_box.remove_child(c)
		c.queue_free()
	for k in data["keys"]:
		_keys_box.add_child(_keycap(_key_text(String(k))))

	for i in range(_segments.size()):
		_segments[i].color = UIStyle.BAR_FILL if i < step else (UIStyle.OBJECTIVE if i == step else UIStyle.BAR_EMPTY)

	# la tarjeta salta al cambiar de paso
	_card.visible = true
	_card.pivot_offset = Vector2(320, 0)
	_card.scale = Vector2(1.04, 1.04)
	create_tween().tween_property(_card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	call_deferred("_place_hint")


func _place_hint() -> void:
	_hint_label.offset_top = _card.offset_top + _card.size.y + 10.0
	_hint_label.offset_bottom = _hint_label.offset_top + 30.0


func _keycap(text: String) -> Control:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, UIStyle.OBJECTIVE, 2, 5, 10, 3))
	var l := UIStyle.label(text.to_upper(), 14, UIStyle.TEXT, true)
	cap.add_child(l)
	return cap


func _hint(text: String) -> void:
	_hint_label.text = text
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_label.modulate.a = 1.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(2.2)
	_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_N and not _done:
		skip_step()


func _show_end_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	layer.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UIStyle.BG, 0.93)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := UIStyle.label("TUTORIAL COMPLETADO", 56, UIStyle.OBJECTIVE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var recap := UIStyle.label("Ya sabes: rifle automático · escopeta · cuchillo · sigilo y punto ciego · combo y flow · botín · llave y puerta.", 17, UIStyle.TEXT_DIM)
	recap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recap.custom_minimum_size = Vector2(620, 0)
	box.add_child(recap)
	box.add_child(Control.new())

	var play := UIStyle.button("JUGAR NIVEL 1", Vector2(360, 54))
	play.pressed.connect(func() -> void: GameManager.start_level(0))
	box.add_child(play)

	var again := UIStyle.button("REPETIR TUTORIAL", Vector2(360, 54))
	again.pressed.connect(GameManager.start_tutorial)
	box.add_child(again)

	var menu := UIStyle.button("VOLVER AL MENÚ", Vector2(360, 54))
	menu.pressed.connect(GameManager.go_to_menu)
	box.add_child(menu)

	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	get_tree().paused = true
	play.grab_focus()
