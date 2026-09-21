extends Area2D

## Zona marcada del tutorial: emite reached cuando el jugador entra.

const UIStyle := preload("res://Scripts/UI/ui_style.gd")

signal reached

@export var size: Vector2 = Vector2(32, 64)
@export var caption: String = "AQUÍ"

var _time: float = 0.0
var _fired: bool = false
var _retry: float = -1.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	add_to_group("tutorial_target")
	set_meta("caption", caption)


## permite que se dispare de nuevo; si el jugador sigue dentro avisa tras una pausa (evita un bucle)
func rearm(delay: float = 0.8) -> void:
	_fired = false
	_retry = delay


func _on_body_entered(body: Node2D) -> void:
	if _fired or not body.is_in_group("player"):
		return
	_fired = true
	reached.emit()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _retry >= 0.0:
		_retry -= delta
		if _retry < 0.0:
			for body in get_overlapping_bodies():
				_on_body_entered(body)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 3.5)
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, Color(UIStyle.BAR_FILL, 0.10 + pulse * 0.12))
	draw_rect(rect, Color(UIStyle.BAR_FILL, 0.9), false, 2.0)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var p: Vector2 = dir * (minf(size.x, size.y) * 0.3)
		draw_line(p, p - dir * 5.0, Color(UIStyle.BAR_FILL, 0.9), 1.5)
	draw_circle(Vector2.ZERO, 2.5, UIStyle.BAR_FILL)
