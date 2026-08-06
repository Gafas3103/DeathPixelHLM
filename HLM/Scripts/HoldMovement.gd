extends CharacterBody2D

@export var speed: float = 300.0
@export var is_active: bool = false # El segundo personaje empieza inactivo

var start_position: Vector2

func _ready():
	start_position = global_position
	# Conectar señales globales para sincronizar el estado
	Global.character_swapped.connect(_on_character_swapped)
	Global.player_respawned.connect(_on_respawn)
	
	# Aseguramos estar en el estado inicial correcto
	is_active = (Global.active_character == 1)

func _physics_process(delta):
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

		# Sistema de disparo: gasta munición
		if Input.is_action_just_pressed("shoot"):
			if Global.use_ammo():
				print("¡Holding disparó! Balas restantes: ", Global.ammo)
			else:
				print("¡Sin balas!")

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

# Se ejecuta al reaparecer (reinicia su posición)
func _on_respawn():
	global_position = start_position
