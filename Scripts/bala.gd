extends Area2D

@export var speed: float = 900.0
@export var damage: float = 25.0
@export var lifetime: float = 2.0

const TRAIL_POINTS := 11
const TIER_GLOWS: Array[Color] = [Color(1.0, 0.78, 0.22), Color(0.45, 0.9, 1.0), Color(1.0, 0.55, 0.15), Color(1.0, 0.15, 0.2)]

var shooter: Node = null
var tier: int = 0
var pellet: bool = false
var glow_color: Color = Color(0.0, 0.0, 0.0, 0.0)
var size_mult: float = 1.0

var _spent: bool = false
var _age: float = 0.0
var _trail: Line2D = null
var _glow_color: Color = Color(1.0, 0.75, 0.2)
var _is_enemy_bullet: bool = false
var _dir: Vector2 = Vector2.RIGHT


class ImpactRing extends Node2D:
	var radius: float = 2.0
	var alpha: float = 1.0
	var color: Color = Color.WHITE

	func _init() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		z_index = 50
		light_mask = 0

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
		draw_circle(Vector2.ZERO, 7.0 * alpha, Color(1.0, 1.0, 0.9, alpha * alpha))


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	light_mask = 0
	_is_enemy_bullet = (collision_layer & 16) != 0
	_glow_color = Color(1.0, 0.32, 0.22) if _is_enemy_bullet else TIER_GLOWS[clampi(tier, 0, 3)]
	if glow_color.a > 0.0:
		_glow_color = Color(glow_color, 1.0)

	var sprite := get_node_or_null("Sprite2D") as CanvasItem
	if sprite != null:
		sprite.light_mask = 0
		if glow_color.a > 0.0:
			sprite.modulate = _glow_color.lerp(Color.WHITE, 0.35)

	if size_mult != 1.0:
		scale = Vector2.ONE * size_mult

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

	_dir = Vector2.RIGHT.rotated(global_rotation)
	global_position += _dir * speed * delta

	if _trail != null:
		_trail.add_point(global_position)
		while _trail.get_point_count() > (6 if pellet else TRAIL_POINTS):
			_trail.remove_point(0)
	queue_redraw()


func _build_trail() -> void:
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.light_mask = 0
	_trail.width = (4.5 if pellet else 8.0) * (1.0 + 0.2 * float(tier)) * size_mult
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.z_index = -1

	var thickness := Curve.new()
	thickness.add_point(Vector2(0.0, 0.0))
	thickness.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = thickness

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


func _on_body_entered(body: Node2D) -> void:
	_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_hit(area)


func _hit(target: Node) -> void:
	if _spent or target == null:
		return
	if shooter != null and is_instance_valid(shooter):
		if target == shooter or target == shooter.get_parent():
			return

	_spent = true
	set_deferred("monitoring", false)
	_dir = Vector2.RIGHT.rotated(global_rotation)

	var hit_creature := target.has_method("apply_bullet_hit") or target.has_method("take_damage")

	if target.has_method("apply_bullet_hit"):
		target.apply_bullet_hit(damage, _dir)
	elif target.has_method("take_damage"):
		target.take_damage(damage)

	_spawn_impact(hit_creature)
	_detach_trail()
	queue_free()


func _spawn_impact(hit_creature: bool) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	var ring := ImpactRing.new()
	ring.color = Color(1.0, 0.35, 0.3) if hit_creature else _glow_color
	scene_root.add_child(ring)
	ring.global_position = global_position
	ring.start()

	var spark_color := Color(1.0, 0.25, 0.2, 1.0) if hit_creature else Color(1.0, 0.86, 0.45, 1.0)
	var sparks := _make_burst(scene_root, 22 if hit_creature else 14, 0.36, 150.0, 380.0, 2.4, 4.6, spark_color)
	sparks.direction = -_dir
	sparks.spread = 60.0 if not hit_creature else 75.0

	if not hit_creature:
		var smoke := _make_burst(scene_root, 5, 0.45, 15.0, 55.0, 3.0, 6.0, Color(0.75, 0.75, 0.78, 0.45))
		smoke.direction = -_dir
		smoke.spread = 100.0
		smoke.damping_min = 40.0
		smoke.damping_max = 90.0


func _make_burst(scene_root: Node, count: int, life: float, vmin: float, vmax: float, smin: float, smax: float, color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.light_mask = 0
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
