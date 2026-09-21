extends Area2D

## Bala del jugador (Bala.tscn) y del enemigo (BalaEnemy.tscn), con colisión real y efectos.
## La del jugador vive en la capa 4 y detecta 1 y 3: atraviesa jugadores pero choca con paredes y enemigos.

@export var speed: float = 900.0
@export var damage: float = 25.0
@export var lifetime: float = 2.0

## puntos de la estela
const TRAIL_POINTS := 11
## color según el flow (0 normal, 3 berserk)
const TIER_GLOWS: Array[Color] = [Color(1.0, 0.78, 0.22), Color(0.45, 0.9, 1.0), Color(1.0, 0.55, 0.15), Color(1.0, 0.15, 0.2)]

## quién disparó, se ignora en las colisiones
var shooter: Node = null
## nivel de flow y si es perdigón; se asignan antes de añadirla a la escena
var tier: int = 0
var pellet: bool = false

var _spent: bool = false
var _age: float = 0.0
var _trail: Line2D = null
var _glow_color: Color = Color(1.0, 0.75, 0.2)
var _is_enemy_bullet: bool = false


## anillo de onda en el impacto
class ImpactRing extends Node2D:
	var radius: float = 2.0
	var alpha: float = 1.0
	var color: Color = Color.WHITE

	func _init() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		z_index = 50

	func start() -> void:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "radius", 26.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "alpha", 0.0, 0.26)
		tween.chain().tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(color, alpha), 3.0)
		draw_circle(Vector2.ZERO, radius * 0.6, Color(color, alpha * 0.4))
		# destello blanco al chocar
		draw_circle(Vector2.ZERO, 7.0 * alpha, Color(1.0, 1.0, 0.9, alpha * alpha))


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	_is_enemy_bullet = (collision_layer & 16) != 0
	_glow_color = Color(1.0, 0.32, 0.22) if _is_enemy_bullet else TIER_GLOWS[clampi(tier, 0, 3)]

	# el brillo usa mezcla aditiva solo en este nodo
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

	_build_trail()


func _physics_process(delta: float) -> void:
	if _spent:
		return

	_age += delta
	if _age >= lifetime:
		_spent = true
		_detach_trail()
		queue_free()
		return

	# recto hacia donde apunta
	position += transform.x * speed * delta

	if _trail != null:
		_trail.add_point(global_position)
		while _trail.get_point_count() > (6 if pellet else TRAIL_POINTS):
			_trail.remove_point(0)
	queue_redraw()


# efectos en vuelo

func _build_trail() -> void:
	_trail = Line2D.new()
	_trail.top_level = true  # sus puntos son globales
	_trail.width = (4.5 if pellet else 8.0) * (1.0 + 0.2 * float(tier))
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.z_index = -1

	# fina en la cola, gruesa en la cabeza
	var thickness := Curve.new()
	thickness.add_point(Vector2(0.0, 0.0))
	thickness.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = thickness

	# transparente en la cola
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 1.0])
	fade.colors = PackedColorArray([Color(_glow_color, 0.0), Color(_glow_color.lerp(Color.WHITE, 0.35), 0.85)])
	_trail.gradient = fade

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_trail.material = mat
	add_child(_trail)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_age * 40.0)
	var k := (0.55 if pellet else 1.0) * (1.0 + 0.12 * float(tier))
	draw_circle(Vector2.ZERO, (12.0 + pulse * 3.0) * k, Color(_glow_color, 0.16))
	draw_circle(Vector2.ZERO, (7.5 + pulse * 1.5) * k, Color(_glow_color, 0.34))
	draw_circle(Vector2.ZERO, 3.2 * k, Color(1.0, 0.97, 0.85, 0.98))


## deja la estela en el mundo para que se desvanezca
func _detach_trail() -> void:
	if _trail == null or not is_instance_valid(_trail):
		return
	var trail := _trail
	_trail = null
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	remove_child(trail)
	scene_root.add_child(trail)
	var tween := trail.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.2)
	tween.tween_callback(trail.queue_free)


# impacto

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

	# ¿enemigo/jugador o pared?
	var hit_creature := target.has_method("apply_bullet_hit") or target.has_method("take_damage")

	# apply_bullet_hit permite empujar al enemigo
	if target.has_method("apply_bullet_hit"):
		target.apply_bullet_hit(damage, transform.x)
	elif target.has_method("take_damage"):
		target.take_damage(damage)

	_spawn_impact(hit_creature)
	_detach_trail()
	queue_free()


func _spawn_impact(hit_creature: bool) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	# anillo
	var ring := ImpactRing.new()
	ring.color = Color(1.0, 0.35, 0.3) if hit_creature else _glow_color
	scene_root.add_child(ring)
	ring.global_position = global_position
	ring.start()

	# chispas
	var spark_color := Color(1.0, 0.25, 0.2, 1.0) if hit_creature else Color(1.0, 0.86, 0.45, 1.0)
	var sparks := _make_burst(scene_root, 22 if hit_creature else 14, 0.36, 150.0, 380.0, 2.4, 4.6, spark_color)
	sparks.direction = -transform.x
	sparks.spread = 60.0 if not hit_creature else 75.0

	# humo (solo paredes)
	if not hit_creature:
		var smoke := _make_burst(scene_root, 5, 0.45, 15.0, 55.0, 3.0, 6.0, Color(0.75, 0.75, 0.78, 0.45))
		smoke.direction = -transform.x
		smoke.spread = 100.0
		smoke.damping_min = 40.0
		smoke.damping_max = 90.0


func _make_burst(scene_root: Node, count: int, life: float, vmin: float, vmax: float, smin: float, smax: float, color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.local_coords = false
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.damping_min = 200.0
	p.damping_max = 400.0
	p.color = color
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp

	scene_root.add_child(p)
	p.global_position = global_position
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p
