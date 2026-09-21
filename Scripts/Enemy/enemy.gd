extends CharacterBody2D

## Enemigo. Los comportamientos (INERTE, TORRETA, PATRULLA, PERSEGUIR) y los estados están en el README.
##
## No te detecta al instante: mientras te ve sube `awareness` de 0 a 1 (más rápido si estás
## cerca, te mueves o disparas; más lento con Shift). Por su punto ciego casi no te nota.
## El camino sale de level.find_path(); si la escena no es un Level camina en línea recta.

const FloatingText := preload("res://Scripts/floating_text.gd")
const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const BALA_ENEMY_PATH := "res://Scenes/BalaEnemy.tscn"
var _bala_enemy: PackedScene = null

enum Behavior { TORRETA, PATRULLA, PERSEGUIR, INERTE }
# no cambiar el orden, las escenas guardan el número
enum State { PATRULLA, ATACAR, VOLVER, MUERTO, INVESTIGAR, HUIR }

const NO_POINT := Vector2(1.0e9, 1.0e9)


## anillo que se llena, ? al sospechar y ! al detectarte
class AwarenessIcon extends Node2D:
	var enemy: Node = null
	var _time: float = 0.0

	func _init() -> void:
		top_level = true
		z_index = 120

	func _process(delta: float) -> void:
		if enemy == null or not is_instance_valid(enemy):
			queue_free()
			return
		_time += delta
		global_position = enemy.global_position + Vector2(0, -26)
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
## tipo de enemigo
@export var behavior: Behavior = Behavior.PERSEGUIR

@export_group("Patrulla")
## píxeles hacia cada lado de donde lo pongas (en PERSEGUIR es el radio de merodeo)
@export var patrol_distance: float = 300.0
## 0 = horizontal, 90 = vertical
@export_range(-180.0, 180.0, 1.0) var patrol_angle_degrees: float = 0.0
@export var patrol_speed: float = 70.0
## pausa en cada extremo
@export var patrol_wait: float = 0.7
## puntos de ruta (desplazamientos desde su posición); reemplaza a la línea recta
@export var route: Array[Vector2] = []

@export_group("Torreta")
## grados que barre; 0 = mira al frente
@export_range(0.0, 360.0, 1.0) var turret_sweep_degrees: float = 90.0
## segundos por barrido completo
@export var turret_sweep_time: float = 4.0

@export_group("Movimiento")
@export var speed: float = 110.0
@export var acceleration: float = 900.0
@export var friction: float = 1100.0

@export_group("Vida")
@export var max_health: float = 60.0
## empuje al recibir un balazo
@export var knockback: float = 90.0
## con poca vida huye (menos las torretas)
@export var can_flee: bool = true
## fracción de vida a la que huye
@export_range(0.0, 1.0, 0.05) var flee_health_ratio: float = 0.3

@export_group("Percepción")
@export var vision_range: float = 260.0
## cono de visión en grados, 360 ve todo
@export_range(10.0, 360.0, 1.0) var vision_angle: float = 140.0
## segundos que busca tras perderte
@export var give_up_time: float = 3.0
## radio (px) en el que avisa a otros enemigos
@export var alert_radius: float = 260.0

@export_group("Combate")
## solo PERSEGUIR: distancia a la que deja de acercarse y dispara
@export var attack_range: float = 220.0
## segundos entre disparos
@export var fire_rate: float = 0.9
## retardo antes del primer disparo
@export var reaction_time: float = 0.45
## de dónde sale la bala
@export var muzzle_distance: float = 30.0
## dispersión en grados
@export var spread_degrees: float = 6.0
## true = se planta a disparar, false = dispara mientras camina
@export var stop_to_shoot: bool = true

@export_group("Dificultad")
## dificultad mínima: 0 siempre, 1 Normal y Difícil, 2 solo Difícil
@export_enum("Siempre", "Normal y Difícil", "Solo Difícil") var appears_from: int = 0
## custodio de la sala de la puerta: no suelta la llave (si no, quedaría encerrada)
@export var guards_exit: bool = false

var health: float = 0.0
var state: int = State.PATRULLA

## 0 = no sabe nada, 1 = te detectó
var awareness: float = 0.0
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

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var vision_area: Area2D = get_node_or_null("VisionArea")
@onready var hearing_area: Area2D = get_node_or_null("HearingArea")
@onready var vision_ray: RayCast2D = get_node_or_null("VisionRay")
@onready var visuals = get_node_or_null("Visuals")


func _ready() -> void:
	# en dificultades bajas no existe
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

	# ya no se usan, la vista es distancia + rayo
	if vision_area != null:
		vision_area.set_deferred("monitoring", false)
	if hearing_area != null:
		hearing_area.set_deferred("monitoring", false)

	if vision_ray != null:
		vision_ray.enabled = true
		# el rayo solo choca con paredes
		vision_ray.collision_mask = 1

	# INERTE: todo apagado
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


## aplica la tabla de dificultad
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


func _physics_process(delta: float) -> void:
	if state == State.MUERTO or behavior == Behavior.INERTE:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	_shoot_timer = maxf(0.0, _shoot_timer - delta)
	_state_time += delta

	_target = _pick_visible_target(delta)
	var engaged := state == State.ATACAR or state == State.HUIR

	# te vio un instante y te perdió: va a mirar donde estabas
	_peak_awareness = maxf(_peak_awareness, awareness)
	if awareness < 0.05:
		if _peak_awareness > 0.6 and not engaged:
			_investigate(_last_known_position)
		_peak_awareness = 0.0

	# sospecha: se queda quieto mirándote
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


func is_alive() -> bool:
	return state != State.MUERTO


func _set_state(new_state: int) -> void:
	state = new_state
	_state_time = 0.0
	_stuck_timer = 0.0
	_path_goal = NO_POINT


# estados

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
	# reacciona con un pequeño retraso
	_shoot_timer = maxf(_shoot_timer, reaction_time * Settings.enemy_reaction_mult())
	if was_calm and _target != null:
		# grita para que los cercanos vengan
		Global.make_noise(global_position, alert_radius, _target.global_position)


func _state_atacar(delta: float) -> void:
	if _target == null:
		_investigate(_last_known_position)
		return

	_face(_target.global_position)
	var dist := global_position.distance_to(_target.global_position)

	if behavior == Behavior.PERSEGUIR:
		if dist > attack_range:
			_go_to(_target.global_position, delta, speed, false)
		else:
			_brake(delta)
	elif behavior == Behavior.PATRULLA and not stop_to_shoot and route.is_empty():
		# camina mientras dispara
		_advance_on_line(delta)
	else:
		_brake(delta)

	var puede_disparar := dist <= attack_range if behavior == Behavior.PERSEGUIR else true
	if puede_disparar and _shoot_timer <= 0.0:
		_shoot()
		_shoot_timer = fire_rate


## va a ver de dónde vino el ruido
func _state_investigar(delta: float) -> void:
	if _target != null:
		_enter_attack()
		return

	# la torreta solo gira
	if behavior == Behavior.TORRETA:
		_face_smooth(_investigate_pos, delta)
		_brake(delta)
		if _state_time > give_up_time:
			_set_state(State.PATRULLA)
		return

	if _go_to(_investigate_pos, delta, speed):
		# llegó: mira un rato antes de rendirse
		global_rotation += 1.8 * delta
		_search_timer -= delta
		if _search_timer <= 0.0:
			_set_state(State.VOLVER)
	elif _state_time > 12.0:
		_set_state(State.VOLVER)


## vuelve a su puesto
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


## huye; si lo arrinconan, pelea
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


## de varias direcciones, la que más lo aleja
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


# pathfinding

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


## sigue el camino hacia point, true cuando llega
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
		# si el primer punto quedó atrás, lo salta
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


# patrulla

## dirección de la línea
func _patrol_axis() -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(patrol_angle_degrees))


func _patrol_end(sign_dir: float) -> Vector2:
	return _home_position + _patrol_axis() * patrol_distance * sign_dir


## punto de la línea más cercano
func _closest_point_on_line() -> Vector2:
	var axis := _patrol_axis()
	var t: float = clampf((global_position - _home_position).dot(axis), -patrol_distance, patrol_distance)
	return _home_position + axis * t


## a dónde vuelve tras una alerta
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


## patrulla por waypoints en ciclo
func _do_route_patrol(delta: float) -> void:
	if _wait_timer > 0.0:
		_wait_timer -= delta
		_brake(delta)
		return

	var destino := _home_position + route[_route_index]
	if _go_to(destino, delta, patrol_speed):
		_route_index = (_route_index + 1) % route.size()
		_wait_timer = patrol_wait


## el perseguidor merodea cerca de su puesto
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


## si choca con una pared reacciona en vez de empujarla
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
			# arrinconado: pelea
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
	# lerp_angle para que vuelva suave al barrido
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


# percepción

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


## devuelve al jugador solo si ya te detectó (awareness 1) o ya está peleando
func _pick_visible_target(delta: float) -> Node2D:
	if Global.health <= 0.0:
		awareness = maxf(0.0, awareness - delta)
		_seen_now = false
		return null

	var best: Node2D = null
	var best_vis := 0.0
	var best_dist := INF
	for p in get_tree().get_nodes_in_group("player"):
		var who := p as Node2D
		if who == null:
			continue
		var vis := _visibility(who)
		if vis <= 0.0:
			continue
		var d := global_position.distance_to(who.global_position)
		if d < best_dist:
			best_dist = d
			best = who
			best_vis = vis

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
		# cerca sube rápido; moverte o disparar te delata
		var proximity := lerpf(0.35, 2.2, clampf(1.0 - best_dist / vision_range, 0.0, 1.0))
		var loudness = best.get("noise_level")
		var noise := 1.0 if loudness == null else float(loudness)
		var rate := (1.0 / Settings.diff("detect_time")) * proximity * noise * best_vis
		awareness = minf(1.0, awareness + rate * delta)
		if awareness >= 1.0:
			return best
	else:
		awareness = maxf(0.0, awareness - 0.35 * delta)
	return null


## qué tanto te ve: 1 en su cono, 0.55 pegado a su espalda, 0 si no
func _visibility(who: Node2D) -> float:
	var to_target := who.global_position - global_position
	var dist := to_target.length()
	if dist > vision_range:
		return 0.0

	var factor := 1.0
	if vision_angle < 360.0:
		var facing := Vector2.RIGHT.rotated(global_rotation)
		var half := deg_to_rad(vision_angle * 0.5)
		if absf(facing.angle_to(to_target)) > half:
			# punto ciego: solo te nota si estás casi encima
			if dist > 42.0:
				return 0.0
			factor = 0.55

	# ¿hay pared en medio?
	if _wall_between(who.global_position):
		return 0.0
	return factor


## ¿está en su punto ciego?
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


## oye un disparo o un grito y va a investigar
func _on_noise(origin: Vector2, radius: float, investigate_at: Vector2) -> void:
	if state == State.MUERTO or state == State.ATACAR or state == State.HUIR:
		return

	radius *= Settings.diff("hearing")
	var d := global_position.distance_to(origin)
	if d > radius:
		return
	# las paredes amortiguan el sonido
	if d > radius * 0.5 and _wall_between(origin):
		return

	_investigate(investigate_at)


func _investigate(point: Vector2) -> void:
	_investigate_pos = point
	_search_timer = give_up_time
	if state != State.INVESTIGAR:
		_set_state(State.INVESTIGAR)


# disparo

func _shoot() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	if _bala_enemy == null:
		_bala_enemy = load(BALA_ENEMY_PATH)
	if _bala_enemy == null:
		return
	var bullet = _bala_enemy.instantiate()
	scene_root.add_child(bullet)

	var spread := deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	bullet.global_rotation = global_rotation + spread
	bullet.global_position = global_position + Vector2(muzzle_distance, 0.0).rotated(global_rotation)
	if "shooter" in bullet:
		bullet.shooter = self
	if "damage" in bullet:
		bullet.damage *= Settings.enemy_damage_mult()

	if visuals != null:
		visuals.fire()


# daño y muerte

## la llama la bala al impactar
func apply_bullet_hit(amount: float, from_direction: Vector2) -> void:
	if state == State.MUERTO:
		return
	if from_direction != Vector2.ZERO:
		velocity += from_direction.normalized() * knockback
	take_damage(amount)


## golpe de cuchillo: por el punto ciego y sin que te haya visto mata en silencio (puntos dobles),
## si no es un golpe normal
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


## daño sin empuje
func take_damage(amount: float) -> void:
	if state == State.MUERTO:
		return

	health -= amount
	_flash_hit()

	if health <= 0.0:
		die()
		return

	# si le disparan sin haberte visto, va a donde estás
	if state == State.PATRULLA or state == State.VOLVER:
		var player := _closest_player()
		if player != null:
			_investigate(player.global_position)

	# muy herido: huye (menos las torretas)
	if can_flee and not _cornered and behavior != Behavior.TORRETA and state != State.HUIR:
		if health <= max_health * flee_health_ratio:
			_start_flee()


func die() -> void:
	if state == State.MUERTO:
		return
	_set_state(State.MUERTO)
	velocity = Vector2.ZERO

	# los puntos salen sobre el caído, más grandes con el combo
	var silent := _stealth_kill
	Global.last_kill_weapon = 2 if _killed_by_melee else Global.current_weapon
	Global.last_kill_silent = silent
	var earned := Global.add_kill(Global.KILL_POINTS * (2 if silent else 1))
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

	if visuals != null:
		visuals.set_dead(true)
	else:
		AnimNames.play(anim, AnimNames.DEAD)

	set_collision_layer_value(3, false)
	set_collision_mask_value(2, false)
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	z_index = -1


func _flash_hit() -> void:
	if anim == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	anim.modulate = Color(3.0, 3.0, 3.0, 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_property(anim, "modulate", Color.WHITE, 0.12)
