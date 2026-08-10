extends CharacterBody2D

## AGENTE PORTADOR (personaje 2)

const BALA_SCENE = preload("res://Scenes/Bala.tscn")

@export var speed: float = 150.0
@export var is_active: bool = false # El segundo personaje empieza inactivo

@export_group("Disparo")
## Segundos entre disparos (cadencia).
@export var fire_rate: float = 0.18
## A qué distancia del centro nace la bala.
@export var muzzle_distance: float = 34.0
## Si es true se puede dejar el clic presionado para disparar en ráfaga.
@export var automatic: bool = false

var start_position: Vector2
var _cooldown: float = 0.0

@onready var visuals = get_node_or_null("Visuals")


func _ready():
	start_position = global_position
	# Conectar señales globales para sincronizar el estado
	Global.character_swapped.connect(_on_character_swapped)
	Global.player_respawned.connect(_on_respawn)
	Global.player_died.connect(_on_died)

	# Aseguramos estar en el estado inicial correcto
	is_active = (Global.active_character == 1)


func _physics_process(delta):
	_cooldown = maxf(0.0, _cooldown - delta)

	# Si el jugador está muerto, se detiene
	if Global.health <= 0:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Tecla de acción E: cambiar de personaje
	if Input.is_action_just_pressed("action"):
		var next_char = 1 if Global.active_character == 0 else 0
		Global.set_active_character(next_char)

	if is_active:
		# Apuntar al cursor
		look_at(get_global_mouse_position())

		# Sistema de disparo con cadencia
		var quiere_disparar := Input.is_action_pressed("shoot") if automatic else Input.is_action_just_pressed("shoot")
		if quiere_disparar and _cooldown <= 0.0:
			if Global.use_ammo():
				shoot_bullet()
				_cooldown = fire_rate
			else:
				_cooldown = 0.25
				print("¡Sin balas! Recarga con [R]")

		# Controles de prueba universitarios
		if Input.is_key_pressed(KEY_J):
			Global.take_damage(20.0 * delta)
		if Input.is_key_pressed(KEY_H):
			Global.heal(20.0 * delta)
		if Input.is_key_pressed(KEY_R) and Global.health > 0:
			Global.reload()

		# Movimiento 4-direccional del mapa acomodado
		var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()


# Recibe señal cuando cambia el personaje activo
func _on_character_swapped(active_char_id: int):
	is_active = (active_char_id == 1)


# Función para instanciar la bala al disparar
func shoot_bullet():
	var bullet = BALA_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_rotation = global_rotation
	bullet.global_position = global_position + Vector2(muzzle_distance, 0.0).rotated(global_rotation)
	if "shooter" in bullet:
		bullet.shooter = self

	# Retroceso + fogonazo + pose de disparo
	if visuals != null:
		visuals.fire()


## Llamada por las balas enemigas al impactar.
func take_damage(amount: float) -> void:
	if Global.health <= 0:
		return
	Global.take_damage(amount)
	if visuals != null:
		visuals.flash_hit()


func _on_died():
	if visuals != null:
		visuals.set_dead(true)


# Se ejecuta al reaparecer (reinicia su posición)
func _on_respawn():
	global_position = start_position
	if visuals != null:
		visuals.set_dead(false)
