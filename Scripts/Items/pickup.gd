extends Area2D

## Objeto que suelta un enemigo al morir (munición, botiquín o corazón). Salta al aparecer y vuela hacia el jugador si se acerca.

const UIStyle := preload("res://Scripts/UI/ui_style.gd")

enum Kind { AMMO, HEALTH, HEART, SHELLS }

@export var kind: Kind = Kind.AMMO
## balas (AMMO) o vida (HEALTH); HEART siempre da un corazón
@export var amount: int = 12
## distancia a la que el jugador lo atrae (px)
@export var magnet_range: float = 70.0

var _time: float = 0.0
var _taken: bool = false
var _age: float = 0.0


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 0
	collision_mask = 2

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)

	# aparece con un saltito
	var target_scale := scale
	scale = Vector2(0.1, 0.1)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", target_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var hop := position + Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0))
	tween.tween_property(self, "position", hop, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	_age += delta
	queue_redraw()

	# imán
	if _age > 0.4 and not _taken:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and Global.health > 0.0:
			var dist := global_position.distance_to(player.global_position)
			if dist < magnet_range and _needed():
				var pull := lerpf(90.0, 260.0, 1.0 - dist / magnet_range)
				global_position = global_position.move_toward(player.global_position, pull * delta)


## ¿le sirve al jugador ahora?
func _needed() -> bool:
	match kind:
		Kind.AMMO:
			return Global.reserve_ammo < Global.max_reserve
		Kind.HEALTH:
			return Global.health < Global.max_health or Global.lives < Global.MAX_LIVES
		Kind.HEART:
			return Global.lives < Global.MAX_LIVES
		Kind.SHELLS:
			return not Global.reserve_full(Global.Weapons.SHOTGUN)
	return true


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return

	match kind:
		Kind.AMMO:
			if not Global.add_reserve_ammo(amount):
				Global.show_message("MUNICIÓN LLENA")
				return
			Global.show_message("+%d BALAS" % amount)
		Kind.HEALTH:
			if Global.health < Global.max_health:
				if body.has_method("heal"):
					body.heal(float(amount))
				else:
					Global.heal(float(amount))
				Global.show_message("+%d SALUD" % amount)
			elif Global.add_life():
				# con vida llena el botiquín da un corazón
				Global.show_message("+1 CORAZÓN")
			else:
				return
		Kind.HEART:
			if not Global.add_life():
				return
			Global.show_message("+1 CORAZÓN")
		Kind.SHELLS:
			if not Global.add_reserve_ammo(amount, Global.Weapons.SHOTGUN):
				Global.show_message("CARTUCHOS LLENOS")
				return
			Global.show_message("+%d CARTUCHOS" % amount)

	_taken = true
	queue_free()


func _draw() -> void:
	var bob := sin(_time * 3.0 + position.x) * 1.2
	var base := Vector2(0, bob)
	match kind:
		Kind.AMMO:
			var c := UIStyle.AMMO
			draw_circle(base, 10.0, Color(c, 0.14))
			draw_rect(Rect2(base + Vector2(-6, -4), Vector2(12, 9)), UIStyle.PANEL)
			draw_rect(Rect2(base + Vector2(-6, -4), Vector2(12, 9)), c, false, 1.5)
			for i in range(3):
				draw_rect(Rect2(base + Vector2(-4 + i * 3.4, -2), Vector2(1.8, 5)), c)
		Kind.HEALTH:
			var c := UIStyle.LIFE
			draw_circle(base, 10.0, Color(c, 0.14))
			draw_rect(Rect2(base + Vector2(-6, -6), Vector2(12, 12)), UIStyle.TEXT)
			draw_rect(Rect2(base + Vector2(-2, -5), Vector2(4, 10)), c)
			draw_rect(Rect2(base + Vector2(-5, -2), Vector2(10, 4)), c)
		Kind.SHELLS:
			var c := UIStyle.OBJECTIVE
			draw_circle(base, 10.0, Color(c, 0.14))
			for i in range(2):
				var ox := -6.0 + float(i) * 7.0
				draw_rect(Rect2(base + Vector2(ox, -6), Vector2(5, 8)), UIStyle.LIFE)
				draw_rect(Rect2(base + Vector2(ox, 2), Vector2(5, 4)), c)
		Kind.HEART:
			var c := UIStyle.LIFE
			var pulse := 1.0 + 0.12 * sin(_time * 6.0)
			draw_circle(base, 11.0 * pulse, Color(c, 0.2))
			var shape := [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
			for y in range(shape.size()):
				for x in range(shape[y].length()):
					if shape[y][x] == "X":
						draw_rect(Rect2(base + Vector2((x - 3.5) * 2.0 * pulse, (y - 3.0) * 2.0 * pulse), Vector2(2.0, 2.0) * pulse), c)
