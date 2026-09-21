extends CanvasLayer

## Pantalla de victoria: pausa el juego y ofrece el siguiente nivel o el menú.

const UIStyle := preload("res://Scripts/UI/ui_style.gd")


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UIStyle.BG, 0.94)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := UIStyle.label("VICTORIA", 84, UIStyle.OBJECTIVE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var level_name := ""
	if GameManager.current_index >= 0:
		level_name = String(GameManager.LEVELS[GameManager.current_index]["name"])
	var sub := UIStyle.label("MISIÓN CUMPLIDA · " + level_name, 20, UIStyle.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var stats := PanelContainer.new()
	box.add_child(stats)
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 4)
	stats.add_child(stats_box)
	stats_box.add_child(_stat_line("PUNTAJE", str(Global.score), UIStyle.TEXT))
	stats_box.add_child(_stat_line("BAJAS", str(Global.kills), UIStyle.LIFE))
	stats_box.add_child(_stat_line("MEJOR PUNTAJE", str(GameManager.best_score(GameManager.current_index)), UIStyle.BAR_FILL))

	box.add_child(Control.new())

	var next_btn := UIStyle.button("SIGUIENTE NIVEL", Vector2(360, 54))
	if GameManager.has_next_level():
		next_btn.pressed.connect(GameManager.next_level)
	else:
		next_btn.text = "SIN MÁS NIVELES (PRÓXIMAMENTE)"
		next_btn.disabled = true
	box.add_child(next_btn)

	var menu_btn := UIStyle.button("VOLVER AL MENÚ", Vector2(360, 54))
	menu_btn.pressed.connect(GameManager.go_to_menu)
	box.add_child(menu_btn)

	if next_btn.disabled:
		menu_btn.grab_focus()
	else:
		next_btn.grab_focus()


func _stat_line(caption: String, value: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(340, 0)
	var left := UIStyle.label(caption, 18, UIStyle.TEXT_DIM)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	row.add_child(UIStyle.label(value, 22, color, true))
	return row
