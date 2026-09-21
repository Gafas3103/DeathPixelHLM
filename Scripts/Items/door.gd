extends StaticBody2D

## Puerta con llave. Cerrada bloquea jugador, enemigos, balas y vista; con [E] se abre si tienes la llave.
## Se coloca en un hueco de pared y se ajusta con "size".

const UIStyle := preload("res://Scripts/UI/ui_style.gd")

signal opened

## tamaño del hueco en píxeles
@export var size: Vector2 = Vector2(32, 16)
@export var requires_key: bool = true

var is_open: bool = false

var _shape: CollisionShape2D
var _zone: Area2D
var _prompt: Label
var _player_near: bool = false
var _slide: float = 0.0  # 0 cerrada, 1 abierta
var _flash: float = 0.0


func _ready() -> void:
	add_to_group("doors")
	collision_layer = 1  # capa Mundo, como las paredes
	collision_mask = 0

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# la hoja entra 2 px en cada pared para que no quede rendija
	rect.size = size + (Vector2(4, 0) if size.x >= size.y else Vector2(0, 4))
	_shape.shape = rect
	add_child(_shape)

	# zona de interacción, un poco más grande
	_zone = Area2D.new()
	_zone.collision_layer = 0
	_zone.collision_mask = 2
	var zone_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(size.x, size.y) * 0.5 + 20.0
	zone_shape.shape = circle
	_zone.add_child(zone_shape)
	add_child(_zone)
	_zone.body_entered.connect(_on_zone_entered)
	_zone.body_exited.connect(_on_zone_exited)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", UIStyle.OBJECTIVE)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-60, -size.y * 0.5 - 22)
	_prompt.size = Vector2(120, 12)
	_prompt.visible = false
	add_child(_prompt)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	queue_redraw()

	if is_open or not _player_near:
		return
	# cada frame por si recoges la llave ya estando cerca
	_prompt.text = "[E] ABRIR" if (Global.has_key or not requires_key) else "REQUIERE LLAVE"
	if Input.is_action_just_pressed("action"):
		try_open()


func try_open() -> void:
	if is_open:
		return
	if requires_key and not Global.has_key:
		_flash = 0.5
		Global.show_message("NECESITAS LA LLAVE")
		return
	open()


func open() -> void:
	if is_open:
		return
	is_open = true
	_shape.set_deferred("disabled", true)
	_prompt.visible = false

	var level := get_tree().get_first_node_in_group("level")
	if level != null and level.has_method("set_solid_rect"):
		level.set_solid_rect(get_solid_rect(), false)

	var tween := create_tween()
	tween.tween_property(self, "_slide", 1.0, 0.35)
	Global.door_opened.emit()
	opened.emit()


## rectángulo de la puerta en el mundo (pathfinding)
func get_solid_rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)


func _on_zone_entered(body: Node2D) -> void:
	if is_open or not body.is_in_group("player"):
		return
	_player_near = true
	_prompt.text = "[E] ABRIR" if (Global.has_key or not requires_key) else "REQUIERE LLAVE"
	_prompt.visible = true


func _on_zone_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_near = false
	_prompt.visible = false


func _draw() -> void:
	var half := size * 0.5
	var horizontal := size.x >= size.y
	var color := UIStyle.BAR_FILL if is_open else UIStyle.LIFE
	if _flash > 0.0 and int(_flash * 20.0) % 2 == 0:
		color = UIStyle.TEXT

	# al abrirse la hoja se desliza y se encoge
	var length := (size.x if horizontal else size.y) * (1.0 - _slide * 0.85)
	var rect: Rect2
	if horizontal:
		rect = Rect2(-half.x, -half.y, length, size.y)
	else:
		rect = Rect2(-half.x, -half.y, size.x, length)

	draw_rect(rect, UIStyle.PANEL)
	draw_rect(rect, color, false, 2.0)
	# rayas de puerta blindada
	if not is_open:
		var step := 6.0
		if horizontal:
			var x := rect.position.x + step
			while x < rect.end.x:
				draw_line(Vector2(x, rect.position.y + 2), Vector2(x, rect.end.y - 2), Color(color, 0.5), 1.0)
				x += step
		else:
			var y := rect.position.y + step
			while y < rect.end.y:
				draw_line(Vector2(rect.position.x + 2, y), Vector2(rect.end.x - 2, y), Color(color, 0.5), 1.0)
				y += step
