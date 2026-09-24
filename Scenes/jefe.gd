extends CharacterBody2D

## JEFE FINAL - VERSIÓN COMPLETA
##
##   IDLE ──(te detecta)──► CHASE ◄──────────────────────┐
##                           │  ▲                         │
##             (en rango)    ▼  │ (te alejas)             │
##                         ATTACK ──(sin balas)──► RELOAD ┤
##                                                        │
##   CHASE / ATTACK ──(habilidad lista)──► SPECIAL_ATTACK ┘
##
##   cualquier estado ── vida <= 0 ──► DEAD (definitivo)

signal boss_died  ## Por si luego quieres mostrar una pantalla de victoria.

enum State { IDLE, CHASE, ATTACK, RELOAD, SPECIAL_ATTACK, DEAD }
enum SpecialStep { WINDUP, CHARGE, RECOVER }

const BALA_ENEMY_PATH := "res://Scenes/BalaEnemy.tscn"
var _bala_enemy: PackedScene = null

# ---------------------------------------------------------------------------
@export_group("Percepción")
@export var player_group: StringName = &"Players"
## Distancia a la que el jefe te detecta cuando está quieto.
@export var detection_range: float = 400.0
## Distancia a la que te pierde y vuelve a IDLE. Pon 0 para que nunca te suelte.
@export var lose_interest_range: float = 800.0

@export_group("Movimiento")
@export var speed: float = 90.0
@export var acceleration: float = 700.0
@export var friction: float = 1100.0

@export_group("Vida")
@export var max_health: float = 500.0
## Al llegar a este porcentaje de vida (0.5 = 50%) empieza la FASE 2.
@export_range(0.1, 0.9, 0.05) var phase2_health_percent: float = 0.5

@export_group("Disparo")
## A esta distancia o menos, el jefe se detiene y dispara.
@export var attack_range: float = 260.0
## Segundos entre disparos (fase 1).
@export var fire_rate: float = 0.6
## Retardo antes del primer disparo al detectarte (para que sea justo).
@export var reaction_time: float = 0.5
@export var muzzle_distance: float = 40.0
## Dispersión del disparo en grados (0 = puntería perfecta).
@export var spread_degrees: float = 4.0

@export_group("Munición")
## Balas que caben en el cargador.
@export var magazine_size: int = 12
## Balas de reserva al empezar la pelea.
@export var reserve_ammo: int = 96
## Segundos que tarda en recargar.
@export var reload_time: float = 2.0

@export_group("Habilidad especial (embestida)")
## Segundos que debe esperar entre un uso y el siguiente.
@export var special_cooldown: float = 8.0
## Tiempo de preparación: se pone rojo y se queda quieto (tu oportunidad de esquivar).
@export var special_windup: float = 0.8
## Velocidad de la embestida.
@export var special_speed: float = 450.0
## Cuánto dura la embestida (segundos).
@export var special_charge_time: float = 0.5
## Segundos que queda aturdido al terminar.
@export var special_recovery: float = 0.7
@export var special_damage: float = 30.0
## A qué distancia del centro del jefe te golpea la embestida.
@export var special_hit_radius: float = 50.0
## Solo la usa si estás entre estas dos distancias.
@export var special_min_range: float = 120.0
@export var special_max_range: float = 450.0

@export_group("Fase 2")
## Multiplica la velocidad (1.3 = 30% más rápido).
@export var phase2_speed_multiplier: float = 1.3
## Multiplica el tiempo entre disparos (0.6 = dispara 40% más rápido).
@export var phase2_fire_rate_multiplier: float = 0.6
## Multiplica el cooldown de la habilidad (0.5 = la usa el doble de seguido).
@export var phase2_special_cooldown_multiplier: float = 0.5

@export_group("Animaciones")
## Nombres tal como están en el SpriteFrames.
@export var anim_idle: String = "idle"
@export var anim_shoot: String = "attack"
@export var anim_reload: String = "recarga"
## Si no existe, usa la de disparo.
@export var anim_special: String = "habilidad"
## Si no existe, el jefe se oscurece al morir.
@export var anim_death: String = "dead"
@export var anim_up: String = "arriba"
@export var anim_down: String = "walk"
@export var anim_left: String = "izquierda"
@export var anim_right: String = "derecha"
## Cuánto tiempo se ve la pose de disparo después de cada tiro.
@export var shoot_anim_hold: float = 0.25

@export_group("Depuración")
@export var debug_print: bool = true

# ---------------------------------------------------------------------------
var state: int = State.IDLE
var health: float = 0.0
var ammo_in_mag: int = 0
var ammo_reserve: int = 0
var phase_two_active: bool = false

var _target: Node2D = null
var _shoot_timer: float = 0.0
var _shoot_anim_timer: float = 0.0
var _reload_timer: float = 0.0
var _special_timer: float = 0.0

# Valores "actuales": cambian al pasar a la fase 2.
var _speed_now: float = 0.0
var _fire_rate_now: float = 0.0
var _special_cd_now: float = 0.0

# Datos de la habilidad especial
var _special_step: int = SpecialStep.WINDUP
var _step_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
var _special_hit_done: bool = false

var _hit_tween: Tween = null

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")


func _ready() -> void:
	health = max_health
	ammo_in_mag = magazine_size
	ammo_reserve = reserve_ammo
	_speed_now = speed
	_fire_rate_now = fire_rate
	_special_cd_now = special_cooldown
	_special_timer = special_cooldown # Empieza con la habilidad "cargándose".
	_play(anim_idle)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_brake(delta)
		move_and_slide()
		return

	# Todos los cooldowns bajan solos en cada frame.
	_shoot_timer = maxf(0.0, _shoot_timer - delta)
	_shoot_anim_timer = maxf(0.0, _shoot_anim_timer - delta)
	_special_timer = maxf(0.0, _special_timer - delta)

	match state:
		State.IDLE:
			_state_idle(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.RELOAD:
			_state_reload(delta)
		State.SPECIAL_ATTACK:
			_state_special(delta)

	move_and_slide()
	_update_animation()


# ===========================================================================
#  ESTADOS
# ===========================================================================

func _state_idle(delta: float) -> void:
	_brake(delta)
	_target = _pick_target(detection_range)
	if _target != null:
		_shoot_timer = maxf(_shoot_timer, reaction_time)
		_change_state(State.CHASE)


func _state_chase(delta: float) -> void:
	_target = _pick_target(lose_interest_range)
	if _target == null:
		_change_state(State.IDLE)
		return

	_face(_target.global_position)
	var dist := global_position.distance_to(_target.global_position)

	if _try_special(dist):
		return

	var can_see := _has_line_of_sight()
	var has_ammo := _has_ammo()

	# Solo dispara si está en rango Y te ve.
	if has_ammo and dist <= attack_range and can_see:
		_change_state(State.ATTACK)
		return

	# Sin balas se acerca mucho más (para usar la embestida).
	var stop_dist := attack_range if has_ammo else 60.0
	# Si hay una pared en medio, sigue avanzando aunque esté cerca.
	if dist > stop_dist or not can_see:
		var dir := _direction_to_target()
		velocity = velocity.move_toward(dir * _speed_now, acceleration * delta)
	else:
		_brake(delta)


func _state_attack(delta: float) -> void:
	_target = _pick_target(lose_interest_range)
	if _target == null:
		_change_state(State.IDLE)
		return

	_face(_target.global_position)
	_brake(delta)
	var dist := global_position.distance_to(_target.global_position)

	# Vuelve a perseguir si te alejaste, no tiene balas o te escondiste tras una pared.
	if dist > attack_range + 40.0 or not _has_ammo() or not _has_line_of_sight():
		_change_state(State.CHASE)
		return

	if _try_special(dist):
		return

	if ammo_in_mag <= 0:
		_start_reload()
		return

	if _shoot_timer <= 0.0:
		_shoot()
		_shoot_timer = _fire_rate_now


func _state_reload(delta: float) -> void:
	_brake(delta)
	_target = _pick_target(lose_interest_range)
	if _target != null:
		_face(_target.global_position)

	# Mientras recarga NO dispara: aquí no existe ninguna llamada a _shoot().
	_reload_timer -= delta
	if _reload_timer <= 0.0:
		var needed := magazine_size - ammo_in_mag
		var taken := mini(needed, ammo_reserve)
		ammo_in_mag += taken
		ammo_reserve -= taken
		_change_state(State.CHASE)


func _state_special(delta: float) -> void:
	match _special_step:
		SpecialStep.WINDUP:
			# Preparación: quieto, mirándote y en rojo.
			_brake(delta)
			_target = _pick_target(0.0)
			if _target != null:
				_face(_target.global_position)
			_step_timer -= delta
			if _step_timer <= 0.0:
				# Fija la dirección UNA vez: así puedes esquivarlo moviéndote.
				if _target != null:
					_charge_dir = (_target.global_position - global_position).normalized()
				else:
					_charge_dir = Vector2.RIGHT.rotated(global_rotation)
				_special_step = SpecialStep.CHARGE
				_step_timer = special_charge_time

		SpecialStep.CHARGE:
			velocity = _charge_dir * special_speed
			_check_special_hit()
			_step_timer -= delta
			# Termina por tiempo o al chocar con una pared.
			if _step_timer <= 0.0 or is_on_wall():
				velocity = Vector2.ZERO
				_special_step = SpecialStep.RECOVER
				_step_timer = special_recovery

		SpecialStep.RECOVER:
			_brake(delta)
			_step_timer -= delta
			if _step_timer <= 0.0:
				_end_special()


func _change_state(new_state: int) -> void:
	if state == new_state:
		return
	if debug_print:
		print("Jefe: ", State.keys()[state], " -> ", State.keys()[new_state])
	state = new_state


# ===========================================================================
#  RECARGA Y HABILIDAD ESPECIAL
# ===========================================================================

func _has_ammo() -> bool:
	return ammo_in_mag > 0 or ammo_reserve > 0


func _start_reload() -> void:
	_reload_timer = reload_time
	_change_state(State.RELOAD)


## Si la habilidad está lista y estás a buena distancia, la usa. Devuelve true si empezó.
func _try_special(dist: float) -> bool:
	if _special_timer > 0.0:
		return false
	if dist < special_min_range or dist > special_max_range:
		return false
	if not _has_line_of_sight():   # <- NUEVA
		return false
	_start_special()
	return true


func _start_special() -> void:
	_special_step = SpecialStep.WINDUP
	_step_timer = special_windup
	_special_hit_done = false
	if anim != null:
		anim.self_modulate = Color(1.7, 0.35, 0.35, 1.0) # Aviso visual: se pone rojo.
	_change_state(State.SPECIAL_ATTACK)


func _end_special() -> void:
	if anim != null:
		anim.self_modulate = Color.WHITE
	_special_timer = _special_cd_now # Empieza el cooldown.
	_change_state(State.CHASE)


## Durante la embestida: si el jugador está muy cerca, recibe daño (una sola vez).
func _check_special_hit() -> void:
	if _special_hit_done:
		return
	if _target == null or not is_instance_valid(_target):
		return
	if global_position.distance_to(_target.global_position) <= special_hit_radius:
		_special_hit_done = true
		if _target.has_method("take_damage"):
			_target.take_damage(special_damage)


# ===========================================================================
#  PERCEPCIÓN
# ===========================================================================

## Devuelve al jugador más cercano dentro de max_range, o null.
## Con max_range = 0 no hay límite de distancia.
func _pick_target(max_range: float) -> Node2D:
	if Global.health <= 0:
		return null


	var best: Node2D = null
	var best_dist := INF
	for p in get_tree().get_nodes_in_group(player_group):
		var player := p as Node2D
		if player == null:
			continue
		var d := global_position.distance_to(player.global_position)
		if d < best_dist:
			best_dist = d
			best = player

	if best != null and max_range > 0.0 and best_dist > max_range:
		return null
	return best
	
## ¿Puede ver al objetivo? Lanza un rayo y comprueba si una pared (capa 1) lo bloquea.
func _has_line_of_sight() -> bool:
	if _target == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, _target.global_position, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

# ===========================================================================
#  MOVIMIENTO
# ===========================================================================

func _direction_to_target() -> Vector2:
	if nav_agent != null:
		nav_agent.target_position = _target.global_position
		if not nav_agent.is_navigation_finished():
			var next_point := nav_agent.get_next_path_position()
			var to_next := next_point - global_position
			if to_next.length() > 1.0:
				return to_next.normalized()
	return (_target.global_position - global_position).normalized()


func _brake(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _face(point: Vector2) -> void:
	if global_position.distance_to(point) > 1.0:
		look_at(point)


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

	ammo_in_mag -= 1
	_shoot_anim_timer = shoot_anim_hold


# ===========================================================================
#  DAÑO, FASES Y MUERTE
# ===========================================================================

## La bala llama a esta función (con dirección). El jefe no sale empujado.
func apply_bullet_hit(amount: float, _from_direction: Vector2) -> void:
	take_damage(amount)


func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return

	health -= amount
	_flash_hit()

	if health <= 0.0:
		die()
		return

	# Si le disparan estando quieto, se pone a perseguirte.
	if state == State.IDLE:
		_change_state(State.CHASE)

	_check_phase()


## Pasa a la fase 2 UNA sola vez (la variable phase_two_active lo evita repetir).
func _check_phase() -> void:
	if phase_two_active:
		return
	if health > max_health * phase2_health_percent:
		return

	phase_two_active = true
	_speed_now = speed * phase2_speed_multiplier
	_fire_rate_now = fire_rate * phase2_fire_rate_multiplier
	_special_cd_now = special_cooldown * phase2_special_cooldown_multiplier
	_special_timer = minf(_special_timer, _special_cd_now)
	_flash_hit(Color(4.0, 0.3, 0.3, 1.0), 0.6) # Destello rojo: "se enfureció".
	if debug_print:
		print("Jefe: ¡FASE 2!")


func die() -> void:
	if state == State.DEAD:
		return
	_change_state(State.DEAD)
	velocity = Vector2.ZERO

	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	if anim != null:
		anim.self_modulate = Color.WHITE
		anim.modulate = Color.WHITE
		anim.global_rotation = 0.0
		# Si no creaste la animación de muerte, se oscurece.
		if not _play(anim_death):
			anim.stop()
			create_tween().tween_property(anim, "modulate", Color(0.25, 0.25, 0.25, 1.0), 0.6)

	# El cadáver deja de estorbar y queda debajo de todo (igual que tu enemigo).
	set_collision_layer_value(3, false)
	set_collision_mask_value(2, false)
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	z_index = -1

	boss_died.emit()


func _flash_hit(color: Color = Color(3.0, 3.0, 3.0, 1.0), time: float = 0.12) -> void:
	if anim == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	anim.modulate = color
	_hit_tween = create_tween()
	_hit_tween.tween_property(anim, "modulate", Color.WHITE, time)


# ===========================================================================
#  ANIMACIÓN
# ===========================================================================

func _update_animation() -> void:
	if anim == null or anim.sprite_frames == null:
		return

	# El cuerpo rota con look_at(), pero el sprite debe verse siempre derecho.
	anim.global_rotation = 0.0

	match state:
		State.RELOAD:
			_play(anim_reload)
		State.SPECIAL_ATTACK:
			if not _play(anim_special):
				_play(anim_shoot)
		State.ATTACK:
			if _shoot_anim_timer > 0.0:
				_play(anim_shoot)
			else:
				_play(anim_idle)
		State.CHASE:
			if velocity.length() > 8.0:
				_play(_direction_anim())
			else:
				_play(anim_idle)
		_:
			_play(anim_idle)


## Elige arriba / abajo / izquierda / derecha según hacia dónde mira el cuerpo.
func _direction_anim() -> String:
	var facing := Vector2.RIGHT.rotated(global_rotation)
	if absf(facing.x) > absf(facing.y):
		return anim_right if facing.x > 0.0 else anim_left
	return anim_up if facing.y < 0.0 else anim_down


## Reproduce una animación si existe. Devuelve false si no existe.
func _play(anim_name: String) -> bool:
	if anim == null or anim.sprite_frames == null:
		return false
	if not anim.sprite_frames.has_animation(anim_name):
		return false
	if anim.animation != anim_name or not anim.is_playing():
		anim.play(anim_name)
	return true
