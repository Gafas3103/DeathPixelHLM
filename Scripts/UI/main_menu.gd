extends Control

const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const Story := preload("res://Scripts/story.gd")
const StoryScreen := preload("res://Scripts/UI/story_screen.gd")

const CREDITS: Array[String] = [
	"Cristian Serrano|PROGRAMADOR · COORDINADOR · QA",
	"Brian Alba|PROGRAMADOR",
	"Alejandro Rivera|HUD · QA",
	"Isaac Mosquera|ENEMIGOS · ARMAS · ANIMACIONES",
	"Palencia Florez|ENEMIGOS · ARMAS · ANIMACIONES",
	"Kevin Beltran|CORRECCIÓN DE MAPAS",
]
const ENGINE_CREDIT := "HECHO CON GODOT ENGINE 4"

const IDLE_HINT := "Elige una opción del menú."

var _desc: Label
var _menu_box: VBoxContainer
var _credits_panel: Control = null
var _prompt: Control = null
var _story: CanvasLayer = null
var _history_btn: Button
var _credits_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UIStyle.BG
	add_child(bg)
	add_child(_make_embers())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	root.add_child(title_box)

	var title := UIStyle.label("DEATH PIXEL", 92, UIStyle.OBJECTIVE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", UIStyle.LIFE.darkened(0.5))
	title.add_theme_constant_override("outline_size", 10)
	title_box.add_child(title)

	var subtitle := UIStyle.label("H O T L I N E   M I A M I   S W A T", 20, UIStyle.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(subtitle)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 10)
	center.add_child(_menu_box)

	var play := _add_button("JUGAR", "Elige un nivel y empieza la misión.", _on_play)
	_add_button("TUTORIAL", "Aprende a jugar: armas, sigilo, combos, botín y puertas. Se juega sin peligro.", _on_tutorial)
	_history_btn = _add_button("HISTORIA", _history_description(), _on_history)
	_add_button("AJUSTES", "Gráficos, audio, controles y opciones generales.", _on_settings)
	_credits_btn = _add_button("CRÉDITOS", "Quién hizo el juego.", _on_credits)
	_menu_box.add_child(Control.new())
	_add_button("SALIR", "Cierra el juego.", _on_quit)

	var desc_panel := PanelContainer.new()
	root.add_child(desc_panel)
	_desc = UIStyle.label(IDLE_HINT, 20, UIStyle.TEXT_DIM)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_panel.add_child(_desc)

	play.grab_focus()


func _add_button(text: String, description: String, action: Callable) -> Button:
	var b := UIStyle.button(text, Vector2(320, 52))
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	b.mouse_entered.connect(func() -> void: _desc.text = description)
	b.focus_entered.connect(func() -> void: _desc.text = description)
	b.mouse_exited.connect(func() -> void: _desc.text = IDLE_HINT)
	_menu_box.add_child(b)
	return b


func _make_embers() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2(640, 740)
	p.amount = 40
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(680, 4)
	p.direction = Vector2(0, -1)
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UIStyle.OBJECTIVE, 0.0))
	gradient.set_color(1, Color(UIStyle.LIFE, 0.0))
	gradient.add_point(0.15, Color(UIStyle.OBJECTIVE, 0.55))
	gradient.add_point(0.7, Color(UIStyle.LIFE, 0.35))
	p.color_ramp = gradient
	return p


func _on_play() -> void:
	if GameManager.tutorial_done or _prompt != null:
		GameManager.go_to_level_select()
	else:
		_show_tutorial_prompt()


func _on_tutorial() -> void:
	GameManager.start_tutorial()


func _show_tutorial_prompt() -> void:
	_prompt = Control.new()
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_prompt)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UIStyle.BG, 0.94)
	_prompt.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prompt.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := UIStyle.label("¿PRIMERA VEZ?", 52, UIStyle.OBJECTIVE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var text := UIStyle.label("Este juego tiene rifle automático, escopeta, cuchillo, SIGILO (los enemigos te detectan poco a poco y se les puede matar por la espalda), combos y modo BERSERK.\n\nEl tutorial dura unos 5 minutos, no puedes morir y explica todo paso a paso.", 18, UIStyle.TEXT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(640, 0)
	box.add_child(text)
	box.add_child(Control.new())

	var yes := UIStyle.button("HACER EL TUTORIAL (RECOMENDADO)", Vector2(440, 56))
	yes.pressed.connect(GameManager.start_tutorial)
	box.add_child(yes)

	var no := UIStyle.button("IR A LOS NIVELES", Vector2(440, 56))
	no.pressed.connect(func() -> void:
		GameManager.tutorial_done = true
		GameManager.go_to_level_select())
	box.add_child(no)

	var back := UIStyle.button("VOLVER", Vector2(440, 48))
	back.pressed.connect(_close_prompt)
	box.add_child(back)
	yes.grab_focus()


func _close_prompt() -> void:
	if _prompt != null:
		_prompt.queue_free()
		_prompt = null
	(_menu_box.get_child(0) as Button).grab_focus()


func _on_settings() -> void:
	GameManager.go_to_settings()


func _on_credits() -> void:
	if _credits_panel != null:
		return
	_credits_panel = Control.new()
	_credits_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_credits_panel)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = UIStyle.BG
	_credits_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_panel.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := UIStyle.label("CRÉDITOS", 60, UIStyle.OBJECTIVE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 72)
	grid.add_theme_constant_override("v_separation", 22)
	box.add_child(grid)
	for line in CREDITS:
		var parts := line.split("|")
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(380, 0)
		cell.add_theme_constant_override("separation", 2)
		grid.add_child(cell)
		var who := UIStyle.label(parts[0].to_upper(), 26, UIStyle.TEXT, true)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(who)
		if parts.size() > 1:
			var role := UIStyle.label(parts[1], 15, UIStyle.OBJECTIVE)
			role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(role)

	var engine := UIStyle.label(ENGINE_CREDIT, 15, UIStyle.TEXT_DIM)
	engine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(engine)

	box.add_child(Control.new())
	var back := UIStyle.button("REGRESAR", Vector2(260, 52))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_credits)
	box.add_child(back)
	back.grab_focus()


func _close_credits() -> void:
	if _credits_panel != null:
		_credits_panel.queue_free()
		_credits_panel = null
	_credits_btn.grab_focus()


func _history_description() -> String:
	if GameManager.game_completed:
		return "Vuelve a ver la historia de Vega: el prólogo y, como ya terminaste el juego, también el epílogo."
	return "Vuelve a ver el prólogo: quién es Vega y por qué va tras el Contratista."


func _story_open() -> bool:
	return _story != null and is_instance_valid(_story)


func _on_history() -> void:
	if _story_open():
		return
	var s := StoryScreen.new()
	s.pages = Story.PROLOGUE
	s.heading = "PRÓLOGO"
	s.finished.connect(_on_prologue_replayed)
	_story = s
	add_child(s)


func _on_prologue_replayed() -> void:
	if not GameManager.prologue_seen:
		GameManager.mark_prologue_seen()
	if not GameManager.game_completed:
		_on_story_done()
		return
	var s := StoryScreen.new()
	s.pages = Story.EPILOGUE
	s.heading = "EPÍLOGO"
	s.end_title = "FIN"
	s.end_subtitle = "GRACIAS POR JUGAR"
	s.finished.connect(_on_story_done)
	_story = s
	add_child(s)


func _on_story_done() -> void:
	_story = null
	if _history_btn != null:
		_history_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _story_open():
		return
	if event.is_action_pressed("ui_cancel") and _credits_panel != null:
		get_viewport().set_input_as_handled()
		_close_credits()
	elif event.is_action_pressed("ui_cancel") and _prompt != null:
		get_viewport().set_input_as_handled()
		_close_prompt()


func _on_quit() -> void:
	get_tree().quit()
