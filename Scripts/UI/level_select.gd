extends Control

## Selección de niveles: lista a la izquierda, imagen y datos del nivel a la derecha (GameManager.LEVELS).

const UIStyle := preload("res://Scripts/UI/ui_style.gd")

var _buttons: Array[Button] = []
var _preview: TextureRect
var _preview_fallback: Label
var _name_label: Label
var _desc_label: Label
var _info_label: Label
var _status_label: Label
var _selected: int = 0
var _diff_buttons: Array[Button] = []
var _diff_desc: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_build()
	# empieza en el nivel más avanzado que ya se puede jugar
	var start := 0
	for i in range(GameManager.level_count()):
		if GameManager.is_unlocked(i):
			start = i
	_select(start)
	_refresh_difficulty()
	_buttons[_selected].grab_focus()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UIStyle.BG
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	var title_panel := PanelContainer.new()
	root.add_child(title_panel)
	var title := UIStyle.label("SECCIÓN DE NIVELES", 32, UIStyle.OBJECTIVE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_panel.add_child(title)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	root.add_child(body)

	# lista
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)

	for i in range(GameManager.level_count()):
		var b := UIStyle.button("", Vector2(300, 48))
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_on_level_pressed.bind(i))
		b.mouse_entered.connect(_select.bind(i))
		b.focus_entered.connect(_select.bind(i))
		left.add_child(b)
		_buttons.append(b)
	_refresh_button_texts()

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	# dificultad
	var diff_title := UIStyle.label("DIFICULTAD", 15, UIStyle.TEXT_DIM, true)
	left.add_child(diff_title)
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 6)
	left.add_child(diff_row)
	for i in range(Settings.DIFFICULTIES.size()):
		var db := UIStyle.button(Settings.DIFFICULTIES[i], Vector2(96, 40))
		db.add_theme_font_size_override("font_size", 15)
		db.pressed.connect(_on_difficulty_pressed.bind(i))
		diff_row.add_child(db)
		_diff_buttons.append(db)
	_diff_desc = UIStyle.label("", 13, UIStyle.TEXT_DIM)
	_diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_desc.custom_minimum_size = Vector2(300, 56)
	left.add_child(_diff_desc)

	var back := UIStyle.button("REGRESAR", Vector2(300, 52))
	back.pressed.connect(GameManager.go_to_menu)
	left.add_child(back)

	# vista previa
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 10)
	right.add_child(right_box)

	var preview_holder := PanelContainer.new()
	preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_holder.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BAR_EMPTY, 2, 4, 6, 6))
	right_box.add_child(preview_holder)

	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(300, 220)
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_holder.add_child(_preview)

	_preview_fallback = UIStyle.label("SIN VISTA PREVIA", 22, UIStyle.BAR_EMPTY, true)
	_preview_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_fallback.visible = false
	preview_holder.add_child(_preview_fallback)

	_name_label = UIStyle.label("", 28, UIStyle.TEXT, true)
	right_box.add_child(_name_label)

	_desc_label = UIStyle.label("", 17, UIStyle.TEXT_DIM)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_box.add_child(_desc_label)

	_info_label = UIStyle.label("", 17, UIStyle.AMMO)
	right_box.add_child(_info_label)

	_status_label = UIStyle.label("", 18, UIStyle.BAR_FILL, true)
	right_box.add_child(_status_label)


func _refresh_button_texts() -> void:
	for i in range(_buttons.size()):
		var text := "LEVEL %d" % (i + 1)
		if not GameManager.is_playable(i):
			text += "  ···"
		elif not GameManager.is_unlocked(i):
			text += "  [BLOQUEADO]"
		_buttons[i].text = text
		var dim := not GameManager.is_unlocked(i)
		_buttons[i].modulate = Color(1, 1, 1, 0.55) if dim else Color.WHITE


func _select(index: int) -> void:
	_selected = index
	var data: Dictionary = GameManager.LEVELS[index]
	var unlocked := GameManager.is_unlocked(index)
	var playable := GameManager.is_playable(index)

	_name_label.text = "LEVEL %d · %s" % [index + 1, String(data["name"])]
	_desc_label.text = String(data["desc"])

	var path := String(data["preview"])
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_preview.texture = tex
	_preview.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.4, 1.0)
	_preview_fallback.visible = tex == null

	if playable:
		_info_label.text = "ENEMIGOS: %d    MEJOR PUNTAJE: %d" % [int(data["enemies"][Settings.difficulty]), GameManager.best_score(index)]
	else:
		_info_label.text = ""

	if not playable:
		_status_label.text = "PRÓXIMAMENTE"
		_status_label.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
	elif not unlocked:
		_status_label.text = "BLOQUEADO · COMPLETA EL NIVEL %d PARA ENTRAR" % index
		_status_label.add_theme_color_override("font_color", UIStyle.LIFE)
	else:
		_status_label.text = "PRESIONA PARA JUGAR"
		_status_label.add_theme_color_override("font_color", UIStyle.BAR_FILL)


func _on_difficulty_pressed(index: int) -> void:
	Settings.set_difficulty(index)
	_refresh_difficulty()
	_select(_selected)


func _refresh_difficulty() -> void:
	for i in range(_diff_buttons.size()):
		if i == Settings.difficulty:
			_diff_buttons[i].add_theme_stylebox_override("normal", UIStyle.box(UIStyle.BAR_EMPTY, UIStyle.OBJECTIVE, 2))
			_diff_buttons[i].add_theme_color_override("font_color", UIStyle.OBJECTIVE)
		else:
			_diff_buttons[i].remove_theme_stylebox_override("normal")
			_diff_buttons[i].remove_theme_color_override("font_color")
	_diff_desc.text = Settings.DIFFICULTY_DESCRIPTIONS[Settings.difficulty]


func _on_level_pressed(index: int) -> void:
	if GameManager.is_unlocked(index):
		GameManager.start_level(index)
	else:
		_select(index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.go_to_menu()
