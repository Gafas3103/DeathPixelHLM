extends Control

## Menú de ajustes. Como pantalla propia (Scenes/UI/SettingsMenu.tscn) vuelve al menú al cerrar;
## superpuesto (SettingsMenu.new() en pausa) emite closed y se elimina.
## Cada ajuste llama al autoload Settings.

signal closed

const UIStyle := preload("res://Scripts/UI/ui_style.gd")

const TAB_NAMES: Array[String] = ["GRÁFICOS", "AUDIO", "CONTROLES", "GENERAL"]
const TAB_TITLES: Array[String] = ["CONFIGURACIÓN DE GRÁFICOS", "CONFIGURACIÓN DE AUDIO", "CONFIGURACIÓN DE CONTROLES", "CONFIGURACIÓN GENERAL"]
const DEFAULT_HINT := "Pasa el cursor sobre un ajuste para ver qué hace."

var _content: VBoxContainer
var _title: Label
var _desc: Label
var _tab_buttons: Array[Button] = []
var _current_tab: int = 0

var _rebinding_action: String = ""
var _key_buttons: Dictionary = {}
var _resolution_option: OptionButton = null
var _wipe_armed: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _is_standalone():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build()
	_show_tab(0)
	_tab_buttons[0].grab_focus()


# estructura

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UIStyle.BG
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# encabezado
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)

	var title_panel := PanelContainer.new()
	title_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_panel)
	var header_label := UIStyle.label("AJUSTES - DEATH PIXEL", 26, UIStyle.OBJECTIVE, true)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_panel.add_child(header_label)

	var logo := PanelContainer.new()
	logo.custom_minimum_size = Vector2(84, 0)
	header.add_child(logo)
	var logo_label := UIStyle.label("DP", 26, UIStyle.LIFE, true)
	logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(logo_label)

	# cuerpo
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)

	for i in range(TAB_NAMES.size()):
		var b := UIStyle.button(TAB_NAMES[i], Vector2(250, 52))
		b.pressed.connect(_show_tab.bind(i))
		left.add_child(b)
		_tab_buttons.append(b)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	var back := UIStyle.button("REGRESAR", Vector2(250, 52))
	back.pressed.connect(_close)
	_hook_desc(back, "Vuelve a la pantalla anterior. Los cambios ya quedaron guardados.")
	left.add_child(back)

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 12)
	right.add_child(right_box)

	_title = UIStyle.label("", 22, UIStyle.TEXT, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_box.add_child(_title)
	right_box.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_box.add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_right", 18)
	scroll.add_child(scroll_margin)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	scroll_margin.add_child(_content)

	# pie con la descripción
	var desc_panel := PanelContainer.new()
	root.add_child(desc_panel)
	_desc = UIStyle.label(DEFAULT_HINT, 18, UIStyle.TEXT_DIM)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_panel.add_child(_desc)


func _show_tab(index: int) -> void:
	_cancel_rebind()
	_wipe_armed = false
	_current_tab = index
	_key_buttons.clear()
	_resolution_option = null

	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	match index:
		0: _build_graphics()
		1: _build_audio()
		2: _build_controls()
		3: _build_general()

	_title.text = TAB_TITLES[index]
	_desc.text = DEFAULT_HINT
	for i in range(_tab_buttons.size()):
		if i == index:
			_tab_buttons[i].add_theme_stylebox_override("normal", UIStyle.box(UIStyle.BAR_EMPTY, UIStyle.OBJECTIVE, 2))
		else:
			_tab_buttons[i].remove_theme_stylebox_override("normal")


# pestañas

func _build_graphics() -> void:
	var mode := _option(["VENTANA", "PANTALLA COMPLETA"], 1 if Settings.fullscreen else 0)
	mode.item_selected.connect(func(i: int) -> void:
		Settings.set_fullscreen(i == 1)
		if _resolution_option != null:
			_resolution_option.disabled = Settings.fullscreen)
	_add_row("MODO DE PANTALLA", mode, "Ventana o pantalla completa. Puedes cambiarlo también con la tecla ALT+ENTER de tu sistema.")

	var res_names: Array[String] = []
	for r in Settings.RESOLUTIONS:
		res_names.append("%d x %d" % [r.x, r.y])
	_resolution_option = _option(res_names, Settings.resolution_index)
	_resolution_option.disabled = Settings.fullscreen
	_resolution_option.item_selected.connect(Settings.set_resolution_index)
	_add_row("RESOLUCIÓN", _resolution_option, "Tamaño de la ventana. Solo se puede cambiar en modo VENTANA.")

	var vsync := _check(Settings.vsync)
	vsync.toggled.connect(Settings.set_vsync)
	_add_row("SINCRONIZACIÓN VERTICAL", vsync, "Evita cortes en la imagen sincronizando con el monitor. Desactívala si sientes retraso.", null, false)

	var fps := _option(["SIN LÍMITE", "30", "60", "120", "144"], Settings.fps_index)
	fps.item_selected.connect(Settings.set_fps_index)
	_add_row("LÍMITE DE FPS", fps, "Máximo de cuadros por segundo. Un límite menor ahorra batería y calor.")

	var bright := _slider(50.0, 150.0, 5.0, Settings.brightness * 100.0,
		func(v: float) -> void: Settings.set_brightness(v / 100.0),
		func(v: float) -> String: return "%d%%" % roundi(v))
	_add_row("BRILLO", bright[0], "Oscurece o aclara todo el juego. 100% es el valor normal.", bright[1])

	var lighting := _option(Settings.LIGHTING_QUALITIES, Settings.lighting_quality)
	lighting.item_selected.connect(Settings.set_lighting_quality)
	_add_row("ILUMINACIÓN", lighting, "BAJA: sin oscuridad ni luces, como el juego original; para equipos lentos. MEDIA: atardecer, noche y apagón con linterna y luces de colores, sin sombras. ALTA: además las paredes bloquean la luz y proyectan sombras. Se aplica al momento.")

	var show_fps := _check(Settings.show_fps)
	show_fps.toggled.connect(Settings.set_show_fps)
	_add_row("MOSTRAR FPS", show_fps, "Muestra los cuadros por segundo en la parte superior de la pantalla.", null, false)


func _build_audio() -> void:
	var fmt := func(v: float) -> String: return "%d%%" % roundi(v)

	var master := _slider(0.0, 100.0, 1.0, Settings.master_volume * 100.0,
		func(v: float) -> void: Settings.set_master_volume(v / 100.0), fmt)
	_add_row("VOLUMEN GENERAL", master[0], "Volumen de todo el juego.", master[1])

	var music := _slider(0.0, 100.0, 1.0, Settings.music_volume * 100.0,
		func(v: float) -> void: Settings.set_music_volume(v / 100.0), fmt)
	_add_row("MÚSICA", music[0], "Volumen de la música (bus \"Music\").", music[1])

	var sfx := _slider(0.0, 100.0, 1.0, Settings.sfx_volume * 100.0,
		func(v: float) -> void: Settings.set_sfx_volume(v / 100.0), fmt)
	_add_row("EFECTOS", sfx[0], "Volumen de disparos, pasos y efectos (bus \"SFX\").", sfx[1])

	var mute := _check(Settings.muted)
	mute.toggled.connect(Settings.set_muted)
	_add_row("SILENCIAR TODO", mute, "Silencia el juego sin perder tus volúmenes.", null, false)

	var note := UIStyle.label("Los sonidos del juego usan los buses Music y SFX; estos controles ya los afectan.", 14, UIStyle.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)


func _build_controls() -> void:
	for action in Settings.REBINDABLE:
		var btn := UIStyle.button(Settings.key_name(action), Vector2(180, 40))
		btn.pressed.connect(_start_rebind.bind(String(action)))
		_key_buttons[action] = btn
		_add_row(String(Settings.REBINDABLE[action]), btn, "Clic y presiona la nueva tecla. ESC cancela.", null, false)

	_add_fixed_row("DISPARAR", "CLIC IZQUIERDO", "Rifle: un toque = un disparo, mantener = ráfaga. Escopeta: un disparo por clic. Cuchillo: ataque cuerpo a cuerpo.")
	_add_fixed_row("ELEGIR ARMA", "1 · 2 · 3", "1 = rifle automático, 2 = escopeta, 3 = cuchillo. También puedes usar la rueda del mouse o la tecla de cambiar arma.")
	_add_fixed_row("PAUSA", "ESC", "Abre el menú de pausa durante la partida.")

	var reset := UIStyle.button("RESTABLECER TECLAS", Vector2(260, 44))
	reset.pressed.connect(func() -> void:
		Settings.reset_keybinds()
		_refresh_key_buttons())
	_hook_desc(reset, "Devuelve todas las teclas a su valor original (WASD, E y R).")
	_content.add_child(reset)


func _build_general() -> void:
	var diff := _option(Settings.DIFFICULTIES, Settings.difficulty)
	diff.item_selected.connect(Settings.set_difficulty)
	_add_row("DIFICULTAD", diff, "Cambia la cantidad y la inteligencia de los enemigos, el botín y la recarga automática (solo Fácil y Normal). Se aplica al empezar el nivel.")

	var minimap := _check(Settings.show_minimap)
	minimap.toggled.connect(Settings.set_show_minimap)
	_add_row("MOSTRAR MINIMAPA", minimap, "Muestra u oculta el radar de arriba a la derecha.", null, false)

	var cross := _slider(50.0, 200.0, 10.0, Settings.crosshair_scale * 100.0,
		func(v: float) -> void: Settings.set_crosshair_scale(v / 100.0),
		func(v: float) -> String: return "%d%%" % roundi(v))
	_add_row("TAMAÑO DE MIRILLA", cross[0], "Hace más grande o más pequeña la mirilla roja.", cross[1])

	var unlock := _check(Settings.unlock_all_levels)
	unlock.toggled.connect(Settings.set_unlock_all_levels)
	_add_row("DESBLOQUEAR NIVELES", unlock, "Modo demostración: permite entrar a cualquier nivel sin haber pasado el anterior.", null, false)

	var wipe := UIStyle.button("BORRAR PROGRESO", Vector2(260, 44))
	wipe.pressed.connect(func() -> void:
		if not _wipe_armed:
			_wipe_armed = true
			wipe.text = "¿SEGURO? PRESIONA OTRA VEZ"
		else:
			_wipe_armed = false
			GameManager.reset_progress()
			wipe.text = "PROGRESO BORRADO")
	_hook_desc(wipe, "Vuelve a bloquear los niveles y borra los mejores puntajes. Pide confirmación.")
	_content.add_child(wipe)

	var defaults := UIStyle.button("RESTABLECER AJUSTES", Vector2(260, 44))
	defaults.pressed.connect(func() -> void:
		Settings.reset_defaults()
		_show_tab(_current_tab))
	_hook_desc(defaults, "Devuelve gráficos, audio y ajustes generales a sus valores de fábrica (no toca las teclas).")
	_content.add_child(defaults)


# reasignar teclas

func _start_rebind(action: String) -> void:
	_cancel_rebind()
	_rebinding_action = action
	var btn: Button = _key_buttons.get(action)
	if btn != null:
		btn.text = "PRESIONA UNA TECLA…"
	_desc.text = "Presiona la nueva tecla para «%s». ESC cancela." % String(Settings.REBINDABLE[action])


func _cancel_rebind() -> void:
	if _rebinding_action == "":
		return
	_rebinding_action = ""
	_refresh_key_buttons()


func _refresh_key_buttons() -> void:
	for action in _key_buttons:
		var btn: Button = _key_buttons[action]
		btn.text = Settings.key_name(action)


func _input(event: InputEvent) -> void:
	if _rebinding_action == "":
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	get_viewport().set_input_as_handled()
	if key_event.physical_keycode == KEY_ESCAPE:
		_cancel_rebind()
		_desc.text = DEFAULT_HINT
		return
	var action := _rebinding_action
	var conflict := Settings.rebind(action, key_event)
	_rebinding_action = ""
	_refresh_key_buttons()
	if conflict == "":
		_desc.text = "Tecla asignada a «%s»." % String(Settings.REBINDABLE[action])
	else:
		_desc.text = "Esa tecla ya la usa «%s». Elige otra." % conflict


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


## true si es la escena principal, no un panel superpuesto
func _is_standalone() -> bool:
	return get_parent() == get_tree().root


func _close() -> void:
	if _is_standalone():
		GameManager.go_to_menu()
		return
	closed.emit()
	queue_free()


# filas

func _add_row(caption: String, control: Control, description: String, hook_extra: Control = null, expand: bool = true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var l := UIStyle.label(caption, 18, UIStyle.TEXT)
	l.custom_minimum_size = Vector2(260, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)

	if expand:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(control)
	_content.add_child(row)

	_hook_desc(l, description)
	_hook_desc(control, description)
	if hook_extra != null:
		_hook_desc(hook_extra, description)


func _add_fixed_row(caption: String, value: String, description: String) -> void:
	var v := UIStyle.label(value, 18, UIStyle.OBJECTIVE, true)
	_add_row(caption, v, description, null, false)


func _hook_desc(c: Control, description: String) -> void:
	c.mouse_entered.connect(func() -> void: _desc.text = description)
	c.focus_entered.connect(func() -> void: _desc.text = description)


func _option(items: Array, selected: int) -> OptionButton:
	var o := OptionButton.new()
	for item in items:
		o.add_item(String(item))
	o.selected = selected
	o.custom_minimum_size = Vector2(240, 40)
	return o


func _check(value: bool) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = value
	return c


## devuelve [contenedor, slider]
func _slider(min_v: float, max_v: float, step: float, value: float, on_change: Callable, fmt: Callable) -> Array:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)

	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(240, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(s)

	var value_label := UIStyle.label(String(fmt.call(value)), 18, UIStyle.OBJECTIVE, true)
	value_label.custom_minimum_size = Vector2(70, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(value_label)

	s.value_changed.connect(func(v: float) -> void:
		value_label.text = String(fmt.call(v))
		on_change.call(v))
	return [box, s]
