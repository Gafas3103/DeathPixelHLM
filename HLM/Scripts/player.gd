extends CharacterBody2D

const BALA_SCENE = preload("res://Scenes/Bala.tscn")

@export var speed: float = 300.0
@export var is_active: bool = true # Empieza activo por defecto

var start_position: Vector2

func _ready():
	start_position = global_position
	# Conectamos las señales del script de estado Global
	Global.character_swapped.connect(_on_character_swapped)
	Global.player_respawned.connect(_on_respawn)
	
	# Aseguramos estar en el estado inicial correcto
	is_active = (Global.active_character == 0)

func _physics_process(delta):
	# Si el jugador está muerto, detenemos su movimiento
	if Global.health <= 0:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Al presionar la acción (E), cambiamos al otro personaje
	if Input.is_action_just_pressed("action"):
		var next_char = 1 if Global.active_character == 0 else 0
		Global.set_active_character(next_char)

	if is_active:
		# Girar el personaje hacia el mouse
		look_at(get_global_mouse_position())

		# Sistema de disparo simple: Click Izquierdo
		if Input.is_action_just_pressed("shoot"):
			if Global.use_ammo():
				shoot_bullet()
			else:
				print("¡Sin balas! Recarga reapareciendo o en el HUD")

		# CONTROLES DE PRUEBA UNIVERSITARIOS:
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

# Se ejecuta automáticamente al cambiar de personaje en Global
func _on_character_swapped(active_char_id: int):
	is_active = (active_char_id == 0)

# Función para instanciar la bala al disparar
func shoot_bullet():
	var bullet = BALA_SCENE.instantiate()
	bullet.global_position = global_position
	bullet.global_rotation = global_rotation
	get_tree().current_scene.add_child(bullet)

# Se ejecuta al reaparecer (reiniciar posición)
func _on_respawn():
	global_position = start_position
	# Volver a activar este personaje inicial si es necesario
	Global.set_active_character(0)
