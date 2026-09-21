extends CharacterBody2D

## Jugador (personaje 1). Armas, sigilo y flow están en el README (weapons.gd y Global.gd).

const BALA_SCENE = preload("res://Scenes/Bala.tscn")
const FloatingText := preload("res://Scripts/floating_text.gd")
const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const Weapons := preload("res://Scripts/weapons.gd")

## tiempo de clic a partir del cual el rifle dispara en ráfaga
const AUTO_DELAY := 0.17
const MELEE_RANGE := 38.0
const MELEE_HALF_ARC_DEG := 75.0
## color del aura y de los proyectiles según el flow (0 = sin flow)
const TIER_COLORS: Array[Color] = [Color("#FFB000"), Color("#22D3EE"), Color("#FFB000"), Color("#EF3E4A")]

@export var speed: float = 100.0

@export_group("Disparo")
## distancia del centro a la que nace la bala
@export var muzzle_distance: float = 34.0

var start_position: Vector2
## qué tan visible eres (1 normal, menos = más sigiloso); lo leen los enemigos
var noise_level: float = 1.0
var is_sneaking: bool = false

var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _hold_time: float = 0.0
var _melee_cd: float = 0.0
var _lunge_time: float = 0.0
var _lunge_dir: Vector2 = Vector2.RIGHT
var _shot_glow: float = 0.0
var _shake: float = 0.0
var _debug_tick: float = 0.0
var _time: float = 0.0

@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var visuals = get_node_or_null("Visuals")


## destello del cuchillo
class Slash extends Node2D:
	var color: Color = Color.WHITE
	var _t: float = 0.0

	func _init() -> void:
		z_index = 60
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= 0.16:
			queue_free()

	func _draw() -> void:
		var k := 1.0 - _t / 0.16
		var r := 28.0 + (1.0 - k) * 10.0
		draw_arc(Vector2.ZERO, r, -1.2, 1.2, 20, Color(color, k), 5.0)
		draw_arc(Vector2.ZERO, r - 6.0, -0.95, 0.95, 16, Color(1.0, 1.0, 1.0, k * 0.75), 2.5)


func _ready():
	# los enemigos buscan al jugador por este grupo
	add_to_group("player")
	start_position = global_position
	# cursor oculto y confinado a la ventana
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)

	Global.player_respawned.connect(_on_respawn)
	Global.player_died.connect(_on_died)
	Global.enemy_killed.connect(func(_pos: Vector2) -> void: add_shake(3.0))

	if has_node("Camera2D"):
		$Camera2D.make_current()


## sacude la cámara, se apaga sola
func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float):
	_time += delta
	queue_redraw()
	if camera != null:
		_shake = move_toward(_shake, 0.0, delta * 22.0)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake

	# parpadea mientras eres invulnerable (en el tutorial no)
	modulate.a = (0.45 + 0.35 * sin(_time * 28.0)) if (Global.invuln_time > 0.0 and Global.invuln_time < 100.0) else 1.0

	if visuals != null and visuals.has_method("set_material_emission"):
		var tier := Global.flow_tier()
		if tier > 0:
			# aura del flow: cyan, ámbar, rojo
			visuals.set_material_emission(TIER_COLORS[tier], 0.55 * float(tier), true)
		else:
			var danger: float = clampf(1.0 - Global.health / Global.max_health, 0.0, 1.0)
			visuals.set_material_emission(Color(1.0, 0.08, 0.04, 1.0), danger * 1.6, danger > 0.05)


func _physics_process(delta):
	_cooldown = maxf(0.0, _cooldown - delta)
	_melee_cd = maxf(0.0, _melee_cd - delta)
	_lunge_time = maxf(0.0, _lunge_time - delta)
	_shot_glow = maxf(0.0, _shot_glow - delta)

	if Global.health <= 0:
		velocity = Vector2.ZERO
		_reload_left = 0.0
		Global.reloading = false
		move_and_slide()
		return

	look_at(get_global_mouse_position())

	_handle_weapon_keys()
	_update_reload(delta)

	if Input.is_action_just_pressed("melee"):
		_melee()
	_handle_shoot(delta)

	# teclas de prueba (solo desde el editor): J daño, H curar
	if OS.is_debug_build():
		_debug_tick = maxf(0.0, _debug_tick - delta)
		if _debug_tick <= 0.0:
			if Input.is_key_pressed(KEY_J):
				take_damage(8.0)
				_debug_tick = 0.22
			elif Input.is_key_pressed(KEY_H):
				heal(12.0)
				_debug_tick = 0.22

	# 4 direcciones; Shift = sigilo; el flow te hace más rápido
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_sneaking = Input.is_action_pressed("sneak")
	var move_speed := speed * Global.speed_mult() * (0.5 if is_sneaking else 1.0)
	velocity = direction * move_speed
	if _lunge_time > 0.0:
		velocity += _lunge_dir * 240.0

	# visibilidad: sigilo < quieto < moviéndote < disparando
	if is_sneaking:
		noise_level = 0.3
	elif direction.length() > 0.1:
		noise_level = 1.0
	else:
		noise_level = 0.5
	if _shot_glow > 0.0:
		noise_level = maxf(noise_level, 1.6)

	if velocity.length() > 0:
		$AnimatedSprite2D.play("walk")
	else:
		$AnimatedSprite2D.play("idle")

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and Global.health > 0:
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_switch_weapon(posmod(Global.current_weapon - 1, Weapons.LIST.size()))
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_switch_weapon(posmod(Global.current_weapon + 1, Weapons.LIST.size()))


# armas

func _handle_weapon_keys() -> void:
	if Input.is_action_just_pressed("weapon_1"):
		_switch_weapon(Weapons.RIFLE)
	elif Input.is_action_just_pressed("weapon_2"):
		_switch_weapon(Weapons.SHOTGUN)
	elif Input.is_action_just_pressed("weapon_3"):
		_switch_weapon(Weapons.KNIFE)
	elif Input.is_action_just_pressed("weapon_next"):
		_switch_weapon(posmod(Global.current_weapon + 1, Weapons.LIST.size()))


func _switch_weapon(index: int) -> void:
	if index == Global.current_weapon:
		return
	_reload_left = 0.0
	_hold_time = 0.0
	_cooldown = 0.2  # pequeño retraso al sacar el arma
	Global.switch_weapon(index)


func _handle_shoot(delta: float) -> void:
	var def: Dictionary = Weapons.LIST[Global.current_weapon]

	# con el cuchillo el clic es melee
	if bool(def["melee"]):
		if Input.is_action_just_pressed("shoot"):
			_melee()
		return

	# un toque = un disparo, mantener (rifle) = ráfaga
	var wants := false
	if Input.is_action_just_pressed("shoot"):
		_hold_time = 0.0
		wants = true
	elif Input.is_action_pressed("shoot") and bool(def["auto"]):
		_hold_time += delta
		wants = _hold_time >= AUTO_DELAY
	else:
		_hold_time = 0.0

	if not wants or _cooldown > 0.0 or _reload_left > 0.0:
		return

	if Global.use_ammo():
		_fire_weapon(def)
		_cooldown = float(def["fire_rate"]) * Global.fire_rate_mult()
		# cargador vacío: recarga sola solo en Fácil y Normal
		if Global.ammo <= 0 and Global.can_reload() and Settings.auto_reload():
			_start_reload()
	else:
		_cooldown = 0.25
		if Global.reserve_ammo > 0:
			Global.show_message("SIN BALAS - PRESIONA R")
		else:
			Global.show_message("SIN MUNICIÓN - CUCHILLO [F] / [3]")


func _fire_weapon(def: Dictionary) -> void:
	var angle := global_position.angle_to_point(get_global_mouse_position())
	var pellets := int(def["pellets"])
	var damage := float(def["damage"]) * Global.damage_mult()
	var tier := Global.flow_tier()
	var spawn := global_position + Vector2(muzzle_distance, 0.0).rotated(angle)

	for i in range(pellets):
		var bullet = BALA_SCENE.instantiate()
		# se fijan antes de añadirla a la escena, la bala las lee en _ready
		if "shooter" in bullet:
			bullet.shooter = self
		bullet.damage = damage
		bullet.speed = float(def["speed"]) * (randf_range(0.92, 1.08) if pellets > 1 else 1.0)
		bullet.lifetime = float(def["lifetime"])
		bullet.tier = tier
		bullet.pellet = pellets > 1
		get_tree().current_scene.add_child(bullet)
		var spread := deg_to_rad(randf_range(-float(def["spread"]), float(def["spread"])))
		bullet.global_rotation = angle + spread
		bullet.global_position = spawn

	add_shake(float(def["shake"]))
	_shot_glow = 0.9

	# los enemigos cercanos oyen el disparo (la escopeta se oye más lejos)
	Global.make_noise(global_position, float(def["noise"]), global_position)

	if visuals != null:
		visuals.fire()


func _update_reload(delta: float) -> void:
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			Global.reloading = false
			Global.reload()
	elif Input.is_action_just_pressed("reload") and Global.can_reload():
		_start_reload()


func _start_reload() -> void:
	_reload_left = Global.reload_time
	Global.reloading = true


# cuerpo a cuerpo

## golpe de cuchillo a los enemigos de enfrente, sin paredes en medio
func _melee() -> void:
	if _melee_cd > 0.0 or Global.health <= 0:
		return
	var def: Dictionary = Weapons.LIST[Weapons.KNIFE]
	_melee_cd = float(def["fire_rate"]) * Global.fire_rate_mult()

	var aim := Vector2.RIGHT.rotated(global_rotation)
	_lunge_time = 0.12
	_lunge_dir = aim

	var slash := Slash.new()
	slash.color = TIER_COLORS[Global.flow_tier()] if Global.flow_tier() > 0 else Color("#E9E5D8")
	add_child(slash)

	var damage := float(def["damage"]) * Global.damage_mult()
	var space := get_world_2d().direct_space_state
	var hit := false
	for e in get_tree().get_nodes_in_group("Enemies"):
		if not (e.has_method("is_alive") and e.is_alive()):
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > MELEE_RANGE + 12.0:
			continue
		if absf(aim.angle_to(to)) > deg_to_rad(MELEE_HALF_ARC_DEG):
			continue
		# una pared bloquea el golpe
		var query := PhysicsRayQueryParameters2D.create(global_position, e.global_position, 1)
		if not space.intersect_ray(query).is_empty():
			continue
		e.melee_hit(damage, global_position)
		hit = true

	if hit:
		add_shake(3.0)


# daño y curación

## la llaman las balas enemigas al impactar
func take_damage(amount: float) -> void:
	if Global.health <= 0 or Global.invuln_time > 0.0:
		return
	Global.take_damage(amount)
	add_shake(5.0)
	if visuals != null:
		visuals.flash_hit()
	FloatingText.spawn(get_tree().current_scene, global_position, "-%d" % int(round(amount)), UIStyle.LIFE, 12)
	_burst(Color(1.0, 0.2, 0.2), 8, 90.0)


## curación (botiquín o H): parpadeo verde, número y partículas
func heal(amount: float) -> void:
	if Global.health <= 0:
		return
	Global.heal(amount)
	if visuals != null:
		visuals.flash_hit(Color(0.55, 2.2, 0.95, 1.0), 0.35)
	FloatingText.spawn(get_tree().current_scene, global_position, "+%d" % int(round(amount)), UIStyle.BAR_FILL, 12)
	_burst(Color(0.3, 1.0, 0.55), 12, 60.0, true)


## partículas alrededor del jugador (rising = suben)
func _burst(color: Color, count: int, speed_max: float, rising: bool = false) -> void:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = count
	p.lifetime = 0.5
	p.local_coords = false
	p.gravity = Vector2.ZERO
	p.direction = Vector2.UP if rising else Vector2.RIGHT
	p.spread = 40.0 if rising else 180.0
	p.initial_velocity_min = speed_max * 0.4
	p.initial_velocity_max = speed_max
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.color = color
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	get_tree().current_scene.add_child(p)
	p.global_position = global_position
	p.emitting = true
	p.finished.connect(p.queue_free)


func _on_died():
	_reload_left = 0.0
	Global.reloading = false
	if visuals != null:
		visuals.set_dead(true)


# al reaparecer
func _on_respawn():
	global_position = start_position
	if visuals != null:
		visuals.set_dead(false)
