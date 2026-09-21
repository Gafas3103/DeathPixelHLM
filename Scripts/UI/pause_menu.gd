extends CanvasLayer

## Menú de pausa (Esc). Lo crea Level.gd y congela el juego con get_tree().paused.

const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const SettingsMenu := preload("res://Scripts/UI/settings_menu.gd")

var _root: Control
var _settings = null  # sin tipo: su script define la señal closed
var _help: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UIStyle.BG, 0.85)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := UIStyle.label("PAUSA", 56, UIStyle.OBJECTIVE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_help = UIStyle.label("", 15, UIStyle.TEXT_DIM)
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_help)
	box.add_child(Control.new())

	var resume := UIStyle.button("CONTINUAR", Vector2(320, 50))
	resume.pressed.connect(_resume)
	box.add_child(resume)

	var settings_btn := UIStyle.button("AJUSTES", Vector2(320, 50))
	settings_btn.pressed.connect(_open_settings)
	box.add_child(settings_btn)

	var restart := UIStyle.button("REINICIAR NIVEL", Vector2(320, 50))
	restart.pressed.connect(GameManager.restart_level)
	box.add_child(restart)

	var menu := UIStyle.button("MENÚ PRINCIPAL", Vector2(320, 50))
	menu.pressed.connect(GameManager.go_to_menu)
	box.add_child(menu)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# si hay otra pantalla encima no interfiere
	if _settings != null and is_instance_valid(_settings):
		return
	if not _root.visible and (Global.health <= 0.0 or get_tree().paused):
		return
	get_viewport().set_input_as_handled()
	if _root.visible:
		_resume()
	else:
		_pause()


func _refresh_help() -> void:
	_help.text = "MOVER: WASD · APUNTAR: MOUSE · DISPARAR: CLIC IZQ. (MANTENER = RÁFAGA)\nARMAS: 1 RIFLE · 2 ESCOPETA · 3 CUCHILLO · %s CAMBIAR · %s RECARGAR\nCUCHILLO RÁPIDO: %s / CLIC DER. · SIGILO (CAMINAR DESPACIO): %s · INTERACTUAR: %s" % [
		Settings.key_name("weapon_next"), Settings.key_name("reload"), Settings.key_name("melee"), Settings.key_name("sneak"), Settings.key_name("action")]


func _pause() -> void:
	_refresh_help()
	_root.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)


func _resume() -> void:
	_root.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)


func _open_settings() -> void:
	_settings = SettingsMenu.new()
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)
	_root.visible = false


func _on_settings_closed() -> void:
	_settings = null
	_root.visible = true
