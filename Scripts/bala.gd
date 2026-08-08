extends Area2D

## BALA con colisión real.
##
## Capas de física usadas en el proyecto:
##   1 = Mundo / paredes (TileMap)
##   2 = Jugador
##   3 = Enemigo
##   4 = Bala
##
## La bala vive en la capa 4 y detecta las capas 1 y 3, así que atraviesa
## a los jugadores (no te matas a ti mismo ni a tu compañero) pero choca
## con paredes y enemigos.

@export var speed: float = 900.0
@export var damage: float = 25.0
@export var lifetime: float = 2.0

## Quien disparó la bala. Se ignora en las colisiones por seguridad.
var shooter: Node = null

var _spent: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()


func _physics_process(delta: float) -> void:
	if _spent:
		return
	# Avanza en línea recta hacia donde apunta (eje X local).
	position += transform.x * speed * delta


func _on_body_entered(body: Node2D) -> void:
	_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_hit(area)


func _hit(target: Node) -> void:
	if _spent or target == null:
		return
	if target == shooter or (shooter != null and target == shooter.get_parent()):
		return

	_spent = true
	set_deferred("monitoring", false)

	# apply_bullet_hit permite además empujar al enemigo en la dirección del tiro.
	if target.has_method("apply_bullet_hit"):
		target.apply_bullet_hit(damage, transform.x)
	elif target.has_method("take_damage"):
		target.take_damage(damage)

	_spawn_impact()
	queue_free()


func _spawn_impact() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	var sparks := CPUParticles2D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 10
	sparks.lifetime = 0.25
	sparks.local_coords = false
	sparks.direction = -transform.x
	sparks.spread = 60.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 130.0
	sparks.initial_velocity_max = 300.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	sparks.damping_min = 200.0
	sparks.damping_max = 400.0
	sparks.color = Color(1.0, 0.86, 0.45, 1.0)

	scene_root.add_child(sparks)
	sparks.global_position = global_position
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
