extends CanvasLayer

signal finished

const UIStyle := preload("res://Scripts/UI/ui_style.gd")

const SCREEN_BG := Color("#0A0C11")
const BAR_HEIGHT := 72.0
const CHAR_DELAY := 0.03
const TEXT_WIDTH := 920.0
const HIGHLIGHTS := {
	"Contratista": "#EF3E4A",
	"píxel rojo": "#EF3E4A",
	"puntos rojos": "#EF3E4A",
}

var pages: Array[String] = []
var heading: String = ""
var end_title: String = ""
var end_subtitle: String = ""

var _root: Control
var _content: Control
var _heading_row: Control
var _pixel: ColorRect
var _text: RichTextLabel
var _dots: HBoxContainer
var _hint: Label
var _end_box: VBoxContainer
var _end_title_label: Label
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _page: int = -1
var _parsed: String = ""
var _typing: bool = false
var _type_timer: float = 0.0
var _age: float = 0.0
var _busy: bool = true
var _done: bool = false
var _on_end_card: bool = false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _prev_focus: Control = null
var _page_tween: Tween = null


static func spaced_font(spacing: int, bold: bool = false) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.spacing_glyph = spacing
	if bold:
		f.variation_embolden = 0.9
	return f


static func spaced_label(text: String, size: int, color: Color, spacing: int = 4, bold: bool = false) -> Label:
	var l := UIStyle.label(text, size, color)
	l.add_theme_font_override("font", spaced_font(spacing, bold))
	return l


static func vignette(strength: float = 0.8) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, strength))
	g.add_point(0.5, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.15, 0.5)
	tex.width = 256
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func scanlines(alpha: float = 0.14) -> TextureRect:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(4):
		img.set_pixel(x, 3, Color(0, 0, 0, alpha))
	var r := TextureRect.new()
	r.texture = ImageTexture.create_from_image(img)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func pixel_dust(amount: int = 22, color: Color = UIStyle.LIFE) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2(640, 760)
	p.amount = amount
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(700, 10)
	p.direction = Vector2(0, -1)
	p.spread = 16.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 24.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 0.0))
	gradient.set_color(1, Color(color, 0.0))
	gradient.add_point(0.2, Color(color, 0.5))
	gradient.add_point(0.75, Color(color, 0.25))
	p.color_ramp = gradient
	return p


static func letterbox(parent: Control, height: float) -> Array[ColorRect]:
	var top := ColorRect.new()
	top.color = Color.BLACK
	top.anchor_right = 1.0
	top.offset_bottom = height
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top)
	var top_line := ColorRect.new()
	top_line.color = Color(UIStyle.OBJECTIVE, 0.28)
	top_line.anchor_top = 1.0
	top_line.anchor_bottom = 1.0
	top_line.anchor_right = 1.0
	top_line.offset_top = -1.0
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_line)

	var bottom := ColorRect.new()
	bottom.color = Color.BLACK
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.anchor_right = 1.0
	bottom.offset_top = -height
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bottom)
	var bottom_line := ColorRect.new()
	bottom_line.color = Color(UIStyle.OBJECTIVE, 0.28)
	bottom_line.anchor_right = 1.0
	bottom_line.offset_bottom = 1.0
	bottom_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bottom_line)
	var out: Array[ColorRect] = [top, bottom]
	return out


static func is_press(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		return key.pressed and not key.echo
	var mb := event as InputEventMouseButton
	if mb != null:
		return mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	var joy := event as InputEventJoypadButton
	if joy != null:
		return joy.pressed
	return false


static func is_release(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		return not key.pressed
	var mb := event as InputEventMouseButton
	if mb != null:
		return not mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	var joy := event as InputEventJoypadButton
	if joy != null:
		return not joy.pressed
	return false


static func is_cancel(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null and key.pressed and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE):
		return true
	return event.is_action_pressed("ui_cancel")


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prev_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_prev_focus = get_viewport().gui_get_focus_owner()
	if _prev_focus != null:
		_prev_focus.release_focus()
	_build()
	_intro()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = SCREEN_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	_root.add_child(pixel_dust())
	_root.add_child(vignette())
	_root.add_child(scanlines())

	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)

	var heading_center := CenterContainer.new()
	heading_center.anchor_right = 1.0
	heading_center.offset_top = BAR_HEIGHT + 34.0
	heading_center.offset_bottom = BAR_HEIGHT + 70.0
	heading_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(heading_center)
	_heading_row = heading_center

	var heading_box := HBoxContainer.new()
	heading_box.add_theme_constant_override("separation", 14)
	heading_box.alignment = BoxContainer.ALIGNMENT_CENTER
	heading_center.add_child(heading_box)

	_pixel = ColorRect.new()
	_pixel.color = UIStyle.LIFE
	_pixel.custom_minimum_size = Vector2(10, 10)
	_pixel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading_box.add_child(_pixel)

	var heading_label := spaced_label(heading, 20, UIStyle.OBJECTIVE, 8, true)
	heading_box.add_child(heading_label)
	heading_center.visible = heading != ""

	var text_center := CenterContainer.new()
	text_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_center.offset_top = BAR_HEIGHT + 60.0
	text_center.offset_bottom = -BAR_HEIGHT - 60.0
	text_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(text_center)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 30)
	_text.add_theme_font_size_override("bold_font_size", 30)
	_text.add_theme_font_override("bold_font", UIStyle.bold_font())
	_text.add_theme_color_override("default_color", UIStyle.TEXT)
	_text.add_theme_constant_override("line_separation", 10)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_text.add_theme_constant_override("shadow_offset_x", 2)
	_text.add_theme_constant_override("shadow_offset_y", 2)
	text_center.add_child(_text)

	var dots_center := CenterContainer.new()
	dots_center.anchor_top = 1.0
	dots_center.anchor_bottom = 1.0
	dots_center.anchor_right = 1.0
	dots_center.offset_top = -BAR_HEIGHT - 52.0
	dots_center.offset_bottom = -BAR_HEIGHT - 30.0
	dots_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(dots_center)

	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 10)
	dots_center.add_child(_dots)
	for i in range(pages.size()):
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(8, 8)
		d.color = UIStyle.BAR_EMPTY
		_dots.add_child(d)
	dots_center.visible = pages.size() > 1

	_end_box = VBoxContainer.new()
	_end_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_box.add_theme_constant_override("separation", 10)
	_end_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_box.visible = false
	_root.add_child(_end_box)

	_end_title_label = UIStyle.label(end_title, 132, UIStyle.OBJECTIVE, true)
	_end_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title_label.add_theme_color_override("font_outline_color", UIStyle.LIFE.darkened(0.55))
	_end_title_label.add_theme_constant_override("outline_size", 12)
	_end_box.add_child(_end_title_label)

	var end_sub := spaced_label(end_subtitle, 26, UIStyle.TEXT, 10, true)
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_box.add_child(end_sub)

	var bars := letterbox(_root, BAR_HEIGHT)
	_top_bar = bars[0]
	_bottom_bar = bars[1]

	_hint = spaced_label("CLIC O CUALQUIER TECLA: CONTINUAR   ·   ESC: SALTAR", 14, UIStyle.TEXT_DIM, 2)
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 0.5
	_hint.anchor_bottom = 0.5
	_hint.offset_left = -760.0
	_hint.offset_right = -40.0
	_hint.offset_top = -12.0
	_hint.offset_bottom = 12.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.0
	_bottom_bar.add_child(_hint)

	var brand := spaced_label("DEATH PIXEL", 14, Color(UIStyle.TEXT_DIM, 0.6), 6, true)
	brand.anchor_top = 0.5
	brand.anchor_bottom = 0.5
	brand.offset_left = 40.0
	brand.offset_right = 400.0
	brand.offset_top = -12.0
	brand.offset_bottom = 12.0
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bottom_bar.add_child(brand)


func _intro() -> void:
	_root.modulate.a = 0.0
	_top_bar.offset_bottom = 0.0
	_bottom_bar.offset_top = 0.0
	var tween := _tween()
	tween.set_parallel(true)
	tween.tween_property(_root, "modulate:a", 1.0, 0.4)
	tween.tween_property(_top_bar, "offset_bottom", BAR_HEIGHT, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bottom_bar, "offset_top", -BAR_HEIGHT, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_start)


func _start() -> void:
	if _done:
		return
	if pages.is_empty():
		if end_title != "":
			_show_end_card()
		else:
			_finish()
		return
	_show_page(0)


func _tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


func _process(delta: float) -> void:
	var dt := minf(delta / maxf(Engine.time_scale, 0.05), 0.1)
	_age += dt
	if _pixel != null:
		_pixel.modulate.a = 0.35 + 0.65 * absf(sin(_age * 2.2))
	if _hint != null and not _busy and not _typing and not _done:
		_hint.modulate.a = 0.55 + 0.45 * absf(sin(_age * 2.6))
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
		_complete_page()
		return
	_text.visible_characters = shown
	var ch := _parsed.substr(shown - 1, 1) if shown - 1 < _parsed.length() else ""
	var delay := CHAR_DELAY
	match ch:
		".", "!", "?":
			delay = 0.32
		",", ";", ":":
			delay = 0.14
		"\n":
			delay = 0.22
		" ":
			delay = CHAR_DELAY * 0.5
	_type_timer += delay


func _show_page(index: int) -> void:
	_busy = true
	_typing = false
	_page = index
	_hint.modulate.a = 0.0
	if index == 0:
		_set_page_text(index)
		_text.modulate.a = 1.0
		_busy = false
		_begin_typing()
		return
	_kill_page_tween()
	_page_tween = _tween()
	_page_tween.tween_property(_text, "modulate:a", 0.0, 0.2)
	_page_tween.tween_callback(_set_page_text.bind(index))
	_page_tween.tween_property(_text, "modulate:a", 1.0, 0.12)
	_page_tween.tween_callback(func() -> void:
		_busy = false
		_begin_typing())


func _kill_page_tween() -> void:
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	_page_tween = null


func _set_page_text(index: int) -> void:
	_text.text = "[center]" + _decorate(pages[index]) + "[/center]"
	_parsed = _text.get_parsed_text()
	_text.visible_characters = 0
	for i in range(_dots.get_child_count()):
		var d := _dots.get_child(i) as ColorRect
		if i == index:
			d.color = UIStyle.OBJECTIVE
		elif i < index:
			d.color = UIStyle.TEXT_DIM
		else:
			d.color = UIStyle.BAR_EMPTY


func _decorate(raw: String) -> String:
	var out := raw.replace("[", "(").replace("]", ")")
	for word in HIGHLIGHTS.keys():
		out = out.replace(word, "[color=%s]%s[/color]" % [HIGHLIGHTS[word], word])
	return out


func _begin_typing() -> void:
	if _done or _on_end_card:
		return
	_typing = true
	_type_timer = 0.15


func _complete_page() -> void:
	_typing = false
	_text.visible_characters = -1


func _input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if _done or not is_press(event):
		return
	if _age < 0.25:
		return
	if is_cancel(event):
		_skip()
		return
	if _busy:
		return
	_advance()


func _advance() -> void:
	if _typing:
		_complete_page()
		return
	if _on_end_card:
		_finish()
		return
	if _page < pages.size() - 1:
		_show_page(_page + 1)
	elif end_title != "":
		_show_end_card()
	else:
		_finish()


func _skip() -> void:
	if end_title != "" and not _on_end_card:
		_show_end_card()
	else:
		_finish()


func _show_end_card() -> void:
	_kill_page_tween()
	_on_end_card = true
	_busy = true
	_typing = false
	_hint.text = "CLIC O CUALQUIER TECLA PARA TERMINAR"
	_hint.modulate.a = 0.0
	_end_box.visible = true
	_end_box.modulate.a = 0.0
	var tween := _tween()
	tween.tween_property(_content, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func() -> void:
		_end_title_label.pivot_offset = _end_title_label.size * 0.5
		_end_title_label.scale = Vector2(1.25, 1.25))
	tween.tween_interval(0.2)
	tween.tween_property(_end_box, "modulate:a", 1.0, 0.8)
	tween.parallel().tween_property(_end_title_label, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.4)
	tween.tween_callback(func() -> void: _busy = false)


func _finish() -> void:
	if _done:
		return
	_kill_page_tween()
	_done = true
	_typing = false
	_busy = true
	var tween := _tween()
	tween.tween_property(_content, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(_end_box, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_emit_finished)
	tween.tween_property(_root, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _emit_finished() -> void:
	Input.set_mouse_mode(_prev_mouse_mode)
	if _prev_focus != null and is_instance_valid(_prev_focus) and _prev_focus.is_inside_tree() and _prev_focus.is_visible_in_tree():
		_prev_focus.grab_focus()
	finished.emit()
