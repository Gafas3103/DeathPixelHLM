extends CanvasLayer

const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const Story := preload("res://Scripts/story.gd")
const StoryScreen := preload("res://Scripts/UI/story_screen.gd")

var _root: Control
var _rows: Array[Control] = []
var _score_value: Label
var _rank_label: Label
var _rank_box: Control
var _new_best: Label = null
var _story: CanvasLayer = null
var _final: bool = false
var _age: float = 0.0


static func rank_color(rank: String) -> Color:
	match rank:
		"S":
			return UIStyle.OBJECTIVE
		"A":
			return UIStyle.BAR_FILL
		"B":
			return UIStyle.AMMO
	return UIStyle.TEXT_DIM


static func clock(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d" % [floori(total / 60.0), total % 60]


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	_final = GameManager.is_final_level(GameManager.current_index)
	_build()
	_animate()


func _process(delta: float) -> void:
	_age += minf(delta / maxf(Engine.time_scale, 0.05), 0.1)
	if _new_best != null and _new_best.visible:
		_new_best.modulate.a = 0.6 + 0.4 * absf(sin(_age * 4.0))


func _build() -> void:
	var index := GameManager.current_index
	var data := GameManager.level_data(index)
	var rank := GameManager.last_rank
	if rank == "":
		rank = GameManager.compute_rank()

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UIStyle.BG, 0.95)
	_root.add_child(dim)
	_root.add_child(StoryScreen.pixel_dust(26, UIStyle.OBJECTIVE))
	_root.add_child(StoryScreen.vignette(0.7))
	_root.add_child(StoryScreen.scanlines(0.1))

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := UIStyle.label("EL CONTRATISTA HA CAÍDO" if _final else "VICTORIA", 60 if _final else 84, UIStyle.OBJECTIVE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(UIStyle.LIFE.darkened(0.45), 0.85))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title)
	_rows.append(title)

	var chapter := Story.chapter(index)
	var sub_text := "MISIÓN CUMPLIDA"
	if data.has("name"):
		sub_text += "   ·   " + String(data["name"])
	if chapter.has("title"):
		sub_text += "   ·   " + String(chapter["title"])
	var sub := StoryScreen.spaced_label(sub_text, 16, UIStyle.TEXT_DIM, 3, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	_rows.append(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	box.add_child(spacer)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(body)

	var stats := PanelContainer.new()
	stats.custom_minimum_size = Vector2(440, 0)
	body.add_child(stats)
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 6)
	stats.add_child(stats_box)

	var score_row := _stat_line("PUNTAJE", "0", UIStyle.TEXT)
	_score_value = score_row.get_child(1) as Label
	stats_box.add_child(score_row)
	stats_box.add_child(_stat_line("BAJAS", str(Global.kills), UIStyle.LIFE))
	stats_box.add_child(_stat_line("BAJAS SILENCIOSAS", str(Global.stealth_kills), UIStyle.AMMO))
	stats_box.add_child(_separator())
	var par := float(data.get("par_time", 0.0))
	var time_color := UIStyle.BAR_FILL if par > 0.0 and Global.level_time <= par else UIStyle.TEXT
	var time_row := _stat_line("TIEMPO", clock(Global.level_time), time_color)
	if par > 0.0:
		var par_label := UIStyle.label("/ " + clock(par), 15, UIStyle.TEXT_DIM)
		time_row.add_child(par_label)
	stats_box.add_child(time_row)
	stats_box.add_child(_stat_line("DETECCIONES", str(Global.times_detected), UIStyle.BAR_FILL if Global.times_detected == 0 else UIStyle.TEXT))
	stats_box.add_child(_stat_line("MUERTES", str(Global.deaths_this_level), UIStyle.BAR_FILL if Global.deaths_this_level == 0 else UIStyle.LIFE))
	stats_box.add_child(_separator())
	stats_box.add_child(_stat_line("MEJOR PUNTAJE", str(GameManager.best_score(index)), UIStyle.BAR_FILL))

	var rank_panel := PanelContainer.new()
	rank_panel.custom_minimum_size = Vector2(250, 0)
	rank_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, Color(rank_color(rank), 0.75), 2, 6, 14, 12))
	body.add_child(rank_panel)
	_rank_box = rank_panel

	var rank_box := VBoxContainer.new()
	rank_box.alignment = BoxContainer.ALIGNMENT_CENTER
	rank_box.add_theme_constant_override("separation", 0)
	rank_panel.add_child(rank_box)

	var rank_caption := StoryScreen.spaced_label("RANGO", 16, UIStyle.TEXT_DIM, 8, true)
	rank_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_box.add_child(rank_caption)

	_rank_label = UIStyle.label(rank, 150, rank_color(rank), true)
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_rank_label.add_theme_constant_override("outline_size", 10)
	rank_box.add_child(_rank_label)

	if GameManager.last_rank_new_best:
		_new_best = UIStyle.label("¡NUEVO MEJOR RANGO!", 17, UIStyle.OBJECTIVE, true)
		_new_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_box.add_child(_new_best)
	else:
		var best := GameManager.best_rank(index)
		var best_text := "MEJOR RANGO: %s" % best if best != "" else " "
		var best_label := UIStyle.label(best_text, 15, UIStyle.TEXT_DIM)
		best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_box.add_child(best_label)

	var tip := UIStyle.label("EL RANGO PREMIA TERMINAR RÁPIDO, SIN MORIR Y SIN QUE TE DETECTEN", 14, UIStyle.TEXT_DIM)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer2)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)

	var next_btn := UIStyle.button("SIGUIENTE NIVEL", Vector2(300, 54))
	if _final:
		next_btn.text = "VER EL FINAL"
		next_btn.pressed.connect(_on_show_ending)
	elif GameManager.has_next_level():
		next_btn.pressed.connect(GameManager.next_level)
	else:
		next_btn.text = "SIN MÁS NIVELES (PRÓXIMAMENTE)"
		next_btn.custom_minimum_size = Vector2(380, 54)
		next_btn.disabled = true
	if not next_btn.disabled:
		next_btn.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PANEL, UIStyle.OBJECTIVE, 2))
		next_btn.add_theme_color_override("font_color", UIStyle.OBJECTIVE)
	buttons.add_child(next_btn)

	var retry_btn := UIStyle.button("REPETIR NIVEL", Vector2(230, 54))
	retry_btn.pressed.connect(GameManager.restart_level)
	buttons.add_child(retry_btn)

	var menu_btn := UIStyle.button("VOLVER AL MENÚ", Vector2(250, 54))
	menu_btn.pressed.connect(GameManager.go_to_menu)
	buttons.add_child(menu_btn)

	for b: Button in [next_btn, retry_btn, menu_btn]:
		b.add_theme_font_size_override("font_size", 20)

	if next_btn.disabled:
		menu_btn.grab_focus()
	else:
		next_btn.grab_focus()

	for row in stats_box.get_children():
		_rows.append(row as Control)
	_rows.append(tip)
	_rows.append(buttons)


func _stat_line(caption: String, value: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var left := UIStyle.label(caption, 18, UIStyle.TEXT_DIM)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	row.add_child(UIStyle.label(value, 22, color, true))
	return row


func _separator() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(UIStyle.BAR_EMPTY, 0.9)
	return line


func _tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


func _animate() -> void:
	for row in _rows:
		row.modulate.a = 0.0
	_rank_label.modulate.a = 0.0
	if _new_best != null:
		_new_best.visible = false
	var tween := _tween()
	tween.set_parallel(true)
	for i in range(_rows.size()):
		tween.tween_property(_rows[i], "modulate:a", 1.0, 0.25).set_delay(0.05 * float(i))
	tween.tween_method(_set_score_text, 0.0, float(Global.score), 0.9).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_stamp_rank)


func _set_score_text(value: float) -> void:
	_score_value.text = str(int(round(value)))


func _stamp_rank() -> void:
	_score_value.text = str(Global.score)
	_rank_label.pivot_offset = _rank_label.size * 0.5
	_rank_label.scale = Vector2(2.4, 2.4)
	var tween := _tween()
	tween.set_parallel(true)
	tween.tween_property(_rank_label, "modulate:a", 1.0, 0.18)
	tween.tween_property(_rank_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func() -> void:
		if _new_best != null:
			_new_best.visible = true
		if _rank_box != null:
			_rank_box.pivot_offset = _rank_box.size * 0.5
			var shake := _tween()
			shake.tween_property(_rank_box, "rotation", deg_to_rad(-2.0), 0.05)
			shake.tween_property(_rank_box, "rotation", deg_to_rad(1.5), 0.06)
			shake.tween_property(_rank_box, "rotation", 0.0, 0.08))


func _on_show_ending() -> void:
	if _story != null and is_instance_valid(_story):
		return
	var s := StoryScreen.new()
	s.pages = Story.EPILOGUE
	s.heading = "EPÍLOGO"
	s.end_title = "FIN"
	s.end_subtitle = "GRACIAS POR JUGAR"
	s.finished.connect(_on_ending_finished)
	_story = s
	add_child(s)


func _on_ending_finished() -> void:
	GameManager.mark_game_completed()
	GameManager.go_to_menu()
