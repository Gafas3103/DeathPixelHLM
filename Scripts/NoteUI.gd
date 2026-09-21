extends CanvasLayer

## Pantalla de lectura de la nota: papel con el texto encima, pausa el juego, cualquier tecla la cierra.
## La crea NoteItem.gd.

const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const PAPER_PATH := "res://Assest/UI/nota_papel.png"
const INK := Color("#3A2410")            # tinta marrón oscuro
const STAMP := Color("#B3202B")          # sello rojo

var title_text: String = "NOTA"
var body_text: String = ""
var signature_text: String = ""

var _age: float = 0.0
var _closing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	_build()


func _process(delta: float) -> void:
	_age += delta


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.07, 0.8)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	# papel
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

	# texto dentro de los márgenes
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

	var title := UIStyle.label(title_text, 30, INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	text_box.add_child(signature)

	# sello rojo torcido
	var stamp := UIStyle.label("CONFIDENCIAL", 26, Color(STAMP, 0.62), true)
	stamp.rotation = deg_to_rad(-14.0)
	stamp.position = Vector2(84, 470)
	paper.add_child(stamp)

	# pista para cerrar
	var hint := UIStyle.label("PRESIONA CUALQUIER TECLA PARA CERRAR", 16, UIStyle.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	# entrada: el papel cae con un pequeño giro
	paper.scale = Vector2(0.85, 0.85)
	paper.rotation = deg_to_rad(-3.0)
	paper.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(paper, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(paper, "rotation", deg_to_rad(-0.8), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(paper, "modulate:a", 1.0, 0.2)


func _input(event: InputEvent) -> void:
	if _closing or _age < 0.25:
		return
	var pressed := false
	var key_event := event as InputEventKey
	var mouse_event := event as InputEventMouseButton
	if key_event != null:
		pressed = key_event.pressed and not key_event.echo
	elif mouse_event != null:
		pressed = mouse_event.pressed
	if not pressed:
		return

	_closing = true
	get_viewport().set_input_as_handled()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	queue_free()
