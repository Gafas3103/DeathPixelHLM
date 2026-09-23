extends CanvasLayer

signal closed

const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const Story := preload("res://Scripts/story.gd")
const StoryScreen := preload("res://Scripts/UI/story_screen.gd")

const BAR_HEIGHT := 64.0
const CHAR_DELAY := 0.022
const MIN_OPEN_TIME := 0.8
const OVERLAY := Color(0.035, 0.04, 0.06, 0.95)
const RULE_WIDTH := 380.0

var level_index: int = 0

var _root: Control
var _pixel: ColorRect
var _location: Label
var _title: Label
var _rule: ColorRect
var _text: RichTextLabel
var _parsed: String = ""
var _cards: Array[Control] = []
var _objective_label: Label
var _boss_value: Label = null
var _prompt: Label
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _intro_tween: Tween = null
var _age: float = 0.0
var _typing: bool = false
var _type_timer: float = 0.0
var _revealed: bool = false
var _armed: bool = false
var _closing: bool = false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()
	_build()
	_intro()
	if not Global.objective_changed.is_connected(_on_objective_changed):
		Global.objective_changed.connect(_on_objective_changed)


func _build() -> void:
	var data := GameManager.level_data(level_index)
	var chapter := Story.chapter(level_index)
	var title := String(chapter.get("title", "NIVEL %d" % (level_index + 1)))
	var location := String(chapter.get("location", String(data.get("name", ""))))
	var briefing := String(chapter.get("briefing", String(data.get("desc", ""))))

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = OVERLAY
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_root.add_child(StoryScreen.pixel_dust(16))
	_root.add_child(StoryScreen.vignette(0.85))
	_root.add_child(StoryScreen.scanlines(0.12))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", int(BAR_HEIGHT) + 30)
	margin.add_theme_constant_override("margin_bottom", int(BAR_HEIGHT) + 26)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var loc_row := HBoxContainer.new()
	loc_row.add_theme_constant_override("separation", 12)
	column.add_child(loc_row)
	_pixel = ColorRect.new()
	_pixel.color = UIStyle.LIFE
	_pixel.custom_minimum_size = Vector2(10, 10)
	_pixel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	loc_row.add_child(_pixel)
	_location = StoryScreen.spaced_label(location, 17, UIStyle.TEXT_DIM, 5, true)
	loc_row.add_child(_location)

	_title = UIStyle.label(title, 54, UIStyle.OBJECTIVE, true)
	_title.add_theme_color_override("font_shadow_color", Color(UIStyle.LIFE.darkened(0.45), 0.85))
	_title.add_theme_constant_override("shadow_offset_x", 4)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	column.add_child(_title)

	_rule = ColorRect.new()
	_rule.color = UIStyle.OBJECTIVE
	_rule.custom_minimum_size = Vector2(RULE_WIDTH, 3)
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_rule)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.custom_minimum_size = Vector2(900, 0)
	_text.add_theme_font_size_override("normal_font_size", 23)
	_text.add_theme_color_override("default_color", UIStyle.TEXT)
	_text.add_theme_constant_override("line_separation", 6)
	_text.text = briefing.replace("[", "(").replace("]", ")").replace("Contratista", "[color=#EF3E4A]Contratista[/color]")
	_parsed = _text.get_parsed_text()
	column.add_child(_text)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	column.add_child(cards)

	var twist := GameManager.twist_info(level_index)
	var twist_box := _card(cards, "MODALIDAD", UIStyle.AMMO)
	twist_box.add_child(UIStyle.label(String(twist.get("name", "ASALTO")), 24, UIStyle.TEXT, true))
	twist_box.add_child(_detail(String(twist.get("desc", ""))))

	var obj_box := _card(cards, "OBJETIVO", UIStyle.OBJECTIVE)
	_objective_label = UIStyle.label(_objective_text(), 20, UIStyle.TEXT, true)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(260, 0)
	obj_box.add_child(_objective_label)
	obj_box.add_child(_detail(_mission_details(data)))

	if GameManager.is_boss_level(level_index):
		var boss_box := _card(cards, "JEFE FINAL", UIStyle.LIFE)
		_boss_value = UIStyle.label(Story.BOSS_NAME, 24, UIStyle.LIFE, true)
		boss_box.add_child(_boss_value)
		boss_box.add_child(_detail("«%s»" % Story.BOSS_TITLE, UIStyle.TEXT))
		boss_box.add_child(_detail("Te espera antes de la salida. No podrás extraer mientras siga en pie."))

	var bars := StoryScreen.letterbox(_root, BAR_HEIGHT)
	_top_bar = bars[0]
	_bottom_bar = bars[1]

	var header_left := StoryScreen.spaced_label("INFORME DE MISIÓN", 14, UIStyle.TEXT_DIM, 6, true)
	_pin_in_bar(header_left, _top_bar, true)
	var difficulty := ""
	if Settings.difficulty >= 0 and Settings.difficulty < Settings.DIFFICULTIES.size():
		difficulty = "   ·   " + Settings.DIFFICULTIES[Settings.difficulty]
	var header_right := StoryScreen.spaced_label("NIVEL %d / %d%s" % [level_index + 1, GameManager.level_count(), difficulty], 14, UIStyle.TEXT_DIM, 4, true)
	header_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pin_in_bar(header_right, _top_bar, false)

	_prompt = StoryScreen.spaced_label("PRESIONA CUALQUIER TECLA PARA COMENZAR", 17, UIStyle.OBJECTIVE, 5, true)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.5
	_prompt.anchor_bottom = 0.5
	_prompt.offset_top = -14.0
	_prompt.offset_bottom = 14.0
	_bottom_bar.add_child(_prompt)


func _pin_in_bar(l: Label, bar: Control, left: bool) -> void:
	l.anchor_top = 0.5
	l.anchor_bottom = 0.5
	l.offset_top = -12.0
	l.offset_bottom = 12.0
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if left:
		l.offset_left = 48.0
		l.offset_right = 600.0
	else:
		l.anchor_left = 1.0
		l.anchor_right = 1.0
		l.offset_left = -600.0
		l.offset_right = -48.0
	bar.add_child(l)


func _card(parent: Control, caption: String, accent: Color) -> VBoxContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UIStyle.box(Color(UIStyle.PANEL, 0.88), Color(accent, 0.55), 2, 6, 16, 12)
	style.border_width_left = 5
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	box.add_child(StoryScreen.spaced_label(caption, 13, accent, 4, true))
	parent.add_child(card)
	_cards.append(card)
	return box


func _detail(text: String, color: Color = UIStyle.TEXT_DIM) -> Label:
	var l := UIStyle.label(text, 15, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	return l


func _mission_details(data: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("ENEMIGOS: %d" % _enemy_count(data))
	var par := float(data.get("par_time", 0.0))
	if par > 0.0:
		parts.append("TIEMPO OBJETIVO: %s" % _clock(par))
	var line := "   ·   ".join(parts)
	var rank := GameManager.best_rank(level_index)
	if rank != "":
		line += "\nRÉCORD: RANGO %s   ·   %d PTS" % [rank, GameManager.best_score(level_index)]
	return line


func _enemy_count(data: Dictionary) -> int:
	var count := 0
	if is_inside_tree():
		for e in get_tree().get_nodes_in_group("Enemies"):
			if e.has_method("is_alive") and not e.is_alive():
				continue
			count += 1
	if count == 0:
		var table: Variant = data.get("enemies", [])
		if table is Array and not (table as Array).is_empty():
			count = int((table as Array)[clampi(Settings.difficulty, 0, (table as Array).size() - 1)])
	return count


func _clock(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [floori(total / 60.0), total % 60]


func _objective_text() -> String:
	var t := Global.objective
	if t == "":
		var lv := get_parent()
		if lv != null and "objective_start" in lv:
			t = String(lv.get("objective_start"))
	if t == "":
		t = "ELIMINA A TODOS LOS ENEMIGOS"
	return t


func _on_objective_changed(_text_value: String) -> void:
	if _objective_label != null and is_instance_valid(_objective_label):
		_objective_label.text = _objective_text()


func _tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


func _intro() -> void:
	_root.modulate.a = 0.0
	_top_bar.offset_bottom = 0.0
	_bottom_bar.offset_top = 0.0
	_location.modulate.a = 0.0
	_title.modulate.a = 0.0
	_rule.custom_minimum_size.x = 0.0
	_text.visible_characters = 0
	_prompt.modulate.a = 0.0
	for c in _cards:
		c.modulate.a = 0.0
	_intro_tween = _tween()
	_intro_tween.tween_property(_root, "modulate:a", 1.0, 0.3)
	_intro_tween.parallel().tween_property(_top_bar, "offset_bottom", BAR_HEIGHT, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.parallel().tween_property(_bottom_bar, "offset_top", -BAR_HEIGHT, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_location, "modulate:a", 1.0, 0.25)
	_intro_tween.tween_property(_title, "modulate:a", 1.0, 0.3)
	_intro_tween.parallel().tween_property(_rule, "custom_minimum_size:x", RULE_WIDTH, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_callback(_begin_typing)


func _begin_typing() -> void:
	if _closing or _revealed:
		return
	_typing = true
	_type_timer = 0.1


func _process(delta: float) -> void:
	var dt := minf(delta / maxf(Engine.time_scale, 0.05), 0.1)
	_age += dt
	if _pixel != null:
		_pixel.modulate.a = 0.35 + 0.65 * absf(sin(_age * 2.4))
	if _boss_value != null:
		_boss_value.modulate.a = 0.65 + 0.35 * absf(sin(_age * 3.2))
	if _revealed and not _closing and _age >= MIN_OPEN_TIME:
		_prompt.modulate.a = 0.5 + 0.5 * absf(sin(_age * 2.8))
	if not _typing:
		return
	_type_timer -= dt
	var guard := 0
	while _typing and _type_timer <= 0.0 and guard < 8:
		guard += 1
		_type_next()


func _type_next() -> void:
	var total := _text.get_total_character_count()
	var shown := _text.visible_characters + 1
	if shown >= total:
		_text.visible_characters = -1
		_typing = false
		_reveal_cards()
		return
	_text.visible_characters = shown
	var ch := _parsed.substr(shown - 1, 1) if shown - 1 < _parsed.length() else ""
	var delay := CHAR_DELAY
	match ch:
		".", "!", "?":
			delay = 0.24
		",", ";", ":":
			delay = 0.1
		"\n":
			delay = 0.16
	_type_timer += delay


func _reveal_cards() -> void:
	if _revealed:
		return
	var tween := _tween()
	tween.set_parallel(true)
	for i in range(_cards.size()):
		tween.tween_property(_cards[i], "modulate:a", 1.0, 0.3).set_delay(0.12 * float(i))
	tween.chain().tween_callback(func() -> void: _revealed = true)


func _complete_all() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = null
	_typing = false
	_root.modulate.a = 1.0
	_top_bar.offset_bottom = BAR_HEIGHT
	_bottom_bar.offset_top = -BAR_HEIGHT
	_location.modulate.a = 1.0
	_title.modulate.a = 1.0
	_rule.custom_minimum_size.x = RULE_WIDTH
	_text.visible_characters = -1
	for c in _cards:
		c.modulate.a = 1.0
	_revealed = true


func _input(event: InputEvent) -> void:
	if _closing:
		return
	get_viewport().set_input_as_handled()
	if StoryScreen.is_press(event):
		if _age < 0.3:
			return
		if not _revealed:
			_complete_all()
			return
		if _age >= MIN_OPEN_TIME:
			_armed = true
	elif _armed and StoryScreen.is_release(event):
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	_typing = false
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = null
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	closed.emit()
	var tween := _tween()
	tween.set_parallel(true)
	tween.tween_property(_root, "modulate:a", 0.0, 0.45)
	tween.tween_property(_top_bar, "offset_bottom", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_bottom_bar, "offset_top", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
