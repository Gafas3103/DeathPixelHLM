extends CharacterBody2D

const FloatingText := preload("res://Scripts/floating_text.gd")
const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const BALA_ENEMY_PATH := "res://Scenes/BalaEnemy.tscn"
var _bala_enemy: PackedScene = null

enum Behavior { TORRETA, PATRULLA, PERSEGUIR, INERTE }
enum State { PATRULLA, ATACAR, VOLVER, MUERTO, INVESTIGAR, HUIR }
enum Variant { SOLDADO, PESADO, TIRADOR, RAPIDO }

const NO_POINT := Vector2(1.0e9, 1.0e9)
const VARIANT_KEYS: Array[String] = ["soldado", "pesado", "tirador", "rapido"]
const LASER_LEAD := 0.6
const LASER_LOCK := 0.18
const NO_GLOW := Color(0.0, 0.0, 0.0, 0.0)


class AwarenessIcon extends Node2D:
	var enemy: Node = null
	var _time: float = 0.0

	func _init() -> void:
		top_level = true
		z_index = 120
		light_mask = 0

	func _process(delta: float) -> void:
		if enemy == null or not is_instance_valid(enemy):
			queue_free()
			return
		_time += delta
		global_position = enemy.global_position + Vector2(0, -float(enemy.icon_offset))
		queue_redraw()

	func _draw() -> void:
		if enemy == null or not is_instance_valid(enemy):
			return
		var st: int = enemy.state
		var aw: float = enemy.awareness
		if st == 3:
			return
		var font := ThemeDB.fallback_font
		if st == 1 or st == 5:
			var bounce := absf(sin(_time * 10.0)) * 2.0
			draw_string_outline(font, Vector2(-5, 7 - bounce), "!", HORIZONTAL_ALIGNMENT_CENTER, 10, 20, 5, Color(0, 0, 0, 0.9))
			draw_string(font, Vector2(-5, 7 - bounce), "!", HORIZONTAL_ALIGNMENT_CENTER, 10, 20, Color("#EF3E4A"))
			return
		if st == 4:
			draw_string_outline(font, Vector2(-5, 7), "?", HORIZONTAL_ALIGNMENT_CENTER, 10, 18, 5, Color(0, 0, 0, 0.9))
			draw_string(font, Vector2(-5, 7), "?", HORIZONTAL_ALIGNMENT_CENTER, 10, 18, Color("#A5A3A0"))
			return
		if aw < 0.05:
			return
		var col := Color("#FFB000").lerp(Color("#EF3E4A"), aw)
		draw_arc(Vector2.ZERO, 7.0, -PI * 0.5, -PI * 0.5 + TAU * aw, 20, col, 3.0)
		if aw > 0.25:
			draw_string_outline(font, Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_CENTER, 8, 14, 4, Color(0, 0, 0, 0.9))
			draw_string(font, Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_CENTER, 8, 14, col)


@export_group("Comportamiento")
@export var behavior: Behavior = Behavior.PERSEGUIR
@export var variant: Variant = Variant.SOLDADO

@export_group("Patrulla")
@export var patrol_distance: float = 300.0
@export_range(-180.0, 180.0, 1.0) var patrol_angle_degrees: float = 0.0
@export var patrol_speed: float = 70.0
@export var patrol_wait: float = 0.7
@export var route: Array[Vector2] = []

@export_group("Torreta")
@export_range(0.0, 360.0, 1.0) var turret_sweep_degrees: float = 90.0
@export var turret_sweep_time: float = 4.0

@export_group("Movimiento")
@export var speed: float = 110.0
@export var acceleration: float = 900.0
@export var friction: float = 1100.0

@export_group("Vida")
@export var max_health: float = 60.0
@export var knockback: float = 90.0
@export var can_flee: bool = true
@export_range(0.0, 1.0, 0.05) var flee_health_ratio: float = 0.3

@export_group("Percepción")
@export var vision_range: float = 260.0
@export_range(10.0, 360.0, 1.0) var vision_angle: float = 140.0
@export var give_up_time: float = 3.0
@export var alert_radius: float = 260.0

@export_group("Combate")
@export var attack_range: float = 220.0
@export var fire_rate: float = 0.9
@export var reaction_time: float = 0.45
@export var muzzle_distance: float = 30.0
@export var spread_degrees: float = 6.0
@export var stop_to_shoot: bool = true

@export_group("Dificultad")
@export_enum("Siempre", "Normal y Difícil", "Solo Difícil") var appears_from: int = 0
@export var guards_exit: bool = false

var health: float = 0.0
var state: int = State.PATRULLA
var awareness: float = 0.0
var icon_offset: float = 26.0
var kill_points: int = 100
var pellets: int = 1
var fan_degrees: float = 0.0
var bullet_speed_mult: float = 1.0
var bullet_damage_mult: float = 1.0
var has_laser: bool = false

var _variant_applied: bool = false
var _seen_now: bool = false
var _peak_awareness: float = 0.0
var _stealth_kill: bool = false
var _killed_by_melee: bool = false

var _target: Node2D = null
var _last_known_position: Vector2 = Vector2.ZERO
var _investigate_pos: Vector2 = Vector2.ZERO
var _search_timer: float = 0.0
var _state_time: float = 0.0
var _shoot_timer: float = 0.0

var _home_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _patrol_dir: float = 1.0
var _route_index: int = 0
var _wait_timer: float = 0.0
var _stuck_timer: float = 0.0
var _sweep_time: float = 0.0
var _hit_tween: Tween = null
var _wander_target: Vector2 = NO_POINT

var _cornered: bool = false
var _flee_point: Vector2 = NO_POINT
var _flee_repick: float = 0.0
var _unseen_time: float = 0.0

var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _path_goal: Vector2 = NO_POINT
var _repath_timer: float = 0.0
var _level: Node = null

var _laser: Line2D = null
var _laser_glow: Line2D = null
var _laser_flash: float = 0.0
var _laser_time: float = 0.0

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var vision_area: Area2D = get_node_or_null("VisionArea")
@onready var hearing_area: Area2D = get_node_or_null("HearingArea")
@onready var vision_ray: RayCast2D = get_node_or_null("VisionRay")
@onready var visuals = get_node_or_null("Visuals")


func _ready() -> void:
	if Settings.difficulty < appears_from:
		remove_from_group("Enemies")
		process_mode = Node.PROCESS_MODE_DISABLED
		hide()
		queue_free()
		return

	_apply_difficulty()
	health = max_health
	_home_position = global_position
	_base_rotation = global_rotation
	_last_known_position = _home_position

	set_collision_mask_value(3, true)

	if vision_area != null:
		vision_area.set_deferred("monitoring", false)
	if hearing_area != null:
		hearing_area.set_deferred("monitoring", false)

	if vision_ray != null:
		vision_ray.enabled = true
		vision_ray.collision_mask = 1

	if variant != Variant.SOLDADO:
		var wanted: int = variant
		_apply_variant_now(wanted)

	if behavior == Behavior.INERTE:
		if vision_ray != null:
			vision_ray.enabled = false
		return

	Global.noise_made.connect(_on_noise)

	var icon := AwarenessIcon.new()
	icon.enemy = self
	add_child(icon)

	if behavior == Behavior.PATRULLA and route.is_empty():
		global_rotation = _patrol_axis().angle()


func _apply_difficulty() -> void:
	vision_range *= Settings.diff("vision_range")
	vision_angle = minf(vision_angle * Settings.diff("vision_angle"), 360.0)
	spread_degrees *= Settings.diff("spread")
	fire_rate *= Settings.diff("fire_rate")
	speed *= Settings.diff("speed")
	patrol_speed *= Settings.diff("speed")
	alert_radius *= Settings.diff("alert")
	give_up_time *= Settings.diff("give_up")
	max_health *= Settings.diff("health")


func variant_key() -> String:
	return VARIANT_KEYS[clampi(int(variant), 0, VARIANT_KEYS.size() - 1)]


func apply_variant(v: int) -> void:
	if _variant_applied:
		return
	if v <= Variant.SOLDADO or v > Variant.RAPIDO:
		return
	if not is_node_ready():
		variant = v
		return
	_apply_variant_now(v)


func _apply_variant_now(v: int) -> void:
	if _variant_applied or v <= Variant.SOLDADO or v > Variant.RAPIDO:
		return
	_variant_applied = true
	variant = v
	var tint := Color.WHITE
	var size_k := 1.0
	var glow := NO_GLOW
	match v:
		Variant.PESADO:
			max_health *= 2.4
			speed *= 0.75
			patrol_speed *= 0.75
			knockback *= 0.3
			fire_rate *= 1.35
			pellets = 4
			fan_degrees = 14.0
			bullet_damage_mult = 0.8
			can_flee = false
			size_k = 1.18
			tint = Color(0.55, 0.68, 0.95)
			kill_points = 150
		Variant.TIRADOR:
			vision_range *= 1.7
			vision_angle = maxf(vision_angle * 0.6, 10.0)
			attack_range *= 1.6
			fire_rate *= 2.2
			reaction_time *= 1.5
			spread_degrees *= 0.2
			bullet_speed_mult = 1.9
			bullet_damage_mult = 2.2
			stop_to_shoot = true
			has_laser = true
			tint = Color(0.74, 0.84, 0.46)
			kill_points = 130
		Variant.RAPIDO:
			speed *= 1.55
			patrol_speed *= 1.3
			acceleration *= 1.4
			max_health *= 0.6
			fire_rate *= 0.55
			spread_degrees *= 1.5
			attack_range *= 0.6
			reaction_time *= 0.6
			can_flee = false
			size_k = 0.92
			tint = Color(1.0, 0.5, 0.42)
			glow = Color(1.0, 0.18, 0.08, 1.0)
			kill_points = 120
	health = max_health
	_apply_variant_visuals(tint, size_k, glow)
	if has_laser:
		_build_laser()


func _apply_variant_visuals(tint: Color, size_k: float, glow: Color) -> void:
	icon_offset = 26.0 * size_k
	if body_shape != null and size_k != 1.0:
		body_shape.scale = Vector2.ONE * size_k
	if anim == null:
		return
	if size_k != 1.0:
		anim.scale *= size_k
		if visuals != null:
			if visuals.get("_sprite_home_scale") != null:
				visuals.set("_sprite_home_scale", anim.scale)
			var muzzle = visuals.get("muzzle_offset")
			if muzzle is Vector2:
				visuals.set("muzzle_offset", muzzle * size_k)
	var mat := anim.material as ShaderMaterial
	if mat == null:
		anim.self_modulate = tint
		return
	mat = mat.duplicate() as ShaderMaterial
	anim.material = mat
	mat.set_shader_parameter("albedo_color", tint)
	if glow.a > 0.0:
		mat.set_shader_parameter("emission_enabled", true)
		mat.set_shader_parameter("emission", glow)
		mat.set_shader_parameter("emission_energy_multiplier", 0.35)


func _build_laser() -> void:
	if _laser != null:
		return
	_laser_glow = _make_laser_line("LaserGlow", true)
	_laser = _make_laser_line("Laser", false)


func _make_laser_line(line_name: String, additive: bool) -> Line2D:
	var line := Line2D.new()
	line.name = line_name
	line.light_mask = 0
	line.width = 1.2
	line.z_index = 30
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.default_color = Color(1.0, 0.1, 0.1, 0.15)
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		line.material = mat
	line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	add_child(line)
	return line


func _physics_process(delta: float) -> void:
	if state == State.MUERTO or behavior == Behavior.INERTE:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		if state == State.MUERTO and velocity == Vector2.ZERO:
			set_physics_process(false)
		return

	_shoot_timer = maxf(0.0, _shoot_timer - delta)
	_state_time += delta

	_target = _pick_visible_target(delta)
	var engaged := state == State.ATACAR or state == State.HUIR

	_peak_awareness = maxf(_peak_awareness, awareness)
	if awareness < 0.05:
		if _peak_awareness > 0.6 and not engaged:
			_investigate(_last_known_position)
		_peak_awareness = 0.0

	if _target == null and _seen_now and awareness > 0.25 and not engaged:
		_face_smooth(_last_known_position, delta)
		_brake(delta)
	else:
		match state:
			State.PATRULLA:
				_state_patrulla(delta)
			State.ATACAR:
				_state_atacar(delta)
			State.INVESTIGAR:
				_state_investigar(delta)
			State.VOLVER:
				_state_volver(delta)
			State.HUIR:
				_state_huir(delta)

	move_and_slide()
	_check_stuck(delta)
	if _laser != null:
		_update_laser(delta)


func is_alive() -> bool:
	return state != State.MUERTO


func _set_state(new_state: int) -> void:
	state = new_state
	_state_time = 0.0
	_stuck_timer = 0.0
	_path_goal = NO_POINT


func _state_patrulla(delta: float) -> void:
	if _target != null:
		_enter_attack()
		return

	match behavior:
		Behavior.TORRETA:
			_do_turret_sweep(delta)
		Behavior.PATRULLA:
			if route.is_empty():
				_do_line_patrol(delta)
			else:
				_do_route_patrol(delta)
		Behavior.PERSEGUIR:
			_do_wander(delta)


func _enter_attack() -> void:
	var was_calm := state != State.ATACAR and state != State.HUIR
	awareness = 1.0
	_set_state(State.ATACAR)
	_shoot_timer = maxf(_shoot_timer, reaction_time * Settings.enemy_reaction_mult())
	if has_laser:
		_shoot_timer = maxf(_shoot_timer, LASER_LEAD)
	if was_calm:
		if not Global.boss_alive:
			Global.register_detection()
		if _target != null:
			Global.make_noise(global_position, alert_radius, _target.global_position)


func _aim_locked() -> bool:
	return has_laser and _shoot_timer > 0.0 and _shoot_timer <= LASER_LOCK


func _state_atacar(delta: float) -> void:
	if _target == null:
		_investigate(_last_known_position)
		return

	if not _aim_locked():
		_face(_target.global_position)
	var dist := global_position.distance_to(_target.global_position)

	if behavior == Behavior.PERSEGUIR:
		if dist > attack_range:
			_go_to(_target.global_position, delta, speed, false)
		else:
			_brake(delta)
	elif behavior == Behavior.PATRULLA and not stop_to_shoot and route.is_empty():
		_advance_on_line(delta)
	else:
		_brake(delta)

	var puede_disparar := dist <= attack_range if behavior == Behavior.PERSEGUIR else true
	if puede_disparar and _shoot_timer <= 0.0:
		_shoot()
		_shoot_timer = fire_rate
	elif has_laser and not puede_disparar:
		_shoot_timer = maxf(_shoot_timer, LASER_LEAD)


func _state_investigar(delta: float) -> void:
	if _target != null:
		_enter_attack()
		return

	if behavior == Behavior.TORRETA:
		_face_smooth(_investigate_pos, delta)
		_brake(delta)
		if _state_time > give_up_time:
			_set_state(State.PATRULLA)
		return

	if _go_to(_investigate_pos, delta, speed):
		global_rotation += 1.8 * delta
		_search_timer -= delta
		if _search_timer <= 0.0:
			_set_state(State.VOLVER)
	elif _state_time > 12.0:
		_set_state(State.VOLVER)


func _state_volver(delta: float) -> void:
	if _target != null:
		_enter_attack()
		return

	if behavior == Behavior.TORRETA:
		_set_state(State.PATRULLA)
		return

	if _go_to(_return_point(), delta, patrol_speed if behavior == Behavior.PATRULLA else speed):
		_set_state(State.PATRULLA)
	elif _state_time > 10.0:
		_set_state(State.PATRULLA)


func _state_huir(delta: float) -> void:
	var threat := _last_known_position
	var player := _closest_player()
	if player != null:
		threat = player.global_position

	if _target != null:
		_unseen_time = 0.0
	else:
		_unseen_time += delta
		if _unseen_time > give_up_time:
			_set_state(State.VOLVER)
			return

	_flee_repick -= delta
	if _flee_point == NO_POINT or _flee_repick <= 0.0 or global_position.distance_to(_flee_point) < 12.0:
		_flee_point = _pick_flee_point(threat)
		_flee_repick = 0.7
	_go_to(_flee_point, delta, speed * 1.25)


func _start_flee() -> void:
	_set_state(State.HUIR)
	_unseen_time = 0.0
	_flee_point = NO_POINT
	_flee_repick = 0.0


func _pick_flee_point(threat: Vector2) -> Vector2:
	var best := global_position
	var best_score := -INF
	for i in range(16):
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 16.0)
		for step in range(1, 5):
			var candidate := global_position + dir * 50.0 * float(step)
			if not _is_walkable(candidate):
				break
			var score := candidate.distance_to(threat) - candidate.distance_to(global_position) * 0.2 + randf() * 8.0
			if score > best_score:
				best_score = score
				best = candidate
	return best


func alert_to(point: Vector2) -> void:
	if state == State.MUERTO or state == State.ATACAR or state == State.HUIR:
		return
	if behavior == Behavior.INERTE:
		return
	_last_known_position = point
	_investigate(point)
	_search_timer = maxf(_search_timer, give_up_time * 1.5)


func _get_level() -> Node:
	if _level == null or not is_instance_valid(_level):
		_level = get_tree().get_first_node_in_group("level")
	return _level


func _is_walkable(point: Vector2) -> bool:
	var level := _get_level()
	if level != null and level.has_method("is_walkable"):
		return level.is_walkable(point)
	return true


func _compute_path(point: Vector2) -> PackedVector2Array:
	var level := _get_level()
	if level != null and level.has_method("find_path"):
		return level.find_path(global_position, point)
	return PackedVector2Array([point])


func _go_to(point: Vector2, delta: float, move_speed: float, face_move: bool = true) -> bool:
	if global_position.distance_to(point) <= 10.0:
		_brake(delta)
		return true

	_repath_timer -= delta
	if _path_goal.distance_to(point) > 24.0 or _repath_timer <= 0.0:
		_path = _compute_path(point)
		_path_index = 0
		_path_goal = point
		_repath_timer = 0.5
		if _path.size() > 1 and global_position.distance_to(_path[1]) < _path[0].distance_to(_path[1]):
			_path_index = 1

	var next := point
	if not _path.is_empty():
		while _path_index < _path.size() - 1 and global_position.distance_to(_path[_path_index]) < 7.0:
			_path_index += 1
		if _path_index < _path.size() - 1:
			next = _path[_path_index]

	var dir := (next - global_position).normalized()
	velocity = velocity.move_toward(dir * move_speed, acceleration * delta)
	if face_move:
		_face_smooth(next, delta)
	return false


func _patrol_axis() -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(patrol_angle_degrees))


func _patrol_end(sign_dir: float) -> Vector2:
	return _home_position + _patrol_axis() * patrol_distance * sign_dir


func _closest_point_on_line() -> Vector2:
	var axis := _patrol_axis()
	var t: float = clampf((global_position - _home_position).dot(axis), -patrol_distance, patrol_distance)
	return _home_position + axis * t


func _return_point() -> Vector2:
	match behavior:
		Behavior.PATRULLA:
			if route.is_empty():
				return _closest_point_on_line()
			var best := _home_position + route[0]
			var best_d := INF
			for i in range(route.size()):
				var p := _home_position + route[i]
				var d := global_position.distance_to(p)
				if d < best_d:
					best_d = d
					best = p
					_route_index = i
			return best
	return _home_position


func _do_line_patrol(delta: float) -> void:
	if patrol_distance <= 1.0:
		_brake(delta)
		return

	if _wait_timer > 0.0:
		_wait_timer -= delta
		_brake(delta)
		return

	_advance_on_line(delta)


func _advance_on_line(delta: float) -> void:
	var destino := _patrol_end(_patrol_dir)

	if global_position.distance_to(destino) < 10.0:
		_turn_around()
		return

	if state != State.ATACAR:
		_face(destino)

	var axis := _patrol_axis()
	velocity = velocity.move_toward(axis * _patrol_dir * patrol_speed, acceleration * delta)


func _turn_around() -> void:
	_patrol_dir *= -1.0
	_wait_timer = patrol_wait
	_stuck_timer = 0.0
	velocity = Vector2.ZERO


func _do_route_patrol(delta: float) -> void:
	if _wait_timer > 0.0:
		_wait_timer -= delta
		_brake(delta)
		return

	var destino := _home_position + route[_route_index]
	if _go_to(destino, delta, patrol_speed):
		_route_index = (_route_index + 1) % route.size()
		_wait_timer = patrol_wait


func _do_wander(delta: float) -> void:
	if _wait_timer > 0.0:
		_wait_timer -= delta
		_brake(delta)
		return

	if _wander_target == NO_POINT:
		for i in range(8):
			var candidate := _home_position + Vector2(randf_range(-patrol_distance, patrol_distance), randf_range(-patrol_distance, patrol_distance))
			if _is_walkable(candidate):
				_wander_target = candidate
				break
		if _wander_target == NO_POINT:
			_wait_timer = 1.0
			return

	if _go_to(_wander_target, delta, patrol_speed):
		_wander_target = NO_POINT
		_wait_timer = randf_range(0.6, patrol_wait + 1.2)


func _check_stuck(delta: float) -> void:
	if _wait_timer > 0.0 or state == State.MUERTO:
		_stuck_timer = 0.0
		return

	var quiere_moverse := velocity.length() > 5.0
	if quiere_moverse and get_real_velocity().length() < 5.0:
		_stuck_timer += delta
		if _stuck_timer > 0.35:
			_stuck_timer = 0.0
			_on_stuck()
	else:
		_stuck_timer = 0.0


func _on_stuck() -> void:
	match state:
		State.PATRULLA:
			if behavior == Behavior.PATRULLA and route.is_empty():
				_turn_around()
			elif behavior == Behavior.PATRULLA:
				_route_index = (_route_index + 1) % route.size()
				_repath_timer = 0.0
			else:
				_wander_target = NO_POINT
		State.HUIR:
			_cornered = true
			if _target != null:
				_enter_attack()
			else:
				_set_state(State.VOLVER)
		_:
			_repath_timer = 0.0


func _do_turret_sweep(delta: float) -> void:
	_brake(delta)
	if turret_sweep_degrees <= 0.0 or turret_sweep_time <= 0.0:
		return
	_sweep_time += delta
	var fase := sin(TAU * _sweep_time / turret_sweep_time)
	var objetivo := _base_rotation + deg_to_rad(turret_sweep_degrees * 0.5) * fase
	global_rotation = lerp_angle(global_rotation, objetivo, clampf(delta * 6.0, 0.0, 1.0))


func _brake(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _face(point: Vector2) -> void:
	if global_position.distance_to(point) > 1.0:
		look_at(point)


func _face_smooth(point: Vector2, delta: float) -> void:
	if global_position.distance_to(point) > 1.0:
		var wanted := (point - global_position).angle()
		global_rotation = lerp_angle(global_rotation, wanted, clampf(delta * 10.0, 0.0, 1.0))


func _closest_player() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for p in get_tree().get_nodes_in_group("player"):
		var who := p as Node2D
		if who == null:
			continue
		var d := global_position.distance_to(who.global_position)
		if d < best_dist:
			best_dist = d
			best = who
	return best


func _sight_range(who: Node) -> float:
	var lv = who.get("light_visibility")
	if lv == null:
		return vision_range
	return vision_range * clampf(float(lv), 0.05, 4.0)


func _pick_visible_target(delta: float) -> Node2D:
	if Global.health <= 0.0:
		awareness = maxf(0.0, awareness - delta)
		_seen_now = false
		return null

	var best: Node2D = null
	var best_vis := 0.0
	var best_dist := INF
	var best_range := vision_range
	for p in get_tree().get_nodes_in_group("player"):
		var who := p as Node2D
		if who == null:
			continue
		var reach := _sight_range(who)
		var vis := _visibility(who, reach)
		if vis <= 0.0:
			continue
		var d := global_position.distance_to(who.global_position)
		if d < best_dist:
			best_dist = d
			best = who
			best_vis = vis
			best_range = reach

	_seen_now = best != null
	if best != null:
		_last_known_position = best.global_position

	if state == State.ATACAR or state == State.HUIR:
		if best != null:
			awareness = 1.0
		else:
			awareness = maxf(awareness - 0.2 * delta, 0.5)
		return best

	if best != null and Global.grace_time <= 0.0:
		var proximity := lerpf(0.35, 2.2, clampf(1.0 - best_dist / maxf(best_range, 1.0), 0.0, 1.0))
		var loudness = best.get("noise_level")
		var noise := 1.0 if loudness == null else float(loudness)
		var rate := (1.0 / Settings.diff("detect_time")) * proximity * noise * best_vis
		awareness = minf(1.0, awareness + rate * delta)
		if awareness >= 1.0:
			return best
	else:
		awareness = maxf(0.0, awareness - 0.35 * delta)
	return null


func _visibility(who: Node2D, reach: float = -1.0) -> float:
	if reach < 0.0:
		reach = _sight_range(who)
	var to_target := who.global_position - global_position
	var dist := to_target.length()
	if dist > reach:
		return 0.0

	var factor := 1.0
	if vision_angle < 360.0:
		var facing := Vector2.RIGHT.rotated(global_rotation)
		var half := deg_to_rad(vision_angle * 0.5)
		if absf(facing.angle_to(to_target)) > half:
			if dist > 42.0:
				return 0.0
			factor = 0.55

	if _wall_between(who.global_position):
		return 0.0
	return factor


func _in_blind_spot(point: Vector2) -> bool:
	if vision_angle >= 360.0:
		return false
	var facing := Vector2.RIGHT.rotated(global_rotation)
	return absf(facing.angle_to(point - global_position)) > deg_to_rad(vision_angle * 0.5)


func _wall_between(point: Vector2) -> bool:
	if vision_ray == null:
		return false
	vision_ray.target_position = to_local(point)
	vision_ray.force_raycast_update()
	return vision_ray.is_colliding()


func _on_noise(origin: Vector2, radius: float, investigate_at: Vector2) -> void:
	if state == State.MUERTO or state == State.ATACAR or state == State.HUIR:
		return

	radius *= Settings.diff("hearing")
	var d := global_position.distance_to(origin)
	if d > radius:
		return
	if d > radius * 0.5 and _wall_between(origin):
		return

	_investigate(investigate_at)


func _investigate(point: Vector2) -> void:
	_investigate_pos = point
	_search_timer = give_up_time
	if state != State.INVESTIGAR:
		_set_state(State.INVESTIGAR)


func _shoot() -> void:
	var count := maxi(1, pellets)
	for i in range(count):
		var offset := 0.0
		if count > 1:
			offset = lerpf(-fan_degrees * 0.5, fan_degrees * 0.5, float(i) / float(count - 1))
		var angle := global_rotation + deg_to_rad(offset + randf_range(-spread_degrees, spread_degrees))
		_spawn_bullet(angle, bullet_speed_mult, bullet_damage_mult, NO_GLOW, 1.0, NO_POINT, count > 1)
	if has_laser:
		_laser_flash = 0.12
	if visuals != null:
		visuals.fire()


func _spawn_bullet(angle: float, speed_mult: float = 1.0, damage_mult: float = 1.0, glow: Color = NO_GLOW, size: float = 1.0, origin: Vector2 = NO_POINT, as_pellet: bool = false) -> Node:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	if _bala_enemy == null:
		_bala_enemy = load(BALA_ENEMY_PATH)
	if _bala_enemy == null:
		return null
	var bullet = _bala_enemy.instantiate()
	if "shooter" in bullet:
		bullet.shooter = self
	if "pellet" in bullet:
		bullet.pellet = as_pellet
	if glow.a > 0.0 and "glow_color" in bullet:
		bullet.glow_color = glow
	if size != 1.0 and "size_mult" in bullet:
		bullet.size_mult = size
	if "speed" in bullet:
		bullet.speed *= speed_mult
	if "damage" in bullet:
		bullet.damage *= damage_mult * Settings.enemy_damage_mult()
	scene_root.add_child(bullet)
	var start := origin
	if start == NO_POINT:
		start = global_position + Vector2(muzzle_distance, 0.0).rotated(angle)
	bullet.global_rotation = angle
	bullet.global_position = start
	return bullet


func _update_laser(delta: float) -> void:
	_laser_time += delta
	_laser_flash = maxf(0.0, _laser_flash - delta)
	if state == State.MUERTO or behavior == Behavior.INERTE:
		_set_laser_visible(false)
		return
	_set_laser_visible(true)
	var dir := Vector2.RIGHT.rotated(global_rotation)
	var from := global_position + dir * muzzle_distance * 0.7
	var reach := maxf(vision_range, 60.0)
	var to := from + dir * reach
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		to = hit["position"]
	var alpha := 0.22
	var width := 1.0
	var glow := 0.07
	var col := Color(1.0, 0.1, 0.08)
	if state == State.ATACAR and _shoot_timer <= LASER_LEAD:
		var k := 1.0 - clampf(_shoot_timer / LASER_LEAD, 0.0, 1.0)
		alpha = lerpf(0.45, 0.95, k)
		width = lerpf(1.2, 2.2, k)
		glow = lerpf(0.14, 0.4, k)
		if _aim_locked():
			var on := fmod(_laser_time * 28.0, 2.0) < 1.0
			alpha = 1.0 if on else 0.55
			glow = 0.55 if on else 0.25
			width = 2.6
			col = Color(1.0, 0.28, 0.22)
	if _laser_flash > 0.0:
		alpha = 1.0
		glow = 0.8
		width = 3.4
		col = Color(1.0, 0.9, 0.8)
	var pts := PackedVector2Array([to_local(from), to_local(to)])
	_laser.points = pts
	_laser.width = width
	_laser.default_color = Color(col, alpha)
	if _laser_glow != null:
		_laser_glow.points = pts
		_laser_glow.width = width * 3.2
		_laser_glow.default_color = Color(col, glow)


func _set_laser_visible(on: bool) -> void:
	if _laser != null:
		_laser.visible = on
	if _laser_glow != null:
		_laser_glow.visible = on


func apply_bullet_hit(amount: float, from_direction: Vector2) -> void:
	if state == State.MUERTO:
		return
	if from_direction != Vector2.ZERO:
		velocity += from_direction.normalized() * knockback
	take_damage(amount)


func melee_hit(amount: float, from_pos: Vector2) -> void:
	if state == State.MUERTO:
		return
	var unaware := state != State.ATACAR and state != State.HUIR
	_killed_by_melee = true
	if unaware and _in_blind_spot(from_pos):
		_stealth_kill = true
		take_damage(max_health * 4.0)
		return

	var dir := (global_position - from_pos).normalized()
	velocity += dir * knockback * 2.5
	Global.make_noise(global_position, 110.0, from_pos)
	take_damage(amount)
	_killed_by_melee = false


func take_damage(amount: float) -> void:
	if state == State.MUERTO:
		return

	health -= amount
	_flash_hit()

	if health <= 0.0:
		die()
		return

	if state == State.PATRULLA or state == State.VOLVER:
		var player := _closest_player()
		if player != null:
			_investigate(player.global_position)

	if can_flee and not _cornered and behavior != Behavior.TORRETA and state != State.HUIR:
		if health <= max_health * flee_health_ratio:
			_start_flee()


func die() -> void:
	if state == State.MUERTO:
		return
	_set_state(State.MUERTO)
	velocity = Vector2.ZERO

	var silent := _stealth_kill
	Global.last_kill_weapon = 2 if _killed_by_melee else Global.current_weapon
	Global.last_kill_silent = silent
	if silent:
		Global.register_stealth_kill()
	var earned := Global.add_kill(kill_points * (2 if silent else 1))
	var mult := Global.last_multiplier
	var tint := UIStyle.BAR_FILL
	if mult >= 10:
		tint = UIStyle.LIFE
	elif mult >= 5:
		tint = UIStyle.OBJECTIVE
	FloatingText.spawn(get_tree().current_scene, global_position, "+%d" % earned, tint, 12 + mini(mult, 10))
	if silent:
		FloatingText.spawn(get_tree().current_scene, global_position + Vector2(0, -18), "SILENCIOSO", UIStyle.AMMO, 11)
	Global.enemy_killed.emit(global_position)

	_set_laser_visible(false)
	if visuals != null:
		visuals.set_dead(true)
	else:
		AnimNames.play(anim, AnimNames.DEAD)

	set_collision_layer_value(3, false)
	set_collision_mask_value(2, false)
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	_send_corpse_back()


func _send_corpse_back() -> void:
	z_index = 0
	call_deferred("_reorder_corpse")


func _reorder_corpse() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child == self:
			return
		if child.has_method("is_alive"):
			parent.move_child(self, child.get_index())
			return


func _flash_hit() -> void:
	if anim == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	anim.modulate = Color(3.0, 3.0, 3.0, 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_property(anim, "modulate", Color.WHITE, 0.12)
