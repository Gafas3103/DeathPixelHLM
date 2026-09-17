extends CharacterBody2D

## ENEMIGO con tres comportamientos posibles (se elige en el Inspector).
##
##   INERTE   -> NO HACE NADA. Sin vision, sin movimiento, sin disparos.
##               Se le puede disparar y muere, pero no toma ni una decision.
##   TORRETA  -> no se mueve nunca. Barre la zona girando y dispara.
##   PATRULLA -> va y viene sobre UNA LÍNEA RECTA. Al verte se planta y dispara.
##   PERSEGUIR-> te sigue por todo el mapa (ojo: se atasca en las esquinas).
##
## Estados internos:
##
##      te ve                       lo pierde de vista
##   PATRULLA ──────► ATACAR ──────────────────────────► VOLVER
##      ▲                                                   │
##      └────────── llega a su línea otra vez ──────────────┘
##
##   cualquier estado ── vida <= 0 ──► MUERTO (definitivo)

const BALA_ENEMY_PATH := "res://Scenes/BalaEnemy.tscn"
var _bala_enemy: PackedScene = null

enum Behavior { TORRETA, PATRULLA, PERSEGUIR, INERTE }
enum State { PATRULLA, ATACAR, VOLVER, MUERTO }

# ---------------------------------------------------------------------------
@export_group("Comportamiento")
## Qué tipo de enemigo es. Cambiarlo aquí no requiere tocar código.
@export var behavior: Behavior = Behavior.PERSEGUIR

@export_group("Patrulla")
## Cuántos píxeles recorre hacia CADA lado desde donde lo pongas.
## El recorrido total es el doble de este valor.
@export var patrol_distance: float = 300.0
## Inclinación de la línea. 0 = horizontal, 90 = vertical.
@export_range(-180.0, 180.0, 1.0) var patrol_angle_degrees: float = 0.0
@export var patrol_speed: float = 70.0
## Segundos que se detiene en cada extremo antes de darse la vuelta.
@export var patrol_wait: float = 0.7

@export_group("Torreta")
## Grados que barre girando de un lado a otro. 0 = mira siempre al frente.
@export_range(0.0, 360.0, 1.0) var turret_sweep_degrees: float = 90.0
## Segundos que tarda en completar un barrido de ida y vuelta.
@export var turret_sweep_time: float = 4.0

@export_group("Movimiento")
@export var speed: float = 110.0
@export var acceleration: float = 900.0
@export var friction: float = 1100.0

@export_group("Vida")
@export var max_health: float = 60.0
## Cuánto se empuja el enemigo al recibir un balazo.
@export var knockback: float = 90.0

@export_group("Percepción")
@export var vision_range: float = 260.0
## Ángulo total del cono de visión, en grados. 360 = ve en todas direcciones.
@export_range(10.0, 360.0, 1.0) var vision_angle: float = 140.0
## Segundos que sigue alerta tras perderte de vista.
@export var give_up_time: float = 3.0

@export_group("Combate")
## Solo para PERSEGUIR: a qué distancia deja de acercarse y dispara.
@export var attack_range: float = 220.0
## Segundos entre disparos.
@export var fire_rate: float = 0.9
## Retardo antes del primer disparo al detectarte (para que sea justo).
@export var reaction_time: float = 0.45
## De dónde sale la bala.
@export var muzzle_distance: float = 30.0
## Dispersión del disparo en grados (0 = puntería perfecta).
@export var spread_degrees: float = 6.0
## Si es true se planta para disparar. Si es false sigue patrullando mientras tira.
@export var stop_to_shoot: bool = true

# ---------------------------------------------------------------------------
var health: float = 0.0
var state: int = State.PATRULLA

var _target: Node2D = null
var _candidates: Array[Node2D] = []
var _last_known_position: Vector2 = Vector2.ZERO
var _give_up_timer: float = 0.0
var _shoot_timer: float = 0.0

var _home_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _patrol_dir: float = 1.0
var _wait_timer: float = 0.0
var _stuck_timer: float = 0.0
var _sweep_time: float = 0.0
var _hit_tween: Tween = null

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var vision_area: Area2D = get_node_or_null("VisionArea")
@onready var vision_ray: RayCast2D = get_node_or_null("VisionRay")
@onready var visuals = get_node_or_null("Visuals")


func _ready() -> void:
	health = max_health
	_home_position = global_position
	_base_rotation = global_rotation
	_last_known_position = _home_position

	if vision_area != null:
		vision_area.body_entered.connect(_on_vision_body_entered)
		vision_area.body_exited.connect(_on_vision_body_exited)

	if vision_ray != null:
		vision_ray.enabled = true
		# Solo nos interesa saber si hay una PARED tapando (capa 1 = Mundo).
		vision_ray.collision_mask = 1

	# INERTE: apagamos la deteccion por completo. El enemigo queda
	# como un decorado: no percibe nada y no ejecuta ninguna logica.
	if behavior == Behavior.INERTE:
		if vision_area != null:
			vision_area.set_deferred("monitoring", false)
		if vision_ray != null:
			vision_ray.enabled = false
		return

	# La patrulla arranca mirando hacia donde va a caminar.
	if behavior == Behavior.PATRULLA:
		global_rotation = _patrol_axis().angle()


func _physics_process(delta: float) -> void:
	if state == State.MUERTO:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	# INERTE: se queda quieto. Ni busca objetivos ni decide nada.
	if behavior == Behavior.INERTE:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	_shoot_timer = maxf(0.0, _shoot_timer - delta)
	_target = _pick_visible_target()

	match state:
		State.PATRULLA:
			_state_patrulla(delta)
		State.ATACAR:
			_state_atacar(delta)
		State.VOLVER:
			_state_volver(delta)

	move_and_slide()
	_check_stuck(delta)


# ===========================================================================
#  ESTADOS
# ===========================================================================

func _state_patrulla(delta: float) -> void:
	if _target != null:
		state = State.ATACAR
		# Tarda un poco en reaccionar la primera vez, para que sea justo.
		_shoot_timer = maxf(_shoot_timer, reaction_time)
		return

	match behavior:
		Behavior.TORRETA:
			_do_turret_sweep(delta)
		Behavior.PATRULLA:
			_do_line_patrol(delta)
		Behavior.PERSEGUIR:
			_do_wander(delta)


func _state_atacar(delta: float) -> void:
	if _target == null:
		state = State.VOLVER
		_give_up_timer = give_up_time
		return

	_face(_target.global_position)
	var dist := global_position.distance_to(_target.global_position)

	if behavior == Behavior.PERSEGUIR:
		# El perseguidor se acerca hasta attack_range.
		if dist > attack_range:
			_move_towards(_target.global_position, delta)
		else:
			_brake(delta)
	elif behavior == Behavior.PATRULLA and not stop_to_shoot:
		# Sigue caminando sobre su línea mientras dispara (más difícil de acertar).
		_advance_on_line(delta)
	else:
		# Torreta, o patrulla que se planta para apuntar.
		_brake(delta)

	# Torreta y patrulla disparan a cualquier distancia que alcancen a ver.
	var puede_disparar := dist <= attack_range if behavior == Behavior.PERSEGUIR else true
	if puede_disparar and _shoot_timer <= 0.0:
		_shoot()
		_shoot_timer = fire_rate


func _state_volver(delta: float) -> void:
	# ¿Reapareció?
	if _target != null:
		state = State.ATACAR
		return

	_give_up_timer -= delta
	if _give_up_timer > 0.0:
		# Todavía alerta: mira hacia donde lo vio por última vez.
		_face(_last_known_position)
		_brake(delta)
		return

	match behavior:
		Behavior.TORRETA:
			# Vuelve a su ángulo original y sigue barriendo.
			state = State.PATRULLA
		Behavior.PERSEGUIR:
			state = State.PATRULLA
		Behavior.PATRULLA:
			# Regresa a su línea y retoma el paseo.
			var punto := _closest_point_on_line()
			if global_position.distance_to(punto) < 12.0:
				state = State.PATRULLA
			else:
				_face(punto)
				_move_towards(punto, delta)


# ===========================================================================
#  MOVIMIENTO
# ===========================================================================

## Dirección de la línea de patrulla (vector unitario).
func _patrol_axis() -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(patrol_angle_degrees))


func _patrol_end(sign_dir: float) -> Vector2:
	return _home_position + _patrol_axis() * patrol_distance * sign_dir


## Punto de la línea más cercano a donde esté ahora (para volver a ella).
func _closest_point_on_line() -> Vector2:
	var axis := _patrol_axis()
	var t: float = clampf((global_position - _home_position).dot(axis), -patrol_distance, patrol_distance)
	return _home_position + axis * t


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

	# ¿Llegó al extremo? Da media vuelta.
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

var _wander_target: Vector2 = Vector2.ZERO

func _do_wander(delta: float) -> void:
	if _wait_timer > 0.0:
		_wait_timer -= delta
		_brake(delta)
		return
		
	if _wander_target == Vector2.ZERO or global_position.distance_to(_wander_target) < 20.0:
		_wander_target = _home_position + Vector2(randf_range(-patrol_distance, patrol_distance), randf_range(-patrol_distance, patrol_distance))
		_wait_timer = randf_range(1.0, patrol_wait)
		return
		
	if state != State.ATACAR:
		_face(_wander_target)
	
	_move_towards(_wander_target, delta)


## Si choca contra una pared en mitad de la línea, se da la vuelta igual
## en vez de quedarse empujando el muro para siempre.
func _check_stuck(delta: float) -> void:
	if (behavior != Behavior.PATRULLA and behavior != Behavior.PERSEGUIR) or _wait_timer > 0.0:
		_stuck_timer = 0.0
		return
	if state != State.PATRULLA and state != State.ATACAR:
		return

	var quiere_moverse := velocity.length() > 5.0
	if quiere_moverse and get_real_velocity().length() < 5.0:
		_stuck_timer += delta
		if _stuck_timer > 0.35:
			if behavior == Behavior.PATRULLA:
				_turn_around()
			elif behavior == Behavior.PERSEGUIR:
				_wander_target = Vector2.ZERO # Force new target
				_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0


func _do_turret_sweep(delta: float) -> void:
	_brake(delta)
	if turret_sweep_degrees <= 0.0 or turret_sweep_time <= 0.0:
		return
	_sweep_time += delta
	var fase := sin(TAU * _sweep_time / turret_sweep_time)
	var objetivo := _base_rotation + deg_to_rad(turret_sweep_degrees * 0.5) * fase
	# lerp_angle en vez de asignar directo: así vuelve suave al barrido
	# después de dejar de apuntarte, sin pegar un tirón.
	global_rotation = lerp_angle(global_rotation, objetivo, clampf(delta * 6.0, 0.0, 1.0))


func _brake(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _face(point: Vector2) -> void:
	if global_position.distance_to(point) > 1.0:
		look_at(point)


func _move_towards(point: Vector2, delta: float) -> void:
	var dir := (point - global_position).normalized()
	velocity = velocity.move_toward(dir * speed, acceleration * delta)


# ===========================================================================
#  PERCEPCIÓN
# ===========================================================================

func _on_vision_body_entered(body: Node2D) -> void:
	if body == self:
		return
	if body is CharacterBody2D and not _candidates.has(body):
		_candidates.append(body)


func _on_vision_body_exited(body: Node2D) -> void:
	_candidates.erase(body)


## Devuelve el jugador visible más cercano, o null.
func _pick_visible_target() -> Node2D:
	var best: Node2D = null
	var best_dist := INF

	for c in _candidates:
		if not is_instance_valid(c):
			continue
		if not _can_see(c):
			continue
		var d := global_position.distance_to(c.global_position)
		if d < best_dist:
			best_dist = d
			best = c

	if best != null:
		_last_known_position = best.global_position
	return best


func _can_see(who: Node2D) -> bool:
	var to_target := who.global_position - global_position
	var dist := to_target.length()
	if dist > vision_range:
		return false

	# Cono de visión: el frente del enemigo es su eje X local.
	if vision_angle < 360.0:
		var facing := Vector2.RIGHT.rotated(global_rotation)
		var half := deg_to_rad(vision_angle * 0.5)
		if absf(facing.angle_to(to_target)) > half:
			# Si está pegado al enemigo, lo nota igual aunque sea por detrás.
			if dist > 60.0:
				return false

	# Línea de vista: ¿hay pared en medio?
	if vision_ray != null:
		vision_ray.target_position = to_local(who.global_position)
		vision_ray.force_raycast_update()
		if vision_ray.is_colliding():
			return false

	return true


# ===========================================================================
#  DISPARO
# ===========================================================================

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

	if visuals != null:
		visuals.fire()


# ===========================================================================
#  DAÑO Y MUERTE
# ===========================================================================

## Llamada por la bala al impactar (con empuje en la dirección del disparo).
func apply_bullet_hit(amount: float, from_direction: Vector2) -> void:
	if state == State.MUERTO:
		return
	if from_direction != Vector2.ZERO:
		velocity += from_direction.normalized() * knockback
	take_damage(amount)


## Daño genérico, sin empuje.
func take_damage(amount: float) -> void:
	if state == State.MUERTO:
		return

	health -= amount
	_flash_hit()

	# Si le disparan por la espalda, se pone alerta.
	if state == State.PATRULLA:
		state = State.VOLVER
		_give_up_timer = give_up_time

	if health <= 0.0:
		die()


func die() -> void:
	if state == State.MUERTO:
		return
	state = State.MUERTO
	velocity = Vector2.ZERO

	if visuals != null:
		visuals.set_dead(true)
	else:
		AnimNames.play(anim, AnimNames.DEAD)

	# El cadáver deja de estorbar y queda debajo de todo.
	set_collision_layer_value(3, false)
	set_collision_mask_value(2, false)
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	if vision_area != null:
		vision_area.set_deferred("monitoring", false)
	z_index = -1

	# Drop note if last enemy
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var alive_count = 0
	for e in enemies:
		if e.state != State.MUERTO:
			alive_count += 1
			
	if alive_count == 0:
		var note_scene = preload("res://Scenes/NoteItem.tscn")
		var note = note_scene.instantiate()
		get_tree().current_scene.call_deferred("add_child", note)
		note.set_deferred("global_position", global_position)


func _flash_hit() -> void:
	if anim == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	anim.modulate = Color(3.0, 3.0, 3.0, 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_property(anim, "modulate", Color.WHITE, 0.12)
