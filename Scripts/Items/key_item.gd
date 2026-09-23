extends Area2D

## Llave del nivel, abre las puertas cerradas. Se dibuja por código.

const UIStyle := preload("res://Scripts/UI/ui_style.gd")

var _time: float = 0.0
var _taken: bool = false


func _ready() -> void:
	add_to_group("key_items")
	light_mask = 0
	collision_layer = 0
	collision_mask = 2

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)

	# cae con rebote
	var target_scale := scale
	scale = Vector2(0.1, 0.1)
	create_tween().tween_property(self, "scale", target_scale, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	Global.collect_key()
	Global.show_message("LLAVE OBTENIDA")
	queue_free()


func _draw() -> void:
	var bob := sin(_time * 3.0) * 1.5
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)

	# halo que late
	draw_circle(Vector2(0, bob), 9.0 + pulse * 3.0, Color(UIStyle.OBJECTIVE, 0.16 + pulse * 0.12))

	var c := UIStyle.OBJECTIVE
	var dark := Color(0.35, 0.22, 0.0)
	draw_circle(Vector2(-4, bob), 4.5, dark)
	draw_circle(Vector2(-4, bob), 3.4, c)
	draw_circle(Vector2(-4, bob), 1.4, dark)
	draw_rect(Rect2(-0.5, bob - 1.0, 9.0, 2.0), c)
	draw_rect(Rect2(5.0, bob + 1.0, 1.6, 3.0), c)
	draw_rect(Rect2(7.6, bob + 1.0, 1.6, 2.2), c)
