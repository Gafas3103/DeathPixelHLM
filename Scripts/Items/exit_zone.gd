extends Area2D

## Zona de salida: al entrar con la llave se completa el nivel.

const UIStyle := preload("res://Scripts/UI/ui_style.gd")

@export var size: Vector2 = Vector2(36, 36)
@export var requires_key: bool = true

var _time: float = 0.0
var _done: bool = false
var _warn_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("exit_zone")
	collision_layer = 0
	collision_mask = 2

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_warn_cooldown = maxf(0.0, _warn_cooldown - delta)
	queue_redraw()
	# el jugador se queda en la zona y luego consigue la llave
	if not _done and (Global.has_key or not requires_key):
		for body in get_overlapping_bodies():
			if body.is_in_group("player") and Global.health > 0.0:
				_finish()
				return


func _on_body_entered(body: Node2D) -> void:
	if _done or not body.is_in_group("player"):
		return
	if requires_key and not Global.has_key:
		if _warn_cooldown <= 0.0:
			Global.show_message("NECESITAS LA LLAVE PARA SALIR")
			_warn_cooldown = 2.0
		return
	_finish()


func _finish() -> void:
	_done = true
	GameManager.complete_level()


func _draw() -> void:
	var active := Global.has_key or not requires_key
	var color := UIStyle.BAR_FILL if active else UIStyle.BAR_EMPTY
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, Color(color, 0.12 + pulse * 0.12 * (1.0 if active else 0.0)))
	draw_rect(rect, Color(color, 0.9), false, 1.5)
	var c := Vector2.ZERO
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var p: Vector2 = dir * (size.x * 0.32)
		draw_line(p, p + dir * -4.0, Color(color, 0.9), 1.5)
	draw_circle(c, 2.0, color)
