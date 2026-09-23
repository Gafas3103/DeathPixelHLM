extends Area2D

## Nota de historia (nivel 1). La suelta el último enemigo con la llave; con E se lee (NoteUI) y el juego se pausa.
## El texto se cambia en el Inspector (note_title, note_text, note_signature).

const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const NoteUIScene := preload("res://Scenes/NoteUI.tscn")
const ICON_PATH := "res://Assest/UI/nota_icono.png"

@export var note_title: String = "ORDEN CONFIDENCIAL"
@export_multiline var note_text: String = "La familia del objetivo ya fue eliminada.\n\nEl siguiente en la lista es él: el agente que sigue nuestro rastro. Encuéntrenlo y acaben con él antes de que llegue a la sede.\n\nNo dejen testigos ni pruebas. Los demás equipos ya están en posición."
@export var note_signature: String = "— El Contratista"

var can_pickup: bool = false
var _time: float = 0.0
var _icon: Sprite2D = null

@onready var prompt: Label = $PromptLabel


func _ready() -> void:
	add_to_group("notes")
	light_mask = 0
	collision_layer = 0
	collision_mask = 2

	var old_rect := get_node_or_null("ColorRect")
	if old_rect != null:
		old_rect.queue_free()

	if ResourceLoader.exists(ICON_PATH):
		_icon = Sprite2D.new()
		_icon.texture = load(ICON_PATH)
		_icon.scale = Vector2(0.3, 0.3)
		_icon.light_mask = 0
		add_child(_icon)

	prompt.light_mask = 0
	prompt.text = "[E] LEER NOTA"
	prompt.add_theme_font_size_override("font_size", 8)
	prompt.add_theme_color_override("font_color", UIStyle.OBJECTIVE)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-60, -30)
	prompt.size = Vector2(120, 12)
	prompt.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var final_scale := scale
	scale = Vector2(0.1, 0.1)
	create_tween().tween_property(self, "scale", final_scale, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_pickup = true
		prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_pickup = false
		prompt.visible = false


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _icon != null:
		_icon.position.y = sin(_time * 2.5) * 1.5
	if can_pickup and Input.is_action_just_pressed("action") and not Global.cutscene_active:
		read_note()


func _draw() -> void:
	# halo para que se vea de lejos
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	draw_circle(Vector2.ZERO, 14.0 + pulse * 3.0, Color(UIStyle.OBJECTIVE, 0.12 + pulse * 0.08))
	if _icon == null:
		# sin imagen importada, papel dibujado por código
		draw_rect(Rect2(-7, -9, 14, 18), Color("#F5E49F"))
		draw_rect(Rect2(-7, -9, 14, 18), Color("#7A5A20"), false, 1.5)


func read_note() -> void:
	var ui := NoteUIScene.instantiate()
	ui.set("title_text", note_title)
	ui.set("body_text", note_text)
	ui.set("signature_text", note_signature)
	get_tree().current_scene.add_child(ui)
	get_tree().paused = true
