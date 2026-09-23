extends CanvasLayer

const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const PAPER_PATH := "res://Assest/UI/nota_papel.png"
const INK := Color("#3A2410")
const STAMP := Color("#B3202B")
const MIN_OPEN_TIME := 0.3

var title_text: String = "NOTA"
var body_text: String = ""
var signature_text: String = ""

var _age: float = 0.0
var _armed: bool = false
var _closing: bool = false
var _root: Control
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	_build()


func _process(delta: float) -> void:
	_age += minf(delta / maxf(Engine.time_scale, 0.05), 0.1)
	if _hint != null and not _closing and _age >= MIN_OPEN_TIME:
		_hint.modulate.a = 0.55 + 0.45 * absf(sin(_age * 2.6))


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.07, 0.8)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var paper := Control.new()
	paper.custom_minimum_size = Vector2(560, 576)
	paper.pivot_offset = paper.custom_minimum_size * 0.5
	column.add_child(paper)

	if ResourceLoader.exists(PAPER_PATH):
		var tex := TextureRect.new()
		tex.texture = load(PAPER_PATH)
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		paper.add_child(tex)
	else:
		var flat := ColorRect.new()
		flat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flat.color = Color("#F5E49F")
		paper.add_child(flat)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 78)
	margin.add_theme_constant_override("margin_right", 78)
	margin.add_theme_constant_override("margin_top", 78)
	margin.add_theme_constant_override("margin_bottom", 70)
	paper.add_child(margin)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 10)
	margin.add_child(text_box)

	var title := UIStyle.label(title_text if title_text != "" else "NOTA", 30, INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 3)
	rule.color = Color(INK, 0.7)
	text_box.add_child(rule)

	var body := UIStyle.label(body_text, 20, INK, false)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("line_spacing", 4)
	text_box.add_child(body)

	var signature := UIStyle.label(signature_text, 22, INK, true)
	signature.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	signature.visible = signature_text != ""
	text_box.add_child(signature)

	var stamp := UIStyle.label("CONFIDENCIAL", 26, Color(STAMP, 0.62), true)
	stamp.rotation = deg_to_rad(-14.0)
	stamp.position = Vector2(84, 470)
	paper.add_child(stamp)

	_hint = UIStyle.label("PRESIONA CUALQUIER TECLA PARA CERRAR", 16, UIStyle.TEXT_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.0
	column.add_child(_hint)

	paper.scale = Vector2(0.85, 0.85)
	paper.rotation = deg_to_rad(-3.0)
	paper.modulate.a = 0.0
	var tween := create_tween().set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(paper, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(paper, "rotation", deg_to_rad(-0.8), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(paper, "modulate:a", 1.0, 0.2)


func _input(event: InputEvent) -> void:
	if _closing:
		return
	var key_event := event as InputEventKey
	var mouse_event := event as InputEventMouseButton
	var joy_event := event as InputEventJoypadButton
	var pressed := false
	var released := false
	if key_event != null:
		pressed = key_event.pressed and not key_event.echo
		released = not key_event.pressed
	elif mouse_event != null:
		if mouse_event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			return
		pressed = mouse_event.pressed
		released = not mouse_event.pressed
	elif joy_event != null:
		pressed = joy_event.pressed
		released = not joy_event.pressed
	else:
		return
	get_viewport().set_input_as_handled()
	if pressed and _age >= MIN_OPEN_TIME:
		_armed = true
	elif released and _armed:
		_close()


func _close() -> void:
	_closing = true
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(_root, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)
