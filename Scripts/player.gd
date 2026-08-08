extends CharacterBody2D

const BALA_SCENE = preload("res://Scenes/Bala.tscn")

@export var speed: float = 300.0
@export var character_id: int = 0
@export var is_active: bool = true

@onready var camera: Camera2D = $Camera2D
@onready var muzzle: Marker2D = $Muzzle

var start_position: Vector2

func _ready() -> void:
	add_to_group("player")
	start_position = global_position
	Global.character_swapped.connect(_on_character_swapped)
	Global.player_respawned.connect(_on_respawn)
	_set_active(Global.active_character == character_id)

func _physics_process(delta: float) -> void:
	if Global.is_dead or not is_active:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if Input.is_action_just_pressed("action"):
		Global.set_active_character(1 - character_id)
		velocity = Vector2.ZERO
		move_and_slide()
		return

	look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("shoot") and Global.use_ammo():
		shoot_bullet()

	if Input.is_action_just_pressed("reload"):
		Global.reload()

	if Input.is_key_pressed(KEY_J):
		Global.take_damage(20.0 * delta)
	if Input.is_key_pressed(KEY_H):
		Global.heal(20.0 * delta)

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var forward := Vector2.RIGHT.rotated(global_rotation)
	var strafe := Vector2.DOWN.rotated(global_rotation)
	velocity = (forward * -input.y + strafe * input.x).limit_length(1.0) * speed
	move_and_slide()

func shoot_bullet() -> void:
	var bullet = BALA_SCENE.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.global_rotation = global_rotation
	bullet.setup(self, false)
	get_tree().current_scene.add_child(bullet)

func take_damage(amount: float) -> void:
	Global.take_damage(amount)

func _set_active(value: bool) -> void:
	is_active = value
	camera.enabled = value

func _on_character_swapped(active_char_id: int) -> void:
	_set_active(active_char_id == character_id)

func _on_respawn() -> void:
	global_position = start_position
	velocity = Vector2.ZERO
	_set_active(Global.active_character == character_id)
